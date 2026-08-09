# Backlog — GitHub → SRO via Adapters e Mappers

Primeira integração real do The Band: ingerir dados do GitHub e materializá-los no modelo
da **Scrum Reference Ontology**.

Documento derivado de `priv/knowledge_base/ontology/continuum/sro/` e
`priv/knowledge_base/mappings/github/`.

---

## 1. O problema honesto: GitHub não é Scrum

Antes de qualquer tarefa, a constatação que define o escopo:

**A API do GitHub não expõe a maior parte do que a SRO descreve.** Não há cerimônias, não
há Product Owner, não há critério de aceitação estruturado, não há distinção entre tarefa
planejada e executada. Fingir que há produz dado inventado — que é pior que dado ausente,
porque ninguém desconfia dele.

### Matriz de cobertura

| Conceito SRO | Observável no GitHub? | Origem | Confiança |
|---|---|---|---|
| `sro.scrum_project` | ⚠️ por configuração | repositório ou GitHub Project v2 declarado como projeto Scrum pelo tenant | média |
| `sro.scrum_process` | ⚠️ derivado | inferido da existência de sprints no projeto | baixa |
| `sro.sprint` | ✅ | `ProjectV2IterationField` (iterations do Projects v2) | alta |
| `sro.product_backlog` | ⚠️ derivado | o conjunto de itens do Project sem iteração atribuída | média |
| `sro.sprint_backlog` | ✅ | itens do Project atribuídos a uma iteration | alta |
| `sro.user_story` | ⚠️ por regra | issue classificada por label/tipo, regra declarada por tenant | média |
| `sro.epic` / `sro.atomic_user_story` | ✅ | sub-issues (parent/child) da API de issues | alta |
| `sro.acceptance_criterion` | ❌ | texto livre no corpo da issue | — |
| `sro.intended_scrum_development_task` | ⚠️ derivado | item de backlog no momento da entrada na iteration | baixa |
| `sro.performed_scrum_development_task` | ⚠️ derivado | transição de status do item + issue fechada | média |
| `sro.deliverable` | ⚠️ derivado | Pull Request mergeado vinculado à issue | média |
| `sro.accepted_deliverable` | ❌ | não há avaliação contra critério de aceitação | — |
| `sro.ceremony` (4 tipos) | ❌ | não existe na API | — |
| `sro.scrum_team` | ⚠️ parcial | GitHub Team, se o tenant declarar equivalência | baixa |
| `sro.development_team` | ⚠️ parcial | idem | baixa |
| `sro.product_owner` / `scrum_master` | ❌ | não há papel Scrum no GitHub | — |
| `sro.developer` | ⚠️ por regra | assignee de issue ou autor de PR — papel presumido, não declarado | média |
| `sro.scrum_project_deliverable` | ⚠️ derivado | release | média |

**Legenda.** ✅ existe na API · ⚠️ exige regra de classificação declarada pelo tenant ·
❌ não é derivável do GitHub.

### O que fazer com o que não é observável

Três opções, e a escolha precisa ser explícita por conceito:

1. **Não materializar.** Cerimônias, Product Owner e Scrum Master ficam ausentes. As
   perguntas de competência CQ04, CQ17, CQ18, CQ21 e CQ22 ficam **sem resposta a partir
   do GitHub** — e o sistema deve dizer isso, não retornar lista vazia como se fosse
   resposta.
2. **Materializar por configuração do tenant.** Papéis Scrum vêm de um cadastro manual
   que liga contas GitHub a papéis. Dado com proveniência `project_decision`, não
   `github`.
3. **Materializar por regra declarada.** User story, developer e task saem de regras
   por tenant (labels, tipos de issue, campos de Project). A regra é versionada como
   YAML e a proveniência aponta para ela.

> **Regra que não se quebra.** Conceito derivado por inferência carrega
> `derivation_rule_id` e `confidence` na proveniência. Um número calculado sobre dados
> inferidos precisa poder dizer que foi inferido — senão vira fato por acidente.

