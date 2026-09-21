<!-- DERIVADO da varredura de `schema "..." do` em lib/**/*.ex (65 declarações), cruzada
     por nome de tabela com os sete documentos de docs/modelos/classes/, e da contagem de
     `belongs_to`, `has_many`, `has_one`, `many_to_many` e `field :..., :binary_id` em
     lib/**/*.ex; confrontada com a reconstrução das 93 migrações para separar FK declarada
     de coluna crua — em 2026-09-18.
     Conferido contra o código nesta data. Regenerar ao mudar a fonte. -->

# Classes — o mapa dos schemas

**O censo, antes dos diagramas.** Esta página existe para que nenhum schema desapareça por não
ter cabido, e para registrar o fato mais surpreendente deste modelo para quem chega.

## O fato que muda como se lê todo diagrama desta pasta

> **O domínio quase não tem associação Ecto.** São **3** em **65 schemas**.

A contagem, feita em `lib/` inteiro:

| Construção | Quantas |
|---|---:|
| `belongs_to` | **1** |
| `has_many` | **2** |
| `has_one` | **0** |
| `many_to_many` | **0** |
| **total de associações** | **3** |
| `field :<algo>_id, :binary_id` | **214** |
| declarações `schema "..." do` | **65** |

### As três associações

São todas fora do domínio observado — e é isso que as torna a exceção que confirma a regra:

| Onde | O quê |
|---|---|
| `lib/the_band/tenants/user.ex:90` | `belongs_to :tenant, TheBand.Tenants.Tenant` |
| `lib/the_band/tenants/tenant.ex:24` | `has_many :users, TheBand.Tenants.User` |
| `lib/the_band/sources/connected_tool.ex:38` | `has_many :credentials, TheBand.Sources.ToolCredential, foreign_key: :connected_tool_id` |

**Tenant ↔ conta** e **ferramenta ↔ credencial**. Nada da EO, nada da SPO, nada da CMPO, nada
da SRO, nada do trabalho coletado.

### E a ligação existe — no banco

O ponto que engana: a ausência de associação Ecto **não** significa esquema frouxo. Medido nas
93 migrações reconstruídas:

| | Quantas |
|---|---:|
| colunas com `references(...)` — **FK declarada no banco** | **201** |
| colunas `:binary_id` / `:uuid` **sem** `references`, fora das PKs | **12** |

> **A ligação é declarada no banco e não é modelada no Ecto.** 201 chaves estrangeiras de
> verdade, e 3 associações. O `join` é sempre explícito, na consulta.

