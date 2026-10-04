<!-- DERIVED from the migrations in priv/repo/migrations/ that create `connected_tools`,
     `tool_credentials`, `tool_observation_events`, `syncs`, `sync_checkpoints`,
     `raw_payloads`, `sys_swo_loaded_software_system_copies`, `cmpo_source_repositories`,
     `observed_repositories` and `cmpo_branches`, compared with
     `information_schema.columns`, `pg_constraint` and `pg_indexes` of the development
     database `the_band_dev`; and from the schemas
     lib/the_band/sources/*.ex, lib/the_band/ingestion/{sync,checkpoint}.ex,
     lib/the_band/raw_data.ex, lib/the_band/ontology/seon/cmpo/schemas/*.ex,
     lib/the_band/configuration/schemas/branch.ex — on 2026-09-12.
     Checked against the code on this date. Regenerate when the source changes. -->

# Database — ingestion and observation

**10 tables out of 63.** The connected tool, the credential, the collection run, the checkpoint, the
preserved raw payload, and the repository in its three layers. Slice declared in
[`mapa-das-tabelas.md`](mapa-das-tabelas.md#the-seven-erds-and-what-each-one-covers).

## The diagram

```mermaid
erDiagram
    tenants ||--o{ connected_tools : bounds
    connected_tools ||--o{ tool_credentials : "authenticates with"
    connected_tools ||--o{ tool_observation_events : "ends and resumes"
    connected_tools ||--o{ syncs : runs
    tool_credentials |o--o{ syncs : "was used in"
    syncs ||--o{ sync_checkpoints : "resumes by"
    syncs ||--o{ raw_payloads : preserves
    connected_tools ||--o{ observed_repositories : reaches
    sys_swo_loaded_software_system_copies ||--o{ cmpo_source_repositories : materializes
    cmpo_source_repositories ||--o{ observed_repositories : "is observed as"
    eo_organizations ||--o{ cmpo_source_repositories : owns
    observed_repositories ||--o{ cmpo_branches : has

    connected_tools {
        uuid id PK
        uuid tenant_id FK
        string tool_type
        string instance_url
        string organization_login
        int sync_interval_minutes "null = no automatic collection"
        datetime last_sync_at
        datetime needs_attention_since "null = healthy"
        string needs_attention_reason
    }

    tool_credentials {
        uuid id PK
        uuid tenant_id FK
        uuid connected_tool_id FK
        string label
        bytea secret "encrypted by Cloak"
        string last_four
        bool active
        string owner_login
        text_array scopes
        datetime validated_at "null = never validated"
        datetime last_failure_at
        string last_failure_reason
    }

    tool_observation_events {
        uuid id PK
        uuid tenant_id FK
        uuid connected_tool_id FK
        string event "ended or resumed"
        datetime occurred_at
        uuid actor_user_id FK
        string reason
        json impact
    }

    syncs {
        uuid id PK
        uuid tenant_id FK
        uuid connected_tool_id FK
        uuid credential_id FK
        string status "running, completed, failed or interrupted"
        datetime started_at
        datetime finished_at "null = in progress"
        int records_collected
        int records_created
        int records_updated
        int records_skipped
        int repositories_unreachable
        int repositories_skipped
        json skip_reasons
        int memberships_pending_role
        string error_reason
        uuid interrupted_by_user_id FK
    }

    sync_checkpoints {
        uuid id PK
        uuid tenant_id FK
        uuid sync_id FK
        string entity_type
        string cursor
        int page_count
        int record_count
        int expected_count
        datetime last_page_at
        string status
    }

    raw_payloads {
        uuid id PK
        uuid tenant_id FK
        uuid sync_id FK
        string raw_entity_type
        string external_id
        json payload
        string mapping_id
        int mapping_version
        datetime collected_at
    }

    sys_swo_loaded_software_system_copies {
        uuid id PK
        uuid tenant_id FK
        string internal_id
        string type "CHECK = source_repository"
        string external_id
        datetime no_longer_observed_at
    }

    cmpo_source_repositories {
        uuid id PK
        uuid tenant_id FK
        uuid loaded_software_system_copy_id FK
        uuid organization_id FK
        string name
        string qualified_name
        string url
        string primary_language
        string default_branch
        datetime archived_at
        datetime last_pushed_at
    }

    observed_repositories {
        uuid id PK
        uuid tenant_id FK
        uuid connected_tool_id FK
        uuid source_repository_id FK
        datetime excluded_at "tenant decision"
        uuid excluded_by_user_id FK
        datetime inaccessible_since "reach failure"
        string inaccessible_reason
        datetime issues_collected_at
        datetime comments_collected_at
        datetime changes_collected_at
        datetime verifications_collected_at
        datetime branches_collected_at
        datetime reviews_collected_at "dead column"
        int branches_total
        json query_versions
    }

    cmpo_branches {
        uuid id PK
        uuid tenant_id FK
        uuid observed_repository_id FK
        string name
        string head_sha
        datetime head_committed_at
        bool is_default
        bool is_protected
        datetime no_longer_observed_at
    }
```

## The partial indexes

| Index | Form | States |
|---|---|---|
| `syncs_one_running_per_tool_index` | `UNIQUE (connected_tool_id) WHERE status = 'running'` | **one collection in progress per tool** — FR-018. The Oban worker's `unique` alone would not be enough: it expires in 300 s, and a long collection goes beyond that |
| `connected_tools_auto_sync_index` | `INDEX (sync_interval_minutes) WHERE sync_interval_minutes IS NOT NULL` | not an invariant — it is the question `Jobs.ScheduleDueSyncs` asks every 5 min, served without a scan |

## The `CHECK`s

| Constraint | Rule |
|---|---|
| `syncs_status_check` | `running`, `completed`, `failed` or `interrupted` — four, and nothing else |
| `observed_repositories_exclusion_has_author` | `excluded_at` null, **or** `excluded_by_user_id` present |
| `tool_observation_events_event_check` | `ended` or `resumed` |
| `sys_swo_copies_type_check` | `type = 'source_repository'` — the loaded copy is always a repository, today |

**There is no `CHECK` requiring an author for `inaccessible_since`**, and that is consistent: exclusion is
a **person's decision** and so it has an author; inaccessibility is a **fact observed** by the credential
and has no human author. Both prevent collection, and the model distinguishes them.

## The FKs and what happens on delete

| From | To | On delete |
|---|---|---|
| `tool_credentials.connected_tool_id` | `connected_tools` | `CASCADE` |
| `syncs.connected_tool_id` | `connected_tools` | `CASCADE` |
| `syncs.credential_id` | `tool_credentials` | **`SET NULL`** — the run stays in history without the credential |
| `syncs.interrupted_by_user_id` | `users` | `SET NULL` |
| `sync_checkpoints.sync_id` | `syncs` | `CASCADE` |
| `raw_payloads.sync_id` | `syncs` | `CASCADE` |
| `observed_repositories.connected_tool_id` | `connected_tools` | `CASCADE` |
| `observed_repositories.source_repository_id` | `cmpo_source_repositories` | `CASCADE` |
| `observed_repositories.excluded_by_user_id` | `users` | `SET NULL` |
| `cmpo_source_repositories.loaded_software_system_copy_id` | `sys_swo_...copies` | `CASCADE` |
| `cmpo_source_repositories.organization_id` | `eo_organizations` | **`RESTRICT`** |
| `cmpo_branches.observed_repository_id` | `observed_repositories` | `CASCADE` |
| `cmpo_branches.tenant_id` | `tenants` | **`CASCADE`** — exception, see below |
| other `.tenant_id` | `tenants` | `RESTRICT` |

**`cmpo_branches.tenant_id` is `CASCADE` while the other nine are `RESTRICT`.** I did not find the
written reason for the difference in the code. Two readings: either it was a decision (a branch is derived
from the repository and goes with it), or it is an inconsistency of a later migration. Take it to whoever
maintains ingestion — it is not this document's choice.

## The longest cascade in the database

```
tenants  ×  connected_tools  →  observed_repositories  →  cmpo_branches
                             →  syncs  →  sync_checkpoints
                                      →  raw_payloads
```

Deleting a `connected_tools` takes along credentials, events, runs, checkpoints, raw payloads, observed
repositories and branches. **Deleting a `tenants` takes nothing — it is refused** by the `RESTRICT` on the
first FK. The asymmetry is the rule: the tool is operational and disposable; the tenant is the root and
only leaves after everything it bounds.

## What the diagram does not show

- `inserted_at` / `updated_at`; `tool_observation_events` uses `timestamps(updated_at: false)`.
- `source_system`, `source_instance`, `external_id`, `collected_at`, `last_observed_at` in the
  collected tables — the Application Reference (FR-012). `cmpo_source_repositories` and
  `sys_swo_...copies` have them; `connected_tools`, `syncs` and `sync_checkpoints` do not, because they are
  platform and not observed data.
- `record_version` and `internal_id` in `sys_swo_...copies`.
- `cmpo_branches.raw_payload` and `cmpo_branches.external_created_at`.
- The **non-partial** indexes — there are dozens, and none carries an invariant.
- `Ingestion.Cota`, `Ingestion.Janela` and `Ingestion.QueryVersion` **have no table**: the quota lives in
  a process (ADR 0007), the window is a function, and the query version writes to
  `observed_repositories.query_versions`.

## What the data says today

Development database, 2026-09-12:

| Fact | Value |
|---|---|
| connected tools / credentials | 1 / 1 |
| collection runs | 9 |
| checkpoints | 103 |
| preserved raw payloads | **16 820** |
| repositories, in the three layers | **126 / 126 / 126** — no divergence |
| branches | 755 |
| observation events (`ended`/`resumed`) | 0 |

The three layers of the repository having exactly 126 rows each is what is expected when collection is
consistent; **the day they diverge, the difference is the finding**, and this number is the baseline for
noticing it.

## Divergence

**`observed_repositories.reviews_collected_at`** is in the ERD with the note *dead column*, and not in the
Ecto schema. Details and follow-up in
[`classes/ingestao-e-observacao.md`](../classes/ingestao-e-observacao.md#divergences-found).