---

## 2. Arquitetura: Portas, Adapters e Mappers

Três responsabilidades, três camadas, nenhuma sabendo da seguinte.

```text
GitHub GraphQL/REST
   │
   ▼
┌──────────────────────────────────────────────────────────┐
│ ADAPTER — TheBand.Integrations.GitHub                    │
│ Fala o protocolo: auth, GraphQL, paginação, rate limit,  │
│ retry, cursor. Devolve payload bruto normalizado.        │
│ NÃO conhece ontologia. NÃO conhece Ecto de domínio.      │
└──────────────────────────────────────────────────────────┘
   │  %RawEntity{type: "github.issue", payload: %{...}, provenance: %{...}}
   ▼
┌──────────────────────────────────────────────────────────┐
│ RAW + PROVENANCE — TheBand.RawData / Provenance          │
│ Persiste o payload original, imutável, com proveniência. │
│ Nada é descartado aqui.                                  │
└──────────────────────────────────────────────────────────┘
   │
   ▼
┌──────────────────────────────────────────────────────────┐
│ MAPPER — TheBand.SemanticIntegration.Mapper              │
│ Lê o mapeamento YAML, aplica regras do tenant, produz    │
│ comandos de domínio. Conhece ontologia.                  │
│ NÃO conhece HTTP. NÃO escreve no banco diretamente.      │
└──────────────────────────────────────────────────────────┘
   │  {:ok, [{TheBand.Ontology.Continuum.SRO, :register_user_story, [attrs]}]}
   ▼
┌──────────────────────────────────────────────────────────┐
│ API PÚBLICA DO MÓDULO ONTOLÓGICO                         │
│ TheBand.Ontology.Continuum.SRO.register_user_story/1     │
│ Única porta de escrita. Valida, persiste, versiona.      │
└──────────────────────────────────────────────────────────┘
```

### Contratos (behaviours)

```elixir
defmodule TheBand.Integrations.SourceAdapter do
  @moduledoc "Porta que toda fonte externa implementa."

  @callback fetch(entity :: atom(), opts :: keyword()) ::
              {:ok, %{entities: [map()], cursor: String.t() | nil, has_next: boolean()}}
              | {:error, term()}

  @callback entity_types() :: [atom()]
  @callback rate_limit_status(opts :: keyword()) :: {:ok, map()} | {:error, term()}
end

defmodule TheBand.SemanticIntegration.Mapper do
  @moduledoc "Porta que traduz payload bruto em comandos de domínio."

  @callback map(raw_entity :: map(), mapping :: map(), context :: map()) ::
              {:ok, [command :: {module(), atom(), list()}]}
              | {:skip, reason :: String.t()}
              | {:error, term()}
end
```

**Por que separar Adapter de Mapper.** Uma issue do GitHub alimenta SRO (user story),
EO (autor) e SPO (atividade). Um Adapter por conceito significaria buscar a mesma issue
três vezes. Um Mapper acoplado ao HTTP significaria não conseguir remapear dados já
coletados quando a regra semântica mudar — e ela vai mudar.

Com a separação, **remapear é reprocessar `raw_entities`**, sem tocar na API do GitHub.
Isso é o que torna a correção de um mapeamento errado barata.

### Onde vive cada coisa

