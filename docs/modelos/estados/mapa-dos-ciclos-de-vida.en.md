<!-- DERIVED from priv/repo/migrations/*.exs (93 migrations), reconstructed in order to
     obtain table → columns, and compared with the 65 `schema "..." do` declarations in
     lib/**/*.ex; plus the sweep of the writes of each lifecycle column in
     lib/**/*.ex (outside `@doc`, `@moduledoc` and comments) — on 2026-09-18.
     Checked against the code on this date. Regenerate when the source changes.
     It was NOT measured in the database: this house had no `psql` available on that date, and so
     there is no row count here. What there is is structure, which comes from the migration. -->

# States — the map of the lifecycles

**Before any state machine, the census.** This page exists so that no lifecycle disappears for not having
fit in a diagram, and so that newcomers know **where to look** for a record's state — because in this
codebase it is almost never where one expects.

## The rule that explains everything below

> **State is almost never a column.** It is a pair of date columns, and the question
> *"what situation is it in?"* is answered by asking *"which of these dates is null?"*.

Of the **66 domain tables**, exactly **three** have a column called `status`:

| Table | Values | Where they are declared |
|---|---|---|
| `syncs` | `running`, `completed`, `failed`, `interrupted` | `lib/the_band/ingestion/sync.ex:13` |
| `sync_checkpoints` | (situation of the collection stage) | `lib/the_band/ingestion/checkpoint.ex:19` |
| `tenants` | (situation of the tenant) | `lib/the_band/tenants/tenant.ex:19` |

The rest of the platform encodes situation in **dates that can be null**, and the reason is the same in
every case, written and rewritten in the migrations:

> *"Revoking MARKS, and never deletes: the question 'since when does this criterion hold' only has an
> answer if the ending preserves the beginning."*
> — `priv/repo/migrations/20260825140000_create_activity_start_criteria.exs:66-67`

An overwritten `status` column loses the beginning. A `declared_at` / `revoked_at` pair keeps both
instants and the author of each. The price is that the state stops being readable at a glance, and that
is exactly the price this folder pays back.

## The census: each lifecycle column, and in how many tables

Count made by reconstructing the 93 migrations in order. `n` is the number of domain tables that have the
column.

