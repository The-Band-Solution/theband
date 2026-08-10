# AGENTS.md — The Band

Instruções operacionais para agentes de codificação (Claude Code, Codex, Cursor, etc.) neste repositório.

Este arquivo é normativo. Quando ele conflitar com o hábito do agente, ele vence. Quando ele conflitar com uma ADR aprovada em `docs/adr/`, a ADR vence.

---

## 1. O que é The Band

The Band é uma plataforma de **integração semântica de dados de Engenharia de Software**, derivada da tese de doutorado de Paulo Sérgio dos Santos Júnior (UFES, 2023), *"From Continuous Software Engineering Reference Ontologies to the Integration of Data for Data-Driven Software Development"*, onde The Band é o componente de integração de dados do ambiente Immigrant, baseado na (sub)rede ontológica **Continuum** integrada à **SEON**.

Objetivo: coletar dados de ferramentas de desenvolvimento (GitHub, GitLab, Azure DevOps, Jira, Sonar, CI/CD, monitoramento, time tracking), **harmonizá-los semanticamente contra ontologias de referência**, preservar proveniência e rastreabilidade, e responder necessidades de informação com dados confiáveis e explicáveis.

Perguntas que o sistema deve responder:

- Quais projetos apresentam maior retrabalho? Quais equipes têm maior cycle time?
- Quais Pull Requests aguardam mais tempo por revisão? Quais receberam múltiplas solicitações de mudança?
- Quais componentes concentram mais defeitos? Quais commits estão ligados a falhas de build?
- **De qual fonte um indicador foi derivado? Como a medida foi calculada? Quais dados e relações sustentam esta resposta?**

The Band **não é**: um dashboard, um data lake sem semântica, um conjunto de scripts de ETL, uma cópia dos modelos de dados das ferramentas, nem um chatbot ligado direto ao banco.

### 1.1 Da tese para o código

A tese descreve uma arquitetura em 4 camadas com serviços federados (OBS/OBDR). Nesta implementação, essas camadas viram **fronteiras internas de um monólito modular**, não serviços separados:

| Camada da tese | Realização neste repositório |
|---|---|
| Application Integration Layer (ASAs, Extract Components) | `lib/the_band/integrations/`, `lib/the_band/ingestion/`, `priv/connectors/` |
| Internal Data Communication Layer (broker, Transform/Load) | Oban + `lib/the_band/semantic_integration/` (**não** Kafka/RabbitMQ) |
| Federated Ontology-Based Service Layer (OBS + OBDR) | `lib/the_band/ontology/<rede>/<ontologia>/` + tabelas prefixadas em PostgreSQL |
| Federated Data Access Layer | `lib/the_band/analytics/`, `reportify/`, `the_band_web/live/` e APIs |

Conceitos da tese que **permanecem obrigatórios** no modelo de dados:

- `internal_id` — identidade estável do dado entre módulos ontológicos.
- `record_version` — versão do registro, para detectar dessincronização.
- **Application Reference** — `source_system` + `source_instance` + `external_id`, ligando cada registro à entidade de origem na ferramenta externa. Sem isso não há rastreabilidade e o dado é inválido.

---

## 2. Diretriz arquitetural

**Monólito modular multitenant em Elixir/Phoenix.** Simples, evolutivo, baixo custo operacional.

```text
Fontes externas
→ conectores Elixir (Req + GraphQL/REST declarativo)
→ dados brutos + proveniência
→ mapeamento semântico (YAML)
→ módulos organizados pelas ontologias
→ PostgreSQL/Ecto
→ necessidades de informação → medidas → indicadores
→ Reportify → LiveView e APIs
```

O núcleo do domínio é organizado **pelas ontologias**, nunca pelas ferramentas externas. Não existe módulo `TheBand.GitHub` no domínio — GitHub é fonte, não conceito.

Sem microserviços prematuros. Sem Python, Go, frontend TS separado, NATS, Kafka, RabbitMQ, Apache AGE, Neo4j, pgvector, Kubernetes ou GraphRAG na fundação — cada um exige feature própria + análise comparativa + ADR.

---

## 3. Stack

```text
Elixir / Erlang OTP        Phoenix + LiveView
Ecto + PostgreSQL          Oban (jobs, retries, agendamento)
Req (HTTP)                 ExUnit + Mox
Credo + Dialyzer           ExDoc
Docker Compose (dev)       Phoenix Releases (deploy)
GitHub Spec Kit            YAML como base de conhecimento versionada
```

Fixe as versões exatas em `mix.exs` e registre-as no `plan.md` da feature. Biblioteca YAML: escolher no `/speckit-plan` avaliando manutenção, segurança e compatibilidade — **não** fixe uma sem essa pesquisa.

Toda dependência nova precisa de justificativa escrita no plano da feature.

---

## 4. Comandos

```bash
# ambiente
docker compose up -d              # PostgreSQL
mix setup                         # deps.get + ecto.setup + assets.setup
mix phx.server                    # http://localhost:4000
iex -S mix phx.server

# banco
mix ecto.create && mix ecto.migrate
mix ecto.reset
mix ecto.gen.migration <nome>

# base de conhecimento
mix knowledge.validate            # YAMLs contra os schemas
mix knowledge.compile             # YAML → estruturas Elixir
mix knowledge.graph               # dependências e ciclos entre ontologias
mix knowledge.test                # perguntas de competência e regras
mix knowledge.diff                # diff semântico entre versões

# testes
mix test
mix test path/to/file_test.exs:42
mix test --only integration
mix test --cover
```

