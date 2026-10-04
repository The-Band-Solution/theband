# The Band data model

How the database and the Ecto schemas are organized, and **why they have this shape**.

Companion to [overview.md](overview.md), which deals with the architecture. This one deals
with the tables and the classes.

**State of the document**: written on 2026-08-11, from the 16 migrations and the 13
Ecto schemas that exist in the repository. What was not checked is declared in the
[last section](#what-this-document-does-not-cover).

---

## 1. The thing that most confuses newcomers

**Most of this schema was not written by hand. It was derived.**

There is a script — `scripts/derive_information_model.py` — that reads the knowledge
base in `priv/knowledge_base/` and produces the information model: which
concepts become a table, which become a discriminator column, which become a foreign
key, and which become nothing.

```bash
python3 scripts/derive_information_model.py --ontology eo
```

The migration is written **from that output**. This inverts the normal instinct:
you do not decide that `eo_teams` needs an organization column and
add it. You declare the relation in the ontology, run the deriver, and the column
appears — or it does not, and then the answer is that it should not exist.

The rule has a name: **ADR 0004, decision D4** — the information model is derived,
never written by hand.

### What happens when someone ignores this

It happened, and it is recorded in a migration that exists only to undo it:

```
priv/repo/migrations/20260810140000_drop_hand_written_organization_columns.exs
```

In feature 001, `eo_people.organization_id` and `eo_teams.organization_id` were
added by hand because the relation was not declared in EO — and declaring it would not
have been enough, because the deriver did not yet generate a foreign key from an
association. Writing the column was the shortcut.

The result, measured before removing it:

```
tabela    | total | com organization_id
----------+-------+--------------------
eo_people |    72 |                   0
eo_teams  |    10 |                   0
```

**Zero in 100% of the records.** No code filled the columns, because no
command derived from the ontology knew they existed. A column outside the derived
model is not just irregular: it has nobody to write it.

And `eo_people.organization_id` did not come back, for a reason stronger than
procedure: **it is semantically wrong**. The same GitHub account appears in
more than one organization, and the person is a single row, because their identity is the
Application Reference. A simple column would alternate its value on each collection, and the
last organization synchronized would erase the previous one. The correct path is person →
team → organization.

`eo_teams.organization_id` came back in the next migration — **derived**, nullable, and
with the constraint the deriver asked for.

---

## 2. Two halves that do not mix

The database has two natures, and the boundary between them is **principle II of the
constitution**: *an external source is not the domain*.

```
┌─────────────────────────────────────────────────────────────────┐
│  INFRAESTRUTURA DA PLATAFORMA                                   │
│  o que a plataforma precisa para funcionar                      │
│                                                                  │
│  tenants ─── users                                               │
│     │                                                            │
│     ├── connected_tools ─── tool_credentials                     │
│     │         │                                                  │
│     │         ├── tool_observation_events   (append-only)        │
│     │         └── syncs ─── sync_checkpoints                     │
│     │                  └── raw_payloads     (payload preservado) │
│     │                                                            │
└─────┼────────────────────────────────────────────────────────────┘
      │  a travessia acontece aqui: semantic_integration/
      │  lê raw_payloads e chama a API pública do módulo ontológico
┌─────┼────────────────────────────────────────────────────────────┐
│     ▼   DOMÍNIO — derivado das ontologias                        │
│                                                                  │
│  eo_organizations ──┬── eo_teams ──┐                             │
│                     │              ├── eo_team_memberships       │
│                     └── eo_people ─┤        (relator)            │
│                                    └── eo_team_membership_       │
│  eo_organizational_roles ───────────────────  evidence           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Why the separation matters.** A `raw_payload` is what GitHub answered — with
GitHub's vocabulary, GitHub's fields and GitHub's errors. A row in
`eo_people` is a person in the sense of the Enterprise Ontology. Mixing the two would make
the domain inherit each source's data model, which is exactly the problem
the platform exists to solve.

Practical consequence: **no `eo_*` table has a column that only makes sense for
GitHub.** If you need one, its place is the preserved payload.

### Table inventory

Checked against the 16 migrations. Oban has its own table, created by the library.

| Table | Nature | What it holds |
|---|---|---|
| `tenants` | platform | the tenant; every domain table points here |
| `users` | platform | a person who uses the platform — **not** `eo_people` |
| `connected_tools` | platform | an organization observed on a tool instance |
| `tool_credentials` | platform | credential encrypted at rest |
| `tool_observation_events` | platform | `ended` / `resumed` transitions, append-only |
| `syncs` | platform | one collection run, with its report |
| `sync_checkpoints` | platform | cursor per entity type, to resume |
| `raw_payloads` | platform | what the source answered, preserved |
| `eo_organizations` | domain (EO) | `eo.organization` |
| `eo_people` | domain (EO) | `eo.person` |
| `eo_teams` | domain (EO) | `eo.team`, with a subtype discriminator |
| `eo_organizational_units` | domain (EO) | `eo.organizational_unit` — formerly `eo_sectors` |
| `eo_organizational_roles` | domain (EO) | `eo.organizational_role` |
| `eo_team_memberships` | domain (EO) | the allocation **relator** |
| `eo_team_membership_evidence` | domain (EO) | what was observed and has not yet become an allocation |

**`users` versus `eo_people` is the most common confusion.** `users` is whoever logs in.
`eo_people` is whoever appears in the collected data. The same physical person can be
in both, and the two rows are not linked: linking them would require deciding that the GitHub
account and the login e-mail are the same identity, and that is a statement about the
world nobody has declared.

---

## 3. Application Reference: the identity that sustains idempotency

Every domain table that comes from an external source has these three columns:

```elixir
add :source_system,   :string, null: false   # "github"
add :source_instance, :string, null: false   # "https://github.com"
add :external_id,     :string, null: false   # o id global na origem
```

And a unique index over them, with the tenant:

```elixir
create unique_index(
  :eo_people,
  [:tenant_id, :source_system, :source_instance, :external_id],
  name: :eo_people_application_reference_index
)
```

**Why three columns and not one.** The same identifier can exist in two
different instances of the same tool — `github.com` and an internal GitHub Enterprise
Server. Without `source_instance`, the two would collide; and the collision would show up
as a person with two names, not as an error.

**What it buys: idempotency.** Collecting twice duplicates nothing, because
the upsert recognizes the row by its Application Reference. The constitution treats this
as non-negotiable (principle III), and the test that proves it compares the counts
before and after a second identical collection.

**Why not use the number the source shows.** An issue's number is unique
within the repository, and moving the issue between repositories creates another one. The
global identifier does not change. The rule holds for every entity: the identity is the
global identifier, never the number shown in the interface.

### `internal_id` and `record_version`

Two columns on every domain table that come from the thesis, not from GitHub:

| Column | What it is for |
|---|---|
| `internal_id` | stable identity of the data **across ontology modules** — a module references another's data through this, never through the primary key |
| `record_version` | the record's version, for reprocessing and retrofitting |

---

## 4. A role is never a column: the relator

This is the decision that surprises the most, and the one that saves the most refactoring
later.

**The wrong question**: "what is this person's role?" — which suggests an
`eo_people.role` column.

**Why it is wrong**: the answer is always *it depends*. It depends on the team, on the
period, and there can be more than one. A column holds one value and loses all three
things:

| The column loses | Concrete example |
|---|---|
| **the context** | the same person is Product Owner on one team and a developer on another |
| **the period** | "who was the PO in sprint 3" is a legitimate question, and the column only knows today |
| **the multiplicity** | two simultaneous allocations are normal |

The correct shape is a table of its own — the **relator**, which reifies the relation:

```elixir
create table(:eo_team_memberships, primary_key: false) do
  add :person_id,              references(:eo_people), null: false
  add :team_id,                references(:eo_teams),  null: false
  add :organizational_role_id, references(:eo_organizational_roles)
  add :started_at, :utc_datetime
  add :ended_at,   :utc_datetime
end
```

`started_at` and `ended_at` are what a column would never have. It is **ADR 0004, D5**.

The deriver applies this rule on its own. Running the SRO derivation, it prints
one line per role:

```
sro.product_owner: role elevado a eo.person [outra ontologia];
                   materializa pelo relator, não por discriminador
```

And it almost was not applied. Until 2026-08-10 the guard only held when the target
was in the same ontology, and CMPO and SPO were already producing `eo.person.type +=
{project_person_stakeholder}` with green CI. None of those columns reached the
database, and the fix is recorded in [L22](../sprints/licoes-aprendidas.md).

### Why there is a separate *evidence* table

`eo_team_membership_evidence` exists because **GitHub does not provide an organizational
role**. It provides an access level on the platform — `MEMBER`,
`MAINTAINER` — which is something else: it says what the person can do in the tool, not
their role in the organization.

Without a role, the allocation cannot be created: `organizational_role_id` would be part
of a statement nobody is able to support. So what was observed is
stored as **evidence**, with the platform's access level named as
such:

```elixir
add :platform_access_level,  :string        # MEMBER, MAINTAINER — o que o GitHub dá
add :promoted_membership_id, references(:eo_team_memberships)   # nulo até haver papel
```

`promoted_membership_id` stays null while the evidence has not become an allocation. The
column exists so that the promotion, when it happens, is traceable — and so that
`count_evidence_pending_role/2` can say how many are waiting.

**The `eo_team_memberships` table exists in the database and does not yet have an Ecto schema.**
This is intentional and not an omission: the relator only materializes when there is a
declared role, and that is precisely what issues
[#99 and #100](https://github.com/The-Band-Solution/theband/issues/99) will do.

---

## 5. An event is append-only; a situation is derived

**ADR 0004, D7.** Events are recorded and never altered. Situations are not
materialized — they come out of a query over the events.

The concrete case is a tool's observation cycle. Ending and resuming
**occurred**, at an instant, by someone: they are events.

```elixir
create table(:tool_observation_events, primary_key: false) do
  add :connected_tool_id, references(:connected_tools), null: false
  add :event,       :string,        null: false     # "ended" | "resumed"
  add :occurred_at, :utc_datetime,  null: false
  add :actor_user_id, references(:users)            # anulável de propósito
  add :reason,  :text
  add :impact,  :map

  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

Three decisions inside those lines:

**No `updated_at`.** There is no path to alter an event, and the Ecto schema
does not have an `update_changeset` either. If an ending was recorded wrongly, the
correction is a new event — updating would rewrite the past. Having the column
would invite that.

**`impact` holds what was counted at that instant.** Not what a query today
would return. The two diverge: a later collection changes the numbers, and what
matters in the record is what the person saw before confirming.

**`actor_user_id` is nullable.** A resumption can come from a process, and inventing an
author would be worse than declaring there is none.

The state comes out of a function, not a column:

```elixir
def observation_ended?(%ConnectedTool{id: tool_id}) do
  Repo.one(
    from e in ObservationEvent,
      where: e.connected_tool_id == ^tool_id,
      order_by: [desc: e.occurred_at, desc: e.inserted_at],
      limit: 1, select: e.event
  ) == "ended"
end
```

**A single path.** The screen and the collection filter use the same function. Two paths
would disagree, and the screen would show as ended what the platform keeps
collecting.

### The microsecond, and why it is there

`timestamps(type: :utc_datetime_usec)` is not fussiness. With second precision,
an `ended` and a `resumed` in the same second **tied**, and the "last event"
came to depend on Postgres's execution plan. The observed effect: resuming
successfully and the screen still saying "ended".

`occurred_at` stays in seconds — it is when the thing *occurred*, and a second is enough.
`inserted_at` is the **write order**, and it is what breaks the tie. Separating the two
roles is what makes the order defined without pretending to a precision the event does not have.

It was the second occurrence of the same defect in the project — the first was in the choice
of credential — and it recurred because the first lesson was recorded about
*credentials* instead of about *deriving state from an ordered set*. It is in
[L20](../sprints/licoes-aprendidas.md).

### The debt that contradicts this section

`connected_tools.status` **materializes a situation**, against D7. It is a debt from
feature 001, it is declared, and feature 003 did not extend it — it only stopped
showing it when it contradicts the derived state.

---

## 6. Absence marks, never deletes

Three domain tables have this pair:

```elixir
add :last_observed_at,      :utc_datetime
add :no_longer_observed_at, :utc_datetime
```

**Why not `DELETE`.** GitHub emits no event when someone leaves a team.
The platform notices the absence **by comparing collections**: who was there
before and did not show up now. And "did not show up" is not the same as "does not exist" —
it can be permissions, it can be a partial failure, it can be a change of scope.

Deleting would turn an inference into an irreversible fact. Marking preserves the
answer to "who was on this team in March".

### The scope, which is the easy part to get wrong

The mark needs to be scoped to **what was actually observed in that collection**.
This version is wrong:

```elixir
# ERRADO — foi a L19
where: e.tenant_id == ^tenant_id and
       e.last_observed_at < ^collection_started_at
```

Collecting *one* organization marked the team memberships of *all* of them: the others had not
appeared in that collection, and never would. The real effect, in the development
database: the 7 team memberships of one organization and 55 of the 70 of another marked
at the same instant, `00:44:30`, while the running collection was of a third one.

The correct form restricts to the observed scope:

```elixir
equipes_da_org =
  from t in Team,
    where: t.tenant_id == ^tenant_id and t.organization_id == ^organization_id,
    select: t.id

from e in TeamMembershipEvidence,
  where: e.tenant_id == ^tenant_id and
         e.team_id in subquery(equipes_da_org) and
         e.last_observed_at < ^collection_started_at and
         is_nil(e.no_longer_observed_at)
```

**The general rule, for whoever writes the next collection**: the absence filter
must have the same slice as the collection. If the collection looked at one organization, the filter
is by organization. If it looks at a repository, it will be by repository — and that is why
feature 004 brings this as a requirement and not as a reminder.

### The order inside the ending is also a rule

In `end_observation/3`, the marking is: **teams, then team memberships, then
people**. People last because the decision about the person depends on the
team memberships already marked — they only lose validity if *none* of their team memberships is left.
Reversing it would mark someone who still had a team membership in another organization.

---

## 7. Credential encrypted by the type, not by the code

```elixir
defmodule TheBand.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: TheBand.Vault
end
```

And in the schema:

```elixir
@derive {Inspect, except: [:secret]}

schema "tool_credentials" do
  field :secret, TheBand.Encrypted.Binary, redact: true
  field :last_four, :string
  ...
end
```

**Why in the Ecto type and not in the changeset.** A field declared with this type has
no way of being written in plain text because whoever writes the command forgot. If
encryption lived in the changeset, every new write path would need to remember —
and one of them will not remember.

Three layers, each one covering a leak from a different place:

| Mechanism | What it prevents |
|---|---|
| `TheBand.Encrypted.Binary` | writing in plain text to the database |
| `@derive {Inspect, except: [:secret]}` | leaking in a log, in `IO.inspect`, in a stacktrace |
| `last_four` | showing something useful on screen without showing the secret |

**How it is verified**: by reading the table directly. The test does not assert that encryption
works — it looks for the plain text in the stored value and requires not finding it. For
any security invariant, the test is the violation.

The master key comes from the environment (`THE_BAND_MASTER_KEY`) and the application **refuses
to boot without it**. A consequence worth knowing before tripping over it: a credential
encrypted with one key cannot be decrypted with another — changing the key requires
`mix the_band.rotate_key`, and a throwaway key does not open real data.

---

## 8. Explicit `tenant_id` on every domain table

There is no schema per tenant, no implicit `WHERE`, no middleware that injects the
filter. **The column is there and every query uses it.**

```elixir
add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
```

`on_delete: :restrict` on purpose: deleting a tenant with data inside is refused
by the database.

**Why explicit.** It is principle V of the constitution. An implicit filter
works until the first query that bypasses it — a `join`, a `subquery`, a
new function — and the resulting leak is silent: the data shows up, nobody
notices it belongs to another tenant.

With the explicit column, the violation is **textual**, and that is why it gets caught in review: a
query on a domain table without `tenant_id` in the `where` is wrong, and you can
see it by reading.

**How the error is presented to the user**: a resource from another tenant returns **"not
found"**, never "no permission". Saying "no permission" already reveals that the
resource exists.

---

## 9. Private schemas, and why the boundary is the root module

```
lib/the_band/ontology/seon/eo.ex          ← a fronteira
lib/the_band/ontology/seon/eo/
    commands.ex                            ← escritas
    queries.ex                             ← leituras
    constraints.ex                         ← verificações
    schemas/
        organization.ex                    ← privados
        person.ex
        team.ex
        organizational_role.ex
        team_membership_evidence.ex
```

The root module contains **only `defdelegate`** (ADR 0003):

```elixir
defdelegate upsert_person_from_source(tenant, attrs), to: Commands
```

**The rule**: no module outside `eo/` reaches `EO.Schemas.*`, and no module
outside `eo/` calls `Repo` on the `eo_*` tables.

### Why the root module and not the schema

The instinct is to make the schema the public unit — that is what it looks like. But the
schema is the **shape of the table**, and the table is derived: it changes when the ontology
changes. If other modules depended on the schema, every derivation change
would break consumers across the whole application, and the pressure not to touch the
derivation would beat the semantics.

A second reason, more immediate: **a function that returns `Ecto.Query` leaks the
boundary**. Whoever receives the query can compose on it and, by composing, bypass the
tenant filter. That is why no public function returns a query — they return data.

### What the API deliberately does not expose

Documented in the module itself, and worth reading before adding a function:

| Absent | Why |
|---|---|
| `create_person/2`, `create_team/2` | there is no manual registration in this feature, and exposing it would invite creating records without provenance |
| `delete_*` | absence marks `no_longer_observed_at`; the platform exists to preserve traceability |
| `create_team_membership/2` | requires an organizational role, which no current source provides |
| any function that returns `Ecto.Query` | leaks the internal schema and allows bypassing the tenant filter |

**An absence documented with a reason is a decision. A silent absence is forgetfulness.**
The two look the same in the code, and that is why the reason is written down.

---

## 10. Subtype discriminator, and the constraint that comes with it

`eo_teams` has a column that looks like a banal enum:

```elixir
add :type, :string, null: false, default: "organizational_team"
```

It is the materialization of `subkind` — a rigid subtype does not get its own table,
it gets a discriminator value in the kind's table. `eo.organizational_team` and
`eo.project_team` are the two possible rows.

And the constraint that came with it shows why the discriminator is not decorative:

```sql
check: organization_id IS NOT NULL OR type <> 'organizational_team'
```

An **organizational** team needs an organization. A **project** team does not — it
can cross organizations, and making the column mandatory for every subtype would assert the
opposite. That is what sets this apart from a `NOT NULL`: the requirement belongs to the subtype, and
the discriminator is what says which subtype the row is.

**An operational detail that cost a migration**: creating column and constraint together
does not work on a populated database. The teams already collected were all
`organizational_team` with no organization, and Postgres refused with
`ERROR 23514 (check_violation)`. The separation became an advantage — the constraint's
migration became **the retrofit's verification**: if any organizational team
is left without an organization, it refuses to apply.

---

## 11. Collection: what each table answers

```
connected_tools ──┬── syncs ──┬── sync_checkpoints   (onde parei, por entidade)
                  │           └── raw_payloads       (o que a origem respondeu)
                  └── tool_observation_events        (encerrei / retomei)
```

| Table | Question it answers |
|---|---|
| `syncs` | how much this run collected, created, updated, and why it skipped what it skipped |
| `sync_checkpoints` | where I stopped in each entity type, to resume without re-collecting |
| `raw_payloads` | exactly what the source answered, to reprocess when the rule changes |

**`raw_payloads` is what makes the error recoverable.** The classification rules
will be wrong on the first attempt. If fixing them required a new full collection
from the source, nobody would fix them — and the platform would pile up misclassified data
nobody dares to reprocess.

It also stores `mapping_id` and `mapping_version`: which mapping processed
that payload and in which version. A payload stored before the field existed appears
in reprocessing as an ignored record with a named reason, and not as a silent
failure.

**`syncs` has a partial unique index on `connected_tool_id`** for the runs
in progress — two simultaneous collections of the same tool would produce counts
neither of them would explain.

---

## 12. How to add something to the model

The order matters, and it is the reverse of the instinct.

1. **Declare it in the ontology**, in `priv/knowledge_base/ontology/<rede>/<ont>/modules/`.
   A concept needs `ufo_category` **and** `ontouml_stereotype` — without both, the
   deriver refuses to derive instead of guessing.
2. **Run the deriver** and read the output:
   ```bash
   python3 scripts/derive_information_model.py --ontology eo
   ```
   It says the table, the columns, the discriminators and what was absorbed
   where. If the column you expected did not appear, the answer is that it should not
   exist — not that the deriver is incomplete.
3. **Write the migration from that output**, and explain in the `@moduledoc` why
   the shape is what it is. The migrations in this project are long on purpose: the reason is
   the part nobody recovers later.
4. **Schemas in `schemas/`**, private. The public API is `defdelegate` in the root
   module.
5. **Nine quality gates**, including `mix knowledge.validate`, the Python validator
   and the reproducibility of the derivation.

### What makes the deriver refuse

```
não é possível derivar sro: 43 conceito(s) sem ontouml_stereotype
```

This is correct behavior, not a bug. `ufo_category` is the top-level category and
**does not express sortality or rigidity** — the two meta-properties that decide
whether the concept becomes a table, a discriminator or a relator. Without them, guessing produces
a plausible and wrong schema, which is worse than an absent schema.

How each stereotype materializes:

| Stereotype | Becomes |
|---|---|
| `kind` | table |
| `subkind` | `type` discriminator value in the kind's table |
| `phase` | `status` discriminator value in the kind's table |
| `role` | **nothing** — materializes through the relator |
| `relator` | table |
| `category`, `role_mixin`, `mixin` | flattened |

---

## What this document does not cover

Declared instead of omitted.

| Not covered | Where to look |
|---|---|
| The 11 ontologies without a table | only 4 have `ontouml_stereotype` — EO, SPO, CMPO and SRO. RSRO and SYS_SWO have 16 concepts without a stereotype |
| SRO tables | the derivation came into existence in sprint 003; **no SRO migration has been written yet** |
| Oban | table created by the library; I did not inspect it |
| Complete indexes | I listed the unique ones that sustain the Application Reference; I did not audit them all |
| Columns of `eo_organizational_units` | table renamed from `eo_sectors`; I did not reread the original migration |
| Derivation rules in detail | `scripts/derive_information_model.py` and [ADR 0004](../adr/README.md) |

## Maintaining this document

Rewrite it when: a new migration changes the shape of a domain table; the
deriver starts producing another shape; a new ontology gains stereotypes and
becomes a table.

The criterion is: **if someone who read this document and then the database found a
divergence, it is out of date.** The counts cited are from 2026-08-11.
