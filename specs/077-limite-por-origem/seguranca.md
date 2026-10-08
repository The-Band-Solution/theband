# Avaliação de segurança da spec 077, antes do plano e do código

**Feature**: `specs/077-limite-por-origem/spec.md` — o defeito [#1229](https://github.com/The-Band-Solution/theband/issues/1229)
(S12/D7 da 074) e a tarefa [#1106](https://github.com/The-Band-Solution/theband/issues/1106)
(070/T043), que dependem da medição [#1063](https://github.com/The-Band-Solution/theband/issues/1063)
(070/T004).
**Data**: 2026-10-05
**Papel**: Security (`AGENTS.md` §13 e §14.0). **Não escrevi este desenho**: a spec e o desenho
proposto (módulo de borda que resolve a origem, contador em ETS, recusa idêntica com o custo do
hash) são de outro agente.
**Natureza**: leitura do desenho e do código que ele toca, com arquivo e linha. **Não é varredura
completa**, e **nenhum gate nem ferramenta da casa foi rodado**: a instrução desta avaliação vedou
`mix` (outro agente compila nesta árvore). A única execução foi `erl -eval` para conferir como
`:inet.parse_address/1` trata formas não canônicas de endereço (L12).

Os identificadores dos achados aqui são **L1..L14**. A spec anota as emendas como *"(seguranca.md,
Sn)"*; ao incorporar, use os números desta avaliação.

## O que foi lido

| artefato | o que se tirou dele |
|---|---|
| `specs/077-limite-por-origem/spec.md` | o desenho, FR-001..FR-013, SC-001..SC-006 |
| `gh issue view 1229`, `1106`, `1063` (2026-10-05) | as três abertas; #1063 **sem comentário nem resultado**; #1106 ainda descreve `Plug.RewriteOn` |
| `lib/the_band/tenants/auth.ex` | a ordem da decisão (`:65-75`), a espera com o hash (`:221-249`), `resolver/1` com duas consultas quando não resolve (`:294-326`), `change_password/4` sem espera (`:350-361`) |
| `lib/the_band/platform/credentials.ex` | as quatro portas, o esqueleto `passo/3` (`:473-483`), o evento `[:the_band, :platform, :custo_do_hash]` (`:563-572`) |
| `lib/the_band_web/controllers/session_controller.ex` | a recusa única (`:25`, `:46-47`), o correlator apagado antes de decidir (`:34-35`) |
| `lib/the_band_web/plataforma/entrada_controller.ex`, `cadastro_controller.ex` | a recusa de cada porta; as pré-conferências sem segredo do cadastro (`cadastro_controller.ex:32`, `:90`) |
| `lib/the_band_web/router.ex` | `:browser` (`:28-52`) e `:plataforma` (`:65-79`), ambos com `protect_from_forgery`; as rotas (`:174-182`, `:287`, `:351`) |
| `lib/the_band_web/plugs/api_rate_limit.ex` | o precedente: incremento atômico (`:109`), poda **por chave tocada** (`:135-139`), recusa que **anuncia** o limite (`:155-171`) |
| `config/prod.exs`, `config/runtime.exs` | só `x_forwarded_proto` (`prod.exs:15`); Bandit escuta em `::` (`runtime.exs:151`); `DNS_CLUSTER_QUERY` (`runtime.exs:137`) |
| `deps/plug/lib/plug/rewrite_on.ex:133-141` | o valor mais à esquerda, e só com **um** cabeçalho |
| `deps/bandit/lib/bandit/socket_helpers.ex:52-59` | o endereço do par sai do socket sem conversão — IPv4 mapeado em IPv6 continua mapeado |
| `specs/070-operador-da-plataforma/seguranca-autenticacao.md` | A3, A4, P2, e a **decisão 2 de 2026-10-01** |
| `specs/074-jornada-entrar-e-sair/seguranca.md` | S12, D7; o formato |
| `priv/knowledge_base/rules/journey_entrar_e_sair.yaml` | a lista fechada de motivos de `entrar_com_senha` |
| `docs/producao/runbook.md` | Traefik do Dokploy, porta interna 4000 (§3), **Cloudflare com nuvem laranja** no endereço próprio e o `sslip.io` direto ao mesmo tempo (§9, passos 1-5), §13.7 |

## Resumo

O desenho acerta no que é mais difícil de consertar depois: **não** usa `Plug.RewriteOn` (que lê
o lado do cabeçalho que quem ataca escreve), só lê o cabeçalho quando o socket é um proxy
nomeado, usa o valor que o proxy escreveu, normaliza IPv6, incrementa antes de conferir, e a
recusa por limite não registra falha em conta (FR-004), o que impede usar o limite para pôr a
conta de outra pessoa em espera.

Os riscos que sobram estão em quatro lugares:

1. **O padrão "socket" em produção contradiz uma decisão já tomada e cria uma negação de serviço
   que não existe hoje.** Antes da #1063, o socket é o Traefik: o limite vira teto **global**, e
   onze requisições a cada cinco minutos, de qualquer pessoa na internet, impedem todas as contas
   e o operador de entrar. A decisão 2 da pessoa mantenedora (070, 2026-10-01) diz que **sem a
   medição o limite por IP não entra** (L1).
2. **A forma do endereço**: o Bandit escuta em `::`, e o IPv4 chega mapeado (`::ffff:a.b.c.d`).
   Aplicada a regra do `/64` a esse formato, **todo IPv4 vira uma origem só**; e uma lista de
   proxies em IPv4 nunca casa o socket mapeado, então o cabeçalho deixa de ser lido sem que nada
   avise (L2).
3. **Pagar o hash na recusa por limite não esconde nada**, porque o limite é por origem e não por
   conta, e anula a metade do conserto da #1229 que é a CPU. A analogia com a #1047 não vale
   aqui (L5).
4. **O precedente da `ApiRateLimit` não serve inteiro**: a poda é por chave tocada, e origem que
   não volta fica na tabela para sempre (L6); a recusa dela anuncia o limite em cabeçalho (L9).

## Veredito

**Pode seguir para o plano, com as emendas da seção *"Decisões tomadas por este papel"*
incorporadas na spec antes do `/speckit-plan`**, e com M1 decidida pela pessoa mantenedora.
Nenhum achado é Alta pelo desenho como está; L3 é **Alta se a configuração for feita do jeito
fácil** (a sub-rede inteira do Dokploy, ou `0.0.0.0/0`), e por isso a guarda dele é bloqueante.

O que bloqueia, e o quê:

| achado | bloqueia |
|---|---|
| L1 | o **plano**: a spec precisa dizer o que acontece em produção antes da #1063, e o que ela diz hoje contradiz a decisão 2 |
| L2, L3 | o **merge**: são guardas que precisam nascer com o código, vistas reprovando |
| L5, L7, L8 | o **plano**: mudam FR-003, SC-002 e o lugar onde a contagem mora |
| demais | nada; viram tarefa ou risco declarado |

## Tabela de achados

Severidade pela régua do papel: **Alta** = dado de um tenant alcançável por outro, segredo
exposto, autenticação contornável; **Média** = defesa que depende de alguém lembrar, ausência de
registro que impede investigar, configuração que afrouxa garantia declarada; **Baixa** =
endurecimento. Negação de serviço contra a entrada é classificada como **Média**, como a A4 da
070, para que as duas avaliações sejam comparáveis. Achado sobre desenho ainda não implementado é
classificado **pelo que acontece se ele for implementado como está escrito**.

| # | Achado | Severidade | OWASP 2021 / ASVS 4.0.3 | Evidência | O que fecha | Bloqueia |
|---|---|---|---|---|---|---|
| **L1** | Produção antes da #1063: socket = Traefik, o limite vira teto global e negação de serviço de todas as entradas; contradiz a decisão 2 de 2026-10-01 | Média | A04, A07 · V2.2.1, V11.1.4 | spec FR-005 e *Edge Cases*; runbook §3.4; 070 *Decisões*, linha 2 | estado **"origem desconhecida"** em produção sem configuração: conta e registra, **não recusa**; log de subida; M1 | plano |
| **L2** | IPv4 mapeado em IPv6: `/64` junta todo IPv4 numa origem; CIDR IPv4 não casa socket mapeado | Média | A04 · V11.1.4, V5.1.3 | `runtime.exs:151`; `bandit/socket_helpers.ex:52-59` | desmapear `::ffff:0:0/96` antes de **tudo** (CIDR e `/64`); `remote_ip` que não é endereço (`{:local, _}`) com destino declarado | merge |
| **L3** | Lista de proxies larga demais transforma vizinho, ou qualquer um, em "proxy confiável" | Média (**Alta** se configurada com `/0` ou faixa pública) | A05, A04 · V14.1.3, V2.2.1 | desenho; runbook §1 (rede do Dokploy compartilhada) | recusar subir com `/0`, faixa pública ou valor malformado; log de subida com a lista | merge |
| **L4** | "O último valor" é certo com um salto; com Cloudflare na frente do Traefik é a borda do Cloudflare, e há dois caminhos para a mesma aplicação | Média | A04 · V11.1.4 | runbook §9, passos 1-5 | regra **"o mais à direita que não é proxy confiável"**; #1063 mede os dois caminhos; nenhum outro cabeçalho é lido | não |
| **L5** | O hash na recusa por limite não esconde nada e mantém o gasto de CPU que a #1229 aponta | Média | A04, A07 · V2.2.1, V11.1.4 | `auth.ex:65-75`; spec FR-003, SC-002, US1 cenário 4, US2 cenário 3 | a recusa por limite **não** paga hash e **não** consulta; a guarda passa a contar zero | plano |
| **L6** | Teto de memória: a poda do precedente só limpa a chave tocada | Média | A04 · V11.1.4 | `api_rate_limit.ex:135-139`; spec FR-012 | processo dono da tabela com varredura global por fatia, e teto de tamanho com alarme | não (tarefa com guarda) |
| **L7** | Onde a contagem mora: depois do CSRF, depois das pré-conferências sem segredo, dentro do contexto antes de resolver, num ponto só | Média | A04, A01 · V2.2.1, V4.2.2 | `router.ex:33`, `:72`; `cadastro_controller.ex:32`, `:90`; `session_controller.ex:34-37` | a decisão D-L7 abaixo | plano |
| **L8** | "Contar só falhas" mal feito vira tentativas ilimitadas: zerar no sucesso, ou devolver em fatia errada | Média | A07 · V2.2.1, V11.1.4 | desenho (incremento antes, devolução no sucesso) | devolução de **exatamente um**, na fatia do incremento, com piso zero, sem criar chave | plano |
| **L9** | A recusa por limite não pode herdar o que a `ApiRateLimit` faz de certo para a API | Baixa | A07 · V2.2.1 | `api_rate_limit.ex:155-171` | sem `429`, sem `retry-after`, sem `x-ratelimit-*`, sem log por requisição | não (guarda) |
| **L10** | O endereço é dado pessoal: o que vai para log e telemetria | Média | A09 · V7.1.1, V8.3.4 | spec FR-011 | nada na telemetria; no log, prefixo truncado, só na transição para o limite | não |
| **L11** | Estado em ETS: deploy reinicia o orçamento, N instâncias multiplicam o limite, dono da tabela que morre | Baixa | A04 · V11.1.4 | `runtime.exs:137`, `application.ex:48`; `api_rate_limit.ex:83-89` | dono supervisionado; falha de ETS nunca vira "permitido" em silêncio; o ×N declarado | não |
| **L12** | Análise do endereço: `:inet.parse_address/1` aceita `127.1`, `0x7f.0.0.1` e descarta zona | Baixa | A04 · V5.1.3 | `erl -eval`, 2026-10-05 | `:inet.parse_strict_address/1`, `String.trim/1`, recusa de zona | não |
| **L13** | O limite tira a campanha do bcrypt e do banco, **não** da fila de telemetria | Baixa | A09, A04 · V7.1.3 | `auth.ex:85-105`; 074 S12 | depende do contador anterior ao descarte da 074 (S12); risco declarado | não |
| **L14** | Fora do escopo: `POST /profile/password` verifica a senha atual sem espera nem contador | Média | A07 · V2.2.1 | `auth.ex:350-361`; `router.ex:351` | issue `security` própria | não (outra issue) |

---

## Achados

### L1 — Média: o padrão "socket" em produção antes da #1063

**O que é.** A04/A07. A spec põe o socket como origem por padrão **em todo ambiente** (FR-005) e
reconhece, nos casos de borda, que em produção isso faz de todo visitante uma origem só. Ela deixa
a decisão para esta avaliação.

**Caminho.** Quem ataca não precisa de nada: um `GET /sign-in` para o token de CSRF e onze
`POST /session` com qualquer coisa a cada 300 s. Com o limite proposto (10 por 300 s, contando
falhas), a 11.ª esgota a cota do Traefik — que é a de todo mundo —, e **nenhuma conta entra**,
inclusive com a senha certa (US1 cenário 2). O mesmo com quatro requisições em `/platform/*`
contra o balde "operador": o operador não entra para suspender uma organização comprometida, que
é o caso que a A4 da 070 já descrevia, agora sem precisar do e-mail do operador. Custo do ataque:
0,04 requisição por segundo.

Hoje esse ataque **não existe**: a espera é por conta, e quem não sabe o e-mail não nega a
entrada de ninguém. Ligar o limite no socket troca um defeito conhecido (a #1229: tentativas sem
freio) por um mais barato de explorar.

**A decisão que já existe.** A decisão 2 da pessoa mantenedora, 070, 2026-10-01: *"Sem ela [a
medição], o limite por IP não entra, e fica só a espera por conta (#1046)"*. Um limite por socket
em produção **é** o limite por IP sem a medição, com o pior caso dela. A spec não pode
contradizê-la sem uma decisão nova, e por isso M1.

**As três opções, com números.**

| opção | o que acontece em produção antes da #1063 | custo para negar a entrada a todos | o que protege |
|---|---|---|---|
| (a) limite ativo no socket, 10/300 s | teto global de 10 falhas por 5 min | ~0,04 req/s | nada que a espera por conta não proteja; acrescenta a negação de serviço |
| (b) teto maior no socket, p. ex. 300/300 s | teto global de 1 falha por segundo | ~1 req/s, trivial | um piso contra esgotar CPU — mas a recusa sem hash (L5) já faz isso por origem real, e sem origem real o número não tem medição que o sustente (seria número mágico, AGENTS §7.7) |
| **(c) "origem desconhecida"** | o mecanismo está no ar, conta por socket, **registra** a transição para o limite (L10) e **não recusa**; o log de subida diz `limite por origem: só observado — a origem é o proxy` | não há | a #1229 continua aberta em produção, **declarada**, até a #1063; nada piora |

**Recomendação: (c)**, que é a decisão 2 aplicada. O mecanismo, a resolução da origem e todas as
guardas entram e são testados; a recusa liga em produção **por configuração, sem código**, no dia
em que a #1063 registrar o resultado. O registro da transição em modo observado tem um ganho
próprio: mostra, antes de ligar, quantas vezes o teto global teria sido atingido por tráfego
legítimo — é a única medida que a plataforma consegue ter sem o endereço real.

**Como se configura, para (c) não ser fallback silencioso (princípio VIII).** Três estados, e o
de produção sem configuração é **nomeado**:

| estado | onde | recusa? |
|---|---|---|
| `socket` declarado | `dev`, `test`, e produção exposta diretamente (declarado por variável) | sim |
| `proxy`, com cabeçalho e lista | produção depois da #1063 | sim |
| sem declaração | produção hoje | **não**; conta, registra e diz no log de subida |

A recusa nunca liga por ausência de configuração em produção; a confiança no cabeçalho nunca liga
por ausência de configuração em ambiente nenhum.

**Alternativa que fica registrada, e não entra.** O padrão de *device cookie* do OWASP (um cookie
assinado, emitido depois de uma entrada certa e ligado àquela conta, que isenta aquele navegador
do limite por origem e não da espera por conta) tornaria (a) tolerável: só navegador novo seria
barrado. É mecanismo novo, com contrato e cookie novos, e o problema que ele resolve deixa de
existir quando a #1063 fecha. Princípio VIII: não entra por previsão.

### L2 — Média: IPv4 mapeado em IPv6

**O que é.** `config/runtime.exs:151` faz o Bandit escutar em `{0, 0, 0, 0, 0, 0, 0, 0}`. Com o
padrão do Linux (`bindv6only = 0`), um par IPv4 chega como `::ffff:a.b.c.d`, e o Bandit repassa o
endereço como veio (`bandit/socket_helpers.ex:52-59`: `{ip, port} -> {ip, port}`). O
`conn.remote_ip` é então `{0, 0, 0, 0, 0, 65535, x, y}`.

**Caminho, nos dois sentidos.**

- **Tudo numa origem.** A FR-007 manda contar IPv6 pelo `/64`. Os primeiros 64 bits de todo
  endereço mapeado são zero: aplicada a regra a esse formato, **todos os clientes IPv4 da
  internet viram a mesma origem**, e o L1 volta mesmo depois da #1063 para quem chega sem
  passar pelo cabeçalho.
- **O cabeçalho nunca é lido.** A lista de proxies confiáveis será escrita em IPv4 (a rede do
  Docker é IPv4). O socket mapeado não pertence a `10.0.0.0/8` na comparação ingênua de tuplas, a
  confiança nunca se aplica, e a origem cai no socket — o Traefik — sem nenhum erro. É o "sucesso
  silencioso" na forma exata: a configuração foi feita, o log de subida diz `proxy`, e o limite
  continua global.

**Não medido em execução**: li o código do Bandit; não vi um `remote_ip` de produção. A guarda vale
igual, porque o formato é possível pela configuração escrita.

**O que fecha.** Uma função só de normalização, aplicada **antes** da comparação com a lista e
**antes** do `/64`: `::ffff:0:0/96` vira o IPv4 correspondente. E `remote_ip` que não é endereço
(`{:local, caminho}`, `:unspec`, que o Bandit pode devolver, `socket_helpers.ex:54-56`) tem destino
declarado — uma origem fixa nomeada, e nunca `raise` dentro da entrada.

### L3 — Média, Alta se mal configurado: a lista de proxies confiáveis

**O que é.** A04/A05. O desenho só lê o cabeçalho se o socket pertence à lista. A garantia é tão
boa quanto a lista.

**Caminho.** O jeito fácil de configurar, quando o endereço do Traefik muda a cada reinício do
contêiner, é pôr a sub-rede inteira da rede do Dokploy — e essa rede é **compartilhada** por todo
serviço do painel (banco, outros apps, o SigNoz da 074, S7 de lá). Qualquer contêiner vizinho
passa a ser "proxy confiável" e escolhe a origem que quiser. Pior: `0.0.0.0/0` (ou `::/0`), que é
o que alguém escreve para "fazer funcionar", faz **todo cliente** escolher a própria origem a cada
tentativa — e o limite deixa de existir, com o log de subida dizendo que está ligado. Isso é a
autenticação contornável da régua: **Alta**.

**O que fecha.**

- recusar **subir** com valor malformado, com `/0`, ou com faixa que não seja de rede local
  (RFC 1918, `100.64.0.0/10`, laço local, `fc00::/7`). Um proxy que fala com o socket da
  aplicação está na rede local por definição; faixa pública na lista é erro de configuração, e
  configuração de segurança errada falha ruidosa, como `THE_BAND_MASTER_KEY` ausente;
- o log de subida (FR-009) imprime a lista e o nome do cabeçalho;
- o plano registra que a sub-rede do Dokploy é compartilhada, e que confiar nela é confiar nos
  vizinhos — risco residual enquanto a rede dedicada da 074 (S7) não existir.

### L4 — Média: um salto ou dois

**O que é.** "O último valor do último cabeçalho" é o que **o proxy do socket** acrescentou. Com
um salto (cliente → Traefik → aplicação), é o endereço do cliente — nos dois comportamentos do
Traefik:

| Traefik | o cliente manda `X-Forwarded-For: 203.0.113.7` | chega à aplicação | último valor |
|---|---|---|---|
| **sobrescreve** (não confia em quem o chamou, que é o padrão) | descartado | `<cliente>` | o cliente ✔ |
| **acrescenta** (`insecure` ou fonte confiável) | mantido | `203.0.113.7, <cliente>` | o cliente ✔ |

Nos dois casos o valor forjado não é o último, e **não há como o cliente escrever depois do
proxy**. O desenho está certo para um salto, e é por isso que ele é melhor que o `Plug.RewriteOn`
que a #1106 descreve (`rewrite_on.ex:133-137`: o primeiro valor, e nada quando há mais de uma
linha do cabeçalho).

**Caminho do problema.** O runbook (§9, passos 1-5) põe o Cloudflare com a nuvem laranja na frente
de `app.theband.dev`, e mantém `theband.5.189.161.85.sslip.io` direto no Traefik. São **dois
caminhos** para a mesma aplicação. No caminho do Cloudflare, o último valor é o endereço da
**borda do Cloudflare**: muitas pessoas numa origem (o L1 em escala menor), e a origem muda conforme
a borda. Não é contorno — o cliente não escolhe a borda —, é a origem errada.

**O que fecha.** A regra geral, que é idêntica ao "último valor" com um salto: **percorrer os
valores da direita para a esquerda e usar o primeiro que não pertence à lista de proxies
confiáveis**. Com um salto, é o último. Com o Cloudflare na lista, é o cliente. Mas **confiar nas
faixas do Cloudflare** é confiar em qualquer pessoa que aponte uma zona própria do Cloudflare para
o nosso endereço — e se, por esse caminho, ela controla algo à esquerda da borda, eu **não
verifiquei**. Por isso: nesta spec a lista contém só proxies de rede local (L3), e o caminho pelo
Cloudflare fica com a origem da borda, declarado; confiar no Cloudflare é decisão posterior,
com medição própria.

**Os bypass perguntados, um a um.**

| tentativa | resultado no desenho com L2, L3 e L4 |
|---|---|
| requisição direta ao contêiner, sem o Traefik | o socket é o de quem chama, fora da lista: cabeçalho ignorado, contado pelo próprio endereço. **Sem contorno**. Se a porta 4000 estiver publicada no host, isso é caminho real — a #1063 confere (procedimento, passo 7) |
| várias linhas de `X-Forwarded-For` | juntar todas, **na ordem**, separar por vírgula, e aplicar a regra. Ler só a primeira linha, ou só a última, é o defeito a injetar |
| `Forwarded` (RFC 7239), `X-Real-IP`, `CF-Connecting-IP`, `True-Client-IP` | **nunca** lidos. Só o nome configurado, que é um. Ler `Forwarded` exigiria outro analisador (`for="[2001:db8::1]:4711"`) e outra medição |
| IPv4 mapeado | L2 |
| valor com espaço, porta, zona, ou forma curta (`127.1`) | L12: o valor não é endereço, e vale a regra de malformado |
| cabeçalho ausente, vazio ou malformado vindo de proxy confiável | o socket (FR-006). Esse balde é o do próprio proxy; quem ataca não consegue fazer o Traefik acrescentar um valor malformado, então não consegue mandar ninguém para lá |

### L5 — Média: o hash na recusa por limite

**O que é.** A spec pede que a recusa por limite pague o `Bcrypt.no_user_verify/0`, *"como a #1047
fez"*, para que o tempo não diga que o limite agiu (FR-003, SC-002, US1 cenário 4, US2 cenário 3).

**Por que a analogia não vale.** Na #1047 a espera era **por conta**: o tempo instantâneo dizia
*"este e-mail existe e está em espera"*, e o identificador era o segredo que a mensagem única
protegia. O limite desta spec é **por origem**, e é conferido **antes** de resolver qualquer
identificador. O que o tempo pode dizer é *"a sua origem está no limite"* — um fato sobre quem
ataca, que ele já sabe contando as próprias falhas, porque o número mora na base de conhecimento
de um repositório público. O tempo da recusa por limite **não depende de conta, de senha nem de
identificador**, e por isso não é oráculo de nada.

A pergunta 3 da encomenda — *"pular a consulta da conta cria diferença de tempo mensurável?"* —
tem resposta **sim**: sem conta, `resolver/1` faz duas consultas (`auth.ex:294-326`), e com milhares
de amostras um milissegundo se mede pela rede. E **não importa**, pela mesma razão: a diferença
separa "limite" de "não limite", e nunca "conta existe" de "não existe".

**O que o hash custa.** Com o hash, uma campanha de uma origem a 100 tentativas por segundo continua
gastando 100 bcrypt por segundo (12 rodadas por padrão; não conferi o valor do release, ver *O que
NÃO verifiquei*): a #1229 nomeia esse gasto como metade do defeito (*"consome CPU de bcrypt à
vontade"*). O limite pararia de verificar senhas e **continuaria pagando por elas**.

**Decisão deste papel.** A recusa por limite **não** paga hash e **não** faz consulta. Emendas:

- **FR-003**: *"A recusa por limite MUST NOT verificar a senha, o código ou o segundo fator, MUST
  NOT consultar conta ou operador, e MUST NOT pagar o custo de hash: o tempo dela pode ser menor,
  e isso não distingue nada que dependa de conta (seguranca.md, L5)."*
- **SC-002**: tirar *"e o tempo dela não se distingue…"*; acrescentar *"e nenhuma consulta de conta
  nem hash é feito para ela"*.
- US1 cenário 4 e US2 cenário 3: substituir pela asserção de que **zero** hashes e **zero**
  consultas acontecem. A guarda fica melhor que a de cronômetro: na porta do operador, o evento
  `[:the_band, :platform, :custo_do_hash]` (`credentials.ex:563-572`) conta exatamente isso, e a
  asserção é zero, sem instabilidade.

**A condição que mantém isto certo**: a conferência do limite acontece **antes** de qualquer leitura
que dependa do identificador (L7). Se um dia ela for para depois de `resolver/1`, a recusa
rápida passa a ser oráculo de existência, e a #1047 reaparece. É o defeito a injetar no cenário Q5.

### L6 — Média: o teto de memória

**O que é.** A FR-012 pede teto. O precedente poda **só a chave da requisição corrente**
(`api_rate_limit.ex:135-139`). Na API isso basta, porque os tokens são poucos e voltam. Origens não
voltam: a última fatia de cada endereço que tentou uma vez fica na tabela **para sempre**.

**Caminho.** Quem tem um `/48` de IPv6 tem 65 536 `/64`; uma rede de bots tem milhões de IPv4. Cada
origem nova deixa uma entrada. Mesmo limitado pelo ritmo que o servidor aguenta, são milhões de
entradas por dia, e a memória cresce até o contêiner cair — negação de serviço da aplicação inteira,
que é pior que a da entrada.

**O que fecha.** Um processo dono da tabela, supervisionado, que a cada largura de fatia apaga
**todas** as fatias fora da janela, de todas as chaves (`:ets.select_delete/2` pela fatia, sem
filtrar a chave), e que mede o tamanho; acima de um teto declarado na base de conhecimento, registra
e varre. A chave é `{entrada, origem, fatia}`, para que a varredura seja um padrão só.

### L7 — Média: onde a contagem mora, e o que conta como tentativa

Quatro regras, e cada uma fecha um caminho concreto.

1. **Depois do CSRF.** As duas pipelines conferem o token antes do controller (`router.ex:33`,
   `:72`). Contar antes (num plug de endpoint, por exemplo) deixaria **qualquer site** gastar a cota
   de quem o visita, com um formulário que posta em `/session` sem token — e, no estado L1, a cota de
   todos. Requisição sem token válido não verifica segredo nenhum; não conta.
2. **Depois das pré-conferências que não verificam segredo.** No `POST /platform/setup`, a
   confirmação diferente é recusada **antes** do contexto, com `recusa: :confirmacao`
   (`cadastro_controller.ex:32`, `:54`); no passo 3, a caixa desmarcada também
   (`cadastro_controller.ex:90`, `:96`). Se a conferência do limite viesse antes delas, a recusa por
   limite de uma requisição com confirmação diferente sairia com `:codigo` (o ramo `{:error, _}`,
   `:50-51`) em vez de `:confirmacao` — a recusa mudaria por causa do limite, que é exatamente o que
   a FR-002 proíbe. Essas requisições não contam, e a recusa delas não muda.
3. **Dentro do contexto, antes de resolver.** Em `Tenants.Auth.decidir/2`, antes de `resolver/1`
   (`auth.ex:66`); em `Credentials.autenticar/3` e `passo/3`, antes de `operador_por_email/1`
   (`credentials.ex:57`, `:474`). O controller resolve a origem e a passa como opção; o contexto
   decide. Três razões: a recusa sai pelo **mesmo** `{:error, :invalid_credentials}` que todo outro
   motivo; o passo `entrar_com_senha` já é emitido ali (`auth.ex:54`, `:96-105`) e ganha o motivo
   novo sem segunda emissão; e a FR-004 fica verdadeira **por construção** — sem conta resolvida, não
   há `registrar_falha/1` a chamar. No `SessionController`, a sessão continua perdendo o
   `:jornada_id` antes da decisão (`session_controller.ex:34-35`), e o cookie da recusa por limite é
   o mesmo de toda recusa.
4. **Um ponto de decisão.** As cinco portas chamam a **mesma** função de limite, com o nome da
   entrada (`:contas` ou `:operador`). Uma checagem própria em cada controller é a segunda porta de
   autorização (A04): a quinta envelhece.

**O que conta.** Toda requisição que chegaria a verificar um segredo, **com qualquer desfecho**,
incrementa antes de verificar (L8). As quatro portas do operador dividem um balde (`:operador`); a
de contas tem o seu (`:contas`). Separadas, porque quem ataca a entrada das contas a partir de uma
rede não deve impedir o operador da mesma rede; juntas entre si, porque o operador é uma pessoa e
as quatro portas protegem a mesma conta.

**Correção de fato na spec.** O caso de borda *"requisição sem o formulário completo conta como
tentativa"* não é o que acontece em `POST /session`: `create/2` casa `identifier` e `password` na
cabeça (`session_controller.ex:27`), e o formulário incompleto é `400` do Phoenix antes de qualquer
código desta spec. Não verifica nada, não conta, e a resposta já é diferente hoje,
independentemente do limite. Nas portas do operador, `texto/2` transforma campo ausente em `""`
(`entrada_controller.ex:49-54`), e aí conta. A spec deve dizer as duas coisas.

### L8 — Média: contar só as falhas, sem abrir tentativas ilimitadas

**A pergunta 1 da encomenda.** Sob NAT (a rede da universidade, o escritório), contar **toda**
tentativa faz o limite barrar o 11.º acerto da manhã: uma turma entrando junto esgota a cota sem
errar nada. Contar **só as falhas** faz a cota medir o que importa — tentativas erradas —, e é a
**decisão deste papel**: o limite conta falhas por origem.

**Como, sem corrida.** "Só falhas" só se sabe depois de verificar, e conferir depois de verificar
deixa N tentativas paralelas passarem juntas (o A1 da 070 de novo, agora na origem). Então:

1. **incremento atômico antes de qualquer verificação**, incondicional — inclusive na tentativa que
   vai ser recusada pelo limite: quem martela continua fora enquanto martela;
2. a soma da janela é lida **depois** do próprio incremento. Com `incrementa-e-lê`, duas tentativas
   simultâneas não conseguem deixar de ver uma à outra, e no máximo `limite` falhas são verificadas
   por janela;
3. **no sucesso, e só no sucesso, devolve exatamente um**, na **mesma fatia** que incrementou (a
   chave fica guardada na requisição; com bcrypt e a trava `FOR UPDATE`, o sucesso pode terminar na
   fatia seguinte), com piso zero e **sem criar chave** se ela já tiver sido podada.

**Os dois jeitos de errar, e o que cada um abre.**

- **Zerar no sucesso.** Quem tem **uma conta própria** — qualquer pessoa de qualquer organização —
  faz 9 tentativas contra outras contas, entra na própria, o contador zera, e repete: tentativas
  ilimitadas. Devolver *um* só desfaz o próprio sucesso, e nunca as falhas.
- **Devolver em chave inexistente com valor padrão.** `:ets.update_counter/4` com padrão cria a
  chave em `-1`: crédito negativo que se acumula. Por isso, sem padrão na devolução, e com o limiar
  de piso.

**O efeito colateral aceito.** Tentativas paralelas da mesma origem podem ver por um instante o
incremento de um sucesso que ainda vai ser devolvido, e serem recusadas. Erra para o lado estrito,
que é o lado certo.

### L9 — Baixa: o que a recusa por limite não herda

A `ApiRateLimit` acerta para a API ao **anunciar** o limite: `429`, `retry-after`,
`x-ratelimit-limit`, `x-ratelimit-remaining` e um `Logger.warning` por recusa
(`api_rate_limit.ex:117-119`, `:155-171`). Na entrada, cada um desses é a diferença que a FR-002
proíbe, e o log por requisição é a inundação do L10. Copiar o plug como molde é o caminho mais curto
para os quatro aparecerem. A guarda compara **o conjunto de cabeçalhos** da recusa por limite com o
da recusa comum, e não só o corpo.

**A pergunta 2 da encomenda, porta a porta**, pelo que a recusa comum é hoje:

| porta | recusa comum | a recusa por limite |
|---|---|---|
| `POST /session` | `302` para `/sign-in`, *flash* `Credenciais inválidas.`, `:jornada_id` apagado | a mesma, pelo mesmo ramo `{:error, _}` (`session_controller.ex:46-47`) |
| `POST /platform/session` | `422`, página de entrada com `recusada: true` e o e-mail de volta | a mesma (`entrada_controller.ex:34-37`) |
| `POST /platform/setup` | `422`, `recusa: :codigo` | a mesma: o contexto devolve `{:error, :invalid_credentials}`, nunca changeset. A pessoa operadora legítima no limite lê "código inválido" com o código certo — e o código **não** é gasto nem conta falha, porque não foi conferido |
| `POST /platform/setup/second-factor` | `422`, tela de cadastro sem o segredo, com o código de cadastro de volta | a mesma (`cadastro_controller.ex:76-79`) |
| `POST /platform/setup/recovery-codes` | `422`, `concluido: false` | a mesma (`:93`) |

**A senha certa no limite** recebe a recusa de todas as portas, sem `Bcrypt.verify_pass/2`, sem
`registrar_sucesso/1` e, portanto, **sem zerar** `failed_attempts` da conta: a espera por conta não
é afetada pelo limite em nenhuma direção (FR-013).

### L10 — Média: o endereço no log e na telemetria

O endereço IP é dado pessoal (LGPD, art. 5.º, I; a ANPD o trata assim), e a pergunta é o que a
investigação **precisa**.

| forma | serve para | contra |
|---|---|---|
| completo | bloquear no Traefik | é dado pessoal em volume, e o log do proxy já o tem, com retenção própria; duplicá-lo na aplicação é coleta sem finalidade nova |
| hash com chave | correlacionar campanhas | uma chave nova para guardar e girar (como a D1-B da 074), e não serve para bloquear nada; o ganho não paga a chave |
| **prefixo truncado** (IPv4 `/24`, IPv6 `/48`) | dizer se é **uma** campanha ou muitas, e de que bloco de rede | não identifica a pessoa sozinho; não serve para bloquear um endereço — o que é certo, porque bloquear é ato do proxy, com o log dele |
| nada | — | quem opera não distingue uma rede de bots de um NAT com uma turma errando |

**Decisão deste papel.**

- **Telemetria**: nada do endereço, em forma nenhuma (a FR-010 e a FR-011 já dizem; a guarda é a
  sentinela da 074 com um endereço de documentação, `198.51.100.23`).
- **Log**: uma linha por **transição** para o limite — a tentativa cuja soma passa do limite pela
  primeira vez na janela —, e não por recusa; com a entrada, a fonte (`socket`, `proxy` ou
  `desconhecida`), o **prefixo truncado** e a contagem. Nunca o endereço completo, nunca o
  identificador digitado, nunca a conta.
- **Nunca em `Logger.metadata/1`**: metadado se propaga para toda linha seguinte do processo, e o
  endereço sairia em linhas que nem sabem que o carregam.
- **A decisão volta no retorno** (L69): a função de limite devolve `{:recusa, :transicao}` /
  `{:recusa, :dentro}` / `:segue` — e, no estado sem declaração de D-L1, `{:observado, :transicao}`
  / `{:observado, :dentro}` —, e o teste assere sobre isso; o log é registro. A forma exata é do
  contrato, e não desta avaliação.

### L11 — Baixa: o estado em ETS

**A pergunta 4 da encomenda. ETS, e não banco.** Contar no Postgres é uma escrita por tentativa, e
sob campanha isso é a campanha escrevendo no banco — um amplificador. A espera por conta, que
**precisa** sobreviver ao deploy, já está no banco (FR-013).

O que o ETS custa, declarado:

- **reinício e deploy** zeram o orçamento: quem ataca ganha uma janela nova a cada deploy. Os deploys
  são do CD depois de merge, e quem ataca não os provoca. Aceitável;
- **mais de uma instância** (`DNSCluster` está no supervisor, `application.ex:48`, e liga com
  `DNS_CLUSTER_QUERY`, `runtime.exs:137`): cada uma conta sozinha, e o limite efetivo vira `N ×
  limite`. Com uma instância (premissa da spec), é o limite. O plano declara o `×N` e a condição de
  revisão: a segunda instância em produção;
- **o dono da tabela**: no precedente, a tabela nasce em `Application.start/2`
  (`api_rate_limit.ex:83-89`). Se o processo dono morre, a tabela some, e `:ets.update_counter/4`
  levanta `ArgumentError` — a entrada responde `500` para todos. A tentação, depois, é um `rescue`
  que deixa passar, e aí o limite desliga em silêncio. O dono é o processo supervisionado da
  varredura (L6); se ele reinicia, a tabela renasce vazia, **e isso é registrado**.

### L12 — Baixa: análise do endereço

Medido em 2026-10-05 com `erl -eval`: `:inet.parse_address('127.1')` e
`:inet.parse_address('0x7f.0.0.1')` devolvem `{ok, {127,0,0,1}}`, e `fe80::1%eth0` perde a zona
em silêncio; `:inet.parse_strict_address('127.1')` devolve `{error, einval}`, e `' 1.2.3.4'` (com o
espaço que sobra depois da vírgula) também falha. Usar `parse_strict_address`, aparar o espaço, e
tratar zona como malformado. Com um proxy que acrescenta, só o último valor importa e ele vem do
proxy; a análise estrita é para que um proxy mal configurado produza "malformado", e não um endereço
inventado.

### L13 — Baixa: a fila de telemetria continua recebendo a campanha

Cada recusa por limite em `POST /session` emite `entrar_com_senha` / `falhou` /
`limite_por_origem` (FR-010). O limite tira a campanha do bcrypt (L5) e do banco (L7), **não** da
fila de exportação, que é a outra metade da S12 da 074. Aceito como está, porque a defesa contra a
perda é o contador anterior ao descarte que a S12 já pede — **e essa dependência precisa estar
escrita no plano**: se aquele contador não existir, o alerta da US5 da 074 conta só o que
sobreviveu ao descarte.

### L14 — Média, fora do escopo: a troca de senha sem espera

`Tenants.Auth.change_password/4` (`auth.ex:350-361`), atrás de `POST /profile/password`
(`router.ex:351`), verifica a senha atual com `Bcrypt.verify_pass/2` e **não** tem espera, contador
nem registro de falha. Caminho: quem alcança uma sessão alheia por alguns minutos — o cenário que
o H1 de 2026-09-09 fechou na outra porta (`session_controller.ex:132-148`) — tenta senhas comuns
sem limite e, quando acerta, troca a senha e derruba a pessoa: acesso temporário vira posse
permanente. Exige sessão válida, e por isso não é Alta; a senha atual é a última barreira e está
sem freio. **Não pertence à 077**: o freio certo ali é por conta, e não por origem. Recomendo issue
`bug` + `security` própria.

---

## Decisões tomadas por este papel

Entram na spec antes do `/speckit-plan`, com a anotação *(seguranca.md, Ln)*.

| id | decisão | emenda |
|---|---|---|
| D-L1 | três estados de origem; em produção sem declaração, **conta e registra, não recusa** — salvo decisão contrária em M1 | FR-005 reescrita; *Edge Cases*, "Produção antes da #1063"; US3 cenário 1 |
| D-L2 | normalização única: desmapear `::ffff:0:0/96` antes da lista e do `/64`; `remote_ip` que não é endereço tem destino nomeado | FR-007 |
| D-L3 | recusar subir com lista malformada, `/0` ou faixa não local | FR-005, FR-009 |
| D-L4 | "o mais à direita que não é proxy confiável"; nenhum cabeçalho além do configurado; várias linhas juntadas na ordem | FR-006 |
| D-L5 | a recusa por limite não paga hash nem consulta | FR-003, SC-002, US1-4, US2-3 |
| D-L6 | processo dono, varredura global por fatia, teto de tamanho na base de conhecimento | FR-012 |
| D-L7 | depois do CSRF e das pré-conferências; no contexto, antes de resolver; uma função para as cinco portas; dois baldes, `:contas` e `:operador` | FR-001; caso de borda do formulário incompleto corrigido |
| D-L8 | conta falhas: incremento antes, incondicional; devolução de um, na fatia do incremento, piso zero, sem criar chave | FR-001; FR-008 ("comportamento sob NAT" vira esta regra) |
| D-L9 | a recusa por limite não tem `429`, `retry-after`, `x-ratelimit-*`, nem log por requisição | FR-002 |
| D-L10 | telemetria sem endereço; log com prefixo `/24` ou `/48`, só na transição; nunca em metadado | FR-011 |
| D-L11 | ETS; o `×N` por instância declarado no plano | *Assumptions* |
| D-L12 | `:inet.parse_strict_address/1` | FR-006 |

**Os números** (10 falhas por 300 s, por origem e por balde): aceitos como **proposta inicial** na
base de conhecimento, com a razão escrita na regra — contam só falhas, e a espera por conta continua
por baixo. Não há medida de quantas falhas legítimas uma rede compartilhada produz (a telemetria da
074 não tem endereço, por decisão), e por isso o modo observado de D-L1 é a primeira fonte dessa
medida. Janela em dez fatias de 30 s: a soma cobre entre 270 e 300 s, mais estrita que a declarada,
como no precedente.

## Decisões da pessoa mantenedora

Só uma é dela, porque muda uma decisão que ela já tomou ou aceita um risco em produção.

### M1 — O que a produção faz antes da #1063

A decisão 2 de 2026-10-01 já responde: sem a medição, o limite por IP não entra. Esta spec pode
entregar o mecanismo sem contradizê-la, e a pergunta é só se ela quer revê-la.

| opção | efeito em produção | risco aceito |
|---|---|---|
| **(c) manter a decisão 2: conta e registra, não recusa** | nenhuma mudança de comportamento; o log mostra quantas vezes o teto global teria sido atingido | a #1229 e a A4 continuam abertas **em produção**, declaradas na nota da release, até a #1063 |
| (a) recusar no socket, 10/300 s | o teto global | negação de serviço de todas as entradas, a ~0,04 req/s |
| (b) recusar no socket com teto maior | um piso contra rajada | negação de serviço a ~1 req/s, e um número sem medição |

**Recomendação: (c).** O caminho mais curto para fechar a #1229 em produção não é escolher entre
(a) e (b): é a #1063, que é uma hora de trabalho com o procedimento abaixo.

**O que NÃO é decisão dela, e fica registrado para quem prioriza**: abrir a issue do L14 (Product
Owner); e o resultado da #1063, que é medição, não escolha.

---

## Cenários de ataque para o QA

Regras herdadas: `assert` de que a medida mediu antes de qualquer `refute`; cada guarda vista
**reprovando** com o defeito injetado, com cópia do arquivo antes de injetar; endereços só de
documentação (RFC 5737 e RFC 3849); nenhum segredo real. Dois endereços povoados ao mesmo tempo em
todo cenário de isolamento, como dois tenants no princípio V.

| # | Quem, com o quê | Asserção | Defeito a injetar |
|---|---|---|---|
| Q1 | De `203.0.113.7`, 10 falhas em `POST /session` com identificadores inexistentes, e a 11.ª | `assert` 10 passos `identificador_nao_resolveu`; a 11.ª tem status, `location`, *flash* e **conjunto de cabeçalhos** iguais aos da 10.ª, e o passo dela é `limite_por_origem` sem `user_id`, sem `tenant_id` | conferir o limite antes do incremento (ler, depois somar) |
| Q2 | Origem no limite manda a senha **certa** de uma conta | recusa idêntica; `refute` sessão aberta; `failed_attempts` e `logged_in_at` da conta **inalterados** | deixar a senha certa passar no limite |
| Q3 | Origem A no limite; origem B entra com a senha certa | `assert` B entra; `assert` A continua recusada | chave do limite sem a origem (só a entrada) |
| Q4 | 20 tentativas paralelas (`Task.async_stream`) de uma origem com cota 10 | `assert` exatamente 10 chegaram a verificar (passos com motivo de verificação) e 10 saíram `limite_por_origem` | conferir antes de incrementar |
| Q5 | Recusa por limite em `/session` e nas quatro portas | **zero** eventos `custo_do_hash` e `senha_conferida`; zero consultas a `users`/`platform_operators` (contador de consultas do `Repo` por telemetria) | mover a conferência para depois de `resolver/1` ou de `operador_por_email/1` |
| Q6 | Conta legítima com uma falha anterior; a origem do atacante esgota o limite tentando essa conta | `failed_attempts` da conta não sobe nas recusas por limite (FR-004, SC-005) | chamar `registrar_falha/1` no ramo do limite |
| Q7 | Origem faz 9 falhas, 1 sucesso (conta própria), e repete 3 vezes | a 11.ª **falha** acumulada é recusada | zerar o contador no sucesso |
| Q8 | Sucesso cuja fatia foi podada antes da devolução | nenhuma chave com valor negativo na tabela; a soma nunca é negativa | `update_counter` de devolução com valor padrão |
| Q9 | Sem configuração: `X-Forwarded-For: 198.51.100.9` | contado pelo socket | ler o cabeçalho sem a confiança ligada |
| Q10 | Confiança ligada, socket fora da lista, mesmo cabeçalho | contado pelo socket | não conferir o socket contra a lista |
| Q11 | Confiança ligada, socket na lista: `203.0.113.7, 198.51.100.9`; e duas linhas, `203.0.113.7` e `198.51.100.9` | contado por `198.51.100.9` nos dois | ler o primeiro valor (o do `Plug.RewriteOn`); ler só a primeira linha |
| Q12 | Confiança ligada, socket `{0,0,0,0,0,65535,2560,1}` (`::ffff:10.0.0.1`), lista `10.0.0.0/8` | o cabeçalho **é** lido | não desmapear antes da lista |
| Q13 | Dois clientes IPv4 diferentes chegando mapeados pelo socket | são **duas** origens | aplicar o `/64` ao mapeado |
| Q14 | Dois IPv6 do mesmo `/64`; e dois de `/64` diferentes | uma origem; duas origens | contar pelo endereço inteiro |
| Q15 | Cabeçalho vazio, `"198.51.100.9,"`, `"127.1"`, `"fe80::1%eth0"`, `"[2001:db8::1]:443"` de proxy confiável | contado pelo socket em todos | `:inet.parse_address/1` |
| Q16 | `Forwarded: for=198.51.100.9` e `X-Real-IP: 198.51.100.9`, confiança ligada para `x-forwarded-for` | ignorados | ler qualquer cabeçalho além do configurado |
| Q17 | Subida com lista `0.0.0.0/0`, `::/0`, `8.8.8.0/24`, `abc` | a aplicação **recusa subir**, com mensagem que nomeia a variável e não o valor | aceitar e seguir |
| Q18 | Produção sem declaração de origem, 11 falhas | **nenhuma** recusa por limite; uma linha de transição no log com fonte `desconhecida`; o retorno da função é `{:observado, :transicao}` | recusar no estado desconhecido |
| Q19 | `POST /platform/setup` com confirmação diferente, origem no limite | `recusa: :confirmacao` (a de sempre); o contador **não** sobe | conferir o limite no controller antes da confirmação |
| Q20 | Formulário de outra origem posta em `/session` sem token de CSRF, 20 vezes | o contador da origem não sobe | contar em plug antes do `protect_from_forgery` |
| Q21 | 100 000 origens distintas, uma tentativa cada; o relógio avança uma janela; a varredura roda | o tamanho da tabela volta a ~0 | poda só da chave tocada |
| Q22 | Sentinela `198.51.100.23` como origem, recusa por limite | `assert` o passo chegou; `refute` a sentinela, inteira ou em parte, no passo e em `Logger.metadata`; no log, só `198.51.100.0/24` | logar o endereço completo; pô-lo em metadado |

## Procedimento seguro da medição #1063

Para a pessoa mantenedora, dona da #1063. **Nenhum segredo, nenhum dado de pessoa e nenhum acesso
pedido a este papel.** O método evita tocar a aplicação: mede o que **um contêiner atrás do mesmo
Traefik recebe**, que é a pergunta.

1. **Registrar o ponto de partida**: data, versão do Traefik (`docker exec <contêiner do traefik>
   traefik version`) e o bloco `entryPoints.*.forwardedHeaders` da configuração estática do Traefik
   do Dokploy (`trustedIPs`, `insecure`) — sem copiar nada além desse bloco.
2. **Subir um eco temporário**: a imagem `traefik/whoami`, fixada por **digest** e não por tag, como
   aplicação do Dokploy na mesma rede, com um domínio **temporário de `sslip.io`** — nunca um
   subdomínio de `theband.dev`, para que nenhum cookie da plataforma seja enviado a ele. O eco
   devolve todos os cabeçalhos que recebe; por isso:
3. **Medir sem credencial**: `curl` sem cookie e sem `Authorization`, da máquina de quem mede, com
   valores de documentação:
   - `-H 'X-Forwarded-For: 203.0.113.7'`;
   - duas linhas: `-H 'X-Forwarded-For: 203.0.113.7' -H 'X-Forwarded-For: 198.51.100.9'`;
   - `-H 'Forwarded: for=192.0.2.60'` e `-H 'X-Real-IP: 192.0.2.61'`;
   - com IPv6 (`curl -6`), se o servidor tiver.
   Para cada um, anotar o `X-Forwarded-For` que chegou e **em que posição** está o endereço de quem
   mediu — comparado, e **não transcrito**: no registro, ele aparece como `<endereço de quem
   mediu>`.
4. **Anotar o `RemoteAddr`** que o eco mostra: é o endereço do Traefik **na rede do Docker**, a
   forma em que o socket chega. Anotar também a sub-rede
   (`docker network inspect <rede> --format '{{json .IPAM.Config}}'`) e se ela é compartilhada com
   outros serviços (L3).
5. **Repetir pelo Cloudflare**, se a nuvem laranja estiver ligada em `app.theband.dev`: um nome
   temporário com a nuvem laranja apontando para o eco, e os mesmos casos. É o que diz se há um
   salto ou dois (L4).
6. **Derrubar o eco e o domínio temporário**, e registrar que foram derrubados. Eco de cabeçalhos
   esquecido no ar é uma superfície nova.
7. **Conferir se a porta 4000 da aplicação está publicada no host** (`docker ps` com a coluna de
   portas, para o contêiner da aplicação): publicada, existe o caminho direto da tabela do L4.
8. **Registrar na #1063**: data, método, versão do Traefik, para cada caso "sobrescreve" ou
   "acrescenta", o comportamento com duas linhas, se `Forwarded` e `X-Real-IP` foram removidos ou
   repassados, a sub-rede do proxy, se há Cloudflare, e a porta publicada ou não. Só endereços de
   documentação e `<endereço de quem mediu>`.
9. **Depois de a 077 estar em produção e a confiança ser ligada por configuração**: conferir a linha
   do log de subida (fonte `proxy`, a lista, o cabeçalho), e a aceitação de fora — da própria
   máquina, 11 falhas com um identificador inexistente; da rede do celular, a entrada certa entra.
   Sem isso, "ligado" é afirmação sobre a configuração, e não sobre o comportamento.

## Risco residual, mesmo com tudo acima

- **Até a #1063, a #1229 e a A4 seguem abertas em produção** (se M1 = c), declaradas.
- **Quem tem muitas origens** (rede de bots, um `/48` de IPv6) não é contido pelo limite por
  origem; só pela espera por conta, que não freia quem espalha uma senha por muitas contas.
- **Vizinhos sob NAT** dividem a cota com quem ataca, e a senha certa deles é recusada enquanto a
  campanha durar.
- **Confiar na sub-rede do Dokploy é confiar nos vizinhos** dela, até a rede dedicada (074, S7).
- **O caminho pelo Cloudflare** conta pela borda do Cloudflare.

## O que eu NÃO verifiquei

- **Nenhum gate e nenhuma ferramenta da casa foi rodada**: `mix gates`, `mix test`, `mix sobelow`,
  `mix hex.audit`, `mix deps.audit`. A instrução vedou `mix`. Todo achado é por leitura, salvo L12.
- **O `remote_ip` real em produção**: L2 vem da leitura do Bandit e de `runtime.exs:151`, não de um
  endereço observado. Também não conferi `net.ipv6.bindv6only` do contêiner.
- **O comportamento do Traefik do Dokploy** (sobrescreve ou acrescenta; o que faz com `Forwarded` e
  `X-Real-IP`; a configuração `forwardedHeaders`): é a #1063. As duas linhas da tabela do L4 vêm do
  comportamento documentado do Traefik, não de medição.
- **Se o Cloudflare está hoje na frente de `app.theband.dev`**, e se uma zona alheia do Cloudflare
  apontada para o nosso endereço consegue controlar o valor à esquerda da borda (L4).
- **Se a porta 4000 está publicada no host** (procedimento, passo 7).
- **O custo do bcrypt no release**: assumi o padrão de 12 rodadas; só `config/test.exs:89` fixa um
  valor, e não li a configuração do `bcrypt_elixir` em tempo de execução.
- **Se o processo que executa `Application.start/2` vive o bastante para ser dono de tabela ETS**
  sem risco (L11): não li o `application.ex` inteiro, só as linhas citadas.
- **`TheBandWeb.Plugs.Borda`** e a página de erro do CSRF: não conferi se a recusa de CSRF tem
  cabeçalhos que interajam com L9.
- **As telas de recusa renderizadas** (`TelasHTML`): não conferi se algum elemento varia por
  requisição além do token de CSRF, o que a guarda de Q1 vai medir.
- **`AccessEvents`** além das chamadas citadas: não conferi o que `operador_entrada_recusada/2`
  registra com `op` nulo e motivo novo.
- **`test/the_band/telemetria/taxonomia_test.exs`**: não li; assumi a descrição da regra da 074 de que
  motivo emitido e não declarado reprova.
- **`set-password`, `/profile/password` e os `live` de entrada** fora do que L14 cita.