```text
lib/the_band/
├── integrations/
│   ├── source_adapter.ex          behaviour
│   └── github/
│       ├── adapter.ex             implementa SourceAdapter
│       ├── client.ex              Req + auth + rate limit
│       ├── pagination.ex          cursores do GraphQL
│       └── entities/              um módulo por entidade da API
├── semantic_integration/
│   ├── mapper.ex                  behaviour
│   ├── mapping_registry.ex        carrega mappings/*.yaml
│   ├── transformer.ex             aplica source_path, transforms
│   ├── derivation_rules.ex        regras por tenant (labels → user story etc.)
│   └── mappers/
│       ├── github_issue_mapper.ex
│       ├── github_project_item_mapper.ex
│       └── ...
├── raw_data/                      payload bruto imutável
├── provenance/                    proveniência + confiança + regra de derivação
└── ontology/continuum/sro/        API pública, única porta de escrita

priv/connectors/github/
├── queries/*.graphql              consultas versionadas
└── definitions/*.yaml             paginação, checkpoint, retry, mapeamentos de saída

priv/knowledge_base/mappings/github/  semântica: equivalência, justificativa, limitações
```

---

## 3. Fatias verticais

O backlog é organizado em **fatias que respondem perguntas de competência**, não em
camadas. Cada fatia termina com uma pergunta da SRO respondível com dado real.

### Fatia 0 — Fundação da ingestão

Sem isso nada roda. Não responde CQ nenhuma; é o preço de entrada.

| # | Item | Entrega |
|---|---|---|
| G0.1 | Cadastro de fonte GitHub | `sources` + `source_credentials` (referência a secret manager, nunca o segredo) |
| G0.2 | Cliente HTTP com Req | auth por token/App, timeout, retry com backoff exponencial |
| G0.3 | Controle de rate limit | leitura de `rateLimit` do GraphQL, pausa antes do estouro, não depois |
| G0.4 | Behaviour `SourceAdapter` | contrato + teste de contrato com Mox |
| G0.5 | Persistência de payload bruto | `raw_entities` imutável + `provenance_records` |
| G0.6 | Paginação por cursor | checkpoint persistido; retomada após falha sem reprocessar tudo |
| G0.7 | Job Oban de sincronização | idempotente, com `tenant_id` validado |
| G0.8 | Registry de mapeamentos | carrega `mappings/github/*.yaml`, valida contra schema, cacheia |
| G0.9 | Behaviour `Mapper` + transformer | resolve `source_path`, aplica `transform`, monta comandos |
| G0.10 | Reprocessamento | remapear `raw_entities` sem nova chamada à API |

**10 itens.** Dependências: fundação multitenant (F1–F7 do backlog geral).

---

### Fatia 1 — Pessoas e repositórios

Responde: nada de SRO ainda, mas é pré-requisito de tudo. Já entrega valor em CMPO.

| # | Item | Conceito alvo | Mapeamento | Status do YAML |
|---|---|---|---|---|
| G1.1 | Adapter: `organization` | `eo.organization` | `github.organization.to.eo.organization` | ✅ existe |
| G1.2 | Mapper: organização | `eo.organization` | idem | ✅ |
| G1.3 | Adapter: `user` | `eo.person` | `github.user.to.eo.person` | ✅ existe |
| G1.4 | Mapper: pessoa | `eo.person` | idem | ✅ |
| G1.5 | Classificação de bots | — | novo campo no mapeamento | ⚠️ ajustar |
| G1.6 | Adapter: `repository` | `cmpo.source_repository` | `github.repository.to.cmpo.source_repository` | ✅ existe |
| G1.7 | Mapper: repositório | `cmpo.source_repository` | idem | ✅ |
| G1.8 | Adapter + Mapper: `team` | `eo.team`, `eo.team_membership` | **criar** `github.team.to.eo.team` | ❌ criar |

**8 itens.** G1.5 é obrigatório: conta `Bot` não é pessoa, e contá-la como tal distorce
toda métrica por pessoa.

---

### Fatia 2 — Projeto Scrum e sprints

**Responde CQ03** (quantos sprints foram executados) e **CQ06–CQ11** (datas de início e
fim de projeto, processo e atividades).

