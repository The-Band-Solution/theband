# ADR 0007 — Gestor de cotas: a cota é do usuário, um processo a governa, e a coleta volta de onde parou

## Status

Aceita — 2026-09-05 ("implemente"). Emendada no mesmo dia pela implementação, nos dois
pontos marcados **Emenda** abaixo.

Depende de: [ADR 0006](0006-coleta-paralela.md) — hibernar sem dormir é o que a espera do gestor aciona
Relacionada: [ADR 0005](0005-telemetria-da-jornada.md) — a J2 observa a espera que este ADR decide

Estudo pedido em 2026-09-05 ("como o problema é a cota compartilhada, podemos
fazer um gestor de cotas no qual voltamos de onde paramos"). Nada aqui está implementado.
A decisão de aceitar é do Product Owner; a ordem de entrega proposta está na seção
"Entrega".

Sucede a ADR 0006 e a fecha: a ADR 0006 decidiu paralelizar e hibernar; esta decide **quem
sabe quanto resta** e **de onde a coleta retoma**.

## Contexto

### O que a avaliação da alternativa Broadway concluiu

Dois agentes (técnico e Product Owner) avaliaram Broadway em 2026-09-05 e recusaram pelo
mesmo motivo: **o gargalo da coleta não é distribuição de trabalho, é uma cota compartilhada
que ninguém coordena.** Distribuir mais rápido o que bate na mesma cota só antecipa o 403.

### Como a cota funciona na origem — conferido na documentação do GitHub em 2026-09-05

| fato | consequência para o The Band |
|---|---|
| A cota primária REST é **5 000 requisições por hora, por usuário autenticado**. Todos os tokens do mesmo usuário contam no mesmo saldo ("all of these requests count towards your personal rate limit"). | **A cota não é do token, nem da ferramenta conectada, nem do tenant.** Dois tenants com PATs do mesmo usuário dividem 5 000. Hoje nada no modelo sabe disso: o login do dono do token é descartado em três lugares. |
| A cota GraphQL é **5 000 pontos por hora**, num saldo **separado** do REST. | São dois baldes. Esgotar um não fecha o outro — a coleta pode seguir na GraphQL enquanto a REST reabre, e vice-versa. Hoje a espera do job lê o balde errado em um dos caminhos (corrigido em #806, mas por remendo). |
| Cotas secundárias: **100 requisições concorrentes**, **900 pontos/min REST**, **2 000 pontos/min GraphQL**, 80 criações de conteúdo/min. Sinalizadas com 403 ou 429 e, às vezes, `retry-after`. | A concorrência total em voo por usuário precisa de um **teto global**, não só por etapa. Hoje: 5 slots Oban × 3 etapas com fan-out 5 = até **25 em voo** por PAT, sem ninguém contando. |
| Cabeçalhos `x-ratelimit-limit`, `-remaining`, `-used`, `-reset`, `-resource` vêm em **toda** resposta REST. Na GraphQL, o objeto `rateLimit { cost remaining resetAt }` vem no corpo quando pedido. | **A origem conta por nós.** Um gestor não precisa contar requisições: precisa ler o que a última resposta disse e corrigir pelo que ainda está em voo. Contar por conta própria erra sempre que o mesmo usuário usa o token fora do The Band. |
| `GET /rate_limit` **não consome a cota primária** (consome secundária). | É a fonte para reconstruir o estado quando o processo nasce ou o reset passa. Não serve para consultar a cada requisição. |
| Recomendação oficial: não tentar de novo antes de `x-ratelimit-reset`; para secundária, respeitar `retry-after` ou esperar ≥ 1 min com recuo exponencial. | É o que a ADR 0006 §5 já faz com `{:snooze}`. O que falta é **decidir antes**, e num só lugar. |

### O que o código faz hoje — inventário de 2026-09-05

**Seis portas de saída, quatro políticas.** Toda requisição ao GitHub passa por
`HTTP.impl().get/2` ou `.post/3`, mas o cliente as chama em seis lugares distintos
(`verify_credential`, `commit_files`, `workflow_runs`, `run_jobs`, `graphql`,
`segundos_ate_reabrir`). Não há um `request/1` único. Sobre essas portas, quatro políticas
de cota diferentes cresceram:

| etapa | política de cota | de onde lê |
|---|---|---|
| EO (organização, membros, equipes) | `pause_needed?`: `remaining < cost × 2` → `{:snooze}` | `rateLimit` da GraphQL |
| verificações (REST) | `pausar_se_a_janela_encurtou`: `remaining < 2 × concorrência` → `{:snooze}` (desde #806) | cabeçalhos das respostas 200 |
| arquivos de commit (REST) | `esperar_janela`: **`Process.sleep`** até o reset, no processo do job (o sync desliga com `wait_for_rate_limit: false`) | cabeçalhos do 403 |
| repositórios, issues, projetos, comentários, mudanças, branches (GraphQL) | **nenhuma** — recebem `rate_limit` e descartam; só descobrem a cota pelo erro | — |

**Vinte e cinco em voo, zero coordenação.** Fan-out de 5 dentro de três etapas
(`github_verifications`, `github_issue_comments`, `github_change_requests`), 5 slots na fila
`ingestion`, e a tela permite disparar uma sincronização por ferramenta sem serializar. A
mesma PAT pode estar registrada em N ferramentas de N tenants: nenhum índice impede, nenhum
processo enxerga.

**"Voltar de onde parou" hoje é parcial.** A tabela `sync_checkpoints` existe
(`entity_type`, `cursor`, `page_count`, `status`) e só as etapas EO gravam cursor — e o zeram
ao completar, então a retomada refaz a paginação do início. Projetos e branches não têm
marcador nenhum e são refeitos por inteiro a cada retomada. Issues, comentários, mudanças e
verificações retomam pelo `*_collected_at` do repositório, o que funciona. Um `{:snooze}` na
sexta etapa refaz as requisições das etapas um, dois e sete na volta.

**A tela mostra um contador regressivo.** `SyncLive.Index` exibe apenas os segundos que
vieram na mensagem `{:sync_paused, _, s}`, apagados pela próxima mensagem de progresso.
Ninguém vê quanto resta, quando reabre, nem quantas requisições estão em voo.

**Nó único.** Um container no Dokploy, sem distribuição Erlang, sem `libcluster`. Estado em
memória de VM é correto hoje. A seção "Consequências" diz o que muda com dois nós.

## Decisão proposta

### O que fica onde — a pergunta "gravar em banco para voltar?"

Três estados diferentes, três lugares, e o motivo de cada um:

| estado | onde mora | por quê |
|---|---|---|
| **onde parei** — etapa, cursor, repositório, `done` | **banco**, `sync_checkpoints` (já existe) | precisa sobreviver a deploy, reinício e queda; é o que a retomada lê |
| **quando volto** — `scheduled_at` do job | **banco**, `oban_jobs` (já é assim) | o snooze do Oban é uma linha no Postgres; o servidor cai no meio da espera, sobe, e o job acorda na hora certa |
| **quanto resta** — `remaining`, `reset`, `em_voo`, `esperando` | **memória**, o `GenServer` | reconstruível em **uma** chamada grátis a `/rate_limit`; uma cópia no banco fica velha no instante em que é gravada (o dono gasta cota fora do The Band e ela não sabe) e custaria uma escrita por requisição. A origem é a verdade; o gestor é cache |

Só a terceira linha muda de lugar quando houver um segundo nó — ver Consequências.

Seis partes, na ordem em que se entregam. Cada uma tem um consumidor visível; nenhuma é
infraestrutura sozinha.

### 1. A identidade da cota é o usuário do GitHub, e ela passa a ser gravada

`Client.verify_credential/2` já devolve `%{login: ..., scopes: ...}`. Os três chamadores
descartam o `login`. Passa a ser gravado em `tool_credentials.owner_login` na validação da
credencial, e a **chave da cota** é:

```
{instance_url, owner_login}
```

Não é o token (dois tokens do mesmo usuário dividem saldo), não é a ferramenta conectada,
não é o tenant. **Dois tenants com PATs do mesmo usuário passam pelo mesmo gestor** — e
isso é correto, porque é assim que o GitHub conta. O gestor não guarda o token nem sabe de
que tenant veio a requisição: só conta.

A tela de credenciais mostra o dono do token ao lado dos últimos quatro dígitos. Se duas
ferramentas do tenant têm o mesmo dono, a tela diz: "estas duas ferramentas dividem a
mesma cota de 5 000 requisições por hora".

### 2. Um processo por identidade: `TheBand.Ingestion.Cota`

Um `GenServer` por chave, sob um `DynamicSupervisor`, localizado por `Registry`. Nasce na
primeira requisição da chave e morre ociosa depois de uma hora sem uso.

**Estado**, por balde (`:core` para REST, `:graphql`):

```
%{limit: 5000, remaining: 4212, reset: ~U[...], em_voo: 3, esperando: 2, visto_em: ~U[...]}
```

**Três chamadas:**

```elixir
Cota.pedir(chave, balde, custo)     # :ok | {:espera, segundos}
Cota.observar(chave, balde, leitura) # cabeçalhos REST ou rateLimit GraphQL
Cota.estado(chave)                   # para a tela e para os testes
```

**A regra de concessão:**

```
concede se  remaining  ≥  custo × (em_voo + 1 + teto)
teto = concorrência total em voo permitida (global, 10)
```

> **Emenda (2026-09-05, implementação).** A proposta original era
> `remaining − em_voo − custo ≥ margem`, em requisições. Na GraphQL a unidade é **ponto**, e
> uma consulta do conector custa 100: com 150 pontos sobrando a regra original concedia, e a
> próxima página consumiria dois terços do que restava. A regra passou a contar em unidades
> do balde — na REST (custo 1) ela se reduz à original — e o gestor usa o **maior** entre o
> custo estimado pelo cliente e o último custo visto na identidade, porque o custo de uma
> consulta só se conhece depois dela.

`em_voo` já está na conta — por isso a margem é a concorrência, e não `2 × concorrência`
como hoje. Quem não é concedido recebe `{:espera, segundos_até_reset + 60}` e o
estágio traduz para `{:snooze}` como já faz. Ninguém dorme dentro do gestor, ninguém dorme
no job: a espera é do Oban, como decidiu a ADR 0006 §5.

**A verdade são os cabeçalhos, não a contagem.** `observar/3` substitui `remaining` e `reset`
pelo que a resposta mais recente disse (ordenado por `visto_em`, porque respostas
concorrentes chegam fora de ordem) e decrementa `em_voo`. Se o usuário gastou cota fora do
The Band, o próximo cabeçalho corrige. Contar sozinho — como faria um token bucket local
(`Hammer`, `ExRated`) — erra exatamente nesse caso.

**Reset.** Quando `now ≥ reset`, o saldo volta a **desconhecido** e o gestor concede; a
primeira resposta da janela nova traz o saldo real e corrige.

> **Emenda (2026-09-05, implementação).** A proposta era uma chamada a `GET /rate_limit`
> no reset e ao nascer. Ela exigiria o token **dentro** do processo — e a mesma seção
> decide que o processo não guarda segredo. O custo de não fazê-la é, no pior caso, até
> `teto` requisições concedidas no escuro que voltam 403 se o dono gastou a cota fora do The
> Band; o 403 é tratado como hoje e a leitura seguinte corrige. `/rate_limit` continua sendo
> o que o job consulta para saber quanto esperar quando a GraphQL recusa sem dizer o reset.

**Cota secundária.** O teto de `em_voo` (10) fica abaixo dos 100 concorrentes. Para os 900
pontos/min REST: 10 em voo com latência de ~300 ms produzem ~33 req/s no pior caso, acima do
teto por minuto em rajada. O gestor registra `retry-after` quando vier e recusa até ele
passar; um limitador por minuto entra só se a medição mostrar 429 — não antes.

### 3. Uma porta de saída: todo request passa pelo gestor

`Client` ganha uma função interna única:

```elixir
defp requisitar(ctx, balde, custo, fun)  # fun.() faz o HTTP.impl().get/post
```

que faz `Cota.pedir` antes, executa, `Cota.observar` com a resposta depois, e traduz
`{:espera, s}` para `{:error, {:rate_limited, reset}}` — o mesmo erro que os estágios já
tratam. Os seis pontos de saída passam a chamar `requisitar/4`.

Com isso, **saem** quatro tratamentos:

- `pause_needed?/1` no `do_paginate` do job;
- `pausar_se_a_janela_encurtou/2` e `margem_da_janela/0` nas verificações;
- `esperar_janela/1` com `Process.sleep` nos arquivos de commit;
- o descarte silencioso de `rate_limit` nos cinco estágios que não tratavam nada — passam a
  ter pausa preventiva sem escrever uma linha.

`Client.rate_limit?/1` e `transient?/1` continuam: são a tradução do erro, e o gestor não
muda o que o erro significa.

### 4. A retomada: checkpoint por etapa, cursor gravado, etapa concluída não refaz

`sync_checkpoints` já existe. Passa a ser usada por **todas** as etapas, com duas mudanças:

- **Cursor gravado a cada página** em todas as paginações GraphQL — não só nas EO. Para as
  etapas por repositório, o `entity_type` inclui o repositório
  (`"github.change_request:<repo_id>"`), e o cursor é o `endCursor` da última página gravada.
- **Ao completar, `status: "done"` em vez de `cursor: nil`.** Na retomada do mesmo `sync_id`,
  uma etapa `done` é pulada. Uma etapa em curso retoma do cursor. Uma etapa sem checkpoint
  começa.

O que isso fecha, medido no inventário:

| etapa | hoje na retomada | depois |
|---|---|---|
| EO (org, membros, equipes) | refaz a paginação do início | pulada |
| projetos e quadros | refeita por inteiro, sem marcador | pulada ou retomada do cursor |
| branches | refeita por inteiro (`branches_collected_at` é escrito e nunca lido) | pulada |
| issues, comentários, mudanças, verificações | incremental por `*_collected_at` | igual, mais o cursor dentro do repositório em curso |
| arquivos de commit | continua de `files_collected_at IS NULL` | igual |

**O que não muda:** o `sync` continua `running` durante a espera (ADR 0006 §5). O
`*_collected_at` continua sendo o corte incremental **entre** sincronizações; o checkpoint é
o corte **dentro** de uma.

> **Emenda (2026-09-05, implementação).** A unidade de retomada **dentro** de uma etapa
> é o repositório, e não a página. As etapas por repositório acumulam as páginas em
> memória e gravam no fim (`paginar` → `gravar`); um cursor por página só valeria se cada
> página fosse gravada ao chegar, o que muda a estrutura das seis etapas. O que entrou:
> `etapa:<nome>` marcada `completed` ao fim de cada etapa (a etapa concluída não roda de
> novo na retomada), o mesmo teste para as entidades EO (que já tinham cursor por página e
> agora também têm "concluída"), e as branches passaram a pular o repositório percorrido
> nesta sincronização — a marca era escrita e nunca lida. Custo do que ficou de fora: um
> `{:snooze}` no meio de um repositório refaz as páginas **daquele** repositório na volta
> — no maior da organização medida, dez páginas. Cursor por página nas etapas por
> repositório fica para quando a medida real (Verificação 4) mostrar que isso pesa. A
> consulta da **organização** roda a cada passada — uma requisição: ela é o pai do contexto
> (`organization_node`), e reconstruí-la do payload preservado não valia o custo de uma
> chamada por retomada.

### 5. A tela: a cota é visível, com nome

Princípio IV: nada na tela sem declaração — e o inverso também vale: nada que decide fica
invisível. `SyncLive.Index` ganha um painel por identidade de cota:

```
Cota de paulo-junior em github.com
REST      4 212 / 5 000   reabre 14:32   3 em voo
GraphQL   3 980 / 5 000   reabre 14:07   1 em voo   2 sincronizações esperando
```

Alimentado por `Cota.estado/1` e por um `{:cota, chave, estado}` no PubSub a cada
`observar/3`. O contador regressivo atual vira uma linha desse painel, com o motivo
("REST esgotada, reabre em 12 min") em vez de um número solto.

### 6. As etapas são um grafo, e a próxima é a que tem dependência pronta e balde aberto

Hoje `coletar_trabalho/1` é uma lista fixa de sete etapas, e a espera de qualquer uma fecha
o job inteiro. Mas os dois baldes são independentes: quando a GraphQL esgota, a REST está
cheia — e as etapas REST não precisam da GraphQL para andar.

Cada etapa passa a declarar **balde** e **dependências** (conferido no código em
2026-09-05):

| etapa | balde | depende de |
|---|---|---|
| EO — organização, membros, equipes | GraphQL | — |
| 1 repositórios e issues | GraphQL | EO |
| 2 projetos e quadros | GraphQL | 1 |
| 3 comentários de issues | GraphQL | 1 (as issues precisam existir) |
| 4 solicitações de mudança | GraphQL | 1 |
| 5 arquivos de commit | **REST** | 4 (os commits são gravados pela etapa 4) |
| 6 verificações | **REST** | 1 (só precisa dos repositórios observados) |
| 7 branches | GraphQL | 1 |

**A regra de escolha**, no lugar da lista: a próxima etapa é a que tem **todas as
dependências `done`** no checkpoint deste sync **e cujo balde tem janela**
(`Cota.estado/1` acima da margem). Se nenhuma etapa pronta tem janela, o job hiberna até o
**menor** `reset` entre os baldes que desbloqueiam alguma coisa — e não até o reset do
balde que acabou de fechar.

O que isso muda, com a cota GraphQL esgotada logo depois da etapa 1 (o caso medido em
2026-09-05):

| | hoje | com a parte 6 |
|---|---|---|
| a GraphQL fecha após a etapa 1 | job hiberna até o reset da GraphQL; REST intocada | etapa 6 (verificações, REST) roda enquanto a GraphQL reabre |
| a REST fecha no meio da etapa 6 | job hiberna | etapas 2, 3, 4 e 7 (GraphQL) rodam; a 6 retoma do cursor quando a REST reabrir |
| ambas fechadas | hiberna | hiberna — até o menor reset |

Uma hora inteira de um balde deixa de ser desperdiçada enquanto o outro reabre.

**O que NÃO muda:** o resultado. Ordem diferente, mesmos dados — as dependências garantem
que nenhuma etapa lê o que ainda não foi gravado. É por isso que elas são **declaradas**
no código e conferidas por teste, e não deduzidas: uma etapa que rodasse antes da sua
dependência **não falharia** — coletaria zero, contaria zero, e marcaria `done`. É o
sucesso silencioso que a base já registrou oito vezes, e a Verificação 5 existe para ele.

**O que fica de fora desta parte:** rodar um estágio REST e um GraphQL **ao mesmo tempo**.
Os baldes primários são separados, mas a cota secundária (100 em voo, CPU) é uma só, e o
job hoje é um processo com uma sequência. Primeiro a escolha pela disponibilidade,
sequencial; concorrência entre baldes só depois da Verificação 4 medir onde está o tempo.

## Alternativas consideradas

**Contadores em ETS, sem processo.** `:ets.update_counter` é mais rápido e não tem fila.
Mas não há quem espere: sem processo dono, "quem pediu e não conseguiu" não existe, e a
tela não tem `esperando`. Velocidade não é o problema — 5 000 req/h são 1,4 req/s; um
`GenServer.call` custa microssegundos.

**Token bucket local (`Hammer`, `ExRated`).** Contam o que **nós** fizemos. A cota é do
usuário, e o usuário usa o token no navegador, no `gh`, em outro sistema. O único dado
autoritativo é o cabeçalho da origem. Rejeitado pelo mesmo motivo que a base rejeita
"limitação declarada sem olhar o dado".

**Rate limiter do Oban Pro.** Pago, e limita por **fila**, não por identidade de cota. Duas
ferramentas do mesmo usuário em jobs diferentes continuariam sem coordenação.

**Estado no banco (`quota_windows`).** Correto para vários nós e sobrevive a reinício. Mas
cada requisição faria uma escrita, e o estado é reconstruível em uma chamada a
`/rate_limit`. Adiado: entra quando houver um segundo nó (ver Consequências), com o
`GenServer` virando cache e o banco a verdade.

**Broadway.** Recusado em 2026-09-05 pelos dois agentes; ADR 0006, Alternativas. Este ADR
é o que se propôs no lugar.

**Um processo por token em vez de por usuário.** Errado na origem: dois tokens do mesmo
usuário dividem saldo, e o gestor concederia o dobro do que existe.

## Consequências

**Ganha-se:**

- Uma política de cota, num lugar, para os sete estágios — inclusive os cinco que hoje não
  têm nenhuma.
- Nenhum 403 de cota primária em operação normal: o gestor recusa antes.
- Retomada sem refazer o que já foi feito — a ADR 0006 §5 passo 4 generalizada.
- A tela diz quanto resta e por que espera.
- A duplicidade de PAT entre ferramentas e tenants deixa de ser invisível.

**Paga-se:**

- Um `GenServer` por identidade é ponto de serialização. Em 1,4 req/s é irrelevante; fica
  declarado para quem medir com dez identidades ativas.
- Se o processo morrer, `em_voo` e `esperando` se perdem; `remaining`/`reset` voltam na
  primeira resposta ou numa chamada a `/rate_limit`. Perda aceitável: o pior caso é um 403
  a mais, tratado como hoje.
- **Dois nós** quebram a hipótese: cada nó teria seu gestor, e os dois somariam o dobro.
  Não é o caso hoje (um container, sem distribuição). Quando for, a alternativa "estado no
  banco" entra, e este ADR ganha uma emenda. Fica declarado aqui para não virar surpresa.
- `owner_login` é dado pessoal do dono do token (login público do GitHub). Fica na mesma
  tabela cifrada da credencial, visível só a quem já vê a credencial. Sem novo risco de
  exposição; registrado para a avaliação de segurança.
- O gestor precisa de um token para chamar `/rate_limit` no reset e ao nascer. Recebe o
  token **por chamada**, nunca no estado — o processo não pode ser o lugar onde um segredo
  sobrevive à requisição.

## Verificação

Quatro provas, nenhuma de suíte verde: a medida é na origem ou no contador.

1. **Zero 403 sob concorrência.** Com o mock devolvendo `remaining` decrescente a partir de
   15 e 25 requisições concorrentes por uma chave, o gestor concede exatamente até a margem
   e nenhum 403 é produzido. Hoje: 25 em voo e 403 garantido.
2. **Dois tokens, um saldo.** Duas ferramentas conectadas com PATs do mesmo `owner_login`
   caem no mesmo processo e o segundo `pedir` vê o `em_voo` do primeiro.
3. **Retomada não refaz.** `{:snooze}` na quarta etapa; na volta, as etapas um a três não
   produzem **nenhuma** requisição (contador no mock). Hoje: EO e projetos refazem.
4. **Medida real.** Coleta completa da organização `leds-conectafapes` do zero, com o
   painel aberto: número de 403 (esperado 0), tempo total, e a menor `remaining` vista em
   cada balde. É a Verificação 1 da ADR 0006 que a cota impediu de medir — com o gestor,
   ela cabe numa janela.
5. **Nenhuma etapa antes da sua dependência, e a REST anda com a GraphQL fechada.** Com o
   mock fechando a GraphQL logo após a etapa 1: o job executa a etapa 6 (verificações) e
   **não** executa a 3 (comentários) nem a 5 (arquivos, que dependem da 4). Segunda parte
   da mesma prova: uma etapa cuja dependência não está `done` nunca é escolhida — o
   contador do mock para ela é zero, e não "zero coletado com sucesso".

## Entrega

Ordem proposta, cada item com tela ou medida no fim. O Product Owner decide o que entra
e quando.

| ordem | entrega | consumidor visível |
|---|---|---|
| 1 | `owner_login` gravado e exibido; aviso de cota compartilhada entre ferramentas | tela de credenciais |
| 2 | `Cota` + `requisitar/4` na porta única; remoção das quatro políticas locais; painel mínimo (remaining, reset, em voo) | `SyncLive.Index`; Verificações 1 e 2 |
| 3 | checkpoint com `done` e cursor em todas as etapas | Verificação 3; retomada visível no painel ("etapa 4 de 7, página 12") |
| 4 | medida real da coleta completa, e emenda a esta ADR com os números | Verificação 4; ADR 0006 Verificação 1 |
| 5 | etapas como grafo: balde e dependências declaradas, escolha pela disponibilidade | painel mostra "verificações adiantadas: GraphQL reabre 14:07"; Verificação 5 |

Fora deste ADR: estado no banco para multi-nó; limitador por minuto para a cota secundária
(só se a medida 4 mostrar 429); etapas REST e GraphQL em concorrência (só depois da medida 4).

## Referências

- ADR 0006 — Coleta paralela, §5 (hibernar sem dormir) e Alternativas (Broadway).
- Avaliação Broadway pelos agentes técnico e Product Owner, 2026-09-05 (transcrita no
  relatório da PR #806).
- GitHub Docs, "Rate limits for the REST API" e "Rate limits and node limits for the GraphQL
  API", lidos em 2026-09-05.
- Inventário do código em 2026-09-05: `client.ex` (seis portas), `sync_github_eo.ex`
  (ordem das etapas, snooze), `checkpoint.ex` e `sync_checkpoints`, `SyncLive.Index`,
  `application.ex`, `Dockerfile`, `docs/producao/runbook.md`.