### Quality gates — rodar antes de abrir PR

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate
mix knowledge.graph
mix knowledge.test
```

Todos verdes. Sem exceção. Não desabilite check, não marque `@dialyzer` para silenciar, não apague teste para o pipeline passar.

---

## 5. Estrutura do repositório

```text
the-band/
├── AGENTS.md, CLAUDE.md, README.md, mix.exs, compose.yaml
├── .github/            workflows (ci, security, spec-validation, release), templates, CODEOWNERS
├── .specify/           constitution.md, scripts, templates (Spec Kit)
├── specs/<n>-<feature>/  spec.md, plan.md, tasks.md, research.md, data-model.md, contracts/
├── docs/               architecture/, ontology/, integrations/, metrics/, processes/, adr/
├── config/             config.exs, dev.exs, test.exs, prod.exs, runtime.exs
├── lib/
│   ├── the_band/
│   │   ├── accounts/ tenants/ sources/ integrations/ ingestion/ raw_data/ provenance/
│   │   ├── ontology/
│   │   │   ├── registry.ex concept.ex relation.ex constraint.ex mapping.ex
│   │   │   ├── knowledge_base.ex yaml_loader.ex yaml_validator.ex dependency_graph.ex
│   │   │   ├── ufo/
│   │   │   ├── seon/{eo,spo,sys_swo,rsro,cmpo,roost,qapo,osdef}/
│   │   │   └── continuum/{sro,ciro,cdro}/
│   │   ├── semantic_integration/ information_needs/ measurements/
│   │   ├── analytics/ reportify/ intelligence/ jobs/ audit/ repo.ex
│   │   └── the_band_web/  components/ controllers/ live/ plugs/ router.ex endpoint.ex
├── priv/
│   ├── repo/migrations/
│   ├── knowledge_base/   manifest.yaml, schemas/, ontology/, mappings/,
│   │                     competency_questions/, information_needs/, measurements/,
│   │                     rules/, glossary/, examples/, sources/
│   └── connectors/github/{queries,definitions,mappings}/
└── test/  support/ the_band/ the_band_web/ contract/ integration/ fixtures/
```

**Não crie pastas vazias antecipadamente.** Cada diretório nasce quando uma feature o justifica.

---

## 6. Rede de ontologias

```text
UFO
└── SEON
    ├── EO      organizações, pessoas, equipes, papéis
    ├── SPO     projetos, processos e atividades planejadas vs. executadas
    ├── SysSwO  produto, item de software, sistema, programa, código
    ├── RSRO    requisitos e artefatos de requisitos
    ├── CMPO    repositório, branch, commit, merge, change request, baseline
    ├── ROoST   caso de teste, execução, resultado, ambiente
    ├── QAPO    avaliações, critérios de qualidade, não conformidades
    ├── OSDEF   defect, fault, failure, vulnerability
    └── Continuum
        ├── SRO   Scrum: processo, stakeholders, backlogs, entregáveis
        ├── CIRO  integração contínua: build, test, inspection
        └── CDRO  entrega e implantação contínuas
```

### Regra de dependência — do específico para o geral

Permitido:

```text
SRO  → EO, SPO, SysSwO, RSRO
CIRO → SPO, SysSwO, CMPO, ROoST, QAPO, OSDEF
CDRO → SPO, SysSwO, CIRO
```

Proibido (verificado por `mix knowledge.graph` e por teste em `test/the_band/ontology/`):

```text
EO → SRO      SPO → CIRO      SysSwO → CDRO
```

Se um conceito já existe em ontologia mais geral, **reutilize**. `Person` mora em EO; SRO/CIRO/CDRO apenas referenciam pessoas em papéis contextuais.

### Distinções semânticas que o código deve preservar

Estas não são sutilezas acadêmicas — são a razão de o projeto existir. Violá-las corrompe todas as métricas acima.

| Não confunda | Porque |
|---|---|
| Pull Request ≠ Merge | PR é solicitação de mudança (CMPO `change_request`); merge é evento distinto |
| Pessoa ≠ Membro de equipe | `Team Member` é papel; `Team Membership` é a relação contextual e temporal |
| Processo planejado ≠ executado | SPO separa `intended_*` de `performed_*` |
| Código ≠ Programa | SysSwO trata como conceitos distintos |
| Documento de requisito ≠ Requisito | RSRO: o documento descreve, não é |
| Caso de teste ≠ Execução de teste | ROoST separa planejamento de execução |
| Code smell ≠ Defeito | QAPO registra não conformidade; virar defeito é decisão, não automatismo |
| Defect ≠ Fault ≠ Failure | OSDEF: failure é evento observado; defect nem sempre falha |

**Nunca mapeie conceitos por semelhança de nome.** Mapeamento exige justificativa semântica escrita no YAML, com grau de equivalência e limitações declaradas.

---

## 7. Convenções Elixir

### 7.1 Fronteiras de módulo

Cada ontologia expõe API pública pelo módulo raiz. Ninguém de fora toca schema, changeset ou `Repo` do módulo.

```elixir
defmodule TheBand.Ontology.Continuum.SRO do
  @moduledoc """
  API pública da Scrum Reference Ontology.

  Depende de: EO, SPO, SysSwO, RSRO.
  """
  alias TheBand.Ontology.Continuum.SRO.{Commands, Queries}

  defdelegate register_user_story(attrs), to: Commands
  defdelegate register_sprint(attrs), to: Commands
  defdelegate list_sprint_user_stories(sprint_id), to: Queries