| # | Item | Conceito alvo | Notas |
|---|---|---|---|
| G2.1 | Declaração de projeto Scrum | `sro.scrum_project` | cadastro por tenant: qual repositório ou GitHub Project é um projeto Scrum. **Não é inferível.** |
| G2.2 | Adapter: `ProjectV2` | — | consulta GraphQL de Projects v2 |
| G2.3 | Adapter: `ProjectV2IterationField` | `sro.sprint` | iterations com `startDate` e `duration` |
| G2.4 | Mapper: iteration → sprint | `sro.sprint` | **criar** `github.project_iteration.to.sro.sprint` |
| G2.5 | Derivação do processo Scrum | `sro.scrum_process` | derivado; proveniência com `confidence: low` |
| G2.6 | Adapter: `ProjectV2Item` | — | itens do board com seus campos |
| G2.7 | Sprint backlog | `sro.sprint_backlog`, `sro_sprint_backlog_items` | itens com iteration atribuída |
| G2.8 | Product backlog | `sro.product_backlog` | itens sem iteration — derivado, `confidence: medium` |

**8 itens.** Mapeamentos novos: 2.

> **Iteration é o achado que viabiliza este backlog.** Sem Projects v2 com campo de
> iteração, não há sprint no GitHub — milestone não serve: não tem duração, não tem
> ordem, e é usada para release tanto quanto para sprint. Se o tenant não usa iterations,
> a Fatia 2 não produz dado, e isso precisa aparecer como lacuna, não como zero.

---

### Fatia 3 — Épicos, user stories e tarefas: roteamento por tipo de issue

**Responde CQ23, CQ24, CQ25, CQ27** (user stories no product backlog, prioridade,
decomposição, seleção para sprint).

Uma issue do GitHub não tem destino único. Conforme o `issueType` definido pela
organização, ela é épico, user story, tarefa ou defeito — e o roteamento está declarado
em `priv/knowledge_base/rules/github_issue_type_routing.yaml`.

| `issueType` no GitHub | → Conceito | Mapeamento |
|---|---|---|
| `Epic` | `sro.epic` | `github.issue.epic.to.sro.epic` |
| `User Story`, `Story`, `Feature` | `sro.atomic_user_story` | `github.issue.user_story.to.sro.atomic_user_story` |
| `Task` | `sro.intended_scrum_development_task` | `github.issue.task.to.sro.intended_scrum_development_task` |
| `Bug` | `osdef.defect` | `github.issue.bug.to.osdef.defect` |
| nulo ou desconhecido | — | `fallback: skip` |

#### O tipo declara intenção; a estrutura declara o fato

Em SRO, **épico não é um tipo — é uma consequência**. `sro.epic` e
`sro.atomic_user_story` são ambos `sro.user_story`; a diferença é ter ou não partes.
Por isso a precedência é `structure_over_declaration`:

| Situação no GitHub | Resultado | Por quê |
|---|---|---|
| tipo `Epic`, **com** sub-issues de user story | `sro.epic` | tipo e estrutura concordam |
| tipo `Epic`, **sem** sub-issues | `sro.atomic_user_story` + divergência registrada | não existe épico sem partes — `sro.rule05` |
| tipo `User Story`, **com** sub-issues de user story | `sro.epic` + divergência registrada | a composição a torna épico, o rótulo não importa |
| tipo `User Story`, com sub-issues do tipo `Task` | `sro.atomic_user_story` | tarefa **atende** user story, não a compõe |

A última linha é a armadilha do conjunto. Sub-issue do tipo `Task` parece decomposição,
mas é outra relação: `sro.intended_task_planned_to_meet_user_story`. Tratá-la como
composição promoveria a user story a épico e a tiraria do alcance das tarefas —
`sro.rule07` exige que tarefa se ligue a user story **atômica**.

#### Épico dentro de épico

A relação `sro.epic_composed_of_user_story` tem alvo `sro.user_story`, e épico é uma
user story. Logo a decomposição é **recursiva, sem profundidade fixa**: um épico pode
compor outro épico, que compõe outro, até chegar às atômicas.