| Column | n | Tables | Documented machine |
|---|--:|---|---|
| `no_longer_observed_at` | **23** | see [observacao.md](observacao.md#the-23-tables) | [observacao.md](observacao.md) |
| `revoked_at` | **9** | see [declaracao-revogavel.md](declaracao-revogavel.md#the-nine-tables) | [declaracao-revogavel.md](declaracao-revogavel.md) |
| `unlinked_at` | 4 | `spo_project_organizations`, `spo_project_teams`, `spo_project_repositories`, `spo_project_boards` | [projeto-declarado.md](projeto-declarado.md) |
| `ended_at` | 2 | `eo_team_memberships`, `eo_team_compositions` | [vinculo-de-equipe.md](vinculo-de-equipe.md) |
| `disabled_at` | 2 | `users`, `account_disablements` | [conta.md](conta.md) |
| `validated_at` | 2 | `tool_credentials`, `ai_provider_credentials` | [coleta.md](coleta.md#the-credential) |
| `finished_at` | 2 | `syncs`, `profile_runs` | [coleta.md](coleta.md) |
| `invalidated_at` | 1 | `eo_team_memberships` | [vinculo-de-equipe.md](vinculo-de-equipe.md) |
| `end_declared_at` | 1 | `eo_team_memberships` | [vinculo-de-equipe.md](vinculo-de-equipe.md) |
| `excluded_at` | 1 | `observed_repositories` | [observacao.md](observacao.md#the-other-absence-the-one-that-is-our-decision) |
| `enabled_at` | 1 | `account_disablements` | [conta.md](conta.md) |
| `person_revoked_at` | 1 | `users` | [conta.md](conta.md#machine-2--the-link-between-the-account-and-the-observed-person) |
| `removed_at` | 1 | `spo_projects` | [projeto-declarado.md](projeto-declarado.md) |
| `hidden_at` | 1 | `eo_organizational_roles` | **none — see below** |
| `no_longer_in_configuration_at` | 1 | `project_iterations` | **none — see below** |
| `archived_at` | 1 | `cmpo_source_repositories` | **none — see below** |
| `inaccessible_since` | 1 | `observed_repositories` | [observacao.md](observacao.md#the-unreachable-repository) |
| `interrupted_by_user_id` | 1 | `syncs` | [coleta.md](coleta.md) |
| **`expires_at`** | **0** | — | **the column does not exist; see below** |

## The column that does not exist

The search for **`expires_at`** was requested and found nothing:

```text
$ grep -rn "expires_at" lib priv test
(no occurrence)
```

**No table, no schema, no test.** Nothing on this platform expires by a stored date. What comes closest
are two different things, and naming them avoids the search again:

1. **The session** expires by inactivity, not by column — `users.session_token` is rotated, and whoever
   deactivates an account rotates the token along with it, precisely so that "deactivate" does not mean
   "deactivate seven days from now" (`lib/the_band/tenants.ex:246-249`).
2. **The GitHub quota** has a replenishment window, but it comes from the source with each response and
   is not persisted as a deadline.

It is written here because **an absence found is a result**, and the next person who looks for
`expires_at` deserves to find this line instead of repeating the search.

## The three lifecycles without a drawn machine

They are not omitted: they are **declared as a gap**, with the reason.

| Column | Table | Why there is no diagram |
|---|---|---|
| `hidden_at` | `eo_organizational_roles` | It is **a single state and a single transition** — the role disappears from the choice lists and keeps holding in the team memberships that already cite it. A two-box `stateDiagram` teaches nothing the previous sentence does not. |
| `archived_at` | `cmpo_source_repositories` | **It is not our state**: it is the `archivedAt` GitHub returns, copied. The platform does not write it by its own decision, and so it belongs to the observed data, not to the lifecycle. |
| `no_longer_in_configuration_at` | `project_iterations` | It is `no_longer_observed_at` under another name, for the iteration that left the configuration of the board field. The machine is the same as in [observacao.md](observacao.md); the different name is because the source here is the **configuration**, not the listing. |

## Declared coverage

| | How many |
|---|---:|
| domain tables | **66** |
| tables with some lifecycle column | **51** |
| tables with an explicit `status` column | **3** |
| tables **without** a lifecycle column | **15** |
| lifecycles with a machine drawn in this folder | **7 documents** |
| lifecycles found and **declared without a diagram** | **3** (table above) |

The **15 tables without a lifecycle column** are, for the most part, the ones that record an
**occurrence** — something that happened and does not change: `issue_promotions`,
`profile_automation_events`, `raw_payloads`, `tool_observation_events`, `refused_links`,
`unmapped_pattern_decisions`, `spo_performed_project_activities`. The last one has its own document
([atividade-executada.md](atividade-executada.md)) precisely because *"never updates"* is a design
decision that needs to be written down, not an absence.

Two of these 15 **do have** a situation, and have it outside the table — it is where newcomers get most
lost:

- **`connected_tools`** has no state column. The situation comes from the **last event** of
  `tool_observation_events` (`ended` or `resumed`), through
  `TheBand.Sources.observation_ended?/1`, and `situacao/1` combines it with
  `needs_attention_since` to return `:ended | :needs_attention | :active`
  (`lib/the_band/sources.ex:259-265`). There was a column, and it was removed on purpose:
  *"The column was a third place keeping the same thing"* (`lib/the_band/sources.ex:246-247`).
  It is drawn in [coleta.md](coleta.md#the-observed-tool).
- **`sro_sprints`** keeps the situation in a **boolean**, `completed`
  (`priv/repo/migrations/20260815120000_create_sro_sprints.exs:57`).

### The four states in a boolean

The sweep of `add :<name>, :boolean` over the 93 migrations returns **8 column names in 8 tables**. Four
are observed attributes, not a situation — `is_default` and `is_protected` (`cmpo_branches`),
`is_primary` (`commit_authors`), `is_draft` (`project_items`); one is a flow instruction
(`users.must_change_password`). The remaining **four** answer *what situation is it in?*:

| Table | Column | Who decides | Source |
|---|---|---|---|
| `sro_sprints` | `completed` | the source | `20260815120000_create_sro_sprints.exs:57` |
| `observed_projects` | `closed` | the source | `20260816200000_create_observed_projects.exs:29` |
| `tool_credentials` | `active` | **us** | `20260809120400_create_sources_and_credentials.exs:52` |
| `issue_mapping_rules` | `active` | **us** | `20260811200000_create_issue_mapping_rules.exs:48` |

A boolean answers *did it end?* and not *when, and by whom* — and it is the form the rest of this
codebase abandoned in favour of the date pair. The first two are **a copy of the source** (GitHub says
whether the sprint ended and whether the board closed), and there the boolean is faithful to what was
observed.

The two `active` ones are **our decision kept in a boolean**, and that is the real pattern divergence:
deactivating a credential or a mapping rule leaves neither date nor author, and the question *"since when,
and by whom"* goes unanswered. It is recorded for whoever maintains `Sources` and `Mapping` to decide;
**it is not a defect finding** — it is the difference between this part and the other 9 declaration
tables, which write `revoked_at` and `revoked_by_user_id`.

## The seven machines

| Document | What it answers |
|---|---|
| [`declaracao-revogavel.md`](declaracao-revogavel.md) | the family of **9 tables** in which the organization declares something about its own process, and can revoke it |
| [`atividade-executada.md`](atividade-executada.md) | why the occurrence is **never updated**, and what promotion and complementation are |
| [`observacao.md`](observacao.md) | what happens when the source **stops showing** a record, in the 23 tables that mark absence |
| [`conta.md`](conta.md) | who signs in, who stopped signing in, and which observed person that account is |
| [`coleta.md`](coleta.md) | the collection run, the observed tool and the credential |
| [`projeto-declarado.md`](projeto-declarado.md) | the declared project and its four kinds of link |
| [`vinculo-de-equipe.md`](vinculo-de-equipe.md) | the person-to-team membership — four fields, five situations *(earlier than this batch)* |

## How to read any of them

In every machine in this folder the same convention holds, because it comes from the code:

- **a state name is a combination of nulls**, and the combination is written in the table that opens each
  document;
- **every transition carries the trigger** — the function that writes, with `file:line`;
- **every transition carries the test that proves it**, or the statement that there is no test;
- **what the house refuses becomes a note, never an arrow** — an arrow the code does not write is a false
  statement with the appearance of authority.
