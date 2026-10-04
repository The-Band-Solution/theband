<!-- DERIVED from the sweep of `schema "..." do` in lib/**/*.ex (65 declarations), cross-checked
     by table name against the seven documents in docs/modelos/classes/, and from the count of
     `belongs_to`, `has_many`, `has_one`, `many_to_many` and `field :..., :binary_id` in
     lib/**/*.ex; compared with the reconstruction of the 93 migrations to separate declared FK
     from raw column — on 2026-09-18.
     Checked against the code on this date. Regenerate when the source changes. -->

# Classes — the map of the schemas

**The census, before the diagrams.** This page exists so that no schema disappears for not
having fit, and to record the most surprising fact about this model for newcomers.

## The fact that changes how every diagram in this folder is read

> **The domain has almost no Ecto association.** There are **3** in **65 schemas**.

The count, done over the whole of `lib/`:

| Construct | How many |
|---|---:|
| `belongs_to` | **1** |
| `has_many` | **2** |
| `has_one` | **0** |
| `many_to_many` | **0** |
| **total associations** | **3** |
| `field :<something>_id, :binary_id` | **214** |
| `schema "..." do` declarations | **65** |

### The three associations

They are all outside the observed domain — and that is what makes them the exception that proves the rule:

| Where | What |
|---|---|
| `lib/the_band/tenants/user.ex:90` | `belongs_to :tenant, TheBand.Tenants.Tenant` |
| `lib/the_band/tenants/tenant.ex:24` | `has_many :users, TheBand.Tenants.User` |
| `lib/the_band/sources/connected_tool.ex:38` | `has_many :credentials, TheBand.Sources.ToolCredential, foreign_key: :connected_tool_id` |

**Tenant ↔ account** and **tool ↔ credential**. Nothing from EO, nothing from SPO, nothing from CMPO,
nothing from SRO, nothing from the collected work.

### And the link exists — in the database

The point that misleads: the absence of an Ecto association does **not** mean a loose schema.
Measured in the 93 reconstructed migrations:

| | How many |
|---|---:|
| columns with `references(...)` — **FK declared in the database** | **201** |
| `:binary_id` / `:uuid` columns **without** `references`, outside the PKs | **12** |

> **The link is declared in the database and is not modelled in Ecto.** 201 real foreign keys,
> and 3 associations. The `join` is always explicit, in the query.

The 12 raw columns, and the reason for each one, are in
[`banco/declaracoes-da-organizacao.md`](../banco/declaracoes-da-organizacao.md#the-12-raw-columns-in-the-whole-database)
— four are **polymorphic** (an FK is impossible) and **six have no written reason**, which is a finding
recorded there.

### Why the class diagrams in this folder draw arrows, then

Because the arrow represents the **database FK** and the intent of the domain, not an Ecto
association. A diagram that only showed the 3 declared associations would show three connected boxes
and sixty-two loose ones — and would be faithful to Ecto and lying about the system.

**Practical consequence for whoever is going to program:** `Repo.preload/2` does not work on
practically anything here. Loading the related record means writing the `join`, and the query modules
(`*/queries.ex`) exist for that.

## Declared coverage

| | How many |
|---|---:|
| `schema "..." do` declarations in `lib/` | **65** |
| schemas in at least one class diagram | **65** |
| schemas **outside** every diagram | **0** |
| class documents | **7** |

Before 2026-09-18 it was **61 of 65**. The four that were missing —
`spo_item_phase_declarations`, `spo_event_concept_declarations`, `spo_activity_end_criteria` and
`eo_role_structure_management_grants` — went into
[`declaracoes-da-organizacao.md`](declaracoes-da-organizacao.md).

> **Table without a schema.** The database has **66** domain tables and `lib/` has **65** schemas. The
> difference is `eo_organizational_units`, which was born from the ontology and has no source that
> feeds it — the reason is in
> [`banco/mapa-das-tabelas.md`](../banco/mapa-das-tabelas.md#the-table-no-erd-draws).

## Schemas by context

| Context in `lib/the_band/` | Schemas |
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
| `ai`, `communication`, `configuration`, `ontology/continuum/smpo`, `quality`, `raw_data` | 1 each |
| **total** | **65** |

Two organizational surprises, useful for whoever is looking for a schema:

- **`cmpo_branches` lives in `configuration/`**, not in `ontology/seon/cmpo/`
  (`lib/the_band/configuration/schemas/branch.ex:24`);
- **`raw_payloads` is declared inside `raw_data.ex`**, not in a `schemas/` folder
  (`lib/the_band/raw_data.ex:26`).

In both cases the table name says one thing and the file path says another. Recorded here
to save the search.

## The full census

**The method**, because the count depends on it: a schema counts as covered when the **table name**
or the `class <Name>` declaration appears **inside a `mermaid` block** of the document —
a mention in prose does not count. More than one document is a **declared** overlap: the same entity
seen from two contexts.

Five schemas needed manual mapping, because the class name in the diagram cannot be deduced from the
file name. They are named so that the next count does not lose them:

| Table | File | Class in the diagram |
|---|---|---|
| `sync_checkpoints` | `ingestion/checkpoint.ex` | `SyncCheckpoint` |
| `profile_runs` | `profiles/run.ex` | `ProfileRun` |
| `profile_run_entries` | `profiles/run_entry.ex` | `ProfileRunEntry` |
| `project_items` | `projects/schemas/item.ex` | `ProjectItem` |
| `raw_payloads` | `raw_data.ex` | `RawPayload` |

| Table | Schema | Document(s) |
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

## The virtual fields, which no ERD shows

**12 schemas** declare `field :outcome, Ecto.Enum, virtual: true`. It is not a column: it is the
outcome of the write, returned by the command and used to count what collection did.

| Values | In how many | What it means |
|---|---:|---|
| `[:created, :updated, :unchanged]` | 11 | describes an entity that **changes** |
| `[:created, :unchanged, :promoted, :completed]` | 1 | `spo_performed_project_activities` — describes an **occurrence**, which does not change |

The absence of `:updated` in the twelfth is the most important design decision in SPO, and
it is in [`estados/atividade-executada.md`](../estados/atividade-executada.md).

## Suggested reading order

1. this map — to know the size, and so as not to look for `preload`;
2. the [class diagram](.) of the context of interest, for the *null that means something*;
3. the [ERD](../banco/mapa-das-tabelas.md) of the same context, for keys and partial indexes;
4. the [state machine](../estados/mapa-dos-ciclos-de-vida.md), which is where behaviour lives.