Três axiomas delimitam a recursão — sem eles, a relação admitiria um épico que é parte
de si mesmo:

| Axioma | Garante |
|---|---|
| `sro.rule04.epic_hierarchy_is_acyclic` | nenhuma user story é parte de si mesma, direta ou transitivamente |
| `sro.rule05.epic_has_parts` | todo épico tem ao menos uma parte |
| `sro.rule06.decomposition_terminates_in_atomic` | toda folha da decomposição é uma user story atômica |
| `sro.rule07.task_never_meets_epic` | tarefa se liga a user story atômica, nunca a épico |

> **A verificação de ciclo é responsabilidade do comando de registro.** O GitHub não
> impede ancestralidade circular via API, e uma constraint de banco não pega ciclo
> transitivo em auto-relacionamento — é preciso percorrer o caminho até a raiz antes de
> persistir.

#### Itens

| # | Item | Conceito alvo | Notas |
|---|---|---|---|
| G3.1 | Adapter: `issue` com `issueType` | — | inclui `parent`, `subIssues`, `subIssuesSummary` |
| G3.2 | Regra de roteamento por tipo | — | ✅ `github.issue_type_routing` declarada; falta o motor que a executa |
| G3.3 | Sobrescrita por tenant | — | `rules/tenants/<tenant>.yaml` — nomes de tipo são texto livre da organização |
| G3.4 | Mapper: issue → épico | `sro.epic` | ✅ mapeamento existe |
| G3.5 | Mapper: issue → user story atômica | `sro.atomic_user_story` | ✅ mapeamento existe |
| G3.6 | Mapper: issue → tarefa pretendida | `sro.intended_scrum_development_task` | ✅ mapeamento existe |
| G3.7 | Mapper: issue → defeito | `osdef.defect` | ✅ mapeamento existe |
| G3.8 | Resolução de precedência | — | compara tipo declarado com estrutura; aplica `structure_over_declaration` |
| G3.9 | Registro de divergência | proveniência | grava `declared_concept`, `derived_concept`, `reason` |
| G3.10 | Verificação de ciclo | `sro.rule04` | percorre ancestrais antes de persistir |
| G3.11 | Importance e complexity | atributos | campos de Project (`Priority`, `Estimate`); ausência é nulo, nunca zero |
| G3.12 | Vínculo com sprint backlog | `sro_sprint_backlog_items` | uma story pode reaparecer em sprints seguintes |
| G3.13 | Lacuna de `issueType` | — | tenant sem tipos configurados: `skip` e lacuna reportada, não user story presumida |

**13 itens.** Mapeamentos já criados: 4. Regra de derivação já criada: 1.

> **G3.13 não é caso de borda.** Tipos de issue são recurso relativamente recente e
> opcional. Um tenant que usa apenas labels cai inteiro no `fallback: skip` — e precisa
> saber disso no cadastro da fonte, não depois de uma sincronização que não produziu
> nada.

### Fatia 4 — Tarefas executadas

**Responde CQ05, CQ19, CQ20, CQ29, CQ31** (tarefas executadas no sprint, quem foi
responsável, quem participou).

| # | Item | Conceito alvo | Notas |
|---|---|---|---|
| G4.1 | Adapter: histórico de status | — | `ProjectV2ItemFieldValue` + timeline events |
| G4.2 | Mapper: tarefa executada | `sro.performed_scrum_development_task` | derivado da transição de status/fechamento |
| G4.3 | Tarefa pretendida | `sro.intended_scrum_development_task` | derivada da entrada do item na iteration |
| G4.4 | Causação pretendida → executada | relação `was caused by` | FK; sem ela não há análise de aderência |
| G4.5 | Responsável pela tarefa | `spo_participations` (`is in charge of`) | assignee da issue |
| G4.6 | Participantes | `spo_participations` (`participates in`) | autores de commits e revisores vinculados |
| G4.7 | Papel Developer presumido | `sro.developer` via `eo_team_memberships` | proveniência de inferência obrigatória |