end
```

```elixir
# ERRADO — fura a fronteira, acopla ao schema interno
Repo.insert(%TheBand.Ontology.Continuum.SRO.UserStory{title: t})

# CERTO
TheBand.Ontology.Continuum.SRO.register_user_story(%{title: t})
```

Layout interno de um módulo ontológico:

```text
lib/the_band/ontology/continuum/sro/
├── sro.ex          API pública (defdelegate apenas)
├── schemas/        Ecto schemas — privados ao módulo
├── commands/       escritas; retornam {:ok, struct} | {:error, changeset}
├── queries/        leituras; funções puras de composição de query
├── services/       regras que orquestram mais de um agregado
├── relations/      relações explícitas da ontologia
├── constraints/    invariantes conceituais
└── events/         eventos de domínio internos
```

### 7.2 Estilo

- Retorne `{:ok, value}` / `{:error, reason}` na API pública. Reserve `!` para uso interno onde a falha é bug, não caso de negócio.
- Encadeie com `with`; não use `case` aninhado além de dois níveis.
- Pattern matching na cabeça da função em vez de `if`/`cond` no corpo.
- `@moduledoc` obrigatório em todo módulo público, declarando **de quais ontologias ele depende**. `@doc` + `@spec` em toda função pública (Dialyzer roda em modo estrito).
- Nomeie pelo conceito da ontologia, em inglês, como na ontologia de origem: `PerformedActivity`, não `ActivityDone`.
- Sem `Enum` sobre resultado de query quando dá para filtrar no banco. Sem N+1 — use `preload` ou join explícito.
- Structs de domínio não vazam para o `the_band_web` sem passar por uma view/component function.

### 7.3 Ecto

- Migração e schema no mesmo PR da feature que os introduz.
- Constraint de verdade no banco (`unique_index`, `check_constraint`, FK) **e** validação no changeset. Changeset sozinho não é integridade.
- Toda tabela de domínio: `tenant_id`, `internal_id`, `record_version`, `inserted_at`, `updated_at`.
- Toda tabela alimentada por fonte externa: `source_system`, `source_instance`, `external_id`, `collected_at` — e `unique_index` sobre `[:tenant_id, :source_system, :source_instance, :external_id]` para garantir idempotência de ingestão.
- Migração sempre reversível ou com `down` explícito. Nada de `execute/1` sem par.

### 7.4 Multitenancy

Estratégia inicial: **uma base PostgreSQL, tabelas compartilhadas, `tenant_id`, políticas de acesso**. Não crie banco ou schema por tenant.

- Toda query de domínio recebe o tenant. Nada de "pega o tenant do Process dictionary e reza".
- Todo job Oban carrega `tenant_id` nos args e **valida** antes de executar.
- Testes precisam cobrir vazamento entre tenants: crie dois tenants e prove que um não lê o outro.
- YAMLs da base de conhecimento são globais. Extensão por tenant só via feature futura especificada.

### 7.5 Oban

Use Oban para sincronização de fontes, paginação, coleta periódica, importação histórica, retries, reprocessamento, transformação semântica, validação/compilação da base de conhecimento, cálculo de medidas e geração de relatórios.

```elixir
defmodule TheBand.Jobs.ImportGitHubPullRequests do
  use Oban.Worker, queue: :ingestion, max_attempts: 5, unique: [period: 300]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "source_id" => source_id} = args}) do
    with {:ok, tenant} <- TheBand.Tenants.fetch(tenant_id),
         {:ok, source} <- TheBand.Sources.fetch(tenant, source_id),
         {:ok, page} <- TheBand.Integrations.GitHub.fetch_page(source, args["cursor"]),
         {:ok, _raw} <- TheBand.RawData.store(tenant, page),
         :ok <- schedule_next_page(tenant, source, page) do
      :ok
    end
  end
