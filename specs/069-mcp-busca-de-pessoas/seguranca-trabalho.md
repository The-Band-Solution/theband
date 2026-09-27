# Avaliação de segurança — 069, parte 2: `person_open_work`

Papel: Security (AGENTS.md §13, §14.0). Avaliação **antes do plano**, feita por quem não escreveu
o desenho. Escopo: só `person_open_work`. `people_search` tem avaliação própria.

## 1. Comparação por iteração (ponto 2 da seção Segurança)

**A descrição não basta como controle, e um limite próprio não resolve. O que falta é um sinal
no registro.**

- **A descrição (FR-019) não é controle.** Quem a lê é o modelo, e quem decide iterar é quem
  instrui o modelo. É texto de orientação, útil contra o uso ingênuo, e nulo contra o uso
  deliberado. Não protege nada que se precise afirmar protegido;
- **um limite próprio não separa uso legítimo de ataque.** Com o teto de 120 chamadas por minuto
  por token (FR-021), uma conta que alcança algumas dezenas de pessoas — o `access.ex:456-457`
  cita 88 pessoas no dado real — lê todas em menos de um minuto. Um limite baixo o bastante para
  impedir isso (p. ex. 10 pessoas por hora) quebra a pergunta legítima do líder que revê a
  equipe pessoa a pessoa, e um limite alto não impede nada;
- **o que a conta monta não é dado novo.** Cada `person_open_work` concedido é uma pessoa que
  `pode_ver/3` já abre na tela. A FR-024 da 045 aceitou o risco de agregação e apontou o
  **registro de acesso** como o caminho para percebê-lo (`show.ex:292-299` repete isso). O dano,
  aqui, é o ranking que a plataforma se recusa a produzir; não é quebra de confidencialidade.

O que muda com o MCP é a **escala e o automatismo**: o que na tela custa uma tarde de cliques
custa um minuto a um agente. A FR-020 já grava cada concessão com `token_public_id` e alvo
(`ferramentas.ex:193-199`), então o fato fica registrado — **mas só é percebido por quem
consultar**, e nada consulta.

### A1-1 — varredura de pessoas é registrada e não sinalizada (média)

**Caminho**: um token de conta com escopo de organização é usado para pedir `person_open_work`
de cada pessoa alcançada, em sequência, e o agente monta a tabela *"quem tem mais tarefas
paradas"*. Tudo sai concedido, tudo fica em `api_access_reads`, e nenhum evento em `warning`
acontece — o nível que se filtra primeiro num incidente (`access_events.ex:157-161`).

**Severidade: média** — ausência de registro que impede perceber a agregação que a FR-024 da 045
diz que o registro perceberia.

**O que fecha** (FR nova, sem bloqueio): um evento `leitura_em_lote` em `AccessEvents`, em
`warning`, quando um token lê mais de *N* pessoas **distintas** por `person_open_work` numa
janela *T*, com `token_public_id`, contagem e janela — e **nunca** a lista de pessoas. *N* e *T*
são número mágico se não tiverem razão escrita: proponho *N* = o tamanho da maior equipe vigente
do tenant, porque rever a própria equipe é o uso legítimo mais largo, e *T* = 1 hora. O sinal
**não recusa**: recusar seria a plataforma impedindo a pergunta legítima, que a spec já decidiu
não fazer.

Pela L69, a decisão tem de ser **relator de retorno**, e o log um registro dela: a função que
decide devolve `{:em_lote, contagem}` ou `:normal`, e o teste assere sobre isso, com o caso
*N* + 1 disparando e o caso *N* não disparando (`refute`).

Se o Product Owner decidir não criar o sinal, a spec registra o risco como **aceito**, com a
frase: *"a agregação por iteração é percebida só por consulta ao registro de leituras"*.

## 2. Dado de pessoa exposto a modelo (ponto 3)

(em avaliação)

## 3. FR-008, "em todo o tenant": alcance da tarefa versus alcance da pessoa

**Resposta curta: sim, a tarefa pode vir de repositório, projeto ou organização que a conta não
alcança por outra via. Isso não vaza nada que a tela já não mostre à mesma conta. Mas a spec
não pode calar sobre isso, porque o MCP entrega a um modelo o que a tela mostra a uma pessoa.**