**7 itens.** Mapeamentos novos: 2.

> A distinção pretendida/executada não existe no GitHub — a mesma issue é as duas coisas
> em momentos diferentes. G4.3 e G4.4 a reconstroem a partir do histórico do item. É
> derivação, e a proveniência precisa dizer isso. Colapsar as duas em uma entidade só é
> o atalho que destrói CQ29.

---

### Fatia 5 — Entregáveis

**Responde CQ33, CQ34, CQ35** (entregáveis produzidos no sprint e no projeto, e quais
user stories materializaram).

| # | Item | Conceito alvo | Notas |
|---|---|---|---|
| G5.1 | Adapter: PR com issues vinculadas | — | `closingIssuesReferences` do GraphQL |
| G5.2 | Mapper: PR mergeado → entregável | `sro.deliverable` | **criar** `github.pull_request.to.sro.deliverable` |
| G5.3 | Materialização | `sro_materializations` | entregável × user story |
| G5.4 | Entregável de sprint | `sro.sprint_deliverable` | agregação dos entregáveis do sprint |
| G5.5 | Release → entregável do projeto | `sro.scrum_project_deliverable` | **criar** mapeamento de release |
| G5.6 | Lacuna de aceitação | `acceptance_status` | **fica `unknown`** — GitHub não avalia contra critério de aceitação |

**6 itens.** Mapeamentos novos: 2.

> **G5.6 é uma decisão, não um bug.** `sro.accepted_deliverable` exige conformidade com
> critérios de aceitação, que o GitHub não registra. Preencher `accepted` porque o PR foi
> mergeado seria inventar a avaliação — e a medida de retrabalho nasceria falsa. O estado
> correto é `unknown`, e CQ36/CQ37 ficam sem resposta a partir desta fonte.

---

### Fatia 6 — Times e papéis Scrum

**Responde CQ13, CQ14, CQ15, CQ16** (times, papéis, membros e o papel de cada membro).

| # | Item | Conceito alvo | Notas |
|---|---|---|---|
| G6.1 | Declaração de time Scrum | `sro.scrum_team`, `sro.development_team` | cadastro por tenant sobre GitHub Teams |
| G6.2 | Catálogo de papéis Scrum | `eo_organizational_roles` | seed a partir da base de conhecimento |
| G6.3 | Alocação de papéis | `eo_team_memberships` | **cadastro manual** — não é derivável do GitHub |
| G6.4 | Lacuna de PO e Scrum Master | — | ausentes sem cadastro; CQ17, CQ21, CQ22 sem resposta |

**4 itens.** Nenhum mapeamento novo — é cadastro, não ingestão.

---

## 4. Mapeamentos YAML

### Já criados — 13

| Mapeamento | → Conceito | Equivalência |
|---|---|---|
| `github.user.to.eo.person` | `eo.person` | partial |
| `github.organization.to.eo.organization` | `eo.organization` | partial |
| `github.repository.to.cmpo.source_repository` | `cmpo.source_repository` | partial |
| `github.ref.to.cmpo.branch` | `cmpo.branch` | partial |
| `github.commit.to.cmpo.commit_artifact_copy` | `cmpo.commit_artifact_copy` | partial |
| `github.pull_request.to.cmpo.change_request` | `cmpo.change_request` | partial |
| `github.pull_request_review.to.qapo.artifact_evaluation` | `qapo.artifact_evaluation` | partial |
| `github.workflow_run.to.ciro.continuous_integration_process` | `ciro.continuous_integration_process` | partial |
| `github.deployment.to.cdro.deployment_activity` | `cdro.deployment_activity` | partial |
| **`github.issue.epic.to.sro.epic`** | `sro.epic` | **derived** |
| **`github.issue.user_story.to.sro.atomic_user_story`** | `sro.atomic_user_story` | **derived** |
| **`github.issue.task.to.sro.intended_scrum_development_task`** | `sro.intended_scrum_development_task` | **derived** |
| **`github.issue.bug.to.osdef.defect`** | `osdef.defect` | partial |

