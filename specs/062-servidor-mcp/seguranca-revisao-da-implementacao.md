# Revisão de segurança independente da implementação — feature 062, servidor MCP

**Data**: 2026-09-25 · **Branch avaliado**: `062-mcp-implementacao` (PR #981), em `b3b120f`,
contra `origin/development`

**Quem avaliou**: o agente `security` (`AGENTS.md` §13). **Não escrevi este código** e não
escrevi o desenho. Esta revisão não aceita nem recusa nada. A classificação do entregável e a
decisão sobre cada achado ficam com o Product Owner. Achado alto aqui é **recomendação** de
bloqueio.

**Régua**: OWASP Top 10 (2021), OWASP ASVS 4.0, e OWASP Top 10 for LLM Applications (LLM01,
LLM02) onde o consumidor ser um modelo muda o risco.

**Tipo de trabalho**: revisão do **diff** (`git diff origin/development...origin/062-mcp-implementacao`,
33 arquivos) e das superfícies que ele reusa, mais a leitura do código da `ex_mcp` 1.5.0 em
`deps/ex_mcp` onde o comportamento dependia dela. Sete cenários foram **medidos** com testes de
rascunho pela rota real `/mcp`, num worktree descartável (removido ao fim, e nenhum arquivo de
rascunho ficou no repositório). Não escrevi exploit, não toquei sistema externo, não acessei
produção. Nenhum segredo foi lido, pedido ou gravado.

---

## O que foi lido

- **Contexto MCP**: `lib/the_band/mcp/ferramentas.ex`, `envelope.ex`, `ausencia.ex`,
  `texto_de_terceiro.ex`, `ferramentas/team_roster.ex`, `team_open_work.ex`,
  `team_review_wait.ex`, `team_stale_work.ex`
- **Transporte**: `lib/the_band_web/mcp/porta.ex`, `servidor.ex`,
  `lib/the_band_web/plugs/mcp_metodos.ex`, `api_read_log.ex`, o escopo `/mcp` de
  `lib/the_band_web/router.ex`, e o `Plug.Parsers` de `endpoint.ex:46-49`
- **Domínio tocado pelo diff**: `lib/the_band/tenants/access_events.ex` (`equipe_recusada/4`),
  `lib/the_band_web/controllers/api/v1/team_controller.ex` (`com_equipe/3`),
  `lib/the_band_web/live/teams_live/show.ex` (o N6 do inventário de 2026-09-24, e não o N6 desta revisão), `lib/the_band/profiles.ex`
  (`conversa_das_issues/2`), `lib/the_band/ingestion.ex` (`ultima_coleta_concluida/1`),
  `lib/the_band/ontology/knowledge_base.ex`
- **Domínio reusado, lido para a pergunta de vazamento e de tenant**:
  `lib/the_band/ontology/seon/eo/roster.ex` (inteiro), `EO.fetch_team/2`
  (`eo/queries.ex:1531`), `EO.team_member_ids_at/4` (`eo/queries.ex:378`),
  `TeamWork.open_tasks_by_person/4` e `fechadas_entre/4`, `Quality.team_time_to_first_review/3`,
  `Discussions.last_act_for_issues/2`
- **`mix.exs`**: a exceção do `cowlib` (linhas 21-46) e `{:ex_mcp, "== 1.5.0"}` (linha 184)
- **Testes**: todos em `test/the_band/mcp/`, `test/the_band_web/mcp/`, mais
  `test/the_band_web/api/recusa_de_equipe_registrada_test.exs` e
  `test/the_band/cowlib_inalcancavel_test.exs`
- **`ex_mcp` 1.5.0**: `http_plug.ex` (despacho, seleção de era, `read_or_cached_body`,
  `request_stream?`), `transport/http/request_headers.ex` (validação de `Mcp-Method`/`Mcp-Name`),
  `message_processor.ex`, `message_processor/method_handlers.ex` (`safe_call`, `put_error`),
  `server/cancellation.ex`, `server/context.ex`, `internal/message_validator.ex`
- **A revisão do desenho**: `specs/062-servidor-mcp/seguranca-revisao-independente.md` (R1-R10,
  complementos ao A3, I1, I2)

## O que foi rodado, com o código de saída lido

| Comando | Código de saída | O que ele diz |
|---|---|---|
| `mix sobelow --exit low --skip` | **0** | nenhum padrão reconhecido pelo Sobelow no código lido. **Mediu**: com uma sonda de mentira em `lib/the_band_web/mcp/` (HTML interpolado e SQL montado) saiu **1** e apontou o arquivo; removida a sonda, voltou a 0 |
| `mix hex.audit` | **1** | **reprova**, por um aviso **novo e alheio à 062**: `lazy_html 0.1.12 - EEF-CVE-2026-92106 (LOW)`, dependência só de teste (`mix.exs:113`). As duas do `cowlib` aparecem como *Ignored advisories*, o que prova que a exceção está ativa. `mix hex.info lazy_html` mostra a `0.1.13` publicada hoje, 2026-09-25. Ver N7 |
| `mix deps.audit` | **0** | "No vulnerabilities found". Não enxerga o aviso do `lazy_html`, que é a razão de os dois auditores coexistirem |
| os 12 arquivos de teste da 062 e o `cowlib_inalcancavel_test.exs` | **0** | 77 testes, 0 falhas |

Não rodei a suíte inteira (servidor dev de pé) e **não rodei `mix gates`**: com o
`hex.audit` em 1, o gate reprova hoje, e esse veredito é do QA.

---

## Resumo

| # | Achado | Severidade | Onde |
|---|---|---|---|
| **N1** | `team_roster` devolve o **e-mail** de quem registrou o equívoco (`mistake.por`) | **alta** | `team_roster.ex:84`, via `roster.ex:324,398` |
| **N2** | `team_roster` **quebra** em qualquer equipe com vínculo encerrado: tupla no JSON, e-mail no log de erro, e a leitura gravada sem resposta entregue | **média** | `team_roster.ex:83`, `roster.ex:376-393`, `servidor.ex:82`, `ferramentas.ex:185-195` |
| **N3** | `notifications/cancelled` enche uma tabela ETS **global** sem limpeza nem teto | **média** | `mcp_metodos.ex:48`, `ex_mcp/server/cancellation.ex:25-28` |
| **N4** | `mistake.razao` é texto livre fora de `untrusted_text` | **baixa** | `team_roster.ex:84`, `roster.ex:398` |
| **N5** | corpo não-JSON levanta exceção no `McpMetodos` (500) | **baixa** | `mcp_metodos.ex:83-84` |
| **N6** | `team_open_work` e `team_stale_work` não têm teto de itens | **baixa** | `team_open_work.ex:36-39`, `team_stale_work.ex:34-48` |
| **N7** | o gate `mix hex.audit` está vermelho por `lazy_html 0.1.12` | **baixa** (alheio à 062, mas bloqueia o gate) | `mix.lock:36`, `mix.exs:113` |
| **I-a a I-e** | informativos | informativo | seção própria |

**Nenhum achado crítico, e nenhum caminho entre tenants.** Não achei caminho em que o tenant ou o
alcance venham de argumento, do `_meta`, de cabeçalho do cliente ou de estado entre requisições
(pergunta 2, abaixo). O achado alto é **dado pessoal de conta que sai pela porta**, dentro do
mesmo tenant, contra a FR-030 e o SC-005 desta feature. **Ele existe igual na API da 061**
(`team_controller.ex:409`), porque as duas portas usam o mesmo `Roster`.

---

## N1 — `team_roster` devolve o e-mail de quem registrou o equívoco · **ALTA**

**OWASP**: A01 (exposição de dado a quem não deveria recebê-lo), A04. **ASVS**: V8.3.1 (dado
sensível fora do necessário), V8.3.4. **LLM02**. **Contradiz**: FR-030, FR-032 e SC-005 da 062;
e o comentário da própria ferramenta (`team_roster.ex:72-73`, *"Quem declarou não sai: o campo
é um e-mail"*).

**O que acontece**. `Roster.com_vinculos/4` seleciona `invalidated_by: quem_invalidou.email`
(`roster.ex:324`), e `equivoco/1` o devolve como `%{razao: …, por: v.invalidated_by, em: …}`
(`roster.ex:398`). A ferramenta repassa o mapa inteiro: `mistake: v.equivoco`
(`team_roster.ex:84`). A implementação tirou o `declared_by` e deixou passar o mesmo e-mail,
com outra chave, **um nível abaixo**.

**Medido**, pela rota `/mcp`, com token: um vínculo declarado por um admin e depois marcado como
equívoco por ele. A resposta de `team_roster` trouxe, em `structuredContent` **e** em
`content[0].text`:

```
"mistake":{"razao":"…","em":"2026-09-25T14:32:28Z","por":"admin-163@example.test"}
```

`GET /api/v1/teams/:id/members` devolveu o mesmo e-mail na mesma medição.

**Cenário concreto**. Quem tem um token de uma conta que alcança a equipe (a liderança dela, e
não só o admin, pela `pode_ver_equipe/3`) liga o token num cliente MCP cujo modelo roda num
provedor externo. Toda equipe que já teve um vínculo corrigido como equívoco entrega ao
provedor o e-mail de quem corrigiu, que é **a conta de administração**. O e-mail é o
identificador de entrada da plataforma (`Tenants.Auth`), e a 045 gasta a FR-002 inteira para
não o enumerar. Pela FR-032, o que saiu pode ficar cacheado do outro lado, fora do alcance da
revogação. Não é recuperável depois de sair.

**Consequência para o negócio**: *quem lidera uma equipe, ou o agente dessa pessoa, recebe o
e-mail de login de quem administra a organização, e isso sai da plataforma para o provedor do
modelo.*

**Por que os testes não pegaram**: `segredo_nao_vaza_test.exs` varre a resposta inteira com a
regex de e-mail (linha 145), e isso está certo. Mas a fixture (linhas 40-63) só cria um vínculo
**observado**, sem declaração, sem saída e sem equívoco. O campo que vaza nunca é povoado. É o
teste vazio com outra forma: a varredura mede, e o dado que vazaria não está lá. O
`team_detail_test.exs:170` da 061 tem o mesmo ponto cego.

**O que a correção deve fazer**:

1. montar o `mistake` campo a campo, na ferramenta **e** no `team_controller.ex`:
   `%{reason: …, at: …}`, **sem** `por`. Se *quem* for necessário, só o `user_id` ou a marca
   `declared_by_platform_user: true`, nunca o endereço. Nomes em inglês, como o resto da resposta;
2. para não reincidir, parar de selecionar e-mail em `Roster` para as portas externas, ou
   devolver um relator próprio para elas. Hoje a tela precisa do e-mail e as portas não, e a
   filtragem vive em quem chama. É o desenho "defesa que mora no chamador" (A04), e este achado
   é a prova de que ele falha.

**O teste que prova** (cenário para o QA): na fixture de `segredo_nao_vaza_test.exs`, somar
**as três formas de vínculo**: declarado, encerrado por saída declarada e marcado como equívoco,
todos por uma conta cujo e-mail é conhecido. Guarda positiva antes da refutação:
`assert resposta =~ ~s("mistakes":1)`, o que prova que o equívoco está na resposta. Depois
`refute resposta =~ admin.email` e `refute Regex.match?(@email, resposta)`. O mesmo para
`/api/v1/teams/:id/members`. Prova de que mede: com a correção desfeita, reprova (hoje reprova).

**Se não entrar agora**: cada chamada de `team_roster` sobre uma equipe com equívoco registrado
entrega o e-mail, e isso não se desfaz. A 061 já está exposta hoje, em produção, pelo mesmo
caminho.

---

## N2 — `team_roster` quebra em toda equipe com vínculo encerrado · **MÉDIA**

**OWASP**: A04, A09. **ASVS**: V7.4.1 (erro sem dado sensível), V7.1.3. **Contradiz**: FR-013
(a resposta nunca vira erro opaco), FR-025 (*recusa não é leitura*, e aqui é o espelho disso:
erro gravado como leitura) e §14/§15 (log sem dado pessoal).

**O que acontece**. `ended_at: v.fim` (`team_roster.ex:83`) repassa `Roster.fim/1`, que devolve
**tupla** para todo vínculo encerrado: `{:declarado, email, registrado, quando}`,
`{:coleta, quando}` ou `{:sem_autor, quando}` (`roster.ex:376-393`). `Jason` não codifica
tupla. A ordem em `Ferramentas.com_equipe/5` é `responder` → `ApiAccessLog.registrar` → devolve
(`ferramentas.ex:185-195`), e a serialização só acontece depois, em `servidor.ex:82`.

**Medido**, com um vínculo declarado e uma saída declarada:

- o cliente recebe `{"error":{"code":-32603,"data":{"type":"handler_crash"},"message":"Tool call failed"}}`.
  A biblioteca não põe o detalhe na resposta, e isso está certo;
- **a linha de leitura foi gravada** (contagem de `api_access_reads` passou de 2 para 3), sem
  que o cliente tenha recebido nada;
- **o e-mail de quem declarou a saída foi para o log de erro**, pelo `Logger.error` da
  biblioteca (`method_handlers.ex:584-590`), que imprime o `Protocol.UndefinedError` com o valor:
  `value: {:declarado, "admin-162@example.test", …}`;
- `GET /api/v1/teams/:id/members` **levanta** a mesma exceção (500). O defeito é da 061 e a 062
  o herdou.

**O alcance real é maior que o medido.** `{:coleta, quando}` é o vínculo **observado** que a
coleta encerrou quando a pessoa sumiu do time no GitHub. Isso acontece sozinho, em toda equipe
real com rotatividade. Não medi isso em produção, mas pelo código a ferramenta de roster, que é a
`sro.cq15`, falha em quase toda equipe com histórico.

**Consequência para o negócio**: *a ferramenta de roster não responde para equipes que já
perderam alguém; o log de erro guarda e-mails de administradores; e o registro de auditoria diz
que houve leitura onde não houve.*

**O que a correção deve fazer**:

1. traduzir `fim` campo a campo, casado por forma, como `origem/1` e `situacao/1` já fazem
   (`team_roster.ex:88-94`): `%{at: quando, by: "declared" | "collection" | "unknown"}`, sem o
   e-mail. O mesmo no `team_controller.ex:408`;
2. **serializar antes de registrar**, ou mover o `Jason.encode!` para dentro do caminho único,
   antes do `ApiAccessLog.registrar`. A regra do moduledoc (*"uma ferramenta que falhe não deixa
   uma leitura que não houve"*, `ferramentas.ex:36-38`) só vale se a falha de serialização
   estiver antes do registro.

**Teste**: equipe com os três fins (`declarado`, `coleta`, `sem_autor`). `team_roster` responde
`state: "checked"` com `ended_at` como objeto. Nenhuma linha do log capturado contém o e-mail. E
um teste de ordem: com uma ferramenta de mentira cujo `responder/2` devolve um termo que não
serializa, **zero** linhas em `api_access_reads`. Guarda: a mesma ferramenta, com termo válido,
grava uma linha.

---

## N3 — `notifications/cancelled` enche uma tabela ETS global, sem teto · **MÉDIA**

**OWASP**: A04, A05. **ASVS**: V11.1.4 (anti-automação), V13.1.3 (limite de recurso por
requisição). **Contradiz**: o próprio `McpMetodos` (*"método sem uso é superfície sem dono"*,
`mcp_metodos.ex:26-27`) e a S7 da 061, que continua aberta.

**O que acontece**. `notifications/cancelled` está na lista permitida (`mcp_metodos.ex:48`). A
biblioteca grava o `requestId` recebido em `:ex_mcp_cancelled_requests`, uma tabela ETS
**nomeada, pública e global ao nó** (`ex_mcp/server/cancellation.ex:25-28`, chamada por
`message_processor.ex:592`), **antes** de qualquer handler. A entrada só sai quando uma
requisição com **o mesmo** id roda até o fim (`server/context.ex:175`). O `requestId` pode ser
qualquer string (`message_validator.ex:479-484`), do tamanho que o corpo permitir: 1 MB pelo
`body_limit` da `ex_mcp` e 8 MB pelo `Plug.Parsers` (R9). E o nosso handler **nunca** consulta
`Context.cancelled?/0`: o método não tem efeito nenhum aqui, só o custo.

**Medido**: cinco `notifications/cancelled` pela rota, com token e `requestId` de 200 KB. Todas
deram `202`. A tabela foi de 0 para 5 entradas, e a memória de binários do nó subiu
**1 000 064 bytes** depois de coleta de lixo. Nada limpa isso.

**Cenário concreto**. Um token válido de qualquer tenant manda 120 notificações por minuto (o
limite por token), cada uma com um `requestId` único de ~900 KB. Em ordem de grandeza, são
~100 MB por minuto por token, retidos até o nó reiniciar. Com poucos tokens, o nó único esgota a
memória, e **todos os tenants** perdem a tela, a API e o MCP. É disponibilidade, não vazamento:
a chave é global, mas o nosso handler não lê a marca, então um tenant não altera a resposta de
outro. **Por isso é média, e não alta.**

**O que a correção deve fazer**: tirar `notifications/cancelled` da lista (`mcp_metodos.ex:48`).
Nenhuma ferramenta desta fatia é longa o bastante para ser cancelada, e o handler não observa o
cancelamento. Se ele ficar, o plug precisa recusar `requestId` que não seja inteiro ou string
curta (por exemplo ≤ 64 bytes). Mesmo assim a tabela continua global e sem teto, e isso precisa
ser escrito no `plan.md` como risco aceito.

**Teste**: `notifications/cancelled` pela rota recebe `-32601` e **não** altera
`:ets.info(:ex_mcp_cancelled_requests, :size)`. Guarda: o tamanho da tabela é lido antes e
depois, e o teste de controle, com o plug desligado, vê o tamanho crescer.
`registro_test.exs:98` usa esse método como "a notificação" do cenário e precisa trocar para
outra forma de `202`, ou virar asserção de recusa.

---

## N4 — `mistake.razao` é texto livre fora de `untrusted_text` · **BAIXA**

**OWASP LLM01**. Complemento 2 ao A3 (*texto de fora e texto da plataforma nunca no mesmo
campo*). `invalidation_reason` é escrito à mão por quem administra (`commands.ex:234`) e sai cru
em `mistake.razao` (`roster.ex:398`, `team_roster.ex:84`). A ferramenta marca o `role.name` pela
mesma razão (`team_roster.ex:79-81`, *"ainda é texto livre, escrito por alguém"*), e esqueceu
este campo. Na medição do N1, a razão `"Ignore previous instructions"` saiu sem marca.

É baixa porque quem escreve está dentro do tenant e já administra. **Correção**: junto com o N1,
`reason: TextoDeTerceiro.marcar(v.invalidation_reason)`. **Teste**: acrescentar o equívoco com
razão hostil ao `ferramentas_de_equipe_test.exs:181` (*"fora de untrusted_text, o título hostil
não aparece em lugar nenhum"*), que hoje só cobre `team_open_work` e `team_stale_work`, e
estender o laço a `team_roster`.

---

## N5 — corpo não-JSON levanta exceção no `McpMetodos` · **BAIXA**

Com `content-type: text/plain`, o `Plug.Parsers` (`pass: ["*/*"]`) deixa `body_params` como
`%Plug.Conn.Unfetched{}`. Nenhuma cláusula de `avaliar/2` casa, a última faz `pedido["id"]` e
levanta `ArgumentError` (`mcp_metodos.ex:83-84`). **Medido**: a requisição autenticada termina
em exceção, com stacktrace no log. **Não chega à biblioteca nem à ferramenta**, e não grava
leitura: falha fechada, mas como 500. Com `application/x-www-form-urlencoded`, o plug deixa
passar o `tools/call` do formulário, e a biblioteca recusa com `-32700` porque não é JSON
(**medido**). Também fecha.

**Correção**: uma cláusula `avaliar(conn, %Plug.Conn.Unfetched{})` e outra para corpo que não
seja JSON, com `415` ou `-32700`. **Teste**: em `metodos_test.exs`, o plug com
`body_params: %Plug.Conn.Unfetched{aspect: :body_params}` fica `halted` e não levanta. Hoje o
teste monta sempre `body_params` como mapa (`metodos_test.exs:21`), e por isso não vê o caso.

---

## N6 — `team_open_work` e `team_stale_work` sem teto de itens · **BAIXA**

`team_roster` e `team_review_wait` cortam em 200 e dizem `truncated`
(`team_roster.ex:28,44`, `team_review_wait.ex:31,57`). As outras duas devolvem **toda** tarefa
aberta dos membros, cada uma com o título (`team_open_work.ex:36-39`,
`team_stale_work.ex:34-48`), e `team_open_work` roda `open_tasks_by_person/3` duas vezes, uma
dentro de `snapshot/4` (`team_work.ex:313`). A API faz o mesmo em `open_by_person`
(`team_controller.ex:446-449`), então isto é paridade, e não regressão.

Pesa mais no MCP por dois motivos. Cada título é texto de terceiro que entra no contexto do
modelo, e mais volume é mais superfície para o LLM01. E o modelo não pagina. **Correção**: o
mesmo teto com `truncated` e `limit` das outras duas. **Teste**: equipe com 201 tarefas abertas
dá `truncated: true` e 200 itens.

---

## N7 — o gate `mix hex.audit` está vermelho por `lazy_html 0.1.12` · **BAIXA**, alheio à 062

`EEF-CVE-2026-92106 (LOW)`, mutação de XSS na serialização de SVG/MathML. É dependência
**só de teste** (`mix.exs:113`), e nada em `lib/` a usa. A `0.1.13` saiu hoje. O PR #981 não
mexe em `mix.lock`, então `development` está no mesmo estado. **O que importa para a 062**:
enquanto isto não for resolvido, `mix gates` sai diferente de zero no PR, e nenhum verde pode ser
declarado. **Correção**: `mix deps.update lazy_html`, com o `hex.audit` relido depois. **Não**
com `ignore_advisories`, que seria enfraquecer o gate para um aviso que já tem correção.

---

## A revisão do desenho, item a item: fechado no código, ou só no papel

| # | Estado | Evidência | Ressalva |
|---|---|---|---|
| **R1** registro no ponto do veredito | **fechado no código, com defeito de ordem** | `ferramentas.ex:180-195` grava `mcp:<ferramenta>` com o `equipe.id` carregado; `porta.ex:55` põe `:delegado` no processo da requisição; `api_read_log.ex:48` pula. `registro_test.exs:89-133` prova as duas linhas exatas, zero `/mcp` e a recusa sem linha, com guarda positiva | a leitura é gravada **antes** da serialização (N2): a falha depois de `responder/2` deixa leitura sem resposta |
| **R2** respostas `2xx` que não são leitura | **fechado** | a marca cobre toda resposta sob `/mcp`; stream recusado antes da biblioteca (`mcp_metodos.ex:66-74`), **medido**: `progressToken` → `400`, `application/json`; notificação `202` sem linha (`registro_test.exs:98`) | o critério do stream na biblioteca é `params._meta` + `Accept` (`http_plug.ex:2011-2020`), e o plug olha o mesmo `params._meta`. Sem divergência |
| **R3** `ex_mcp` e o `cowlib` | **fechado por decisão registrada** (risco residual aceito) | `mix.exs:21-46`, com quem decidiu e quando; `== 1.5.0` em `mix.exs:184`; as quatro guardas de `cowlib_inalcancavel_test.exs` passam; o `hex.audit` lista as duas como *Ignored* | o gate está vermelho por outro motivo (N7) |
| **R4** `subscriptions/listen` e métodos sem uso | **fechado, com um método a mais** | lista fechada `mcp_metodos.ex:48`; **medido**: `tasks/get`, `tasks/cancel`, `resources/list`, `completion/complete`, `sampling/createMessage` → `404`; `protocolo_test.exs:125` prova pela rota | `notifications/cancelled` ficou na lista, sem uso, e abre o N3 |
| **R5** sessões legadas | **fechado** | `protocol_mode: :modern_only` (`porta.ex:35`); `GET`/`DELETE` → `405` (`protocolo_test.exs:94`); **medido**: `tools/call` legado sem sessão → `400 Session ID required`, com sessão inventada → `404 Session not found`; `initialize` recusado pelo plug, então nenhuma sessão legada nasce | — |
| **R6** equipe carregada antes do veredito | **fechado** | `ferramentas.ex:180-181`, e `inputSchema` com `format: uuid` e `additionalProperties: false` (`ferramentas.ex:60-71`); `ferramentas_test.exs:111-123` com a guarda de que o ramo admin concede | — |
| **R7** estado por requisição, por MFA | **fechado** | `porta.ex:32-44` (MFA `{Servidor, :estado, []}`), `servidor.ex:39-46`; `protocolo_test.exs:216-230` varre o `inspect` do estado atrás do segredo | o estado leva `%User{}` inteiro, e `email` não é campo `redact` (`user.ex:47-64`). Não o vi impresso no relatório de queda medido (I-c) |
| **R8** correlação no processo do handler | **fechado** | `servidor.ex:49-51`; `registro_test.exs:123-132` prova o `request_id` do cabeçalho na linha de recusa | — |
| **R9** JSON decodificado antes da autenticação | **aberto**, como decidido | `endpoint.ex:46-49` sem `length`; o `tasks.md:48` o manda para *Fora desta fatia* | o N3 mostra que o limite de corpo também é limite de memória retida |
| **R10** `404` sob `/mcp` | **fechado** | `porta.ex:50-52`; `protocolo_test.exs:110-118`; contrato corrigido (`contracts/ferramentas.md:22-23`) | — |
| **A3.1** canais de alta confiança constantes | **fechado** | descrições e esquema constantes (`ferramentas.ex:60-120`), `instructions` constante (`porta.ex:40-43`); `protocolo_test.exs:164` compara `tools/list` de dois tenants | — |
| **A3.2** texto de fora nunca em campo da plataforma | **parcial** | `note`, `limitations`, `missing` são constantes ou da base; títulos, nomes de equipe e papel marcados | `mistake.razao` sai cru (N4) |
| **A3.3** `structuredContent` + `text` como JSON do mesmo objeto | **parcial** | `servidor.ex:80-84`; `protocolo_test.exs:196-197` | não há `outputSchema` em `tools/list` (`servidor.ex:58`). O cliente não recebe o schema que diria que `untrusted_text` é a fronteira |
| **A3.4** caracteres invisíveis sinalizados | **fechado** | `texto_de_terceiro.ex:30`; `ferramentas_de_equipe_test.exs:158-162` com o bloco de *tags* | — |
| **A3.5** nenhum Markdown montado | **fechado** | a resposta é JSON; nenhuma prosa montada com dado | — |
| **A3.6** nenhuma ferramenta busca URL | **fechado** | `fronteira_test.exs:68-89` (AST) | a busca por `:httpc.` é textual (`fronteira_test.exs:78`), e reprovaria a palavra num comentário. Não é falha de segurança |
| **I1** token de admin alcança o tenant | **aberto, sem código a fazer** | destino é o T029 (`tasks.md:593`), ainda `[ ]` | — |
| **I2** token de produção exposto a interceptação | **não avaliado aqui** | fora do diff | continua com precedência, se ainda sem evidência de revogação |

---

## As oito perguntas da tarefa

**1. R1-R10 e A3 fechados no código?** Ver a tabela. Oito dos dez R estão fechados no código,
o R3 por decisão registrada, e o R9 segue aberto como decidido. Há dois defeitos novos dentro de
itens fechados: a ordem registro-serialização (R1 → N2) e o método a mais (R4 → N3). O A3 está
**parcial** em dois dos seis complementos.

**2. Isolamento por tenant.** **Não achei caminho**, e isto foi conferido assim:

- o tenant, a conta e o `public_id` vêm só de `conn.assigns`, que o `ApiAuth` escreve
  (`servidor.ex:39-46`). Nada lê `_meta`, `mcp-name`, `mcp-method` nem argumento para isso. O
  `_meta` é descartado antes do registro (`servidor.ex:66`), e qualquer chave além de `team_id`,
  inclusive `tenant_id`, é recusada (`ferramentas.ex:170-178`, `protocolo_test.exs:174`);
- **`mcp-name` divergente do corpo** → `400 -32020 "Mcp-Name header does not match the JSON-RPC
  body"`. **`mcp-method` divergente** → idem (**medido**, `request_headers.ex:158-176`). O despacho
  usa o `name` do corpo, e o corpo e o cabeçalho têm de coincidir;
- **contornar `Ferramentas.chamar/5`**: o único chamador de `responder/2` é
  `ferramentas.ex:185` (grep em `lib/`), e o único chamador de `chamar/5` é `servidor.ex:70`.
  Ferramenta fora do registro → `Unknown tool` (**medido**);
- estado entre requisições: um `GenServer` por requisição, com opções por MFA (R7), e
  `protocolo_test.exs:200` alterna tokens de tenants diferentes;
- as consultas reusadas filtram por tenant, ou partem de uma equipe já carregada no tenant:
  `fetch_team` (`eo/queries.ex:1532`), `team_member_ids_at` (`eo/queries.ex:388`),
  `open_tasks_by_person` (`team_work.ex:270`), `fechadas_entre` (`team_work.ex:341`: o
  `TeamMembership` não filtra tenant, mas o `team_id` é do tenant e a issue filtra),
  `Quality.abertas_por_quem_pertencia` (`quality.ex:165-167`), `last_act_for_issues`
  (`communication/discussions.ex:118`), `com_comentarios_coletados` (`profiles.ex:217`),
  `ultima_coleta_concluida` (`ingestion.ex`, novo).

**3. O registro de leitura.** Só na concessão, e a recusa não grava (`registro_test.exs:119`).
Exceção **dentro** de `responder/2` não grava, porque o registro vem depois (por leitura de
código, não medido). Erro de protocolo da biblioteca não grava (`:delegado`, e nenhum
`registrar`). **Falha de serialização grava** (N2, **medido**). O `:delegado` vive em
`conn.private`, que só código do servidor escreve. Não há caminho do cliente até ele (grep:
`porta.ex:55` e `api_read_log.ex:48` são as duas únicas ocorrências).

**4. Vazamento.** **Sim**: e-mail em `mistake.por` (N1) e no log de erro (N2).
`platform_access_level` não sai (`segredo_nao_vaza_test.exs:132-142`, e `Roster` não o
seleciona). `declared_by` não sai. Segredo do token não sai. Perfil e competências (H2-R): nenhuma
das quatro ferramentas lê perfil ou competência, e `conversa_das_issues/2` devolve só estado,
contagem e data (`profiles.ex:201-207`). Os erros que vão ao modelo são constantes, com uma
exceção: `unexpected argument: <chaves>` ecoa as chaves que o próprio cliente mandou (I-a).

**5. Injeção pelo conteúdo.** Texto de terceiro fora de `untrusted_text`: `mistake.razao` (N4).
`login` sai cru (`team_roster.ex:65`), e o login do GitHub é restrito a `[A-Za-z0-9-]`, com até
39 caracteres. Não conferi se pessoa declarada à mão pode ter login livre (lacuna). Nenhum
campo da plataforma interpola dado.

**6. Limite e DoS.** O `/mcp` passa por `[:api, :api_autenticada]` (`router.ex`), e o limite é
um só por token (`limite_test.exs`, com guarda de outro token). Trabalho antes da autenticação:
só o `Plug.Parsers` (R9). Sem teto: N3 (memória), N6 (itens), e o `GenServer.call` do handler,
com 10 s (I-d).

**7. Os testes provam o que dizem?** Na maior parte, sim, e com guardas positivas escritas: as
duas linhas exatas do registro, o `assert {:ok, :admin}` antes da recusa do R6, o outro token no
limite, o controle positivo das varreduras por AST. Os pontos cegos:

- `segredo_nao_vaza_test.exs` varre bem **um dado pobre demais** (N1): sem vínculo declarado,
  encerrado ou invalidado, a varredura não tem como achar o e-mail. É a forma mais perigosa de
  teste vazio, porque a guarda (`"state":"checked"`) passa;
- `metodos_test.exs` monta `body_params` à mão, sempre como mapa (N5);
- `registro_test.exs:98` usa `notifications/cancelled` como exemplo inofensivo de `202` (N3);
- nenhum teste cobre a ordem registro-serialização (N2);
- `ferramentas_de_equipe_test.exs:181` restringe o laço do texto hostil a duas das quatro
  ferramentas.

Não encontrei mock de domínio: os testes passam pelos contextos reais e pelo banco.

**8. A exceção do `cowlib`.** **Continua válida.** O código novo não usa `Plug.Cowboy`, `:cow_*`
nem transporte `:http` (guarda 3 passa, por AST). O endpoint segue no Bandit (guarda 1). A
`ex_mcp` segue `== 1.5.0` (guarda 4). Em `deps/ex_mcp/lib`, `Plug.Cowboy` só aparece no
transporte próprio e na documentação (`http_plug.ex:30`, `server/transport.ex:177-204`), que a
porta não usa, e **não há nenhuma** chamada `:cow_*`. **Ressalva**: o trace dinâmico de
`r3-cowlib-alcance.md:138-147` exercitou o fluxo **legado** (`initialize` … `ping`). O fluxo
moderno que a 062 serve de fato (`server/discover`, os cabeçalhos `Mcp-*`) só tem a evidência
estática do grep. Refazer o trace com o fluxo moderno fecharia isso.

---

## Informativos

- **I-a** — `unexpected argument: <chaves>` (`ferramentas.ex:177`) devolve ao modelo, como erro
  do servidor, texto que o próprio cliente mandou (**medido**: `"IGNORE ALL <b>x</b>"` voltou
  intacto). Não é canal de terceiro, porque quem manda é o próprio modelo ou cliente. Uma
  mensagem constante (*"only team_id is accepted"*) fecharia o eco sem perder informação.
- **I-b** — a recusa registra sempre `:fora_do_alcance` no MCP e na API
  (`ferramentas.ex:200`, `team_controller.ex:320`), mesmo quando o veredito deu outro motivo ou
  a equipe não existe. É a resposta certa para o cliente. No **log**, que é do servidor,
  distinguir *inexistente*, *outro tenant* e *fora do alcance* ajudaria a investigar uma
  varredura de UUIDs. Decisão de produto, não defeito.
- **I-c** — o estado do handler leva `%User{}` inteiro, com `email` legível no `inspect`. No
  relatório de queda medido (N2), a biblioteca imprimiu a última mensagem e a exceção, e **não**
  o estado. Não varri todos os caminhos de queda. Levar `user_id` e `role` em vez da struct
  tiraria a dúvida.
- **I-d** — o handler roda sob `GenServer.call` com 10 s. Não verifiquei o que acontece com uma
  ferramenta que passe disso: se o processo do handler continua e **grava a leitura depois** de
  o cliente receber o erro de tempo, o N2 tem uma segunda porta.
- **I-e** — `AccessEvents.equipe_recusada/4` na tela (`show.ex:4412-4414`, chamada na 4413) roda em
  `carregar_espera_por_revisao/1`, e a LiveView monta duas vezes. Uma pessoa sem alcance que
  abre o painel deve gerar ao menos dois `warning` por visita. Não é defeito de segurança, mas
  enche o filtro de recusas, que é o que se lê primeiro num incidente. O `id` cru da URL no log
  da API (`team_controller.ex:320`) passa por `inspect/1` (`access_events.ex`, `registrar/2`),
  e por isso não forja linha de log.

---

## O que NÃO avaliei

- **produção**: nada foi medido lá. O alcance do N2 em produção (quantas equipes têm
  `{:coleta, _}`) é inferência do código;
- **a suíte inteira e `mix gates`**: não rodei, por instrução (servidor dev de pé). Só os 12
  arquivos da 062 e o guarda do `cowlib`;
- **a exceção dentro de `responder/2`**: a afirmação de que não grava é por leitura de código, e
  não medida com injeção;
- **o tempo esgotado do handler** (I-d);
- **a extensão de *tasks* e o MRTR da `ex_mcp`** em `tools/call`: li o suficiente para ver que os
  métodos `tasks/*` são recusados pelo plug e que o handler não declara a capacidade. Não li o
  caminho inteiro de `tools/call` com `params.task`;
- **clientes MCP reais** (T030): não conectei nenhum. Não sei o que cada cliente faz com
  `untrusted_text`, nem se algum renderiza Markdown do `text`;
- **login livre de pessoa declarada à mão** (pergunta 5);
- **o trace dinâmico do `cowlib` no fluxo moderno** (pergunta 8);
- **`lib/the_band_web/live/teams_live/show.ex` além do trecho da recusa registrada**: o arquivo tem mais de
  4 400 linhas e não foi relido;
- **o `@sobelow_skip` do repositório**: o diff não acrescenta nenhum (grep), e não reauditei
  os existentes;
- **I2** da revisão do desenho: a revogação do token de produção exposto continua sem evidência
  **nesta** revisão.

---

## O que isto pede ao Product Owner

| Achado | Pedido | Se não entrar agora |
|---|---|---|
| **N1** (alta) | **recomendação de bloqueio** da release que publicar o `/mcp`, e correção **também** na 061, que está exposta em produção hoje | o e-mail de login de quem administra sai para o provedor do modelo em toda equipe com equívoco registrado, e não se recolhe |
| **N2** (média) | corrigir junto com o N1: é o mesmo campo e o mesmo arquivo | `team_roster` não responde para equipes com histórico, o log guarda e-mails, e o registro de auditoria afirma leituras que não houve |
| **N3** (média) | tirar `notifications/cancelled` da lista antes de publicar | um token esgota a memória do nó único, e todos os tenants caem |
| **N4, N5, N6** (baixa) | backlog; N4 cabe no mesmo commit do N1 | — |
| **N7** (baixa, alheio) | `mix deps.update lazy_html`, em PR próprio ou neste | `mix gates` segue vermelho, e nenhum PR pode declarar verde |

Cada achado precisa virar teste **antes** da correção, pelo QA, com o cenário escrito acima.