Evidência:

- `pode_ver/3` (`lib/the_band/tenants/access.ex:226`) decide sobre a **pessoa**, e não sobre a
  tarefa. `comparar_com_alvo/3` (`access.ex:445`) concede quando a conta tem escopo de equipe
  que cruza as equipes vigentes do alvo, ou escopo de organização que cruza as organizações do
  alvo (equipe promovida **ou** evidência observada, `access.ex:455-459`). Em nenhum momento
  pergunta de qual projeto ou organização é o trabalho que a pessoa tem;
- a tela, com o `{:ok, _}`, lê `WorkItems.list_issues(tenant, assigned_to: pessoa.id, ...)`,
  `count_assigned_to/2` e `timeline_coverage/2`
  (`lib/the_band_web/live/people_live/show.ex:421`, `:319`, `:463-470`), todas só por tenant e
  pessoa. O cartão *assigned, not done* (`show.ex:584`) é `@designadas_abertas`, que vem de
  `timeline_coverage/2` (`show.ex:318-319`, `:428`);
- o próprio `access.ex:470-484` registra por que o escopo de projeto **deixou** de abrir painel
  de pessoa: *"alcançava o painel completo de qualquer pessoa cuja equipe tocasse aquele projeto,
  incluindo o trabalho dela em outros projetos"*. O mesmo raciocínio se aplica, em escala menor,
  ao escopo de organização: quem tem escopo sobre a organização A alcança uma pessoa observada em
  A e lê as tarefas dela na organização B do mesmo tenant. É o regime que a pessoa mantenedora
  decidiu em 2026-09-09 (*"quem tem o escopo de team, organization e admin podem ver"*,
  `access.ex:273-276`), e a tela o aplica hoje.

Conclusão por ferramenta:

| Porta | O que a conta com escopo sobre a organização A lê de uma pessoa de A e B |
|---|---|
| tela da pessoa | todas as issues atribuídas, de A e de B, com título (`show.ex:463`) |
| `person_open_work` (FR-008) | as mesmas, com título, em lote de até 200, para um modelo |

**Severidade: média.** Não há dado de outro tenant nem contorno do veredito, então não é alta.
É média porque (a) a garantia de que o MCP não amplia o alcance fica escrita em lugar nenhum da
spec, e o segundo implementador pode "melhorar" filtrando por outra coisa ou deixar de filtrar;
(b) FR-032 da 062 diz que o que o modelo lê pode ser guardado do outro lado, e títulos de
repositório privado de B indo para um provedor externo é consequência que o regime da tela não
tinha.

**Consequência para o negócio**: quem tem escopo só sobre a organização A manda para o agente
dele os títulos das tarefas que uma pessoa compartilhada tem na organização B.

**O que fecha** (decisão do Product Owner, com duas alternativas):

1. **declarar** na spec que o alcance da tarefa segue o da pessoa, citando `access.ex:445` e a
   decisão de 2026-09-09, e que `person_open_work` não é mais estrito que a tela nesse eixo; ou
2. **restringir** as tarefas às organizações/equipes que a conta alcança (margem maior, como a
   FR-016 fez com a identidade). Custa uma divergência a mais com a tela, e precisa ser escrita.

Qualquer das duas vira FR. O teste, em ambos os casos, usa **duas organizações povoadas** no
mesmo tenant, uma pessoa com tarefa aberta nas duas, e uma conta com escopo só sobre A; a
asserção é sobre quais `issue_id` saem, e ela tem de ser igual à lista da tela (alternativa 1)
ou só a de A (alternativa 2).

### Achado lateral, fora do escopo desta avaliação: a tela não é um oráculo limpo

A FR-016 afirma que *"a tela mostra a identidade de qualquer pessoa do tenant e esconde só o
trabalho"*. Não é bem assim: a seção `#provenance` (`show.ex:1552`) **não** tem guarda
`@ve_o_trabalho?`, e renderiza `@mudancas` (títulos de PRs que a pessoa abriu, revisou e
integrou, `show.ex:1710-1745`) e `@participacao` (discussões, `show.ex:1789-1801`).
`Changes.by_person/3` (`lib/the_band/changes.ex:163`) filtra só por tenant e pessoa, e os
assigns são lidos sem `se_pode` (`show.ex:350`, `:353`). Uma conta **sem** alcance sobre a
pessoa lê os títulos das mudanças dela.