end
```

Regras: job idempotente (rodar duas vezes = mesmo estado final); cursor/checkpoint persistido, nunca só em memória; rate limit tratado com backoff, não com `Process.sleep`; erro de negócio retorna `{:error, reason}` legível, não `raise` genérico. **Não introduza broker externo enquanto Oban atender.**

### 7.6 Testes

- `test/the_band/ontology/<rede>/<ontologia>/` cobrindo conceitos, relações, cardinalidades, constraints, temporalidade, papéis, participações, dependências, mapeamentos e proveniência.
- `test/contract/` para contratos externos, com Mox. Mock só na borda HTTP — nunca mock de módulo de domínio próprio.
- `test/integration/` (tag `:integration`) para PostgreSQL, Ecto, Oban, Req, conectores, paginação, retries, multitenancy, migrações e idempotência.
- Testes da base de conhecimento: campos obrigatórios, referências inexistentes, IDs duplicados, ciclos, dependências inválidas, compatibilidade de versão, perguntas de competência, fórmulas de medidas, mapeamento incompleto, proveniência ausente.
- E2E do caminho completo: `GitHub → Req → payload bruto → proveniência → YAML de mapeamento → transformação → módulo ontológico → Ecto → medida → LiveView`.
- Teste descreve comportamento observável, não implementação. Nome do teste é uma frase, não `test "works"`.

### 7.7 Desenho: o padrão precisa do problema

**Aplicar um padrão sem ter o problema dele é o antipadrão.** Uma fábrica com um
produto, uma interface com uma implementação e uma camada de abstração sobre a
única fonte que existe não são "boa prática": são custo pago adiantado por uma
flexibilidade que talvez nunca seja usada, e que atrapalha quem lê hoje.

Antes de introduzir qualquer padrão, responda três perguntas **no plano da
feature**, não no commit:

1. **Qual problema concreto ele resolve?** Nomeie o problema, não a categoria.
   "Preciso trocar de fonte" é categoria; "CMPO e EO precisam do mesmo conector
   com transformações diferentes" é problema.
2. **O problema existe agora ou é previsão?** Previsão não justifica estrutura.
   O segundo caso justifica; o primeiro, não (regra dos três: duplicar uma vez é
   barato, abstrair cedo é caro).
3. **O que fica pior?** Todo padrão troca algo. Se você não consegue dizer o que
   piorou, não entendeu o padrão.

#### Padrões que este projeto usa, e o problema de cada um

| Padrão | Onde vive | Problema que resolve |
|---|---|---|
| Fachada com `defdelegate` | módulo raiz de cada ontologia | a fronteira precisa ser **verificável em revisão**: `Repo` ou `Schemas.` fora do módulo é violação textual |
| Separação comando/consulta | `commands/` e `queries/` | escrita e leitura têm invariantes diferentes; juntas, a validação da escrita vaza para a leitura |
| Porta e adaptador na borda | `Integrations.GitHub.HTTP` como behaviour | dar ao Mox **um único** ponto de substituição, para que mock de domínio nunca seja necessário |
| Estratégia declarativa | `priv/connectors/*/definitions/*.yaml` | paginação, retry e rate limit são iguais entre entidades; só os caminhos mudam |
| Data mapper declarativo | `mappings/*.yaml` + `SemanticIntegration.Mapper` | quem revisa a semântica não compila o projeto |
| Upsert por chave natural | Application Reference | idempotência sem tabela de controle e sem estado extra para discordar |
| Relator | `eo_team_memberships` | papel é relacional e temporal; uma coluna perderia contexto, período e acúmulo |
| Discriminador | `eo_teams.type` | `subkind` é rígido e exclusivo — cabe num valor, e reclassificar é `UPDATE` |

A tabela é curta de propósito. **Padrão que não está nela precisa da justificativa
das três perguntas** antes de entrar.

#### Antipadrões que este projeto atrai

Não é lista genérica de livro: cada um destes já apareceu aqui ou está a um
descuido de aparecer.

| Antipadrão | Como aparece | Por que dói aqui |
|---|---|---|
| **Booleano no lugar do relator** | `code.is_under_integration = true` | perde em qual processo, desde quando, e impede dois simultâneos |
| **Mapear por semelhança de nome** | `pull_request → merge` porque "é parecido" | contamina toda medida derivada, em silêncio |
| **Consulta sem tenant** | `Repo.all(Person)` | não é bug de correção, é bug de segurança |
| **Fallback silencioso** | `rescue -> []`, `|| 0`, `_ -> :ok` | transforma falha em zero, e zero em decisão errada. Ausência é **nula**, nunca zero |
| **Mock de módulo próprio** | `Mox.defmock(EOMock, for: EO)` | esconde o erro em vez de revelá-lo; mock só na borda HTTP |
| **Generalidade especulativa** | camada de abstração sobre a única fonte que existe | custo hoje por flexibilidade hipotética |
| **Configuração que enfraquece o gate** | `.credo.exs` que substitui o conjunto de checks | o gate continua verde e para de proteger — já aconteceu neste repositório |
| **Acoplamento temporal** | gravar checkpoint **antes** de processar a página | inverte quem paga pela interrupção: reprocessar é seguro, perder não |
| **Estado como string livre** | `status = "pendente"` sem `check_constraint` | valor novo entra por digitação e ninguém percebe |
| **Módulo-deus** | `SRO` com comandos, consultas, regras e transformação juntos | a fronteira deixa de ser revisável, que é a razão de ela existir |
| **Exceção como fluxo de controle** | `raise` para caso de negócio previsto | `{:error, motivo}` é o contrato; `raise` é para bug |
| **Primitivo no lugar do conceito** | passar `tenant_id` cru entre módulos | `%Tenant{}` na assinatura torna o esquecimento um erro de compilação, não um vazamento |
| **N+1** | `Enum.map(pessoas, &busca_equipe/1)` | `preload` ou join; e a contagem some junto com a listagem |
| **Número mágico** | `if remaining < cost * 2` sem nome nem razão | a margem existe por um motivo — escreva o motivo |

#### Práticas que valem em toda mudança

- **O nome carrega o conceito da ontologia.** `PerformedActivity`, não
  `ActivityDone`. Nome errado vira modelo errado em três meses.
- **`with` para o caminho feliz; `else` só para traduzir erro.** `else` que
  reimplementa lógica é sinal de que o `with` está fazendo demais.
- **Efeito na borda, decisão no núcleo.** Função que decide e grava ao mesmo
  tempo só é testável com banco.
- **Comentário diz o *porquê*, nunca o *quê*.** O código já diz o quê. Comentário
  que repete a linha seguinte é ruído que envelhece.
- **Deixe quebrar onde a falha é bug.** Defesa contra `nil` em toda função
  esconde de onde o `nil` veio.
- **Duplicar duas vezes é barato; abstrair errado é caro.** Na terceira, abstraia
  — e aí já se sabe o que varia.

#### Quando refatorar

Refatoração **entra na feature** quando o código que você está tocando torna a
mudança mais difícil. Não entra quando é oportunidade estética: refatoração sem
relação com a feature em curso é proibida (§17), porque mistura no mesmo diff o
que precisa ser revisado por critérios diferentes.

---

## 8. Base de conhecimento YAML

Os YAMLs em `priv/knowledge_base/` são **artefatos de domínio**, não configuração. São versionados, validados no CI, revisados e testados.

Representam: metadados de ontologia, conceitos, definições, especializações, relações, cardinalidades, restrições, perguntas de competência, mapeamentos fonte↔ontologia, necessidades de informação, medidas, fórmulas, glossário, exemplos, regras de transformação, proveniência e consultas declarativas de conectores.

Todo YAML deve ter: schema correspondente em `schemas/`, `version`, identificador estável, dependências declaradas, proveniência declarada, e rejeitar campos desconhecidos quando o schema for estrito.

Exemplo de conceito:

```yaml
concept:
  id: sro.user_story
  ontology: sro
  name: User Story
  label: { pt-BR: História de Usuário, en: User Story }
  definition:
    pt-BR: >
      Artefato de requisito que descreve um requisito em um projeto Scrum.
  classification:
    ufo_category: social_object
    parent: rsro.requirements_artifact
  attributes:
    - { name: title, type: string, required: true }
    - { name: importance, type: decimal, required: false }
  relations:
    - { relation: sro.is_part_of_product_backlog, target: sro.product_backlog, cardinality: many_to_one }
  constraints:
    - sro.user_story.must_describe_requirement
  provenance:
    source_type: thesis
    reference: "SRO Product and Sprint Backlog Subontology"
```

Exemplo de mapeamento externo — repare em `equivalence`, `justification` e `limitations`; são obrigatórios:

```yaml
mapping:
  id: github.pull_request.to.cmpo.change_request
  version: 1
  status: proposed
source:  { provider: github, entity: pull_request, api: graphql, schema_version: v4 }
target:  { ontology: cmpo, concept: cmpo.change_request }
semantics:
  equivalence: partial
  justification: >
    Um Pull Request representa uma solicitação para avaliar e potencialmente integrar
    alterações de uma branch. Não é equivalente ao merge nem à decisão de aprovação.
identity:
  external_id_path: id
  natural_key: [repository.node_id, id]
provenance:
  preserve_raw_payload: true
  required_fields: [source_system, source_instance, collected_at]
limitations:
  - O Pull Request não é equivalente ao merge.
  - Reviews e decisões de aprovação são processadas separadamente.
```

Carregamento: em compile time, boot ou cache controlado — decisão registrada no `plan.md`. **Nunca leia disco a cada requisição.**

Nenhum YAML pode conter token, senha, chave ou credencial. Mudança que altera semântica, contrato ou comportamento exige teste e revisão do agente semântico.

---

## 9. Persistência

Tabelas prefixadas pela ontologia dona do conceito:

```text
eo_organizations  eo_people  eo_teams  eo_team_memberships
spo_projects  spo_performed_processes  spo_performed_activities
sysswo_software_items  sysswo_codes  sysswo_software_systems
rsro_requirements  rsro_requirement_artifacts
cmpo_repositories  cmpo_branches  cmpo_commits  cmpo_merges
roost_test_cases  roost_test_executions  roost_test_results
qapo_evaluations  qapo_noncompliances
osdef_defects  osdef_failures
sro_sprints  sro_user_stories  sro_sprint_backlogs  sro_deliverables
ciro_processes  ciro_builds  ciro_test_processes  ciro_inspections
cdro_deliveries  cdro_deployments  cdro_environments
```

Não duplique conceito reutilizado entre ontologias. Referencie.

---

## 10. Integrações externas

Fluxo obrigatório, sem atalhos:

```text
fonte externa → integração → payload bruto → proveniência
→ mapeamento YAML → validação semântica → comando da ontologia → persistência
```

Uma entidade externa pode alimentar várias ontologias. Um Pull Request do GitHub alimenta CMPO (change request), EO (autor, revisores), SPO (atividades e participações), SysSwO (artefatos alterados) e possivelmente CIRO (gatilho de pipeline).

**Conector nunca escreve em schema Ecto de módulo ontológico.** Ele grava payload bruto + proveniência e chama a API pública do módulo.

GitHub: GraphQL por padrão, REST só com justificativa. Query em `priv/connectors/github/queries/*.graphql`, definição declarativa em `definitions/*.yaml`:

```yaml
connector:
  id: github.repositories
  version: 1
  provider: github
  transport: graphql
query:
  file: queries/repositories.graphql
variables:
  organization: { required: true }
  page_size:    { default: 50 }
pagination:
  type: cursor
  cursor_variable: after
  end_cursor_path: data.organization.repositories.pageInfo.endCursor
  has_next_page_path: data.organization.repositories.pageInfo.hasNextPage
checkpoint: { strategy: cursor }
retry: { max_attempts: 5, backoff: exponential }
output:
  raw_entity_type: github.repository
  mappings: [github/repository/to/cmpo/source_repository]
```

O runtime Elixir carrega a definição, valida contra schema, carrega a query, executa via Req, controla cursor, trata rate limit, guarda payload bruto, preserva proveniência, agenda páginas e retries com Oban, transforma pelos mapeamentos e chama a API pública do módulo ontológico.

---

## 11. Medidas e necessidades de informação

Nenhuma métrica existe sem necessidade de informação declarada. Nenhum dashboard existe sem necessidade de informação explícita.

Todo YAML de medida declara: necessidade de informação atendida, pergunta respondida, decisão apoiada, conceitos envolvidos, fórmula, unidade, fonte, filtros, período, níveis de análise, **limitações**, **interpretações incorretas possíveis** e proveniência.

```yaml
measurement:
  id: review.time_to_first_review.duration
  answers_information_need: [review.time_to_first_review]
  value_type: duration
  unit: seconds
  formula:
    expression: first_review_at - pull_request_opened_at
    inputs: [pull_request_opened_at, first_review_at]
  scope:
    levels: [pull_request, repository, project, team]
  limitations:
    - Reviews automáticas devem ser excluídas ou classificadas separadamente.
    - Pull Requests sem revisão não possuem valor concluído.
  provenance: { required: true }
```

---

## 12. Processo de trabalho

GitHub Spec Kit é **obrigatório** por feature. Não invente comandos que não existem na versão instalada — confira com `specify version` e a listagem de skills. Nesta instalação (Spec Kit 0.15.1.dev0, integração `claude`) os comandos usam hífen.

```text
Necessidade → Discovery → Feature Request
→ /speckit-specify → /speckit-clarify → /speckit-checklist → aprovação humana
→ /speckit-plan → revisão arquitetural → revisão semântica
→ /speckit-tasks → /speckit-taskstoissues → /speckit-analyze
→ /sprint-backlog          ← obrigatório: lições, iteration no GitHub, issues tipadas
→ branch → contrato da API → implementação → testes → quality gates → convergência
→ Pull Request (com revisor pedido) → revisão independente → merge
```

### Todo PR nasce com revisor pedido e ligado ao projeto

Duas obrigações, **ao abrir** o PR:

```bash
gh pr create ... --reviewer <login>            # 1. revisor
# 2. addProjectV2ItemById, Iteration = sprint corrente, Status = In review
```

PR sem revisor solicitado é PR cuja revisão não vai acontecer: ninguém é
notificado, nada entra na fila de ninguém, e a pendência só aparece no merge —
quando já é tarde. Foi o que ocorreu no PR #89, mergeado com `pulls/89/reviews`
vazio.

PR fora do projeto é trabalho invisível ao board: o sprint aparenta ter menos em
andamento do que tem, e `flow.wip.count` subconta. **Grave o `Status` depois de
adicionar o item e confira** — os workflows embutidos do projeto escrevem `Status`
na entrada e competem com a escrita manual; no PR #90 o valor gravado foi
sobrescrito para `Done`.

**Confira o revisor; o `gh` não reporta a recusa.** `--reviewer` e `--add-reviewer`
imprimem a URL, saem com código zero e não atribuem ninguém:

```bash
gh pr view <n> --json reviewRequests   # lista vazia = ninguém foi pedido
```

Lista vazia significa que a revisão não foi solicitada, **independentemente do que
o comando disse** — lição L14. Para ver o erro, use a API com `reviewers[]` ou
`team_reviewers[]`.

#### O revisor é a **equipe** `the-band`, não uma pessoa

```bash
gh api -X POST repos/The-Band-Solution/theband/pulls/<n>/requested_reviewers \
  -f 'team_reviewers[]=the-band'
```

**Pedir à equipe é o que funciona, e é melhor que pedir a uma pessoa.** O pedido fica
aberto para qualquer membro, e o autor — `paulossjunior`, sendo membro — não pode
atendê-lo. A restrição do GitHub passa a **produzir** a independência que o princípio
VII exige, em vez de bloqueá-la. Quem revisa é `Adylla027` ou `EduardoNFraiz`.

`gh pr create --reviewer paulossjunior` **não** funciona: o autor não pode ser
revisor. Não substitua por outro login para o comando passar.

**Histórico, porque a causa não era óbvia.** Até 2026-08-10 não havia revisor possível
neste repositório:

| Fato | Evidência |
|---|---|
| um único colaborador, `paulossjunior`, admin | `GET /repos/.../collaborators` |
| nenhuma equipe com acesso | `GET /repos/.../teams` vazio |
| revisão só se pede a colaborador | `422 Reviews may only be requested from collaborators` |
| o autor não pode ser revisor | `422 Review cannot be requested from pull request author` |

Resolvido concedendo `pull` à equipe `the-band`, o que a tornou **colaboradora** — o
que faltava para o pedido passar. `Adylla027` e `EduardoNFraiz` já eram admins da
organização, então o nível efetivo deles no repositório é `admin`; a concessão não
elevou ninguém, apenas os tornou alcançáveis. A exigência atravessou um sprint inteiro
como "revisão pendente" e custou **duas chamadas de API**: era pendência de permissão,
não de agenda. Lição L15.

**Nível de permissão não contorna a regra de autoria.** A pessoa mantenedora é admin do
repositório e da organização, e o `422` é o mesmo. Autor não pode ser revisor do próprio
PR, e não existe flag.

Quando não houver revisor possível, o mais forte que se consegue é o autor registrar uma
revisão do tipo comentário — `gh pr review <n> --comment`. Entra em `pulls/<n>/reviews`
com nome e data, e **não é aprovação**. Registre como registro, nunca como aprovação: a
diferença é o que separa o princípio VII cumprido de um carimbo.

**Antes de escrever regra que dependa de permissão, verifique a permissão.**
`collaborators` e `teams` respondem em duas chamadas se a regra é cumprível.

### A branch é apagada no merge

`delete_branch_on_merge: true` no repositório, desde 2026-08-10. Cada merge pelo
GitHub apaga a própria head branch, e a faxina manual deixa de existir.

Duas coisas que ele **não** faz, e por isso continuam sendo suas:

- **PR fechado sem merge deixa a branch.** A configuração só age no merge;
- **a branch local não some.** Vira referência morta até `git fetch --prune`, e
  `git branch -D` continua manual.

**Antes de apagar branch cuja `main` não a contém, verifique o conteúdo.** Houve o
caso do `chore/po-docs-em-docs`: PR #90 mergeado e a branch **não** ancestral da
`main`, porque houve force-push depois do merge. O commit exclusivo era redação já
superada, e o conteúdo útil tinha entrado por cherry-pick — mas isso foi **conferido**,
não deduzido de o PR estar mergeado.

### Contrato da API antes da implementação

**Nenhuma função pública é escrita antes de o contrato dela existir em
`specs/<feature>/contracts/`.** O contrato declara nome, assinatura, o que a
função devolve em sucesso e em erro, e — igualmente obrigatório — **o que a API
não expõe e por quê**.

A ordem não é formalidade. Ela existe por três razões concretas:

- **o contrato é revisável antes de custar caro.** Discutir uma assinatura leva
  minutos; mudá-la depois de três chamadores e dois testes leva horas, e o
  segundo chamador costuma nascer torto para acomodar a primeira decisão errada;
- **contrato escrito depois descreve o código, não o decide.** Quando o
  documento é redigido a partir da implementação, ele deixa de ser contrato e
  vira comentário — e a divergência entre os dois passa a ser invisível;
- **a fronteira do módulo só é verificável se estiver escrita.** Sem contrato,
  "não fure a fronteira" é opinião; com contrato, é diferença entre dois
  arquivos.

Quando a implementação mostrar que o contrato estava errado — e vai mostrar —,
**corrija o contrato no mesmo commit**, com a razão. O que não se aceita é o
código divergir em silêncio: código certo com contrato desatualizado é a mesma
falha de rastreabilidade que um mapeamento não declarado.

O `/speckit-analyze` compara os dois e reporta a divergência. Divergência
reportada e não resolvida é bloqueio, não observação.

Toda feature ontológica identifica: ontologia principal, ontologias das quais depende, conceitos adicionados/alterados, relações, cardinalidades, constraints, perguntas de competência, YAMLs criados/alterados, mapeamentos externos, migrações, testes conceituais e riscos semânticos.

**Branches**

```text
feature/<issue>-<descricao>    fix/<issue>-<descricao>    refactor/<issue>-<descricao>
docs/<issue>-<descricao>       test/<issue>-<descricao>   chore/<issue>-<descricao>
```

**Commits** — Conventional Commits com escopo = ontologia ou subsistema:

```text
feat(sro): add user story knowledge definition
feat(github): add pull request connector definition
test(knowledge): validate semantic mappings
fix(cmpo): prevent duplicate commit ingestion
docs(ontology): document review semantics
```

**Pull Request** informa: feature, spec, plan, issues, ontologias afetadas, conceitos e relações afetados, YAMLs alterados, tabela de mapeamentos semânticos (origem | ontologia | conceito | equivalência | limitação), migrações, testes, resultado dos quality gates, perguntas de competência validadas, evidências e riscos residuais.

**Definition of Done**: critérios de aceitação atendidos, issues atualizadas, YAMLs validados, perguntas de competência testadas, testes passando, Credo e Dialyzer aprovados, migrações testadas, mapeamento semântico revisado, documentação atualizada, PR aprovado por outro agente/pessoa, pipeline verde, merge feito, issues encerradas.

---

## 13. Perfis de agente

Cada agente tem escopo. Quem implementa não valida sozinho.

| Agente | Responsabilidade |
|---|---|
| Product & Specification | Discovery, Feature Request, specify, clarify, checklist, critérios de aceitação. **Não implementa código.** |
| Project Manager | tasks, Issues, milestones, labels, dependências, acompanhamento |
| Software Architect | diagnóstico, plan, research, data model, ADRs, revisão arquitetural |
| Ontology & Semantic Integration | conceitos, categorias UFO, definições, relações, cardinalidades, constraints, perguntas de competência, YAMLs, mapeamentos. **Pode bloquear a feature.** |
| Elixir/Phoenix Developer | implementação, testes, migrações, documentação, commits. **Não aprova o próprio PR.** |
| Data Integration | Req, GraphQL, YAMLs de conector, paginação, rate limit, checkpoints, Oban, idempotência, proveniência |
| Knowledge Base | schemas YAML, validação, versionamento, compilação, cache, diff semântico, integridade |
| QA | estratégia de testes, cenários de erro, regressão, testes conceituais, convergência |
| Reviewer | revisar código, arquitetura, semântica, YAMLs, testes, segurança, documentação |
| DevOps | CI, containers, releases, ambientes, migrações, observabilidade |
| Security | autenticação, autorização, tokens, permissões, logs, dependências, dados sensíveis |
| Documentation | README, arquitetura, ontologias, integrações, mapeamentos, ADRs, quickstart, catálogos |

---

## 14. Segurança

Nunca commite token, senha, chave privada, secret, credencial, dado pessoal sensível ou `.env` real. Use variáveis de ambiente e secret manager; mantenha `.env.example` sem valores.

YAML não carrega credencial. Log não expõe token nem payload sensível completo — redija antes de logar.

Toda query multitenant filtra por tenant; considere ausência de filtro de tenant um bug de segurança, não de correção.

---

## 15. Observabilidade

Campos a registrar quando aplicável:

```text
tenant_id  correlation_id  source_system  source_instance  external_id  internal_id
ontology  concept  mapping_id  schema_version  record_version
job_id  attempt  duration  record_count  checkpoint  status  error_code  error_reason
```

Métricas: duração da coleta; registros coletados / transformados / rejeitados / duplicados; atraso de sincronização; falhas por fonte; retries; jobs Oban; falhas de validação YAML; perguntas de competência com erro; tempo de processamento.

---

## 16. Decisões que exigem ADR

Abandonar monólito modular · introduzir microserviços · introduzir Python/Go/backend adicional · frontend separado · substituir PostgreSQL · substituir Oban · introduzir broker externo · banco de grafos · pgvector · alterar estratégia multitenant · alterar organização por ontologias · alterar YAML como base de conhecimento · alterar versionamento dos YAMLs · alterar separação fonte externa ↔ domínio · alterar contratos públicos · abandonar Spec Kit.

ADR em `docs/adr/NNNN-titulo.md`: contexto, decisão, alternativas consideradas, consequências, status.

---

## 17. Proibições

Não:

- programar sem Spec Kit, sem spec, sem plano, sem tarefas, sem issue;
- **implementar sem sprint backlog aberto pela skill `sprint-backlog`**;
- abrir sprint sem ler `docs/sprints/licoes-aprendidas.md`;
- fechar sprint sem `sprint-review.md` separando feito de não feito;
- fazer push direto na branch principal;
- aprovar o próprio PR, ou fazer merge sem revisão independente;
- declarar sucesso sem evidência (log, saída de teste, screenshot);
- remover ou enfraquecer teste para o pipeline passar;
- esconder erro com mock excessivo ou valor fixo;
- inventar requisito ou ampliar escopo silenciosamente;
- expor segredo, nem colocar segredo em YAML;
- misturar features independentes no mesmo PR;
- alterar arquitetura sem ADR;
- mapear conceitos apenas por semelhança de nome;
- ignorar proveniência ou idempotência;
- criar dashboard sem necessidade de informação;
- alterar contrato sem avaliar compatibilidade;
- modificar código para novo requisito sem atualizar o Spec Kit;
- marcar tarefa concluída sem evidência;
- ignorar inconsistências reportadas pelo `/speckit-analyze`;
- duplicar conceitos entre ontologias;
- permitir YAML inválido no repositório;
- usar a API externa como modelo de domínio;
- fazer refatoração sem relação com a feature em curso;
- introduzir tecnologia nova quando a atual atende.

---

## 18. Ao entrar no repositório

Antes de escrever qualquer código:

1. `pwd` e `git status`; identifique a raiz e a branch.
2. Leia `README.md`, `CLAUDE.md`, `.specify/memory/constitution.md`.
3. Inspecione `.github/`, `.claude/`, `specs/`, `docs/adr/`.
4. Inspecione `priv/knowledge_base/` — manifesto, schemas, YAMLs existentes.
5. Inspecione módulos ontológicos, migrações, testes e workflows.
6. Veja commits recentes; Issues e PRs abertos quando houver acesso.
7. Aponte divergências em relação a este documento.

Reporte o diagnóstico com a tabela:

| Área | Esperado | Encontrado | Lacuna | Ação recomendada |
|---|---|---|---|---|

Cobrindo: Elixir/Phoenix, LiveView, PostgreSQL/Ecto, Oban, Req, multitenancy, módulos ontológicos, base YAML, schemas YAML, conectores declarativos, testes, CI, segurança, observabilidade, documentação.

Depois: lacunas, riscos, dívida técnica, proposta de organização, backlog recomendado, feature Spec Kit recomendada, comando `/speckit-specify` proposto, próxima aprovação necessária.

**Pare no diagnóstico. Não modifique arquivos antes da aprovação humana.**

---

## 19. Roadmap

```text
001 Fundação Phoenix e governança      002 Infra da base de conhecimento YAML
003 Infra comum de ontologias          004 UFO: tipos e classificações

005 EO   006 SPO   007 SysSwO   008 RSRO
009 CMPO 010 ROoST 011 QAPO     012 OSDEF

013–017 SRO: processo, stakeholders, backlogs, user stories, entregáveis
018–021 CIRO: integração contínua, build, test, inspection
022–023 CDRO: continuous delivery, continuous deployment

024 Cadastro de fontes externas        025 Motor declarativo GraphQL/YAML
026 GitHub → EO                        027 GitHub → CMPO
028 GitHub → SRO                       029 GitHub Actions → CIRO
030 GitHub Deployments → CDRO

031 Catálogo de necessidades de informação   032 Catálogo de medidas
033 Analytics                                034 Reportify
035 Dashboard gerencial                      036 Avaliação do Knowledge Graph
037 Avaliação de recuperação semântica       038 GraphRAG
```

Cada item tem ciclo próprio de Spec Kit.

---

## 20. Regra de ouro

> Quando houver incerteza relevante — semântica, arquitetural ou de escopo — **pare e apresente alternativas**. Não adivinhe. Um mapeamento errado contamina todas as métricas derivadas dele, e ninguém percebe até a decisão já ter sido tomada com base no dado errado.
