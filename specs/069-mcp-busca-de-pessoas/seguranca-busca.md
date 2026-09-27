# Avaliação de segurança da 069, parte 1: `people_search`

Papel: Security (`AGENTS.md` §13, §14.0). Avaliação **antes do plano**, feita por quem não
escreveu o desenho. Escopo: só a ferramenta `people_search`. `person_open_work` é a parte 2, em
outro documento.

Data: 2026-09-25. Branch: `069-mcp-busca-de-pessoas`, commit `2c3da9b`.

## 1. Enumeração pela busca

**Veredito: o argumento da spec se confirma. A busca não amplia a exposição. Severidade:
informativa.** Resta um endurecimento de registro, de severidade baixa.

**Evidência.**

- O token do MCP passa pela mesma pipeline da API: `/mcp` usa `pipe_through [:api,
  :api_autenticada]` (`lib/the_band_web/router.ex:123-124`), a mesma de `/api/v1`
  (`router.ex:72`). O limite de 120 por minuto é compartilhado entre as duas portas
  (comentário em `router.ex:119`).
- Com esse mesmo token, `GET /api/v1/people` (`router.ex:99`) lista **todas** as pessoas do
  tenant, com `id`, `name`, `login`, `external_id` e organizações, sem nenhum filtro de alcance.
  `EO.list_people(tenant, limit:, after:)` em
  `lib/the_band_web/controllers/api/v1/person_controller.ex:183` não recebe o alcance. O
  alcance (`pessoas_alcancadas/2`, linha 198) só decide as competências (linhas 319-320). A tela
  faz o mesmo (FR-016 da spec).
- Então percorrer `aaa`…`zzz` pelo `people_search` dá, em cerca de 2,5 h, um **subconjunto** do
  que a mesma credencial obtém em `ceil(N/100)` chamadas paginadas de `/api/v1/people`. O que o
  ataque "descobre" é *quais pessoas estão no meu alcance*. A própria conta já sabe isso pela
  tela, e pela API: o campo `competencies` vem preenchido só para quem se alcança.

**O que a enumeração deixaria vazar, se o alcance falhasse.** O argumento vale **só enquanto a
FR-011 e a FR-012 valem**. Com o filtro errado, a busca vira oráculo de pertencimento ao
alcance de outra pessoa, e isso não cai aqui: é o ponto 2 (alta).

**Registro de rajada.** Hoje a leitura por MCP grava uma linha por chamada em
`api_access_reads` (`lib/the_band/mcp/ferramentas.ex`, `ApiAccessLog.registrar/1`, no ramo de
concessão de `com_equipe/5`). Com a FR-020, `people_search` grava rota e `public_id`, sem alvo.
Isso já basta para contar chamadas por token por janela depois do fato. **Não recomendo
controle em linha** (limite próprio ou bloqueio): ele não protege nada que a API não entregue
mais barato, e castiga o uso legítimo. Recomendo (baixa) que o plano declare a consulta de
investigação: *chamadas de `mcp:people_search` por `token_public_id` por minuto*. Assim a
detecção de rajada é pergunta respondível, e não promessa. Não precisa de evento novo.

## 2. FR-011: alcance antes do teto de 10

**Veredito: implementável sem uma consulta por pessoa, porque a forma em lote existe. Mas a
FR-011 nomeia o veredito errado, e o risco de filtrar depois do corte é real. Severidade: alta
enquanto a spec não fixar a ordem e a função.**

**A forma em lote existe.** `Tenants.Access.pessoas_alcancadas/2`
(`lib/the_band/tenants/access.ex:317`) devolve `:todas` ou `{:algumas, MapSet}` em no máximo
três consultas, e o `@doc` dela (linhas 277-315) diz que existe exatamente para não perguntar
`pode_ver/3` por linha (L38). Já é usada assim em `person_controller.ex:198`,
`verification_live/people.ex:90`, `change_live/commits.ex:76` e `process_live/index.ex:40`.

**Mas ela não é `pode_ver/3`, e a FR-011 diz `pode_ver/3`.** Divergências medidas no código:

| Caminho | `pode_ver/3` | `pessoas_alcancadas/2` | Direção |
|---|---|---|---|
| liderança declarada (`EO.Visibility.pode_ver`) | concede (`access.ex:273-276`) | não inclui | mais estreito |
| organização pela evidência observada (`observed_orgs/3`) | concede (`access.ex:458-462`, `502-507`) | só equipes da organização (`access.ex:325-331`) | mais estreito |
| administração | exige `user.tenant_id == tenant.id` (`access.ex:260`) | só `User.admin?(user)` (`access.ex:318`) | **mais largo** |

As duas primeiras erram para o lado fechado, e `person_controller.ex:195-197` já as declara.
Para a busca elas quebram a paridade que a SC-003 promete: um líder declarado recebe
`person_open_work` concedido para uma pessoa que `people_search` não encontra. Isso não vaza
nada, mas é um veredito diferente em duas portas, e é o defeito que a US3 existe para impedir.

A terceira erra para o lado aberto. No MCP, hoje, ela não é explorável: o tenant vem do token
(`lib/the_band_web/mcp/servidor.ex`, `estado/2`, `assigns.current_tenant`), e o token pertence à
conta do tenant. A garantia, porém, mora no chamador, e não no veredito, que é o desenho A04 que
esta casa recusa (média, fora do escopo estrito desta feature, e registrada aqui para não se
perder).

**O risco da implementação ingênua.** A consulta natural é
`list_people(tenant, search: q, limit: 10)` seguida de
`Enum.filter(&alcanca?(alcance, &1.id))`. Ela passa em todo teste com um tenant pequeno e viola
as duas coisas que a FR-011 protege:

1. **vaga ocupada**: dez casamentos fora do alcance ordenados antes, por login, zeram o
   resultado de quem está no alcance. A resposta fica errada e em silêncio (princípio VIII);
2. **oráculo de existência**: `truncated` calculado sobre as 11 linhas **antes** do filtro diz
   `true` quando só há pessoas fora do alcance. É a FR-012 quebrada pelo campo que a FR-005
   exige. Ver o ponto 3.

A variante com `Enum.filter` sobre a lista **inteira** do tenant, seguida de `take(10)`, fecha
os dois furos, mas faz o custo crescer com o tenant e reprova a SC-006.

**O que a spec deve exigir:**

- o alcance entra **no `where` da consulta**, como `p.id in ^ids` (ou nenhuma cláusula quando
  `:todas`), e o `limit 11` vem **depois** dele, no banco. Filtro em Elixir sobre o resultado
  cortado é proibido, e o plano diz isso com essas palavras;
- a função de alcance é **nomeada** na spec. Recomendo `pessoas_alcancadas/2`, pelo lado
  fechado, com a divergência da liderança declarada **declarada** como limitação da FR-011 e
  da SC-003. A alternativa é estender `pessoas_alcancadas/2` com a liderança e a evidência
  observada. Isso é mudança de contrato do `Access` e de quatro chamadores, e é decisão do
  Product Owner, não minha;
- `truncated` é calculado sobre o conjunto **já filtrado**.

## 3. FR-012 / SC-004: resposta idêntica byte a byte

**Veredito: alcançável, desde que três campos sejam fixados na spec. Severidade: alta se
`truncated` ou `collected_at` saírem do conjunto não filtrado. Por tempo, baixa.**

| Canal | Evidência | Avaliação |
|---|---|---|
| **`truncated`** | FR-005 exige que a resposta diga se foi cortada | vaza se for calculado antes do filtro de alcance (ponto 2). Com o filtro no `where` e o `limit 11` depois, "só fora do alcance" e "sem casamento" dão os dois `false` |
| **`collected_at` do envelope** | `Envelope.montar/1` exige `:collected_at` (`lib/the_band/mcp/envelope.ex:50-55`, `73`); no `team_roster` ele vem de `equipe.last_observed_at` | se a busca o derivar de algo que não seja o conjunto filtrado (o `max(collected_at)` dos casamentos brutos, por exemplo), a data difere entre os dois casos. A spec deve fixar: `collected_at` sai das pessoas **devolvidas**, e `nil` quando não há nenhuma |
| **cabeçalhos de limite** | `x-ratelimit-limit` e `x-ratelimit-remaining` em `lib/the_band_web/plugs/api_rate_limit.ex:118-119` | dependem da contagem de chamadas do token, e não do conteúdo. Não são canal. O SC-004 deve comparar o **corpo** e dizer isso, porque `remaining` difere entre duas chamadas seguidas por construção |
| **tempo** | com o alcance no `where`, a diferença é o plano de consulta do Postgres sobre linhas que casam o `ilike` e são descartadas pelo `in` | mensurável em princípio, e ruidoso na rede. E o que ele revelaria, "há alguém com este trecho fora do meu alcance", a mesma credencial já obtém por `/api/v1/people` (ponto 1). Baixa, e sem controle recomendado |
| **registro** | FR-020: sem alvo em `people_search` | o registro é igual nos dois casos. Bom: evento de recusa aqui confirmaria a existência a quem lê o registro. A spec deve dizer que `people_search` **nunca** emite `painel_recusado` |
| **`request_id`** | posto no `Logger.metadata`, e não no corpo (`servidor.ex`, `init/1`) | não entra no corpo, então não quebra a comparação |