Não verifiquei se isso é regime decidido (identidade de trabalho = o que a pessoa mudou) ou
omissão — o H2-R de 2026-09-24 foi exatamente uma seção fora do veredito por omissão. Registro
aqui para triagem própria (issue `security`), com severidade provável **média**, e com uma
consequência para esta spec: **"o mesmo que a tela" não pode ser a régua de alcance do MCP**,
porque a tela tem pelo menos uma seção que não passa pelo veredito. A régua é `pode_ver/3`.

## 4. FR-013/FR-014: o caminho único com `person_id`

### O que existe hoje

`chamar/5` (`lib/the_band/mcp/ferramentas.ex:153-159`) é um `with` de três passos: `buscar/1`
(nome da ferramenta), `team_id/1` (argumento, `:168-180`) e `com_equipe/5` (`:182-209`), que
carrega a equipe no tenant do token (`EO.fetch_team/2`, `:183`), roda `pode_ver_equipe/3`
(`:184`), responde com a **equipe carregada** (`:185`), serializa antes de registrar (`:191`) e
grava a leitura (`:194`). Qualquer falha cai no mesmo `else` (`:203-207`), com o mesmo evento e a
mesma `Ausencia.recusado(:fora_do_alcance)`. O `@moduledoc` (`:23-25`) diz por que o passo 2
existe: *o ramo admin de `pode_ver_equipe/3` concede qualquer UUID*.

### A4-1 — o ramo admin de `pode_ver/3` também concede qualquer UUID (alta, condicional)

`pode_ver/3` (`access.ex:258-259`) devolve `{:ok, :admin}` para **qualquer** `alvo_person_id`
quando a conta é admin do tenant, sem consultar se a pessoa existe nem de qual tenant é; e
`propria_pessoa?/2` (`access.ex:428-430`) decide em memória, também sem banco. Então, com
`person_id`, o isolamento entre tenants **não é feito pelo veredito**: depende de dois controles
que ficam fora dele —

1. a pessoa **carregada no tenant do token** antes do veredito (a FR-013 o exige, mas não diz
   por quê); e
2. a consulta da ferramenta filtrar por tenant. Hoje ela filtra: a fonte da tela,
   `issues_assigned_to/2` e `timeline_coverage/2` (`lib/the_band/work_items/person_work.ex:488`,
   `:495`, `:504`, `:55`), tem `i.tenant_id == ^tenant_id`.

**Caminho concreto**: admin do tenant A tem um token MCP e o `person_id` de alguém do tenant B
(UUID vazado num link, num print, num log de terceiro). Se o passo 1 for omitido e a ferramenta
for escrita com uma consulta nova — p. ex. uma que junte `assignees` por `person_id` sem
`tenant_id` —, `pode_ver/3` concede por `:admin` e A lê os títulos das tarefas abertas de uma
pessoa de B. Com só o passo 1 omitido e a consulta certa, A recebe `checked` com lista vazia:
não vaza, mas **afirma** que a pessoa não tem trabalho, que é a ausência lida como resultado.

A severidade é **alta** porque o desfecho é dado de um tenant alcançável por outro, e o que o
impede está a uma omissão de distância — e **condicional** porque hoje é desenho, não código.
Não é redundância: é a mesma lição do R6 da 062, e ela tem de estar escrita na spec, não só no
`@moduledoc` de outra ferramenta.

**Tarefa bloqueante** (precede qualquer tarefa que implemente `person_open_work`): *"pessoa
carregada no tenant do token antes de `pode_ver/3`, e a ferramenta recebe a pessoa carregada,
nunca o argumento cru"*, com o teste abaixo no campo `Teste`.

**Cenário de ataque para o QA**:

- dois tenants **povoados**, A e B; em B, uma pessoa com ao menos uma tarefa aberta atribuída;
  em A, uma conta **admin** com token MCP, e uma pessoa com tarefa aberta (para a guarda de que
  a consulta mediu alguma coisa: `person_open_work` da pessoa de A devolve lista não vazia);
