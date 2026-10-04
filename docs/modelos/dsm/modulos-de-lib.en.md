<!-- DERIVED from the automatic sweep of lib/the_band/**/*.ex and lib/the_band.ex (184 files):
     every `defmodule` mapped to a file, every `TheBand.*` reference resolved to the longest known
     module and attributed to the context of the file that defines it.
     `@moduledoc`, `@doc` and comments WERE EXCLUDED from the count — 7 edges existed only in
     documentation text and are not dependencies (list at the end).
     Cycles by Tarjan; sequencing by Eades-Lin-Smyth (feedback arc set, heuristic) — on 2026-09-18.
     Checked against the code on this date. Regenerate when the source changes.
     The method is described step by step in the last section, for whoever needs to redo it. -->

# DSM — the modules of `lib/the_band/`

**What must come before what, inside the code.** The DSMs in `dsm/` are usually between user stories;
this one is between **code contexts**, and answers another question: *if I touch this, what else will I
have to understand?*

## How to read it

Rows and columns are the same 37 contexts, **in the same order**. A marked cell `(i, j)` means
**i depends on j** — row `i` *uses* column `j`.

The mark says the **nature** of the dependency, because they come undone in different ways:

| Mark | Nature | How it comes undone |
|---|---|---|
| `F` | **boundary call** — `i` calls a public function of `j` | by extracting the function, or inverting who calls |
| `S` | **schema alias** — `i` builds a query over a schema that belongs to `j` | by exposing the query in `j`, instead of the schema |
| `FS` | both in the same edge | — |
| `B` | **knowledge base read** — `i` reads a rule from the YAML | it does not come undone, nor should it: it is principle I |

The order of the rows was **reordered** to push the marks **below the diagonal**. What is left **above**
is feedback — and that is the finding.

## The measurement

| | How much |
|---|---:|
| contexts | **37** |
| `.ex` files covered | **184** |
| edges between contexts | **136** |
| references that support them | **303** |
| `F` marks (boundary call) | 113 |
| `B` marks (knowledge base) | 12 |
| `S` marks (schema alias) | 6 |
| `FS` marks (both) | 5 |
| edges **above** the diagonal after reordering | **16** of 136 (12%) |
| cycles (strongly connected components with more than 1 node) | **2** |

**Declared coverage: 184 of 184 files.** None was left out. What was left out were two sets, for being
something else:

- **`lib/the_band_web/`** — the screen layer. The DSM between LiveViews and contexts is another
  document, and does not exist yet;
- **`lib/mix/`** — the Mix tasks, which are tooling and not domain.

## The index of the contexts

`uses` is the number of distinct contexts the context calls; `is used by`, the inverse.

| # | context | files | uses | is used by |
|---|---|--:|--:|--:|
| M01 | `forecast` | 1 | 0 | 1 |
| M02 | `ontology/schema_check` | 1 | 0 | 1 |
| M03 | `periodos` | 1 | 0 | 2 |
| M04 | `provenance` | 1 | 0 | 1 |
| M05 | `repo` | 1 | 0 | 21 |
| M06 | `segredo` | 1 | 0 | 2 |
| M07 | `the_band.ex (root)` | 1 | 0 | 5 |
| M08 | `vault` | 1 | 0 | 3 |
| M09 | `encrypted` | 1 | 1 | 2 |
| M10 | `integrations` | 5 | 2 | 5 |
| M11 | `ontology/yaml_loader` | 1 | 1 | 2 |
| M12 | `ontology/yaml_validator` | 1 | 2 | 1 |
| M13 | `ontology/knowledge_base` | 1 | 2 | 12 |
| M14 | `tenants` | 10 | 4 | 22 |
| M15 | `work_items` | 14 | 7 | 5 |
| M16 | `projects` | 8 | 5 | 2 |
| M17 | `ontology/sro` | 5 | 4 | 2 |
| M18 | `ontology/cmpo` | 6 | 3 | 3 |
| M19 | `sources` | 4 | 9 | 3 |
| M20 | `raw_data` | 1 | 4 | 4 |
| M21 | `ontology/eo` | 20 | 5 | 10 |
| M22 | `ontology/spo` | 21 | 6 | 6 |
| M23 | `semantic_integration` | 2 | 5 | 2 |
| M24 | `jobs` | 5 | 8 | 2 |
| M25 | `mapping` | 10 | 9 | 3 |
| M26 | `ai` | 2 | 4 | 1 |
| M27 | `profiles` | 15 | 7 | 2 |
| M28 | `verification` | 5 | 4 | 1 |
| M29 | `quality` | 4 | 3 | 1 |
| M30 | `configuration` | 3 | 2 | 1 |
| M31 | `communication` | 3 | 2 | 1 |
| M32 | `changes` | 7 | 2 | 1 |
| M33 | `ingestion` | 15 | 20 | 6 |
| M34 | `teams` | 2 | 7 | 0 |
| M35 | `release` | 1 | 1 | 0 |
| M36 | `ontology/smpo` | 3 | 2 | 0 |
| M37 | `application` | 1 | 5 | 0 |

