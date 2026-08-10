# Contrato — conector GitHub

**Feature**: 001 · **Fase**: 1 · **Base**: R5 e R6 da [research.md](../research.md), AGENTS.md §10

O conector é **declarativo**. O runtime Elixir carrega a definição, valida contra
schema, carrega a query, executa via Req, controla cursor, trata rate limit,
guarda payload bruto, preserva proveniência, agenda páginas com Oban, transforma
pelos mapeamentos e chama a API pública de EO.

**O conector nunca escreve em schema Ecto de EO.** Ele grava `raw_payloads` e
chama `TheBand.Ontology.SEON.EO.upsert_*_from_source/2`.

## Definições declarativas

`priv/connectors/github/definitions/`. Uma por entidade coletada.

```yaml
connector:
  id: github.organization_members
  version: 1
  provider: github
  transport: graphql
query:
  file: queries/organization_members.graphql
variables:
  organization: { required: true }
  page_size:    { default: 50 }
pagination:
  type: cursor
  cursor_variable: after
  end_cursor_path: data.organization.membersWithRole.pageInfo.endCursor
  has_next_page_path: data.organization.membersWithRole.pageInfo.hasNextPage
checkpoint: { strategy: cursor }
retry: { max_attempts: 5, backoff: exponential }
rate_limit:
  cost_path: data.rateLimit.cost
  remaining_path: data.rateLimit.remaining
  reset_at_path: data.rateLimit.resetAt
  pause_when: "remaining < cost * 2"
output:
  raw_entity_type: github.user
  mappings: [github.user.to.eo.person]
```

As quatro definições desta feature:

| `id` | Coleta | `raw_entity_type` | Mapeamento aplicado |
|---|---|---|---|
| `github.organization` | a organização observada | `github.organization` | `github.organization.to.eo.organization` |
| `github.organization_members` | membros da organização | `github.user` | `github.user.to.eo.person` |
| `github.teams` | times da organização | `github.team` | `github.team.to.eo.organizational_team` |
| `github.team_members` | integrantes de cada time | `github.team_member` | `github.team_member.to.eo.person` + regra `github.team_membership_evidence` |

**Os dois conjuntos de pessoas não coincidem.** Membros da organização e
integrantes de times são conjuntos distintos, e coletar só um daria visão parcial
sem que a pessoa usuária soubesse (Assumptions da spec). Ambos são coletados, e
cada pessoa registra de qual observação veio.

## Queries GraphQL

`priv/connectors/github/queries/*.graphql`. GraphQL por padrão; REST só com
justificativa escrita (AGENTS.md §10).

Toda query **MUST** pedir o bloco de rate limit:

```graphql
rateLimit { cost remaining resetAt }
```

Não é opcional. O limite do GraphQL do GitHub é por **complexidade da consulta**,
não por número de requisições — uma consulta pesada custa centenas de pontos.
Reagir ao 403 perde a janela inteira e espera o reset; a informação para evitar
isso vem na própria resposta.

## Comportamento em execução

### Paginação e checkpoint

O checkpoint é gravado **depois** de a página ser processada com sucesso, nunca
antes. Uma interrupção reprocessa no máximo a última página — seguro porque a
ingestão é idempotente, e é o que SC-006 mede. O cursor é **opaco**: armazenado
como veio, nunca interpretado, decodificado ou construído.

### Rate limit

`remaining < cost × 2` → aguardar até `resetAt` antes da próxima página. A margem
de duas vezes cobre a variação de custo entre páginas.

A espera é agendamento Oban (`schedule_in` até `resetAt`), **nunca**
`Process.sleep`. Segurar o processo bloquearia a fila e faria a pausa parecer
travamento.

**Rate limit não é erro.** É informação de capacidade, e não incrementa tentativa
nem leva a `failed`. Backoff exponencial continua valendo, em separado, para erro
de rede e 5xx.

### Concorrência