- chamada: `person_open_work` com o `person_id` da pessoa de B;
- asserções: `status == "refused"`, `reason == fora_do_alcance`, `value == nil`; `refute` de
  qualquer `issue_id` ou título de B na resposta serializada; nenhuma linha nova em
  `api_access_reads`; um evento de recusa;
- **defeitos injetados que o teste tem de pegar** (copiar o arquivo antes, restaurar depois):
  (a) retirar o carregamento da pessoa e passar o UUID cru para `pode_ver/3` e para a
  ferramenta — o teste tem de reprovar pela resposta `checked`; (b) trocar, na consulta da
  ferramenta, o filtro `tenant_id == ^tenant_id` por nada — com (a) também injetado, o teste
  tem de reprovar pelo título de B aparecendo. Repetir com conta **não** admin e a própria
  pessoa de A, para cobrir o ramo `propria_pessoa?`.

### A4-2 — adaptar sem abrir segundo caminho (média)

Hoje `chamar/5` chama `team_id/1` incondicionalmente (`ferramentas.ex:156`) e o
`@esquema_de_entrada` é **um** para todas (`:60-69`, `:130-132`). Acrescentar `person_id` tem
duas formas:

| Forma | Risco |
|---|---|
| uma segunda função `chamar_pessoa/5`, ou um `if nome == "person_open_work"` antes do `with` | dois caminhos; o segundo nasce sem a serialização antes do registro, sem o evento, ou com outro `else`. É o segundo chamador que não sabe |
| o **tipo do alvo** declarado na entrada do registro (`alvo: :equipe | :pessoa`) e `chamar/5` despachando o validador de argumento e o carregador pelo tipo, com **o mesmo** `with`, a mesma serialização, o mesmo registro e o mesmo `else` | um caminho; o que varia é dado declarado, não fluxo |

A segunda é a que satisfaz a FR-013. A spec deve dizê-lo como requisito verificável: *"existe
uma única função pública até uma ferramenta; o que varia entre ferramentas é o validador do
argumento e o carregador do alvo, declarados na entrada do registro"*. O teste é a guarda de
fronteira existente (`test/the_band/mcp/fronteira_test.exs`) estendida: nenhuma função pública
nova em `TheBand.MCP.Ferramentas` além de `chamar/5`, `listar/0`, `esquema_de_entrada/0` e
`lastro_existe?/1`. `esquema_de_entrada/0` deixa de ser "o mesmo para as quatro"
(`:130`) — o contrato da 062 muda, e isso é mudança de contrato a registrar.

### A4-3 — a mesma recusa, e o canal lateral que sobra (baixa)

O `else` único (`ferramentas.ex:203-207`) já garante que inexistente, de outro tenant e fora do
alcance produzem **a mesma resposta**. Com pessoa, há dois canais a fechar por escrito:

- **o motivo**: `pode_ver/3` devolve motivos distintos (`:sem_elo_declarado`,
  `:alvo_da_concessao_nao_existe_mais`, `:fora_dos_escopos`, `access.ex:510-523`). Para a
  **resposta**, a FR-014 fixa `fora_do_alcance` — correto, e a spec deve dizer que o motivo do
  veredito **não** chega à resposta. Para o **registro**, ver a seção 5;
- **o tempo**: UUID inexistente ou de outro tenant falha no carregamento (uma consulta); pessoa
  do tenant fora do alcance passa por `comparar_com_alvo/3` (duas ou três consultas,
  `access.ex:445-459`). A diferença de tempo diz *"esta pessoa existe no meu tenant"*. O
  atacante precisa já ter o UUID (v4, não adivinhável), e a existência de uma pessoa no próprio
  tenant é visível pela tela (FR-016). **Baixa**, sem controle recomendado; registrada porque a
  FR-016 torna o MCP mais estrito que a tela, e este canal é a exceção a essa promessa.

O teste da FR-014 é *byte a byte*, como a FR-012: as respostas serializadas para (i) UUID
aleatório, (ii) pessoa de outro tenant e (iii) pessoa do tenant fora do alcance são iguais; e
`refute` de que o registro de leitura ganhou linha em qualquer dos três.

## 5. FR-015: reusar `painel_recusado`