## The matrix

The table is wide on purpose: it is the whole DSM, and reducing it would hide exactly what it exists to
show. Read it by row: *what **this** row needs to understand*.


| | M01 | M02 | M03 | M04 | M05 | M06 | M07 | M08 | M09 | M10 | M11 | M12 | M13 | M14 | M15 | M16 | M17 | M18 | M19 | M20 | M21 | M22 | M23 | M24 | M25 | M26 | M27 | M28 | M29 | M30 | M31 | M32 | M33 | M34 | M35 | M36 | M37 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **M01** | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M02** |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M03** |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M04** |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M05** |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M06** |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M07** |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M08** |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M09** |  |  |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M10** |  |  |  |  |  | F |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M11** |  |  |  |  |  |  |  |  |  |  | · |  | B |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M12** |  | F |  |  |  |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M13** |  |  |  |  |  |  |  |  |  |  | F | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M14** |  |  |  |  | F |  |  |  |  |  |  |  | B | · |  |  |  |  |  |  | FS | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M15** |  |  |  |  | F |  |  |  |  |  |  |  | B | F | · |  |  |  |  |  | FS | S |  |  | FS |  | F |  |  |  |  |  |  |  |  |  |  |
| **M16** |  |  |  |  | F |  |  |  |  |  |  |  | B | F |  | · | F |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M17** |  |  |  |  | F |  |  |  |  |  |  |  |  | F | S | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M18** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M19** |  |  |  |  | F | F |  | F | F | F |  |  |  | F |  |  |  | S | · |  | F |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M20** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M21** |  |  |  | F | F |  |  |  |  |  |  |  | B | F |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M22** |  |  | F |  | F |  |  |  |  |  |  |  | B | F | S |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M23** |  |  |  |  |  |  | F |  |  |  |  |  | B | F |  |  |  |  |  | F | F |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M24** |  |  |  |  |  |  |  |  |  | F |  |  |  | F |  |  |  |  | F | F | F |  | F | · | F |  |  |  |  |  |  |  | F |  |  |  |  |
| **M25** |  |  |  |  | F |  | F |  |  |  |  |  | B | F | FS |  |  | F |  |  | F | F |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |
| **M26** |  |  |  |  | F |  |  |  | F | F |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |
| **M27** |  |  |  |  | F |  | F |  |  | F |  |  | B | F |  |  |  |  |  |  | FS |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |
| **M28** |  |  | F |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  | F |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |
| **M29** |  |  |  |  | F |  |  |  |  |  |  |  | B | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |
| **M30** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |
| **M31** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |
| **M32** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |
| **M33** |  |  |  |  | F |  | F |  |  | F |  |  |  | F | F | F | F | F | F | F | F | F | F | F | F |  |  | F | F | F | F | F | · |  |  |  |  |
| **M34** | F |  |  |  | F |  |  |  |  |  |  |  | B | F | S |  |  |  |  |  | S |  |  |  |  |  | F |  |  |  |  |  |  | · |  |  |  |
| **M35** |  |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |
| **M36** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |

`F` = boundary call · `S` = schema alias · `FS` = both · `B` = knowledge base
· `·` = the diagonal.

## The four blocks

The ordering separates the code into four bands, and reading them is the mental map of the project:

| Block | Contexts | What it is |
|---|---|---|
| **A — foundation** (M01–M08) | `forecast`, `ontology/schema_check`, `periodos`, `provenance`, `repo`, `segredo`, `the_band.ex`, `vault` | **depend on nothing**. They are pure calculation, vault, opaque type and database access. |
| **B — vocabulary** (M09–M13) | `encrypted`, `integrations`, `ontology/yaml_loader`, `ontology/yaml_validator`, `ontology/knowledge_base` | encryption, the source's HTTP client and the reading of the network of ontologies. |
| **C — the core** (M14–M33) | `tenants`, `work_items`, `projects`, the four ontologies, `sources`, `raw_data`, `jobs`, `mapping`, `ai`, `profiles`, `verification`, `quality`, `configuration`, `communication`, `changes`, `ingestion` | **20 contexts that use each other.** It is where the big cycle lives — which also includes `integrations`, from block B. |
| **D — the top** (M34–M37) | `teams`, `release`, `ontology/smpo`, `application` | **nobody uses them.** They are entry points: the team measure, the release, the iteration reading and the supervision tree. |

**The eight in the foundation have `uses = 0`** — none of them calls any context. **The four at the top
have `is used by = 0`.** Between them, everything.

The three most used contexts, by number of contexts that call them:

| Context | Is used by | Why |
|---|---:|---|
| `tenants` | **22** | every domain function receives `%Tenant{}` — it is principle V with a shape in the code |
| `repo` | **21** | it is the `Ecto.Repo`; whoever writes, writes through it |
| `ontology/knowledge_base` | **12** | the YAML rules, read instead of written as constants |

That `tenants` surpasses `repo` is the most revealing fact of the matrix: **there are contexts that talk
about the tenant without touching the database**, and not the other way round. Scope per organization is
not a `where` clause added at the end; it is the argument that crosses the signatures.

## The cycles — and there are two

**The direct answer: yes, there is a cycle.** Two strongly connected components with more than one node,
found by Tarjan over the graph of 37 nodes and 136 edges.

### Cycle 1 — reading the ontology (3 contexts)

```text
ontology/knowledge_base  →  ontology/yaml_loader  →  ontology/knowledge_base
ontology/knowledge_base  →  ontology/yaml_validator  →  ontology/yaml_loader  →  ...
```

| Edge | Nature | Evidence |
|---|---|---|
| `knowledge_base → yaml_loader` | `F` | `lib/the_band/ontology/knowledge_base.ex:18` |
| `knowledge_base → yaml_validator` | `F` | `lib/the_band/ontology/knowledge_base.ex:19` |
| `yaml_validator → yaml_loader` | `F` | `lib/the_band/ontology/yaml_validator.ex:16` |
| **`yaml_loader → knowledge_base`** | **`B`** | `lib/the_band/ontology/yaml_loader.ex:52` |

**The edge that closes the cycle is the last one**, and it is a single one. It is small, contained in
three files on the same subject, and the cut is obvious if it ever bothers: what `yaml_loader` needs from
`knowledge_base` moves to a third module, or is passed as an argument.

**Recommendation: do not touch it.** Three modules that read the same YAML and know each other is not
coupling that costs; breaking it would add a module to solve a problem nobody has.

### Cycle 2 — the core of 21 contexts

This is the big one, and it is the finding of the document.

```text
ai, changes, communication, configuration, ingestion, integrations, jobs, mapping,
ontology/cmpo, ontology/eo, ontology/spo, ontology/sro, profiles, projects, quality,
raw_data, semantic_integration, sources, tenants, verification, work_items
```

**21 contexts in a single strongly connected component** — from any of them you reach any other by
following the arrows. In practice: *any of them can, in principle, be affected by any other.*

They are the 20 of block C **plus `integrations`** (M10), which the ordering pushed into block B for
having few incoming edges, but which belongs to the cycle through the edge
`integrations → ingestion` (`client.ex:11`).

But **21 contexts do not form a tangle with 21 ends**. The sequencing shows that **16 edges** are enough
to close it, and of those, a few carry almost all the weight.

## The 16 feedback edges

They are the marks **above** the diagonal. Removing (or inverting) them would leave the graph acyclic.