**O que o teste da SC-004 precisa fixar para medir alguma coisa:** dois tenants povoados; no
tenant do token, uma pessoa fora do alcance cujo login casa `q1`, e nenhuma que case `q2`. Os
corpos (`structuredContent` e o `text`) de `q1` e `q2` são comparados com `==` **depois** de
trocar a `query` ecoada, se a resposta ecoá-la. A spec deve dizer se ecoa. Recomendo que
**não** ecoe, e aí a comparação é crua. Guarda de que mediu: a mesma `q1`, com a pessoa posta no
alcance, devolve 1 resultado.

## 4. A `query` como entrada

**Veredito: não há injeção de SQL. Há curinga, porque nenhuma busca da base escapa `%`, `_` ou
`\`. Não há normalização de acento em lugar nenhum. Severidade: média. Não vaza além do
alcance, mas derruba a condição 2 da FR-017, e com ela a emenda da FR-023.**

**Injeção de SQL: não há.** As três buscas passam o padrão como parâmetro (`^like`):
`lib/the_band/ontology/seon/eo/queries.ex:609-612` (`busca_por_pessoa/2`), `queries.ex:1094-1097`
(`filter_search/2`) e `lib/the_band/ontology/seon/eo/roster.ex:265-267` (`busca/2`). Nenhuma usa
`fragment` com interpolação.

**Curinga: todas as três montam `"%#{termo}%"` sem escapar nada.** Consequências, se a busca
reusar qualquer uma delas:

| Entrada | O que acontece | Fere |
|---|---|---|
| `%%%` ou `___` | casa **toda** pessoa com nome ou login de 3 caracteres ou mais: a busca vira listagem do alcance, 10 por vez | FR-003, FR-017.2, e o edge case "a%b procura o trecho a%b" |
| `a_b` | casa `aXb` | FR-003 (semelhança, e não trecho literal) |
| termina em `\` | o Postgres usa `\` como escape padrão do `LIKE`, e o padrão que termina nele levanta `invalid escape sequence` / *LIKE pattern must not end with escape character*. Vira exceção, e não erro de parâmetro | princípio VIII (exceção como fluxo), e um 500 onde a spec promete erro de parâmetro |

Nada disso alcança fora do alcance, desde que o ponto 2 esteja certo. O dano é que a emenda da
FR-023 vale "**só** porque as cinco condições valem juntas", e a condição 2 cai na primeira
reutilização da função existente. A correção é escapar `\`, `%` e `_`, **nessa ordem** (a barra
primeiro), antes de envolver em `%…%`. Pode ser numa função nova e privada da busca. As três
existentes têm o mesmo defeito nas telas, onde o impacto é só de correção: registro como
achado baixo à parte, sem mexer nelas nesta feature.

**Acento: `grep -rn unaccent lib priv/repo/migrations` não encontra nada.** O edge case
"Zambôrlini acha Zamborlini e vice-versa" não tem suporte hoje. As opções, a decidir no plano:

1. extensão `unaccent` do Postgres. Precisa de migração com `CREATE EXTENSION` (privilégio no
   banco de produção, a conferir) e de um invólucro `IMMUTABLE` para caber em índice. Sem
   índice, o custo cresce com o tenant e fere a SC-006;
2. coluna normalizada (NFD, sem marcas combinantes, minúscula) gravada na escrita da pessoa, e
   a `query` normalizada igual em Elixir. Custo de migração e de backfill.

Nenhuma das duas é problema de segurança em si. O ponto de segurança é **normalizar a `query`
e a coluna pela mesma regra**. Regra divergente faz a busca casar por semelhança, que a FR-003
proíbe.

**Tamanho e forma.** A FR-004 diz "3 a 100 caracteres depois de aparar", e a spec precisa dizer
em quê:

- **contar grafemas** (`String.length/1`), e não bytes. `"çãé"` tem 3 grafemas e 6 bytes;
- `String.trim/1` apara espaço Unicode, mas **não** apara caractere invisível
  (U+200B, U+2060, U+FEFF). `"​ab​"` teria 4 grafemas e passaria no mínimo com 2
  letras reais. Recomendo recusar como erro de parâmetro toda `query` com caractere de controle
  (categoria Cc) ou de formatação (Cf);
- **NUL (`\u0000`) é JSON válido e o Postgres o recusa em `text`**, com exceção. Cai na regra
  de Cc acima, e o teste precisa cobri-lo explicitamente;
- `query` que não seja string (número, lista, `null`) é erro de parâmetro, e não
  `FunctionClauseError`. Hoje o `team_id/1` de `lib/the_band/mcp/ferramentas.ex` faz isso por
  casamento de cabeça, e a busca precisa do equivalente.

## 5. FR-020: não registrar a `query`

**Veredito: não registrar a `query` está certo. Não registrar nada do que saiu tira uma
evidência que a investigação precisa. Severidade: média (A09, e princípio III, "quem viu o
quê").**

**O que o registro tem.** `api_access_reads` guarda `tenant_id`, `token_public_id`, `route`,
**um** `target_id` (uuid, anulável) e `occurred_at`
(`priv/repo/migrations/20260922100000_registro_de_leitura_da_api.exs:42-58`), com índice
`[:tenant_id, :token_public_id, :occurred_at]` (linha 64). Com a FR-020, cada `people_search`
vira uma linha `route: "mcp:people_search"` e `target_id: nil`.

**O que isso responde numa investigação de token vazado:**

| Pergunta | Respondível? |
|---|---|
| o token usou a busca, quando e quantas vezes? | sim, pelo índice |
| houve rajada (varredura `aaa`…`zzz`)? | sim, por contagem por janela (ponto 1) |
| **de quais pessoas o token obteve o `person_id` e o nome pela busca?** | **não** |
| de quais pessoas o token leu o trabalho? | sim, por `mcp:person_open_work` com alvo (FR-020) |

A terceira linha é a lacuna. A exposição mais grave, o trabalho, está coberta pela
`person_open_work`, e isso reduz o achado a média, e não a alto. Mas a FR-032 da 062, que esta
spec invoca na FR-016, diz que o que o modelo lê pode ser guardado do outro lado. Então a lista
de identidades entregues é exatamente o que um incidente precisa enumerar para avisar as
pessoas. E ela não pode ser reconstruída depois: o alcance é derivado a cada chamada
(`access.ex`), e o alcance de hoje não é o de ontem.

**Por que não registrar a `query` continua certo.** Ela é texto livre de quem pergunta (pode
trazer nome digitado com dado a mais, ou até um segredo colado por engano), e não diz o que
saiu: `"sil"` depende do alcance do momento. Registrar a `query` é o risco de A09 (dado
sensível em log) sem o benefício.

**O que recomendo que a spec diga:** registrar os **`person_id` devolvidos**, que são
identificadores da plataforma, finitos (no máximo 10) e não texto livre. Com `target_id`
único, são até 10 linhas por chamada, uma por pessoa, ou uma coluna nova. A escolha é do
plano, com o custo declarado. Busca sem resultado grava uma linha sem alvo, que é o que a
FR-020 já prevê. Isso não quebra a FR-012: o registro não é resposta, e quem o lê é
administração, que já alcança todos (`access.ex:260`).

## 6. FR-016: nenhum outro caminho devolve identidade fora do alcance; equipes da pessoa

(em avaliação)

## Tarefas bloqueantes e cenários de ataque para o QA

(em avaliação)

## O que tem de mudar na spec

(em avaliação)

## O que não foi verificado

(em avaliação)

## Resumo