Os quatro últimos substituem o antigo `github.issue.to.sro.user_story`, que tratava
toda issue como user story. Agora o destino é decidido por `issueType` e pela estrutura
de sub-issues.

### Ainda a criar — 6

| Mapeamento | Fatia | → Conceito |
|---|---|---|
| `github.team.to.eo.team` | 1 | `eo.team` + `eo.team_membership` |
| `github.project_iteration.to.sro.sprint` | 2 | `sro.sprint` |
| `github.project_item.to.sro.sprint_backlog_item` | 2 | vínculo story × sprint backlog |
| `github.project_item_status.to.sro.performed_task` | 4 | `sro.performed_scrum_development_task` |
| `github.pull_request.to.sro.deliverable` | 5 | `sro.deliverable` |
| `github.release.to.sro.scrum_project_deliverable` | 5 | `sro.scrum_project_deliverable` |

> A tarefa **pretendida** saiu desta lista: vem da issue do tipo `Task`, já mapeada.
> O que falta é a tarefa **executada**, derivada do histórico de status do item no
> Project — são entidades distintas ligadas por
> `sro.performed_task_caused_by_intended_task`.

> `pull_request` aparece duas vezes no conjunto: já mapeia para `cmpo.change_request`
> e passará a mapear para `sro.deliverable`. É o comportamento esperado — uma entidade
> externa alimenta várias ontologias. O PR **é** a solicitação de mudança e **produz**
> o entregável; são fatos distintos sobre o mesmo payload.

### Extensão de schema — concluída

Os mapeamentos derivados exigiam campos que o schema não tinha. `mapping.schema.yaml`
ganhou dois blocos:

```yaml
source:
  selector:                          # roteia a mesma entidade para conceitos diferentes
    field: issueType.name
    rule_ref: github.issue_type_routing
    values: ["Epic"]
    structural_requirements:
      has_children: true
      children_of_concept: sro.user_story

derivation:                          # obrigatório quando equivalence é "derived"
  rule_id: github.issue_type_routing
  confidence: medium                 # high | medium | low
  inputs: [issueType.name, subIssues]
  precedence: structure_over_declaration
  on_divergence: flag_and_follow_precedence
  fallback: skip
```

`scripts/validate_knowledge_base.py` passou a exigir:

- `equivalence: derived` sem bloco `derivation` → erro;
- `rule_id` ou `rule_ref` apontando para regra inexistente em `rules/` → erro;
- `fallback` diferente de `skip` → erro;
- conceito citado em `structural_requirements` que não existe → erro.

## 5. Regras de derivação por tenant

Novo tipo de artefato na base de conhecimento: `priv/knowledge_base/rules/tenants/`.

```yaml
derivation_rule:
  id: tenant.acme.user_story_classification
  tenant: acme
  target_concept: sro.user_story
  confidence: medium
  when:
    any_label: ["user story", "feature", "story"]
    issue_type: ["Feature"]
  unless:
    any_label: ["bug", "defect", "chore"]
  fallback: skip     # nunca "assume que é user story"
```

`fallback: skip` é o padrão obrigatório. Quando a regra não decide, o dado fica em
`raw_entities` sem promoção ao domínio — visível como lacuna, não como fato.

---

## 6. Ordem de execução