**Reusar o evento faz sentido; reusá-lo como está, não.** O fato é o mesmo — acesso a dado de
pessoa recusado pelo veredito — e um evento só permite a pergunta da FR-024 da 045 (*"quem
tentou ler quais pessoas?"*) com um filtro. Dois eventos para o mesmo fato seriam duas verdades
a somar. O problema está nos campos.

Evidência:

- `painel_recusado/4` (`lib/the_band/tenants/access_events.ex:97-105`) grava `user_id`,
  `tenant_id`, `alvo_person_id` e `motivo`, e o `@doc` (`:94-95`) diz que o motivo **é o de
  `pode_ver/3`**. A tela o chama com esse motivo (`show.ex:300-306`);
- `equipe_recusada/4` (`:120-128`), chamada nas **três** portas (tela, API, MCP —
  `ferramentas.ex:206`), grava os mesmos quatro campos, com o motivo fixo `fora_do_alcance`;
- nenhum dos dois carrega **a porta** nem o **`token_public_id`**. O `@moduledoc` (`:53`) diz que
  `request_id` entra por `Logger.metadata` "no plug e nas hooks", e o `@moduledoc` de
  `ferramentas.ex` (`:32-34`) diz que a ferramenta roda num processo da `ex_mcp`, onde o que o
  plug escreve não chega. **Não verifiquei** se o `Logger.metadata` é propagado para esse
  processo; se não for, a recusa do MCP sai sem nada que a ligue à requisição.

### A5-1 — a recusa do MCP não diz qual credencial (média)

A FR-020 registra a **concessão** por `public_id` do token (é o que `ApiAccessLog.registrar/1`
faz, `ferramentas.ex:194-199`). A **recusa**, pela FR-015 como escrita, fica só com `user_id`.
Uma conta pode ter vários tokens; quando um deles vaza e é usado para varrer `person_id`, a
pergunta do incidente é *"qual token?"*, para revogar **aquele**, e o registro não responde.
O `@doc` de `equipe_recusada/4` (`:112`) já promete *"esta credencial tentou ler…"* e entrega
"esta conta" — o mesmo defeito, herdado da 062, e vale corrigi-lo junto.

**Caminho**: token de uma conta com escopo de organização vaza; quem o tem chama
`person_open_work` para uma lista de UUIDs; as recusas aparecem em `warning` com o `user_id`, e
a pessoa mantenedora não sabe qual dos tokens da conta revogar, nem separa isso da conta
navegando a tela. Severidade **média**: ausência de registro que impede investigar.

**O que fecha**: `painel_recusado` ganha dois campos **opcionais**, `porta` (`:tela | :api |
:mcp`) e `token_public_id` (só nas portas com token), mantendo o nome do evento. A FR-015 passa a
dizer isso. O teste captura o log (`ExUnit.CaptureLog`, nível `warning`, que é o do evento,
`access_events.ex:175-182`) e assere `porta=:mcp` e `token_public_id=` o do token usado; e
`refute` de que o segredo do token apareça na linha.

### A5-2 — o vocabulário do motivo (baixa, decisão a escrever)

Na tela o motivo é o de `pode_ver/3`; no MCP, a pessoa inexistente ou de outro tenant **não
chega** a `pode_ver/3`, e não tem motivo de veredito. Há duas escolhas, e a spec tem de escolher
uma:

| Escolha | Consequência |
|---|---|
| motivo fixo `fora_do_alcance`, como `equipe_recusada` | o registro mistura, no mesmo evento, o vocabulário do veredito (tela) e o da resposta (MCP); filtrar por motivo fica errado sem filtrar por porta |
| motivo do veredito quando a pessoa foi carregada, e `:pessoa_nao_encontrada` quando não | o **registro** distingue *"não existe no tenant"* de *"existe e está fora"*, e a **resposta** continua idêntica. É o padrão de `sessao_derrubada/3` (`access_events.ex:133-135`): *"no log eles se distinguem, porque é onde a distinção serve"*. E é o que torna visível a varredura de UUIDs de outro tenant |

Recomendo a segunda. O teste da FR-014 (byte a byte na resposta) e o deste campo (distinto no
log) juntos provam que a distinção fica **só** no registro.

## O que não foi verificado

(em avaliação)

## Tabela-resumo

(em avaliação)
