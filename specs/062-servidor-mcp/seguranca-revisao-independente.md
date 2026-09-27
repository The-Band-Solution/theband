# Revisão de segurança independente — feature 062, servidor MCP (T009)

**Data**: 2026-09-24 · **Branch avaliado**: `062-reconciliar-plano` (PR #944), sobre `069ed7a`

**Quem avaliou**: o agente `security` (`AGENTS.md` §13), **independente do desenho**. Não
escrevi `spec.md`, `plan.md`, `tasks.md`, `seguranca.md` nem os contratos, e não participei da
reconciliação de 2026-09-24. Esta revisão não aceita nem recusa nada: a classificação do
entregável e a decisão sobre cada achado são do Product Owner.

**Régua**: OWASP Top 10 (2021) para nomear o risco, OWASP ASVS 4.0 para nomear a verificação,
e OWASP Top 10 for LLM Applications (LLM01, LLM02, LLM06, LLM08) onde o consumidor ser um
modelo muda o risco.

**Tipo de trabalho**: revisão de **desenho** contra o código que ele reusa e contra o
código-fonte da biblioteca proposta. Não há código da 062 para revisar. Nenhum exploit foi
escrito, nenhum sistema externo foi tocado, a produção não foi acessada.

---

## O que foi lido

### Desenho (este repositório)

- `specs/062-servidor-mcp/spec.md`, `plan.md`, `tasks.md`, `seguranca.md`, `data-model.md`,
  `research.md`, `quickstart.md`, `contracts/ferramentas.md`
- `specs/061-api-publica/spec.md` (FR-070 a FR-082 e a seção de Segurança S1–S14)
- `specs/045-autenticacao-e-acesso/spec.md`, FR-024 inteira (linhas 328–370)
- `docs/releases/v0.9.1.md` (lacunas, linhas 405–423), `RETOMAR.md` (linhas 110–120),
  `docs/producao/aceitacao/2026-09-24-v0.9.1.md` (busca por revogação)

### Código reusado (este repositório, no checkout atual)

- `lib/the_band_web/router.ex` — pipelines `:browser`, `:api`, `:api_autenticada`, escopo `/api/v1`
- `lib/the_band_web/endpoint.ex` — `Plug.Parsers`, `Plug.Session`
- `lib/the_band_web/plugs/api_auth.ex`, `api_rate_limit.ex`, `api_read_log.ex`
- `lib/the_band/tenants/api_access_log.ex`, `access_events.ex`, `access.ex` (`pode_ver_equipe/3`),
  `api_tokens.ex`, `schemas/api_access_token.ex`, `user.ex` (campos `redact`)
- `lib/the_band_web/controllers/api/v1/team_controller.ex` (`com_equipe/3`, `members/2`, `medidas/2`)
- `lib/the_band/ontology/seon/eo/roster.ex` (`list_team_roster/3`), `eo/queries.ex` (`fetch_team/2`)
- `priv/knowledge_base/rules/api_access_thresholds.yaml` (regra `rate_limit`)
- `config/config.exs` (adaptador do endpoint), `mix.exs`, `mix.lock`, `lib/mix/tasks/gates.ex`

### A biblioteca proposta: `ex_mcp` **1.5.0** (publicada em 2026-09-21)

Baixada com `mix hex.package fetch ex_mcp 1.5.0 --unpack` num diretório de rascunho fora do
repositório. **Nada foi acrescentado ao `mix.exs` deste repositório.** O pacote tem ~98 mil
linhas em `lib/`; li as da borda HTTP e do ciclo de requisição, e **não** li o resto (ver
*O que não avaliei*):

- `lib/ex_mcp/http_plug.ex` — moduledoc, `init/1`, `call/1`, `dispatch`, o caminho POST inteiro
  (`select_mcp_era`, `do_handle_mcp_request`, leitura de corpo, sessão, `process_mcp_request`,
  assinaturas), origem/host/CORS, `authorize_request` (cerca de 1 300 das 2 868 linhas)
- `lib/ex_mcp/http_plug/core.ex` (`parse_json/1`, `origin_allowed?/2`, `host_allowed?/2`)
- `lib/ex_mcp/session_manager.ex` (moduledoc, limites, vínculo de identidade)
- `lib/ex_mcp/message_processor.ex` (o handler por requisição)
- `lib/ex_mcp/message_processor/method_handlers.ex` (erros de ferramenta e de handler)
- `lib/ex_mcp/server/result_normalizer.ex` (`tool_error_result/1`, `error_message/2`)
- `lib/ex_mcp/server/subscriptions.ex` (padrões de `subscriptions/listen`)
- `lib/ex_mcp/application.ex`, `mix.exs`, `hex_metadata.config`, `CHANGELOG.md`

E uma medição: um projeto vazio de rascunho com `{:ex_mcp, "1.5.0"}`, `mix deps.get` e
`mix hex.audit` (código de saída lido, ver R3).

---

## Resumo dos achados

| # | Achado | Severidade | Contradiz o desenho? |
|---|---|---|---|
| **R1** | T021/T022 são **inexequíveis como escritos**: a ferramenta roda em outro processo e a biblioteca envia a resposta, então `conn.private` nunca chega ao `ApiReadLog` | **alta** | sim — A6 e A7 voltam pela porta dos fundos |
| **R2** | **A8**: o `ApiReadLog` gravaria como leitura a notificação (`202`), o `initialize`, o `tools/list` e **todo stream SSE no instante em que abre** — antes de o veredito existir | **alta** | sim — é o A7 em três formas que ninguém listou |
| **R3** | `ex_mcp 1.5.0` **reprova `mix hex.audit`** (duas advisories do `cowlib` sem correção upstream) e traz **dez pacotes novos**, não um | **média** (exploração baixa aqui); **bloqueia o T001** até decisão | sim — T001 diz "hex.audit sem aviso novo" e "única dependência nova" |
| **R4** | `subscriptions/listen` vem ligado por padrão: stream de até 1 h, conta **uma** chamada no limite, sem teto de concorrência, e **sobrevive à revogação** | **média** | sim — FR-005 e a Q4 |
| **R5** | sessões legadas sem identidade vinculada e com teto **global** de 10 000 por nó: um tenant esgota as sessões dos outros; um token reutiliza sessão de outro | **média** | parcialmente — FR-003 se mantém, a disponibilidade não |
| **R6** | a ordem "carrega a equipe no tenant, depois o veredito" não está exigida: o ramo `admin` de `pode_ver_equipe/3` concede qualquer UUID, e a ferramenta responderia `checked` com vazio para equipe inexistente ou de outro tenant | **média** | sim — contradiz o contrato ("inexistente também é `fora_do_alcance`") e a FR-012 |
| **R7** | as opções do handler precisam ser **por requisição** e via MFA; o estado do handler só pode carregar identificadores | **baixa** | não — é condição para FR-003/FR-006 continuarem verdade |
| **R8** | `Logger.metadata` (`request_id`, `tenant_id`) não atravessa para o processo do handler: os logs da ferramenta e o evento de recusa perdem a correlação | **baixa** | não |
| **R9** | `Plug.Parsers` decodifica até 8 MB de JSON **antes** da autenticação | **baixa** | não — pré-existente, vale para `/api/v1` |
| **R10** | o contrato descreve o `404` sob `/mcp` errado: com `forward`, a biblioteca responde tudo sob `/mcp/*` | **baixa** | sim — só o contrato |
| **—** | complementos ao **A3** (injeção de instrução), sem sanitizar e sem filtrar | média (a do A3) | não |
| **I1** | token de conta `admin` alcança **todas** as equipes do tenant, e mora num arquivo do cliente | informativo | não |
| **I2** | o token de produção que passou por proxy com interceptação de TLS continua **sem evidência de revogação** | informativo, **precedência sobre os demais** | — |

**Nenhum achado crítico.** Não encontrei caminho, no desenho como está, em que o tenant ou o
alcance venham de argumento, de sessão ou de cache (pergunta 1). Os dois altos são de
**registro**, e a razão da severidade é a FR-024: o registro é a única mitigação declarada do
risco de agregação, e os dois fazem ele afirmar o contrário do fato.

---

## R1 — T021/T022 não podem funcionar do jeito que estão escritos · **ALTA**

**OWASP**: A09 (falhas de registro e monitoramento). **ASVS**: V7.1.3, V7.2.2 (registro de
decisões de acesso). **Princípio**: VIII (fallback silencioso), XI (sinal nunca silenciado).

**O que as tarefas dizem**: *"a camada MCP escreve a ferramenta e o alvo em `conn.private`
(`:api_read_route`, `:api_read_target`), e o `ApiReadLog` prefere esses valores"* (T021);
*"o registro do MCP exige marca explícita de concessão em `conn.private`, escrita só quando o
veredito concede"* (T022).

**Por que não funciona**, lido no código:

1. O `ApiReadLog` grava num `register_before_send/2` (`lib/the_band_web/plugs/api_read_log.ex:32-34`).
   O callback roda no processo da requisição, **no instante do `send_resp`**, com o `conn` que
   quem chama `send_resp` tem na mão.
2. Quem chama `send_resp` no `/mcp` é a **biblioteca**, dentro de `ExMCP.HttpPlug.call/2`
   (`ex_mcp/lib/ex_mcp/http_plug.ex:689` para a resposta JSON, `:653` e `:671` para os
   streams, `:703` para a notificação), e ela encerra com `halt(conn)` (`:319`). Não há
   gancho entre "o handler respondeu" e "a resposta saiu" onde código nosso escreva no `conn`.
3. **A ferramenta nem roda nesse processo.** Cada requisição sobe um `GenServer` temporário
   para o handler (`ex_mcp/lib/ex_mcp/message_processor.ex:292-310`,
   `GenServer.start(handler_module, handler_opts)`), e o que volta dele para o plug é o mapa
   JSON-RPC, não o `conn`. `put_private` feito na ferramenta altera um `conn` que não existe
   ali.

**Cenário concreto**: quem implementa T021 descobre, no meio da tarefa, que `conn.private`
chega vazio. As saídas que ficam à mão, todas ruins: gravar pelo molde da rota (é o A6 de
volta: toda linha diz `/mcp`), ou decodificar o `resp_body` no `before_send` e procurar
`"state":"refused"` (o registro passa a depender de como o JSON foi serializado, e não
existe corpo quando a resposta é stream — ver R2). O teste de T022 ("recusa → zero linhas")
pode passar com o registro desligado se a guarda não for escrita com cuidado, e a FR-024
fica apoiada em nada **com a aparência de apoiada**.

**O que a implementação deve fazer** (proposta para o Product Owner decidir):

1. **Registrar no ponto do veredito, e num lugar só.** O registro fechado de ferramentas
   (`TheBand.MCP.Ferramentas`, T006) já é o único caminho para uma ferramenta. Ele passa a ser
   `carregar equipe → veredito → {concedido: registrar leitura | recusado: registrar recusa}
   → montar resposta`, chamando `ApiAccessLog.registrar/1` com
   `route: "mcp:<ferramenta>"` e `target_id: equipe.id` (o id **carregado**, nunca o
   argumento cru). É uma chamada, no registro, e não uma por ferramenta — o argumento do
   moduledoc do `ApiReadLog` ("uma chamada por controlador é uma que alguém esquece") fica
   atendido pela lista fechada;
2. **o `ApiReadLog` deixa de gravar o `/mcp`**, por marca posta **antes** da biblioteca (um
   `put_private(:api_read_log, :delegado)` num plug do escopo `/mcp`, que roda no processo da
   requisição e portanto chega ao `before_send`). As rotas de `/api/v1` continuam idênticas,
   que é a restrição que o T021 já impõe;
3. a identidade que o registro precisa (`tenant_id`, `token_public_id`) chega à ferramenta
   pelas opções do handler, calculadas por requisição (R7).

**O teste que prova** (cenário para o QA): com dois tenants povoados, um token com alcance
chama `team_roster` sobre X, `team_open_work` sobre Y, e `team_roster` sobre uma equipe fora
do alcance; mais um `initialize`, um `tools/list` e uma notificação. Asserir **exatamente
duas** linhas em `api_access_reads`, com `route` `mcp:team_roster`/`mcp:team_open_work` e
`target_id` X/Y; **zero** linhas com `route` começando por `/mcp`; um evento de recusa com o
`team_id` da terceira. Guarda contra teste vazio: `assert length(linhas) > 0` antes das
refutações. Prova de que o teste mede: remover a chamada de registro e ver reprovar.

---

## R2 — A8: três respostas `2xx` que não são leitura, e uma que é gravada antes de existir · **ALTA**

**OWASP**: A09. **ASVS**: V7.1.3. É a mesma família do A7, e o A7 só enxergou uma delas.

O corte do `ApiReadLog` é `status in 200..299` (`api_read_log.ex:36`). No `/mcp`, lido na
biblioteca:

| Mensagem | O que a biblioteca responde | O `ApiReadLog` como está |
|---|---|---|
| notificação (`notifications/initialized`, `notifications/cancelled`…) | `202` sem corpo (`http_plug.ex:696-703`) | grava como leitura |
| `initialize`, `tools/list`, `ping` | `200` com JSON (`http_plug.ex:680-689`) | grava como leitura, sem alvo |
| `tools/call` com `_meta.progressToken` e `Accept: text/event-stream` | `send_chunked(200)` **antes** de o handler rodar; o resultado vem depois, no stream (`http_plug.ex:634-653`, `:1998-2010`) | grava como leitura **no instante em que o stream abre** — antes do veredito, e mesmo que a ferramenta recuse |
| `subscriptions/listen` | `send_chunked(200)` e stream de até 1 h (`http_plug.ex:655-671`) | grava como leitura |

**A terceira linha é a pior**: o cliente escolhe o formato. Um cliente que peça progresso
transforma **toda** chamada — concedida ou recusada — numa linha de leitura, e o A7
reaparece mesmo que alguém conserte o A7 lendo o corpo, porque no stream não há corpo no
`before_send`.

**Batch não é caminho**, e isso foi conferido: `Core.parse_json/1` só aceita objeto
(`ex_mcp/lib/ex_mcp/http_plug/core.ex:42-48`); um array vira `invalid_json_rpc_envelope` e
`400`. Com o `Plug.Parsers` do endpoint na frente, um array chega como `%{"_json" => …}` e a
biblioteca o trata como corpo vazio (`http_plug.ex:992-998`) — também `400`. Uma requisição
HTTP carrega exatamente uma mensagem JSON-RPC.

**O que a implementação deve fazer**: o conserto do R1 fecha o R2 inteiro, porque tira o
`/mcp` do corte por status. Se o R1 não for adotado, o R2 exige no mínimo recusar, **antes**
da biblioteca, `tools/call` que peça stream (ver também a lista fechada de métodos no R4).

**Teste**: as quatro linhas da tabela, cada uma produzindo zero linhas de leitura; a
chamada com `progressToken` sobre equipe fora do alcance produzindo zero linhas e um evento
de recusa.

---

## R3 — `ex_mcp 1.5.0` reprova o gate de dependências, e traz dez pacotes · **MÉDIA** (bloqueia o T001)

**OWASP**: A06 (componentes vulneráveis). **ASVS**: V10.3, V14.2.

**Medido em 2026-09-24**, num projeto vazio de rascunho, fora do repositório:

```
mix hex.audit      → código de saída 1
  cowlib 2.20.0 - EEF-CVE-2026-43966 (MEDIUM)  HTTP Response Splitting via Non-VCHAR Bytes
                                               in cow_http_struct_hd:escape_string/2
  cowlib 2.20.0 - EEF-CVE-2026-43969 (LOW)     Cookie Request Header Injection via
                                               Unvalidated Encoder in cow_cookie:cookie/1
```

A própria biblioteca sabe disso: o `mix.exs` dela ignora exatamente essas duas
(`ex_mcp-1.5.0/mix.exs:29-49`), com o motivo — o mantenedor do Cowlib recusou corrigir, e a
saída é tornar o Cowboy opcional **na 2.0**. O `ignore_advisories` dela **não se propaga**
para quem a usa: o `mix hex.audit` deste repositório, que é gate (`lib/mix/tasks/gates.ex:63`),
vai reprovar.

**E a dependência não é uma.** Comparado o `mix.lock` do rascunho com o deste repositório,
entram: `ex_mcp`, `plug_cowboy`, `cowboy`, `cowboy_telemetry`, `cowlib`, `ranch`,
`mint_web_socket`, `jose`, `ex_json_schema` e `castore` — **dez**. O `plug_cowboy` é
dependência obrigatória, não opcional (`ex_mcp-1.5.0/mix.exs:102`), num projeto cujo
servidor é o Bandit (`config/config.exs:26`). A biblioteca também carrega código de
transporte stdio e adaptadores ACP que executam processos (`System.cmd`/`Port.open` em
`transport/stdio.ex`, `acp/adapters/*`), que a 062 não usa mas passa a ir no release.

**Exploração aqui é baixa, e isso precisa ficar dito**: o endpoint é servido pelo Bandit;
nenhum código deste repositório chamaria `cow_http_struct_hd` ou `cow_cookie`; o Cowboy não
sobe servidor sem ser configurado. **O que é médio é o efeito no gate**: T001 tem como
critério *"`mix hex.audit` sem aviso novo"*, e isso é impossível com esta versão.

**O risco que precisa ser evitado**: quem implementa o T001 acrescenta
`hex: [ignore_advisories: [...]]` ao `mix.exs` para o pipeline passar. Isso é mudar o
comportamento de um gate, e não é decisão de quem implementa.

**O que precisa ser decidido, antes do T001** (as alternativas, com o que cada uma piora):

| Alternativa | O que resolve | O que piora |
|---|---|---|
| aceitar as duas advisories, com `ignore_advisories` **exato** e o motivo escrito, registrado como risco residual aceito, com quem decidiu | a fatia anda com a biblioteca escolhida | o gate passa a ter exceção; ela precisa ser revista a cada versão da `ex_mcp` e removida quando a 2.0 tornar o Cowboy opcional |
| esperar a `ex_mcp` 2.0 | gate intacto | prazo desconhecido |
| enquadramento JSON-RPC próprio sobre `Plug` (a alternativa rejeitada em research.md D1) | nenhuma dependência nova; superfície mínima — a 062 precisa de `initialize`, `tools/list`, `tools/call` e `ping` | protocolo mantido por nós, que é o que a D1 quis evitar |

E, qualquer que seja a escolha, o `research.md` D1 e o comentário do T001 precisam dizer
**dez pacotes**, e não "uma só", e a versão deve ser **fixada** (`== 1.5.0` ou `~> 1.5.0`),
e não `~> 1.5`: com uma versão a cada ~7 dias numa biblioteca de 98 mil linhas, `~> 1.5`
aceita, sem revisão, a próxima mudança de borda. A regra deste repositório já diz isso para
o `req` (`mix.exs`, comentário do `req`).

---

## R4 — `subscriptions/listen` está ligado por padrão, e o stream sobrevive à revogação · **MÉDIA**

**OWASP**: A04 (desenho inseguro), A07 (sessão). **ASVS**: V3.3 (término de sessão), V11.1.4
(limites anti-automação). **Contradiz**: FR-005 (revogação na chamada seguinte) na letra, e a
Q4/FR-026 (limite por token) no efeito.

Lido na biblioteca:

- `subscriptions/listen` é tratado dentro do plug (`http_plug.ex:2030-2032`) e abre um SSE
  próprio (`:655-671`), com todas as notificações suportadas por padrão
  (`server/subscriptions.ex:18`, `:180`) e **vida máxima de 1 hora** por padrão
  (`server/subscriptions.ex:691`, `max_lifetime_ms: 3_600_000`), com keepalive a cada 15 s;
- o stream é autenticado **uma vez**, quando abre. A revogação vale para o próximo POST
  (`ApiAuth` roda a cada requisição, `api_auth.ex:39-46`), mas **não fecha** o stream aberto;
- o `ApiRateLimit` conta **uma** requisição por stream (`api_rate_limit.ex:93-121`), e não há
  teto de conexões simultâneas por token. É a S7 da 061 (*"sem teto de concorrência, o limite
  por janela não protege a aplicação"*), que continua aberta e aqui ganha um meio barato.

**Cenário concreto**: um laço de agente mal escrito, ou um token vazado, abre
`subscriptions/listen` duas vezes por segundo. Em uma hora são até 7 200 conexões abertas,
todas dentro do limite de 120 por minuto, cada uma segurando um processo e um descritor no
único nó. Revogar o token para as chamadas novas e deixa as abertas vivas até expirarem.
Para as quatro ferramentas desta fatia **não há dado** nesse stream (a lista de ferramentas
é estática), então a consequência é disponibilidade, não vazamento — e é por isso que é média.

**O que a implementação deve fazer**:

1. **lista fechada de métodos JSON-RPC antes da biblioteca**: um plug no escopo `/mcp` que lê
   `conn.body_params["method"]` (o `Plug.Parsers` já decodificou) e aceita só `initialize`,
   `notifications/initialized`, `ping`, `tools/list` e `tools/call`; o resto recebe o erro
   JSON-RPC de método inexistente. É a FR-023 aplicada ao protocolo, e não só às ferramentas;
2. se `subscriptions/listen` for mantido por algum motivo, `subscription_max_lifetime_ms`
   curto e `supported_notifications` vazio, declarados no `plan.md` com o motivo;
3. teto de conexões de stream por token, ou a decisão escrita de não ter.

**Teste**: `subscriptions/listen` com token válido recebe recusa e **não** abre stream
(`content-type` não é `text/event-stream`); `resources/list`, `prompts/list` e
`logging/setLevel` idem.

---

## R5 — Sessões legadas sem identidade, e um teto que é de todos os tenants · **MÉDIA**

**OWASP**: A01 (isolamento, na dimensão disponibilidade), A07. **ASVS**: V3.2.1, V3.3.

Lido na biblioteca:

- a revisão moderna do protocolo (2026-07-28) é **sem estado**; o `SessionManager` só atende
  a era legada (2025-03-26 a 2025-11-25), escolhida quando o cliente **não** manda o cabeçalho
  moderno (`session_manager.ex:1-35`, `http_plug.ex:552-585`). O modo `protocol_mode:
  :modern_only` desliga a era legada;
- a sessão legada é vinculada a `principal_id`, `tenant_id`, `issuer` e `audience`
  (`session_manager.ex:104`, `:828-837`), que vêm das **opções do plug**
  (`http_plug.ex:184-185`, `:1839-1850`) ou das *claims* do OAuth. Com OAuth desligado e as
  opções não configuradas, as quatro são `nil` para todo mundo — **toda sessão casa com todo
  token**;
- o teto é **global por nó**: `max_sessions` 10 000 (`session_manager.ex:99`, `:450-451`), com
  expiração por ociosidade de 1 h (`:101`).

**Cenário concreto (disponibilidade)**: dois tokens de um tenant qualquer mandam `initialize`
a 120 por minuto cada um. Em cerca de 42 minutos o nó tem 10 000 sessões, e todo cliente
legado de **todos** os tenants recebe `session_limit_exceeded` até as sessões expirarem. Um
tenant derruba o MCP dos outros, dentro do limite de taxa.

**Cenário concreto (reuso)**: quem obtém o `Mcp-Session-Id` de outro cliente (ele é aleatório,
128 bits, `session_manager.ex:824-826`, então não se adivinha — precisa vazar, por log de
proxy, por exemplo) pode usá-lo com o **próprio** token: pré-reservar ids de requisição da
sessão alheia (`claim_request_id`) ou encerrá-la com `DELETE`. **Não** obtém dado: o alcance
vem do token de quem chama, não da sessão (pergunta 1). É por isso que isto é disponibilidade
e integridade de protocolo, e não A01 de dado.

**O que a implementação deve fazer**:

1. preferir `protocol_mode: :modern_only` se os clientes que se quer atender falam a revisão
   2026-07-28 (**não verifiquei quais falam** — ver lacunas); isso elimina sessão, `GET`,
   `DELETE` e o `SessionManager` do caminho;
2. se a era legada for necessária: `principal_id` = `public_id` do token e `tenant_id` = id
   do tenant, **por requisição** e por MFA (R7), para que a sessão fique presa à credencial
   que a criou; e um teto de `initialize` por token, ou `max_sessions`/TTL dimensionados e
   declarados;
3. escrever no `plan.md` que o estado de sessão existe e **o que ele carrega** (versão
   negociada, ids de requisição, identidade) — hoje o `data-model.md` diz que o servidor
   "não guarda nada", e com a era legada isso não é verdade.

**Teste**: com a era legada ativa, uma sessão criada pelo token A e apresentada pelo token B
recebe recusa de sessão, e a chamada de B **não** é executada; com `:modern_only`, `GET` e
`DELETE` em `/mcp` recebem `405`.

---

## R6 — A equipe tem de ser carregada no tenant antes do veredito · **MÉDIA**

**OWASP**: A01. **ASVS**: V4.1.3, V4.2.1. **Contradiz**: o contrato (*"equipe inexistente
também é `fora_do_alcance`"*) e a FR-012.

`pode_ver_equipe/3` concede ao admin **qualquer** `team_id`, sem ler a equipe
(`lib/the_band/tenants/access.ex:390-398`, a primeira cláusula do `cond`). Isso é
intencional — a FR-022 da 045 foi emendada em 2026-09-09 para "administração do tenant alcança
tudo no tenant" (`specs/045-autenticacao-e-acesso/spec.md`, tabela do regime) — e a 061 está
certa porque **carrega antes**: `EO.fetch_team(tenant, id)` (`eo/queries.ex:1531-1538`, filtra
por `tenant_id` e resgata `CastError`) e só depois o veredito
(`team_controller.ex:305-313`).

O T017 e o contrato dizem *"quando `pode_ver_equipe/3` nega"*, e nada obriga a ferramenta a
fazer o `fetch_team` primeiro.

**Cenário concreto**: uma conta admin do tenant A chama `team_roster` com o UUID de uma
equipe do tenant B (ou um UUID inventado). O veredito concede (`{:ok, :admin}`). A consulta do
roster filtra por tenant (`eo/roster.ex:86-99`) e devolve `[]`. A ferramenta responde
`state: "checked"` com roster vazio: **não vaza dado do tenant B**, mas afirma que a equipe
existe e está vazia, que é a ausência lida como resultado — e quebra a paridade com a API,
que responderia `404`. Se alguma das consultas de `TeamWork` ou `Quality` usadas pelas outras
três ferramentas **não** filtrar por tenant (não conferi — ver lacunas), aí sim o mesmo
caminho vira vazamento entre tenants, e a severidade sobe para alta.

**Um detalhe de biblioteca que pesa aqui**: a `ex_mcp` **não** valida os argumentos contra o
`inputSchema` automaticamente (a validação existe como utilitário,
`server/tools/helpers.ex:147-150`). Um `team_id` que não é UUID chega cru à ferramenta; sem o
`fetch_team`, ele iria para `tem_escopo?/4` e poderia levantar `CastError`, que a biblioteca
transforma em erro de ferramenta — a recusa viraria erro, contra a FR-013.

**O que a implementação deve fazer**: toda ferramenta passa por um único caminho, no registro
(o mesmo do R1): `EO.fetch_team(tenant, team_id)` → `pode_ver_equipe(tenant, user, equipe.id)`
→ carga pelo `equipe.id`. `{:error, :not_found}` e `{:nao, :fora_do_alcance}` produzem a
**mesma** recusa. E o `inputSchema` declara `team_id` com `format: uuid` e
`additionalProperties: false` — um `tenant_id` enviado passa a ser **recusado visivelmente**
em vez de ignorado, o que é mais forte do que o T007 pede.

**Teste**: dois tenants povoados; conta **admin** de A chama as quatro ferramentas com o id de
uma equipe de B e com um UUID inexistente: quatro recusas `fora_do_alcance`, nenhuma
`checked`; guarda: a mesma conta, com o id de uma equipe de A, recebe `checked` com
`people` não vazio.

---

## R7 — O estado do handler tem de nascer a cada requisição · **BAIXA**

**OWASP**: A04. **ASVS**: V1.4.1. Condição para FR-003, FR-005 e FR-006 continuarem verdade.

O que é bom, e foi conferido: o handler é **um `GenServer` por requisição**, parado ao fim
(`message_processor.ex:292-310`); não há estado de handler entre chamadas. O
`SessionManager` guarda identidade, versão e ids de requisição, **não o token**
(`http_plug.ex:1839-1850`). Então, bem configurado, nada de alcance, papel ou token sobrevive.

O que pode dar errado, e onde:

- o `forward` do Phoenix chama `init/1` **em compilação** e escapa o resultado; função anônima
  não escapa. As opções que dependem da requisição (`handler_opts`, `principal_id`,
  `tenant_id`) têm de ser **MFA** (`{Mod, :fun, args}`), que a biblioteca aceita
  (`http_plug.ex:1037-1060`, `:1100-1118`). A tentação, ao ver o erro de compilação, é pôr um
  valor estático — e aí o estado deixa de ser por requisição;
- o estado entregue ao handler deve ser **só** `%{tenant: %Tenant{}, user: %User{},
  token_public_id: "…", request_id: "…"}`. Nunca o `%ApiAccessToken{}` inteiro, nunca
  `conn.req_headers` (que carregam o `Authorization`). A biblioteca registra falha de handler
  com `Exception.format(:error, error, __STACKTRACE__)` (`method_handlers.ex:331`), e
  `FunctionClauseError` imprime os argumentos. `User` redige os campos sensíveis
  (`user.ex:47-64`) e o token exclui `token_hash` e `value` do `inspect`
  (`schemas/api_access_token.ex:38`) — isso protege o `inspect`, e passar só identificadores
  protege o resto;
- erro de ferramenta devolvido como `{:error, motivo}` vai **ao modelo** se for binário, átomo
  ou tiver `:message` (`result_normalizer.ex:286-311`). A ferramenta nunca devolve
  `{:error, _}` com dado; recusa é resposta (FR-013), e falha inesperada é `raise`, que a
  biblioteca transforma em erro genérico (`method_handlers.ex:580-605`, "handler_crash").

**Teste**: duas chamadas seguidas com tokens de tenants diferentes na mesma execução recebem
cada uma o seu tenant (o segundo não herda nada do primeiro); o estado passado ao handler não
contém a string do token (varredura do termo com `inspect`).

---

## R8 — A correlação não atravessa para o processo da ferramenta · **BAIXA**

**OWASP**: A09. **ASVS**: V7.1.4. `AGENTS.md` §15.

O `request_id` e o `tenant_id` vivem em `Logger.metadata` do processo da requisição
(`api_auth.ex:87`, `access_events.ex`, moduledoc). O handler roda em outro processo
(`message_processor.ex:299`), e metadado de `Logger` não se herda. Todo log escrito pela
ferramenta — incluindo o evento de recusa do T022 — sai **sem** `request_id`, e a ligação
entre *"o cliente viu recusa"* e *"o log diz por quê"* se perde, que é exatamente o que o
`ApiAuth` preserva para o `401`.

**O que fazer**: passar `request_id` nas opções do handler (R7) e chamar
`Logger.metadata(request_id: …, tenant_id: …)` no `init/1` do handler. **Teste**: o evento de
recusa de equipe carrega o mesmo `request_id` do cabeçalho `x-request-id` da resposta.

Nota para o QA: o processo do handler não é `Task`, então o sandbox do Ecto em teste
assíncrono pode não o alcançar. Não verifiquei; é risco de teste, não de produção.

---

## R9 — JSON decodificado antes da autenticação · **BAIXA**

**OWASP**: A05. **ASVS**: V13.1.3 (limite de corpo). **Pré-existente**, vale para `/api/v1`.

O `Plug.Parsers` do endpoint (`endpoint.ex:46-49`) decodifica o corpo JSON **antes** do
roteador, com o limite padrão do Plug (8 MB). Quem não tem token faz o servidor decodificar
8 MB e só depois recebe `401`. O `body_limit` de 1 MB da `ex_mcp` (`http_plug.ex:211`) só vale
depois, e reencoda o que o `Plug.Parsers` já decodificou (`http_plug.ex:1000-1035`).

**O que fazer**: um `length` menor no `Plug.Parsers` (o MCP desta fatia não precisa de mais
que alguns KB), ou a decisão escrita de manter. Não bloqueia a 062.

---

## R10 — O `404` sob `/mcp` do contrato não é o que vai acontecer · **BAIXA**

`contracts/ferramentas.md` diz que caminho inexistente sob `/mcp` devolve a página HTML do
site (#943). Com `forward "/mcp", ExMCP.HttpPlug`, **tudo** sob `/mcp/*` vai para a biblioteca:
`GET` qualquer recebe `{"error":"Not found"}` da própria biblioteca (`http_plug.ex:451-470`),
que não é o formato único da 061; e `POST` em **qualquer** subcaminho é tratado como MCP
(`http_plug.ex:409-423`). Não é falha de acesso — passa pela mesma pipeline —, mas o contrato
descreve outra coisa, e o registro (se ficar por molde de rota) veria `/mcp/*`.

**O que fazer**: corrigir o contrato, e decidir se o escopo casa só `"/mcp"` exato.

---

## Complementos ao A3 — injeção de instrução, sem sanitizar e sem filtrar

**OWASP LLM01, LLM02.** Concordo com o A3: filtrar frase é regex larga, sanitizar faz a
plataforma mentir sobre o que observou, e pedir ao modelo é pedir. A marcação no schema é o
que dá. O que se pode acrescentar de concreto, todos sem alterar o texto observado:

1. **Canais de alta confiança são constantes.** A `description` de cada ferramenta e as
   `instructions` do `initialize` são lidas pelo modelo como instrução da plataforma. Elas
   MUST ser literais de código ou da base de conhecimento, e nunca conter dado (nome de
   equipe, título). Teste: `tools/list` idêntico para dois tenants diferentes;
2. **texto do servidor e texto de terceiro nunca no mesmo campo.** `note`, `limitations`,
   `misinterpretations` e `missing` são escritos pela plataforma; `title`, `name`,
   `team_name` são de fora. Nenhuma interpolação de um no outro (por exemplo, `missing: "a
   coleta de comentários de <nome do repositório> não rodou"` põe texto de fora no campo que
   o modelo lê como da plataforma). Teste: com um título hostil semeado, ele não aparece em
   nenhum campo de texto da plataforma;
3. **`structuredContent` com `outputSchema`**, e o bloco `content[].text` sendo a
   serialização JSON do mesmo objeto, nunca prosa montada. Muitos clientes só mostram o
   `text`; se ele for prosa, a marcação estrutural se perde justamente ali;
4. **sinalizar, sem remover, caracteres invisíveis.** Um campo booleano ao lado do texto de
   terceiro — `contains_invisible_characters: true` quando há caracteres de formatação
   Unicode (bloco de *tags* U+E0000–E007F, bidi, largura zero) — é informação que o cliente
   pode usar, e não altera o que foi observado. É o vetor de instrução escondida que um
   humano lendo a tela não vê e o modelo lê;
5. **nenhum Markdown montado pelo servidor.** Título de terceiro dentro de Markdown que o
   cliente renderiza abre a exfiltração por imagem (`![](https://…?q=…)`), que é LLM02 do
   lado do cliente. Entregar como string JSON não resolve o cliente, mas não o piora;
6. **LLM08 continua contido pelo desenho**, e isso deve ficar como requisito: só leitura, lista
   fechada, e **nenhuma ferramenta que busque URL ou siga link**. Uma ferramenta assim
   transformaria a injeção num SSRF (A10) com a credencial da plataforma.

---

## Informativos

### I1 — Token de admin alcança o tenant inteiro

Pelo `pode_ver_equipe/3` (`access.ex:392`) e pelo regime da 045 (FR-022 emendada), um token
de conta `admin` lê as quatro ferramentas sobre **todas** as equipes. Esse token fica num
arquivo de configuração do cliente (FR-007), sem prazo se assim for escolhido (#939). Não é
defeito; é consequência que o T029 deve escrever: *para MCP, gere o token numa conta com o
alcance mínimo, não na de administração*. É o controle de LLM08 que está ao alcance.

### I2 — O token de produção exposto a interceptação de TLS

Ver pergunta 8. Tem precedência sobre todos os achados acima, porque é a única exposição
**ativa** e o fechamento depende só de quem mantém.

---

## As oito perguntas, respondidas

**1. Há caminho em que o tenant ou o alcance venham de argumento, de sessão MCP ou de cache,
em vez do token recomputado a cada chamada?**
**Não, no desenho e no código reusado.** Evidência: o tenant e a conta vêm da linha do token a
cada requisição (`api_auth.ex:70-78`), sem cache (`Tenants.fetch/1` e `fetch_user/1` por
chamada); `pode_ver_equipe/3` e `scopes/2` não têm cache (`access.ex:70-102`, `:390-398`;
sem ETS, `persistent_term` ou processo em `lib/the_band/tenants/`); o handler da biblioteca é
um processo por requisição (`message_processor.ex:292-310`); a sessão legada guarda
identidade e versão, não alcance (`session_manager.ex:104`, `http_plug.ex:1839-1850`); FR-002
proíbe `tenant_id` em argumento. **Três condições** para continuar "não": opções do handler
por requisição via MFA (R7); `team_id` usado só depois de `fetch_team` no tenant (R6); e
nenhuma opção estática `tenant_id`/`principal_id` no plug (R5, R7).

**2. A `ex_mcp` guarda estado por sessão? Pode carregar identidade/escopo e contrariar
FR-003/005/006? A revogação vale com sessão ou stream aberto?**
**Sim, guarda, só na era legada**: `SessionManager` com versão negociada, marca de
inicialização, ids de requisição reclamados e identidade (`session_manager.ex:1-60`,
`:104-110`); o buffer de eventos para `Last-Event-ID` só é usado pelo transporte `GET` SSE
legado (`http_plug/sse_handler.ex:436-500`), **desligado por padrão**
(`legacy_http_sse: false`, `http_plug.ex:166-167`). A era moderna é sem estado. **Não carrega
escopo**, e não guarda token (FR-006 se mantém). **Contraria a disponibilidade**, não o
alcance (R5). **Revogação**: vale na chamada seguinte para todo POST, com ou sem
`Mcp-Session-Id`, porque o `ApiAuth` roda antes da biblioteca em toda requisição. **Não** vale
para stream já aberto: `subscriptions/listen` vive até 1 h, e `tools/call` em stream até o
`handler_call_timeout` de 10 s (`http_plug.ex:173`). R4.

**3. As correções de A6/A7 (T021/T022) bastam? Há um A8?**
**Não bastam, porque não são implementáveis como escritas** (R1). **Há A8** (R2): notificação
em `202`, `initialize`/`tools/list` em `200`, e — o pior — o stream de `tools/call` com
progresso, gravado como leitura **quando abre**, antes do veredito. **Batch não é A8**: a
biblioteca recusa array com `400` (`core.ex:42-48`), então uma requisição é uma mensagem, um
incremento de limite e no máximo uma decisão. **Corpo gigante**: limitado a 8 MB pelo
`Plug.Parsers` antes da autenticação e a 1 MB pela biblioteca depois (R9). **SSE longa**:
dribla o limite em concorrência, não em contagem (R4).

**4. O limite por token vale para `/mcp` como o contrato afirma? Batch e streaming o
contornam?**
**Vale, se** `/mcp` estiver em `pipe_through [:api, :api_autenticada]` (`router.ex:52-60`):
o `ApiRateLimit` conta por `public_id` a cada requisição HTTP (`api_rate_limit.ex:93-121`), e
as duas portas compartilham a mesma tabela ETS e a mesma chave — o T024 prova. **Batch não
contorna** (recusado, e ainda conta um). **Streaming contorna o que o limite quer proteger**:
cada stream conta uma vez e fica aberto (R4). Dois limites declarados que o contrato não diz:
a tabela é **por nó** (`api_rate_limit.ex:83-86`), então um segundo nó dobra a vazão; e as
recusas da biblioteca (`400` de protocolo, `403` de origem) acontecem **depois** do limite,
então também gastam — o que está certo, e o contrato pode dizer.

**5. Injeção de instrução: algo concreto a acrescentar sem sanitizar nem filtrar?**
**Sim**, seis itens na seção *Complementos ao A3*: canais de alta confiança constantes e
iguais entre tenants; texto da plataforma e de terceiro em campos disjuntos, sem
interpolação; `structuredContent` + `outputSchema` com `text` sendo JSON; sinalizar (sem
remover) caracteres invisíveis; nenhum Markdown montado pelo servidor; nenhuma ferramenta que
siga URL.

**6. Algum campo das quatro ferramentas expõe e-mail, `platform_access_level`, segredo ou dado
que a tela esconde? Mensagens de erro da `ex_mcp` ecoam entrada ou stacktrace?**
**Nos contratos, não.** Os campos declarados (`contracts/ferramentas.md`) são `person_id`,
`name`, `login`, `situation`, `direct`, `memberships` (`team_id`, `team_name`, `origin`,
`role`, `current`), contagens, `issue_id`, `title`, idades e marcas — o mesmo que
`GET /api/v1/teams/:id/members` e `/measures` já entregam (`team_controller.ex:372-400`), que
excluem o e-mail de quem declarou de propósito. `login` e nome são **diretório**, que a
FR-024 da 045 põe fora do veredito por pessoa; tarefas abertas por pessoa ficam atrás de
`pode_ver_equipe/3`, que é o fecho que a própria `access.ex` documenta. **Não verifiquei** se
`memberships` traz vínculos com equipes **fora** do escopo do roster — `list_team_roster/3`
passa o escopo a `com_vinculos/4` (`eo/roster.ex:86-99`), mas não li essa função; o teste de
SC-005 deve incluir uma pessoa com vínculo numa equipe que quem chama não alcança.
**Erros da `ex_mcp`**: para o cliente, genéricos — `"Internal error"`, `"Method failed"` com
`data.type` estável (`method_handlers.ex:580-605`); id de sessão inválido não é ecoado
(`http_plug.ex:116-124`); versão de protocolo não suportada ecoa **a versão pedida** (entrada
do próprio cliente, `http_plug.ex:791-806`), inofensivo. **Para o log**: falha de handler vai
com stacktrace e, em `FunctionClauseError`, com os argumentos (`method_handlers.ex:331`) — por
isso o R7. Erro de ferramenta binário vai ao modelo (`result_normalizer.ex:286-311`).

**7. CSRF e origem: o `/mcp` pode aceitar cookie de sessão? DNS rebinding? O que a spec do MCP
exige sobre `Origin`?**
**Cookie: não.** A pipeline `:api` não chama `fetch_session` (`router.ex:44-47`), e o
`ApiAuth` lê só o cabeçalho `Authorization` (`api_auth.ex:39-46`); o `Plug.Session` do
endpoint (`endpoint.ex:53`) não decodifica nada sem `fetch_session`. Não há credencial
ambiente, então não há CSRF clássico. **Preflight**: `Authorization` não é cabeçalho simples;
o `OPTIONS` cai no `ApiAuth` e recebe `401` sem cabeçalho CORS, e o navegador bloqueia.
**DNS rebinding** é ataque contra servidor **local**; este é remoto e exige token. Ainda
assim, a biblioteca valida `Origin` por padrão: `validate_origin: true`, `allowed_origins: []`,
`cors_enabled: false` (`http_plug.ex:207-210`), e qualquer requisição **com** `Origin` fora da
lista recebe `403` (`http_plug.ex:69-79`, `core.ex:50-62`); requisição sem `Origin` passa, que é
o caso de cliente não-navegador. **A spec do MCP** (transporte Streamable HTTP, revisões
2025-03-26 em diante): o servidor MUST validar o `Origin` de toda conexão para prevenir DNS
rebinding, e — a partir de 2025-06-18 — MUST responder `403` quando o `Origin` presente for
inválido; servidor local SHOULD ouvir só em `localhost`; SHOULD autenticar. **Fonte**: meu
conhecimento das revisões de 2025, conferido contra o que a biblioteca implementa; **não li o
texto da revisão 2026-07-28**. **O que a implementação deve fazer**: declarar as três opções
explicitamente no `forward` (para que ninguém troque o padrão sem diff visível), nunca
`allowed_origins: :any`, e testar `Origin: https://exemplo.invalid` → `403`.

**8. O token de produção que passou por proxy que intercepta TLS.**

> **Atualização de 2026-09-24:** **Revogado em 2026-09-24 pela pessoa mantenedora** — declarado, e não medido: pela SC-003 um token revogado e um inexistente respondem igual, então a revogação não se confere de fora. A recomendação abaixo, de conferir no painel de uso se o
> token leu algo depois das medições, continua valendo.

**Localizado** em `docs/releases/v0.9.1.md:417`, na tabela de lacunas: *"o token de produção
usado nas medições passou por um proxy que intercepta TLS"*, classificação **"por revogar"**,
*"ato da pessoa mantenedora. Enquanto não for revogado, existe uma credencial de produção que
já trafegou por intermediário"*; e `:421-423`, que dá a ela **precedência sobre as outras**
por ser a única exposição ativa. `RETOMAR.md:116-117` repete, no commit mais recente deste
branch: *"ainda por revogar. Trate como vazado"*. **Não há evidência no repositório de que foi
revogado**: nenhuma nota, ata de aceitação (`docs/producao/aceitacao/2026-09-24-v0.9.1.md`
não menciona) ou commit registra a revogação. O repositório não tem como provar revogação —
ela é estado do banco de produção —, então a ausência aqui não prova que ela não ocorreu; prova
que **não foi registrada**. Não acessei a produção. **Recomendação**: revogar com a cláusula
`suspeita_de_vazamento`, conferir no painel de uso do #939 se esse `public_id` leu algo depois
da medição, e registrar o ato na nota da próxima release.

---

## O que não avaliei

Com o nome, para que esta revisão não seja lida como "está seguro":

1. **O resto da `ex_mcp`**: li a borda HTTP e o ciclo de requisição. **Não li**: o transporte
   `GET` SSE legado (`http_plug/sse_handler.ex`, além das linhas de replay), MRTR
   (`max_input_requests`, `request_state`), a extensão de *tasks* e o `Tasks.Store.ETS`, o
   `ReplayCache`, o OAuth (`authorization/*`), a resolução remota de JSON Schema
   (`content/schema_remote_resolver.ex`, que faz requisição de saída — uma quarta borda A10 se
   algum dia ligada), os adaptadores ACP, o transporte stdio, `jose`, `mint_web_socket`,
   `ex_json_schema`. Não sei se `clientInfo` do `initialize` é guardado na sessão (e com que
   tamanho);
2. **a biblioteca rodando**: tudo acima é leitura. Não integrei a `ex_mcp` ao Phoenix, não
   confirmei o comportamento do `forward` com `halt`, nem medi o `before_send` com
   `send_chunked`. Os achados R1 e R2 são de leitura de código, com as linhas citadas;
3. **o texto da revisão 2026-07-28 do MCP**, e **quais clientes reais** (Claude Code, Claude
   Desktop, outros) falam a revisão moderna — o que decide se `:modern_only` (R5) é viável;
4. **o filtro por tenant das consultas de `TeamWork` e `Quality`** que `team_open_work`,
   `team_review_wait` e `team_stale_work` vão chamar. Conferi só `fetch_team/2` e
   `list_team_roster/3`. Se alguma não filtrar, o R6 sobe para alta;
5. **`com_vinculos/4`** e portanto se `memberships` pode trazer equipe fora do alcance
   (pergunta 6);
6. **a paridade tela ↔ API hoje**: não li a LiveView da equipe; aceitei o que a 061 afirma;
7. **quantos nós rodam em produção** (o limite é por nó) e **se o proxy/Dokploy tem timeout de
   conexão** que encurte os streams do R4;
8. **o estado da revogação do token da pergunta 8** fora do que o repositório registra;
9. **`mix deps.audit`** (a outra base de avisos) sobre o grafo com `ex_mcp` — só rodei
   `mix hex.audit`;
10. **`mix gates` deste repositório**: não rodei. Esta tarefa não alterou código — só criou
    este arquivo —, e o veredito dos gates é do QA. Nenhum gate foi executado com pipe.

---

## O que isto pede ao `tasks.md` (para o Product Owner decidir)

| Achado | Tarefa proposta | Onde |
|---|---|---|
| R1, R2 | reescrever T021/T022: registro no ponto do veredito, no registro fechado; `ApiReadLog` pula `/mcp` por marca posta antes da biblioteca; o teste de R1 | T021, T022 |
| R3 | **decisão antes do T001**: aceitar as duas advisories com registro de risco, esperar a 2.0, ou enquadramento próprio; e corrigir "única dependência" para dez pacotes, com versão fixada | T001, research.md D1 |
| R4 | lista fechada de métodos JSON-RPC antes da biblioteca | nova, antes do T007 |
| R5 | decidir `:modern_only`, ou vincular a sessão ao token e dimensionar o teto | T007 |
| R6 | caminho único `fetch_team → veredito → carga`; `inputSchema` com `format: uuid` e `additionalProperties: false`; teste com admin e equipe de outro tenant | T006, T017, T018 |
| R7, R8 | opções do handler por MFA e só com identificadores; `request_id` no `Logger.metadata` do handler | T007 |
| R9, R10 | limite do `Plug.Parsers`; corrigir o contrato do `404` | backlog, contrato |
| A3+ | os seis complementos | T014, T015 |
| I1 | a recomendação do token de alcance mínimo | T029 |
| I2 | revogar e registrar | fora da 062, precedência sobre ela |

Os achados ficam **abertos** até serem corrigidos ou explicitamente aceitos. Despriorizado não
é resolvido.