```text
Fatia 0  fundação da ingestão          10 itens   ← nada roda sem isso
   ↓
Fatia 1  pessoas e repositórios         8 itens   ← já entrega valor em CMPO
   ↓
Fatia 2  projeto Scrum e sprints        8 itens   ← primeira CQ de SRO respondida (CQ03)
   ↓
Fatia 3  épicos, stories e tarefas     13 itens   ← CQ23, CQ24, CQ25, CQ27
   ↓
Fatia 4  tarefas executadas             7 itens   ← CQ05, CQ19, CQ20, CQ29, CQ31
   ↓
Fatia 5  entregáveis                    6 itens   ← CQ33, CQ34, CQ35
   ↓
Fatia 6  times e papéis                 4 itens   ← CQ13–CQ16 (cadastro, não ingestão)
```

**56 itens.** Fatias 1 e 2 são o mínimo para o sistema dizer algo verdadeiro sobre um
projeto real.

### Cobertura final de SRO a partir do GitHub

| | CQs | % |
|---|---|---|
| Respondidas com dado observado | CQ03, CQ06–CQ11, CQ13, CQ15, CQ23, CQ25, CQ27, CQ35 | 12 de 37 |
| Respondidas com derivação declarada | CQ05, CQ12, CQ14, CQ16, CQ19, CQ20, CQ24, CQ29, CQ30, CQ31, CQ33, CQ34 | 12 de 37 |
| **Sem resposta a partir do GitHub** | CQ01, CQ02, CQ04, CQ17, CQ18, CQ21, CQ22, CQ26, CQ28, CQ32, CQ36, CQ37 | **13 de 37** |

**65% da SRO fica respondível pelo GitHub.** O terço restante depende de cerimônias,
papéis e critérios de aceitação — que exigem outra fonte (Jira, Azure DevOps) ou
cadastro manual.

Isso não é falha do modelo: é o modelo cumprindo sua função de mostrar o que a ferramenta
**não** sabe. Um integrador sem ontologia simplesmente devolveria listas vazias e ninguém
perceberia a diferença.

---

## 7. Riscos

**Rate limit do GraphQL é por complexidade, não por requisição.** Uma consulta de Projects
v2 com itens, campos e histórico pode custar centenas de pontos. O controle precisa ler
`rateLimit.cost` e `remaining` na própria resposta e pausar antes do estouro — descobrir
o limite por erro 403 já é tarde, e a retomada custa uma janela inteira.

**Projects v2 é opcional.** Se o tenant não usa Projects com iterations, as Fatias 2 a 5
não produzem nada. Isso precisa ser detectado no cadastro da fonte (G0.1) e informado,
não descoberto depois de três dias de sincronização vazia.

**Regras de derivação são configuração de domínio.** Vivem versionadas na base de
conhecimento e passam por revisão semântica. Se virarem campo de formulário editável sem
histórico, a métrica muda de significado sem que ninguém saiba quando.

**Reprocessamento precisa ser barato desde o dia um.** As regras de classificação da
Fatia 3 vão estar erradas na primeira tentativa. Se corrigir exigir nova coleta completa
do GitHub, ninguém vai corrigir. G0.10 não é otimização — é o que torna o erro
recuperável.

**Sub-issues são API recente.** Verificar disponibilidade na versão do GitHub do tenant
(GitHub Enterprise Server costuma estar atrás). Sem sub-issues, a distinção epic vs
atômica cai para heurística de task list em markdown — e aí é melhor não distinguir.

---

## 8. Próximo passo

```text
/speckit-specify Ingestão de dados do GitHub para a Scrum Reference Ontology:
adapter GitHub com paginação por cursor, rate limit e persistência de payload
bruto com proveniência; registry de mapeamentos YAML; mapper de organização,
pessoa e repositório. Escopo das Fatias 0 e 1 do backlog GitHub → SRO.
```

Depois de aprovada, `/speckit-plan` precisa decidir explicitamente:

- biblioteca YAML (pesquisa de manutenção, segurança e compatibilidade);
- estratégia de cache dos mapeamentos (compile time, boot ou ETS);
- formato do checkpoint de paginação;
- se `raw_entities` guarda payload completo ou normalizado — e o custo de armazenamento
  de cada opção.