| # | Edge | Refs | Nature | Evidence |
|---|---|---:|---|---|
| 1 | `jobs → ingestion` | **12** | `F` | `lib/the_band/jobs/sync_github_eo.ex:31-33` |
| 2 | `tenants → ontology/eo` | 3 | `FS` | `lib/the_band/tenants/access.ex:51-52`, `auth.ex:29` |
| 3 | `work_items → mapping` | 2 | `FS` | `lib/the_band/work_items/rotulos.ex:39`, `routing.ex:56` |
| 4 | `work_items → ontology/eo` | 2 | `FS` | `lib/the_band/work_items/team_work.ex:28-29` |
| 5 | `integrations → ingestion` | 1 | `F` | `lib/the_band/integrations/github/client.ex:11` |
| 6 | `jobs → mapping` | 1 | `F` | `lib/the_band/jobs/recompute_promotions.ex:40` |
| 7 | `ontology/cmpo → ingestion` | 1 | `F` | `lib/the_band/ontology/seon/cmpo/commands.ex:8` |
| 8 | `ontology/yaml_loader → knowledge_base` | 1 | `B` | `lib/the_band/ontology/yaml_loader.ex:52` |
| 9 | `projects → ontology/spo` | 1 | `F` | `lib/the_band/projects/commands.ex:14` |
| 10 | `projects → ontology/sro` | 1 | `F` | `lib/the_band/projects/commands.ex:13` |
| 11 | `raw_data → ingestion` | 1 | `F` | `lib/the_band/raw_data.ex:16` |
| 12 | `sources → ingestion` | 1 | `F` | `lib/the_band/sources.ex:13` |
| 13 | `sources → ontology/eo` | 1 | `F` | `lib/the_band/sources.ex:16` |
| 14 | `tenants → ontology/spo` | 1 | `F` | `lib/the_band/tenants/access.ex:53` |
| 15 | `work_items → ontology/spo` | 1 | `S` | `lib/the_band/work_items/person_work.ex:25` |
| 16 | `work_items → profiles` | 1 | `F` | `lib/the_band/work_items/team_work.ex:30` |

### The twelve pairs that look at each other

Twelve edges form a **cycle of length 2** — two contexts that use each other. They are the easiest
coupling to see and the most expensive to ignore:

| Pair | Refs (there / back) | Nature |
|---|---|---|
| `ingestion` ↔ `integrations` | 8 / 1 | `F` / `F` |
| `ingestion` ↔ `jobs` | 1 / 12 | `F` / `F` |
| `ingestion` ↔ `sources` | 3 / 1 | `F` / `F` |
| `ingestion` ↔ `ontology/cmpo` | 1 / 1 | `F` / `F` |
| `ingestion` ↔ `raw_data` | 1 / 1 | `F` / `F` |
| `mapping` ↔ `work_items` | 6 / 2 | `FS` / `FS` |
| `ontology/eo` ↔ `tenants` | 10 / 3 | `F` / `FS` |
| `ontology/spo` ↔ `tenants` | 8 / 1 | `F` / `F` |
| `ontology/spo` ↔ `work_items` | 1 / 1 | `S` / `S` |
| `ontology/sro` ↔ `projects` | 2 / 1 | `F` / `F` |
| `jobs` ↔ `mapping` | 1 / 1 | `F` / `F` |
| `knowledge_base` ↔ `yaml_loader` | 1 / 1 | `F` / `B` |

## What cuts the big cycle — a proposal, and only that

**The architecture decision is not mine.** What follows is a reading of the matrix, for whoever decides.

### Cut 1 — `jobs` ↔ `ingestion` and `integrations` ↔ `ingestion`

It is the most loaded edge of the matrix (12 references) and the one most people run into.

- `jobs → ingestion` **12x**: the job calls collection. Natural, and probably right.
- `ingestion → jobs` **1x**: `lib/the_band/ingestion.ex:17` cites `TheBand.Jobs.SyncGitHubEO` —
  collection **enqueues its own job**.
- `integrations → ingestion` **1x**: `client.ex:11` uses `TheBand.Ingestion.Cota` — the HTTP client
  queries the quota, which lives in collection.

**Proposal:** the two back edges have **one reference each**, and both point to things that are not
"collection": enqueueing and counting quota. Moving `Ingestion.Cota` to its own context (or to
`integrations`, which is who consumes it) and taking the enqueueing out of `ingestion.ex` undoes two
feedbacks with little surgery.

### Cut 2 — `tenants` ↔ `ontology/eo` and `tenants` ↔ `ontology/spo`

`ontology/eo → tenants` **10x** is expected: every EO function receives `%Tenant{}`.

The way back, `tenants → ontology/eo` **3x**, is the real coupling, and it is in two places:
`access.ex:51-52` (the visibility rule needs the organizational structure) and
`auth.ex:29` (alias of the `Person` schema, for the link).