Uma sincronização por ferramenta conectada (FR-018). Duas defesas: índice único
parcial em `syncs` sobre `connected_tool_id` onde `status = 'running'`, e
`unique: [period: ...]` no worker Oban. A corrida existe nos dois níveis — a
segunda requisição HTTP e o segundo job enfileirado.

### Credencial

Todo job carrega `tenant_id` nos args e o **valida** antes de executar. A
credencial é resolvida no momento do uso, nunca passada nos args do job — args de
Oban ficam no banco em claro.

Credencial revogada no meio da coleta: interrupção controlada, progresso parcial
preservado, `syncs.status = interrupted`, ferramenta marcada como precisando de
atenção com data e motivo.

### Instância própria de GitHub

Recurso ausente na instalação própria não é falha: a sincronização registra o que
está disponível e reporta explicitamente o que não pôde ser coletado, no relatório
final (FR-028, `skip_reasons`).

## Taxonomia de erro

Nem toda falha é do mesmo tipo, e tratá-las igual produz os dois erros opostos:
desistir de algo que ia funcionar, e insistir em algo que nunca vai.

| Retorno | Natureza | O que a plataforma faz |
|---|---|---|
| `{:transport, motivo}` | **transitória** | a sincronização **permanece em andamento** e o Oban retenta. Só o esgotamento das tentativas a marca como falha |
| `{:unexpected_status, 5xx}` | **transitória** | idem — erro do servidor da origem não é erro da coleta |
| `:unauthorized` | terminal | interrompe, preserva o progresso, marca a ferramenta como precisando de atenção |
| `{:missing_scopes, escopos}` | terminal | recusa no cadastro; nada é gravado |
| `{:organization_not_found, login}` | terminal | falha nomeando a organização que não foi encontrada |
| `{:graphql_errors, erros}` | terminal | a consulta está errada ou o token não alcança o campo; retentar repetiria o mesmo |
| `{:unexpected_status, 4xx}` | terminal | o pedido está errado; o servidor não vai mudar de ideia |

**Falha transitória não marca a sincronização como `failed`.** Marcar levaria a
pessoa a investigar uma coleta que o Oban ainda vai retentar sozinho — e, pior,
liberaria o índice que impede duas coletas simultâneas da mesma ferramenta,
porque ele só bloqueia enquanto o estado é `running`.

## Contrato de mensagem

Toda falha que chega à interface ou ao registro da sincronização MUST ser texto
legível, em português, dizendo **o que aconteceu** e **o que fazer**. O `inspect/1`
de um struct não é mensagem: `%Req.TransportError{reason: :nxdomain}` não informa
quem lê que o endereço não pôde ser resolvido.

| Causa | Mensagem |
|---|---|
| `:nxdomain` | não foi possível resolver o endereço da instância; conferir a conexão de rede e o endereço cadastrado |
| `:timeout`, `:closed`, `:econnrefused` | a instância não respondeu a tempo, ou recusou a conexão; a coleta será retentada |
| `:unauthorized` | a credencial foi recusada pela ferramenta; pode ter sido revogada ou expirado |
| escopo insuficiente | nomear **quais** escopos faltam |
| organização não encontrada | nomear a organização, e lembrar que se usa o login, não a URL |

O motivo técnico permanece disponível no log estruturado. Ele sai da mensagem,
não do registro — quem opera precisa da frase, quem depura precisa do struct.

## Contrato de teste

| Camada | Onde | Regra |
|---|---|---|
| Contrato | `test/contract/github/` | Mox **somente na borda HTTP** — o cliente Req. Nunca mock de módulo de domínio próprio |
| Integração | `test/integration/` | tag `:integration`; Postgres e Oban reais; cobre paginação, retomada, rate limit, idempotência e isolamento entre tenants |

Fixtures de payload em `test/fixtures/github/`, capturados de resposta real e
**redigidos** — nenhum token, nenhum e-mail de pessoa real.
