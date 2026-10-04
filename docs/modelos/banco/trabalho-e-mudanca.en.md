<!-- DERIVED from the migrations in priv/repo/migrations/ that create and alter `collected_issues`,
     `issue_promotions`, `issue_assignees`, `issue_labels`, `decomposition_links`,
     `refused_links`, `collected_issue_comments`, `collected_change_requests`,
     `change_request_issues`, `collected_commits`, `commit_files`, `commit_authors`,
     `collected_artifact_evaluations`, `collected_verifications`, `verification_components`,
     `issue_mapping_rules` and `unmapped_pattern_decisions` — in particular
     20260819030000_add_attended_issues_provenance.exs:37-38 and
     20260819040000_create_artifact_evaluations.exs:82 —, compared with
     `information_schema.columns`, `pg_constraint` and `pg_indexes` of the development
     database `the_band_dev`, and with the schemas of
     lib/the_band/{work_items,changes,verification,quality,communication,mapping}/
     — on 2026-09-12. Checked against the code on this date. Regenerate when the source changes. -->

# Database — work and change

**17 tables out of 63, and 145 903 rows** in the development database — two thirds of everything that
exists there. Slice declared in
[`mapa-das-tabelas.md`](mapa-das-tabelas.md#the-seven-erds-and-what-each-one-covers).

Two diagrams, because in a single one the 17 boxes cannot be read.

## 1. The issue and its classification

```mermaid
erDiagram
    observed_repositories ||--o{ collected_issues : hosts
    collected_issues ||--o{ issue_promotions : "is classified by"
    issue_mapping_rules |o--o{ issue_promotions : supported
    eo_organizations ||--o{ issue_mapping_rules : declares
    eo_organizations ||--o{ unmapped_pattern_decisions : decides
    collected_issues ||--o{ issue_assignees : "is assigned to"
    collected_issues ||--o{ issue_labels : carries
    collected_issues ||--o{ collected_issue_comments : receives
    collected_issues ||--o{ decomposition_links : "decomposes into"
    collected_issues ||--o{ refused_links : "had refused"
    eo_people |o--o{ collected_issues : wrote
    eo_people |o--o{ issue_assignees : is

    collected_issues {
        uuid id PK
        uuid tenant_id FK
        uuid observed_repository_id FK
        int number "display, never identify"
        string title
        string state
        string state_reason
        text body
        string author_login
        uuid author_person_id FK "null = login without a person"
        string issue_type "raw, as the source delivers it"
        string external_parent_id
        int sub_issue_count
        string external_id
        datetime external_closed_at "null = open"
        datetime no_longer_observed_at
    }

    issue_promotions {
        uuid id PK
        uuid tenant_id FK
        uuid collected_issue_id FK
        string declared_concept "what the SOURCE declared"
        string derived_concept "what the PLATFORM concluded"
        string target_table
        uuid target_id
        string rule_id
        int rule_version
        string evidence_source "declared_type, title or structure"
        string confidence "high, medium or low"
        uuid mapping_rule_id FK
        string divergence_kind
        string divergence_reason
        string skip_reason
        string skip_detail
        datetime promoted_at
        datetime inserted_at "usec — no updated_at, append-only"
    }

    issue_mapping_rules {
        uuid id PK
        uuid tenant_id FK
        uuid organization_id FK
        string where "declared_type or title"
        string how "equals, starts_with, contains or regex"
        string pattern
        bool case_sensitive
        string target_concept
        int position
        bool active
        datetime deactivated_at "null = holds"
        string catalog_key
        int version
    }

    unmapped_pattern_decisions {
        uuid id PK
        uuid tenant_id FK
        uuid organization_id FK
        string pattern
        datetime decided_at
        datetime reverted_at "null = holds"
        string note
    }

    decomposition_links {
        uuid id PK
        uuid tenant_id FK
        uuid parent_issue_id FK
        uuid child_issue_id FK
        datetime observed_at
        datetime no_longer_observed_at
    }

    refused_links {
        uuid id PK
        uuid tenant_id FK
        uuid parent_issue_id FK
        uuid child_issue_id FK
        string child_external_id
        string reason "cycle, out_of_scope or task_meets_epic"
        string cycle_path "the path, never a boolean"
        datetime refused_at
    }

    issue_assignees {
        uuid id PK
        uuid tenant_id FK
        uuid collected_issue_id FK
        string login
        uuid person_id FK
        datetime no_longer_observed_at
    }

    issue_labels {
        uuid id PK
        uuid tenant_id FK
        uuid collected_issue_id FK
        string name
        string color
        datetime no_longer_observed_at
    }

    collected_issue_comments {
        uuid id PK
        uuid tenant_id FK
        uuid collected_issue_id FK
        text body
        string author_login
        uuid author_person_id FK
        datetime external_published_at
        datetime external_edited_at
        datetime no_longer_observed_at
    }
```

## 2. The change, the commit, the verification

```mermaid
erDiagram
    observed_repositories ||--o{ collected_change_requests : hosts
    observed_repositories ||--o{ collected_commits : hosts
    observed_repositories ||--o{ collected_verifications : hosts
    collected_change_requests |o--o{ collected_commits : gathers
    collected_commits ||--o{ commit_files : touches
    collected_commits ||--o{ commit_authors : "has authorship"
    collected_change_requests ||--o{ change_request_issues : closes
    collected_issues ||--o{ change_request_issues : "is closed by"
    collected_change_requests ||--o{ collected_artifact_evaluations : "is evaluated in"
    collected_verifications ||--o{ verification_components : runs
    eo_people |o--o{ collected_change_requests : opened
    eo_people |o--o{ commit_authors : is
    eo_people |o--o{ collected_verifications : triggered
    eo_people |o--o{ collected_artifact_evaluations : evaluated

    collected_change_requests {
        uuid id PK
        uuid tenant_id FK
        uuid observed_repository_id FK
        int number
        string title
        string state
        string source_branch
        string target_branch
        int changed_files
        int commits_total "from the source"
        int commits_collected "what fit on the page"
        string merged_head_sha
        string merged_check_state "raw — null = unknown"
        int merged_check_contexts
        string author_login
        uuid author_person_id FK
        uuid merged_by_person_id FK
        datetime external_merged_at "null = not integrated"
        int reviews_total "ABSENT from the Ecto schema"
        int attended_issues_total "ABSENT from the Ecto schema"
        text_array attended_issues_unresolved "ABSENT from the Ecto schema"
        datetime no_longer_observed_at
    }

    collected_commits {
        uuid id PK
        uuid tenant_id FK
        uuid observed_repository_id FK
        uuid change_request_id FK "null = outside a collected PR"
        string sha
        string message_headline
        text message_body
        int additions
        int deletions
        int changed_files
        datetime external_committed_at
        datetime files_collected_at "null = files not collected"
        datetime no_longer_observed_at
    }

    commit_files {
        uuid id PK
        uuid tenant_id FK
        uuid collected_commit_id FK
        string path
        string change
        int additions
        int deletions
        string previous_path
        datetime no_longer_observed_at
    }

    commit_authors {
        uuid id PK
        uuid tenant_id FK
        uuid collected_commit_id FK
        string author_login
        uuid author_person_id FK
        string author_name
        string author_email
        bool is_primary
        datetime no_longer_observed_at
    }

    change_request_issues {
        uuid id PK
        uuid tenant_id FK
        uuid collected_change_request_id FK
        uuid collected_issue_id FK
        string source "closing_reference"
        datetime no_longer_observed_at
    }

    collected_artifact_evaluations {
        uuid id PK
        uuid tenant_id FK
        uuid collected_change_request_id FK
        string state
        text body
        string author_login
        string author_type "human or bot"
        uuid author_person_id FK
        datetime external_submitted_at
        datetime no_longer_observed_at
    }

    collected_verifications {
        uuid id PK
        uuid tenant_id FK
        uuid observed_repository_id FK
        string workflow_name
        string workflow_path
        string head_sha
        string head_branch
        string trigger_event "raw"
        string run_status
        string conclusion "raw"
        string phase "translation into CIRO"
        text_array process_kinds
        int attempt
        uuid actor_person_id FK
        datetime external_started_at
        datetime external_finished_at
        datetime no_longer_observed_at
    }

    verification_components {
        uuid id PK
        uuid tenant_id FK
        uuid collected_verification_id FK
        string job_name
        string conclusion
        string phase
        text_array components
        text_array step_names
        datetime external_started_at
        datetime external_finished_at
        datetime no_longer_observed_at
    }
```

## The `CHECK`s — and one of them is the heart of the subsystem

| Constraint | Rule |
|---|---|
| **`issue_promotions_promoted_xor_skipped`** | **either** `derived_concept` present and `skip_reason` null, **or** the opposite. Never both, never neither |
| `issue_promotions_divergence_kind_needs_reason` | a divergence **always** with a written reason |
| `issue_promotions_divergence_kind_known` | `epic_without_parts`, `composition_makes_epic`, `task_with_parts`, `user_story_without_parts`, `label_vs_structure` |
| `issue_promotions_evidence_source_known` | `declared_type`, `title` or `structure` |
| `issue_promotions_confidence_known` | `high`, `medium` or `low` |
| `decomposition_links_no_self_parent` | `parent_issue_id <> child_issue_id` |
| `refused_links_reason_check` | `cycle`, `out_of_scope` or `task_meets_epic` |
| `issue_mapping_rules_where_known` | `declared_type` or `title` |
| `issue_mapping_rules_how_known` | `equals`, `starts_with`, `contains` or `regex` |

The first is the most important invariant in the whole database: **a promotion with no conclusion and no
reason would be silent success in the shape of a row** — the platform would have "classified" the issue
without saying as what nor why not. The `CHECK` makes it impossible.

## The partial indexes

| Index | Form | Serves |
|---|---|---|
| `collected_change_requests_merged_red_index` | `INDEX (merged_check_state) WHERE merged_check_state IN ('FAILURE','ERROR')` | the question *"which PR went in with a red verification"* — and the index is small because it only indexes the ones of interest |

It is the only partial index of the subsystem, and **it is not an invariant**: it is a domain question
written into the schema.

## The FKs and what happens on delete

The pattern is uniform and worth stating at once:

- **to the parent issue, PR, commit or verification**: `CASCADE`. Deleting the issue takes labels,
  assignments, comments, decomposition links, refusals and promotions;
- **to `eo_people`**: always `SET NULL`. Deleting the person **does not delete their work** — the
  `author_login` stays, and the platform comes to know who wrote it without knowing who it is;
- **to `issue_mapping_rules`**: `SET NULL` on `issue_promotions.mapping_rule_id`. The classification
  survives the rule that produced it, and that is what allows auditing a promotion after the rule has
  been deleted;
- **to `tenants`**: `RESTRICT`, with **two exceptions in `CASCADE`** —
  `collected_artifact_evaluations` and (in the [other context](ingestao-e-observacao.md))
  `cmpo_branches`. I did not find the written reason; it is recorded in the map.
- `collected_commits.change_request_id` → `collected_change_requests`: **`SET NULL`**. Deleting the PR
  does not delete the commits — they existed in the repository independently of it.

## What the diagram does not show

- `inserted_at` / `updated_at`; `issue_promotions` has only `inserted_at`, in microseconds.
- `raw_payload` (`jsonb`) in `collected_change_requests`, `collected_commits`,
  `collected_verifications`, `collected_artifact_evaluations`, `collected_issue_comments`.
- `source_system`, `source_instance`, `collected_at`, `last_observed_at` — in all collected tables.
- `collected_issues`: `milestone_title`, `milestone_external_id`, `milestone_due_on`,
  `project_titles`, `comment_count`, `reaction_count`, `issue_type_external_id`,
  `external_created_at`, `external_updated_at` — 31 columns in all, 16 in the diagram.
- `issue_mapping_rules`: `created_by_id`, `deactivated_by_id`;
  `unmapped_pattern_decisions`: `decided_by_id`, `reverted_by_id`.
- The non-partial indexes.

## Divergence — three columns the Ecto schema does not have

`collected_change_requests.reviews_total`, `.attended_issues_total` and
`.attended_issues_unresolved` are **in the ERD with the mark `ABSENT from the Ecto schema`**, because the
truth here is the migration. They exist, are written and read — by a **schemaless query**,
13 occurrences of `from c in "collected_change_requests"` in `lib/`.

Whoever reads `lib/the_band/changes/schemas/collected_change_request.ex` concludes they do not exist, and
`%CollectedChangeRequest{}` indeed does not have them. Details, sources and follow-up in
[`classes/trabalho-e-mudanca.md`](../classes/trabalho-e-mudanca.md#divergences-found).