**Proposal:** `auth.ex:29` is `S` — a schema alias crossing a boundary. Replacing it with a query exposed
in `EO` undoes **a third** of this edge without discussing architecture. The other two are `F` and
legitimate: deciding visibility **requires** knowing the structure, and that is the dependency the
product has.

### Cut 3 — the six schema aliases crossing contexts

They are the cheapest coupling to undo, because they do not call for a design decision: they call for a
query function in the schema's owner.

| Who builds the query | Over a schema of | Where |
|---|---|---|
| `ontology/spo` | `work_items` | `projects.ex:34` — `WorkItems.Schemas.CollectedIssue` |
| `ontology/sro` | `work_items` | `queries.ex:12` — `WorkItems.Schemas.CollectedIssue` |
| `sources` | `ontology/cmpo` | `sources.ex:15` — `CMPO.Schemas.ObservedRepository` |
| `teams` | `ontology/eo` | `problems_now.ex:54` — `EO.Schemas.TeamMembership` |
| `teams` | `work_items` | `problems_now.ex:58-59`, `flow_per_person.ex:56` |
| `work_items` | `ontology/spo` | `person_work.ex:25` — `SPO.Schemas.PerformedProjectActivity` |

**Proposal:** the two from `teams` **do not close a cycle** (nobody uses `teams`), and are the safest to
leave as they are. The remaining four take part in feedback, and each becomes a function at the owner's
boundary.

> **Caution, and it is the most important point of this section.** Replacing `S` with `F` **is not
> automatically better**: a query exposed at the boundary that returns a large list can be more expensive
> than the `join` that exists today. The matrix says *where* the coupling is, not that it is a defect.
> Whoever decides is whoever knows the query.

## What the matrix does NOT say

- **Nothing about quality.** An `F` edge with 12 references can be the most correct thing in the
  project. The DSM measures **coupling**, not correctness.
- **Nothing about the screen.** `lib/the_band_web/` was left out, and that is where a good part of the
  boundary calls come from. A screen × context DSM is work that **does not exist yet**.
- **Nothing about dynamic calls.** The sweep is textual: `apply/3`, module names built at run time and
  modules passed as configuration **do not appear**. If they exist, there are extra edges this matrix
  does not have.
- **Nothing about execution frequency.** A reference written once and executed on every collection
  weighs the same as one written twelve times and never executed.

## The 7 edges that existed only in documentation

A record of the method, because the result depends on it. The first sweep returned **143** edges;
excluding `@moduledoc`, `@doc` and comments, **136** were left. The seven differences were module names
cited in **explanatory text**, not dependencies:

| Apparent edge | Where it was |
|---|---|
| `vault → application` | `lib/the_band/vault.ex:30` (moduledoc) |
| `vault → encrypted` | `lib/the_band/vault.ex:6` (moduledoc) |
| `segredo → sources` | `lib/the_band/segredo.ex:49` (moduledoc) |
| `segredo → vault` | `lib/the_band/segredo.ex:38` (moduledoc) |
| `tenants → release` | `lib/the_band/tenants/bootstrap.ex:20` (moduledoc) |
| `ontology/eo → periodos` | `lib/the_band/ontology/seon/eo/queries.ex:343` (comment) |
| `ontology/sro → ontology/smpo` | `lib/the_band/ontology/continuum/sro.ex:23` (moduledoc) |

**Without this exclusion, `vault` and `segredo` would appear in cycles that do not exist.** It is the same
principle as the other pages in this folder: the number has to come from a count whose method is written
down.

## How to regenerate

The method, in four steps, for whoever needs to redo it after a big change:

1. map every `defmodule` of `lib/the_band/` to the file that defines it;
2. sweep each file for `TheBand.*` references, **skipping** `"""` blocks and `#` lines, and resolve each
   one to the known module with the longest name;
3. attribute source and target to the **context** (first directory under `lib/the_band/`, with
   `ontology/` opened per ontology), discarding edges from a context to itself;
4. run Tarjan for the cycles and Eades-Lin-Smyth for the order that minimizes the marks above the
   diagonal.

The classification of the mark comes from the **target**: `TheBand.Ontology.KnowledgeBase` → `B`; a
module in `schemas/` or with `.Schemas.` in the name → `S`; anything else → `F`.