As 12 colunas cruas, e o porquê de cada uma, estão em
[`banco/declaracoes-da-organizacao.md`](../banco/declaracoes-da-organizacao.md#as-12-colunas-cruas-do-banco-inteiro)
— quatro são **polimórficas** (FK é impossível) e **seis não têm razão escrita**, o que é achado
registrado ali.

### Por que os diagramas de classes desta pasta desenham setas, então

Porque a seta representa a **FK do banco** e a intenção do domínio, não uma associação Ecto. Um
diagrama que só mostrasse as 3 associações declaradas mostraria três caixas ligadas e sessenta
e duas soltas — e seria fiel ao Ecto e mentiroso sobre o sistema.

**Consequência prática para quem for programar:** `Repo.preload/2` não funciona em
praticamente nada aqui. Carregar o relacionado é escrever o `join`, e os módulos de consulta
(`*/queries.ex`) existem para isso.

## Cobertura declarada

| | Quantos |
|---|---:|
| declarações `schema "..." do` em `lib/` | **65** |
| schemas em pelo menos um diagrama de classes | **65** |
| schemas **fora** de todo diagrama | **0** |
| documentos de classes | **7** |

Antes de 2026-09-18 eram **61 de 65**. Os quatro que faltavam —
`spo_item_phase_declarations`, `spo_event_concept_declarations`, `spo_activity_end_criteria` e
`eo_role_structure_management_grants` — entraram em
[`declaracoes-da-organizacao.md`](declaracoes-da-organizacao.md).

> **Tabela sem schema.** O banco tem **66** tabelas de domínio e `lib/` tem **65** schemas. A
> diferença é `eo_organizational_units`, que nasceu da ontologia e não tem origem que a
> alimente — a razão está em
> [`banco/mapa-das-tabelas.md`](../banco/mapa-das-tabelas.md#a-tabela-que-nenhum-erd-desenha).

## Schemas por contexto

| Contexto em `lib/the_band/` | Schemas |
|---|---:|
| `ontology/seon/spo` | 12 |
| `ontology/seon/eo` | 10 |
| `work_items` | 6 |
| `projects` | 5 |
| `changes` | 5 |
| `tenants` | 4 |
| `sources` | 3 |
| `profiles` | 3 |
| `ontology/seon/cmpo` | 3 |
| `verification` | 2 |
| `ontology/continuum/sro` | 2 |
| `mapping` | 2 |
| `ingestion` | 2 |
| `ai`, `communication`, `configuration`, `ontology/continuum/smpo`, `quality`, `raw_data` | 1 cada |
| **total** | **65** |

Duas surpresas de organização, que valem para quem procura um schema:

- **`cmpo_branches` mora em `configuration/`**, e não em `ontology/seon/cmpo/`
  (`lib/the_band/configuration/schemas/branch.ex:24`);
- **`raw_payloads` é declarado dentro de `raw_data.ex`**, e não numa pasta `schemas/`
  (`lib/the_band/raw_data.ex:26`).

Nos dois casos o nome da tabela diz uma coisa e o caminho do arquivo diz outra. Registrado aqui
para poupar a busca.

## O censo completo

**O método**, porque a contagem depende dele: um schema conta como coberto quando o **nome da
tabela** ou a declaração `class <Nome>` aparece **dentro de um bloco `mermaid`** do documento —
menção em prosa não conta. Mais de um documento é overlap **declarado**: a mesma entidade vista
de dois contextos.

Cinco schemas precisaram de mapeamento manual, porque o nome da classe no diagrama não se
deduz do nome do arquivo. Ficam nomeados para que a próxima contagem não os perca:

| Tabela | Arquivo | Classe no diagrama |
|---|---|---|
| `sync_checkpoints` | `ingestion/checkpoint.ex` | `SyncCheckpoint` |
| `profile_runs` | `profiles/run.ex` | `ProfileRun` |
| `profile_run_entries` | `profiles/run_entry.ex` | `ProfileRunEntry` |
| `project_items` | `projects/schemas/item.ex` | `ProjectItem` |
| `raw_payloads` | `raw_data.ex` | `RawPayload` |

| Tabela | Schema | Documento(s) |
|---|---|---|
| `access_scope_grants` | `the_band/tenants/access/scope_grant.ex:22` | declaracoes-da-organizacao, tenants-e-acesso |
| `account_disablements` | `the_band/tenants/account_disablement.ex:42` | tenants-e-acesso |
| `ai_provider_credentials` | `the_band/ai/provider_credential.ex:19` | perfis-e-modelo |
| `change_request_issues` | `the_band/changes/schemas/change_request_issue.ex:22` | trabalho-e-mudanca |
| `cmpo_branches` | `the_band/configuration/schemas/branch.ex:24` | ingestao-e-observacao |
| `cmpo_source_repositories` | `the_band/ontology/seon/cmpo/schemas/source_repository.ex:28` | ingestao-e-observacao |
| `collected_artifact_evaluations` | `the_band/quality/schemas/artifact_evaluation.ex:19` | trabalho-e-mudanca |
| `collected_change_requests` | `the_band/changes/schemas/collected_change_request.ex:19` | trabalho-e-mudanca |
| `collected_commits` | `the_band/changes/schemas/collected_commit.ex:22` | trabalho-e-mudanca |
| `collected_issue_comments` | `the_band/communication/schemas/collected_issue_comment.ex:22` | trabalho-e-mudanca |
| `collected_issues` | `the_band/work_items/schemas/collected_issue.ex:21` | projetos-e-processo, trabalho-e-mudanca |
| `collected_verifications` | `the_band/verification/schemas/collected_verification.ex:18` | trabalho-e-mudanca |
| `commit_authors` | `the_band/changes/schemas/commit_author.ex:24` | trabalho-e-mudanca |
| `commit_files` | `the_band/changes/schemas/commit_file.ex:22` | trabalho-e-mudanca |
| `connected_tools` | `the_band/sources/connected_tool.ex:23` | ingestao-e-observacao |
| `decomposition_links` | `the_band/work_items/schemas/decomposition_link.ex:17` | trabalho-e-mudanca |
| `eo_organizational_roles` | `the_band/ontology/seon/eo/schemas/organizational_role.ex:44` | eo-estrutura-organizacional |
| `eo_organizations` | `the_band/ontology/seon/eo/schemas/organization.ex:20` | eo-estrutura-organizacional, ingestao-e-observacao, projetos-e-processo |
| `eo_people` | `the_band/ontology/seon/eo/schemas/person.ex:28` | eo-estrutura-organizacional, perfis-e-modelo, projetos-e-processo, tenants-e-acesso, trabalho-e-mudanca |
| `eo_person_profiles` | `the_band/ontology/seon/eo/schemas/person_profile.ex:34` | perfis-e-modelo |
| `eo_role_structure_management_grants` | `the_band/ontology/seon/eo/schemas/role_structure_management_grant.ex:44` | declaracoes-da-organizacao |
| `eo_role_visibility_grants` | `the_band/ontology/seon/eo/schemas/role_visibility_grant.ex:32` | declaracoes-da-organizacao, eo-estrutura-organizacional |
| `eo_team_compositions` | `the_band/ontology/seon/eo/schemas/team_composition.ex:32` | eo-estrutura-organizacional |
| `eo_team_membership_evidence` | `the_band/ontology/seon/eo/schemas/team_membership_evidence.ex:28` | eo-estrutura-organizacional |
| `eo_team_memberships` | `the_band/ontology/seon/eo/schemas/team_membership.ex:52` | eo-estrutura-organizacional |
| `eo_teams` | `the_band/ontology/seon/eo/schemas/team.ex:29` | eo-estrutura-organizacional, projetos-e-processo |
| `issue_assignees` | `the_band/work_items/schemas/issue_assignee.ex:22` | trabalho-e-mudanca |
| `issue_labels` | `the_band/work_items/schemas/issue_label.ex:25` | trabalho-e-mudanca |
| `issue_mapping_rules` | `the_band/mapping/schemas/mapping_rule.ex:25` | trabalho-e-mudanca |
| `issue_promotions` | `the_band/work_items/schemas/issue_promotion.ex:29` | trabalho-e-mudanca |
| `item_field_values` | `the_band/projects/schemas/field_value.ex:19` | projetos-e-processo |
| `observed_projects` | `the_band/projects/schemas/observed_project.ex:19` | projetos-e-processo |
| `observed_repositories` | `the_band/ontology/seon/cmpo/schemas/observed_repository.ex:18` | ingestao-e-observacao, projetos-e-processo |
| `profile_automation_events` | `the_band/profiles/automation_event.ex:19` | perfis-e-modelo |
| `profile_run_entries` | `the_band/profiles/run_entry.ex:27` | perfis-e-modelo |
| `profile_runs` | `the_band/profiles/run.ex:21` | perfis-e-modelo |
| `project_field_definitions` | `the_band/projects/schemas/field_definition.ex:19` | projetos-e-processo |
| `project_items` | `the_band/projects/schemas/item.ex:20` | projetos-e-processo |
| `project_iterations` | `the_band/projects/schemas/iteration.ex:22` | projetos-e-processo |
| `raw_payloads` | `the_band/raw_data.ex:26` | ingestao-e-observacao |
| `refused_links` | `the_band/work_items/schemas/refused_link.ex:23` | trabalho-e-mudanca |
| `smpo_iteration_field_roles` | `the_band/ontology/continuum/smpo/schemas/iteration_field_role.ex:20` | declaracoes-da-organizacao, projetos-e-processo |
| `spo_activity_deadline_criteria` | `the_band/ontology/seon/spo/schemas/activity_deadline_criterion.ex:31` | declaracoes-da-organizacao, projetos-e-processo |
| `spo_activity_end_criteria` | `the_band/ontology/seon/spo/schemas/activity_end_criterion.ex:37` | declaracoes-da-organizacao |
| `spo_activity_start_criteria` | `the_band/ontology/seon/spo/schemas/activity_start_criterion.ex:43` | declaracoes-da-organizacao, projetos-e-processo |
| `spo_event_concept_declarations` | `the_band/ontology/seon/spo/schemas/event_concept_declaration.ex:30` | declaracoes-da-organizacao |
| `spo_intended_project_processes` | `the_band/ontology/seon/spo/schemas/intended_project_process.ex:20` | projetos-e-processo |
| `spo_item_phase_declarations` | `the_band/ontology/seon/spo/schemas/item_phase_declaration.ex:42` | declaracoes-da-organizacao |
| `spo_performed_project_activities` | `the_band/ontology/seon/spo/schemas/performed_project_activity.ex:35` | projetos-e-processo |
| `spo_project_boards` | `the_band/ontology/seon/spo/schemas/project_board.ex:38` | projetos-e-processo |
| `spo_project_organizations` | `the_band/ontology/seon/spo/schemas/project_organization.ex:17` | projetos-e-processo |
| `spo_project_repositories` | `the_band/ontology/seon/spo/schemas/project_repository.ex:21` | projetos-e-processo |
| `spo_project_teams` | `the_band/ontology/seon/spo/schemas/project_team.ex:17` | projetos-e-processo |
| `spo_projects` | `the_band/ontology/seon/spo/schemas/project.ex:29` | projetos-e-processo |
| `sro_sprint_issues` | `the_band/ontology/continuum/sro/schemas/sprint_issue.ex:28` | projetos-e-processo |
| `sro_sprints` | `the_band/ontology/continuum/sro/schemas/sprint.ex:39` | projetos-e-processo |
| `sync_checkpoints` | `the_band/ingestion/checkpoint.ex:19` | ingestao-e-observacao |
| `syncs` | `the_band/ingestion/sync.ex:15` | ingestao-e-observacao |
| `sys_swo_loaded_software_system_copies` | `the_band/ontology/seon/cmpo/schemas/loaded_software_system_copy.ex:20` | ingestao-e-observacao |
| `tenants` | `the_band/tenants/tenant.ex:19` | tenants-e-acesso |
| `tool_credentials` | `the_band/sources/tool_credential.ex:26` | ingestao-e-observacao |
| `tool_observation_events` | `the_band/sources/observation_event.ex:32` | ingestao-e-observacao |
| `unmapped_pattern_decisions` | `the_band/mapping/schemas/unmapped_pattern_decision.ex:21` | trabalho-e-mudanca |
| `users` | `the_band/tenants/user.ex:38` | eo-estrutura-organizacional, tenants-e-acesso |
| `verification_components` | `the_band/verification/schemas/verification_component.ex:19` | trabalho-e-mudanca |

## Os campos virtuais, que nenhum ERD mostra

**12 schemas** declaram `field :outcome, Ecto.Enum, virtual: true`. Não é coluna: é o desfecho
da gravação, devolvido pelo comando e usado para contar o que a coleta fez.

| Valores | Em quantos | O que significa |
|---|---:|---|
| `[:created, :updated, :unchanged]` | 11 | descreve entidade que **muda** |
| `[:created, :unchanged, :promoted, :completed]` | 1 | `spo_performed_project_activities` — descreve **ocorrência**, que não muda |

A ausência de `:updated` no décimo segundo é a decisão de desenho mais importante da SPO, e
está em [`estados/atividade-executada.md`](../estados/atividade-executada.md).

## Ordem de leitura sugerida

1. este mapa — para saber o tamanho, e para não procurar `preload`;
2. o [diagrama de classes](.) do contexto que interessa, pelo *nulo que significa*;
3. o [ERD](../banco/) do mesmo contexto, para chaves e índices parciais;
4. a [máquina de estados](../estados/), que é onde o comportamento mora.
