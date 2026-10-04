# Models

<!-- DERIVED from the agent structure on 2026-09-07; index recounted on 2026-09-18
     (26 documents, 42 ```mermaid``` blocks, by a sweep of docs/modelos/**/*.md).
     Index maintained by hand; each document below is derived from the code and carries its own
     provenance. -->

The models the implementation does not carry by itself: what exists, which situations it goes
through, what the database stores, and what depends on what in the backlog.

**The rule**: a model is **derived**, never remembered. Every document here comes from a source in
the repository — schema, migration, knowledge base YAML, spec, issue — and opens by saying where it
came from, with `file:line` and the date it was checked. The author is the
[Documentation — Models](../../.claude/agents/documentacao-modelos.md) role.

| Folder | What it answers | Form |
|---|---|---|
| `classes/` | which entities exist, what they carry, how they connect | `classDiagram` (Mermaid), one per subsystem |
| `estados/` | which situations a record goes through, and what triggers each transition | `stateDiagram-v2`, with trigger, guard and the test that proves it |
| `banco/` | which tables, columns, keys and **partial indexes** (which carry an invariant) | `erDiagram`, derived from the migrations |
| `dsm/` | what must come before what, among epics, user stories and features | Markdown matrix, with named blocks and cycles |

## What exists today

**26 documents, 42 Mermaid diagrams**, checked against the code on **2026-09-18** — and all 42
**rendered** with `@mermaid-js/mermaid-cli@11.17.0` on that date, so that no published block is code
that does not turn into a drawing. The *diagrams* column is the count of
```` ```mermaid ```` blocks in the file — zero means the document is a census, table or matrix, not
that a drawing is missing.

**Addition of 2026-10-02 (spec 070)**: three new documents and five new diagrams —
`banco/operador-da-plataforma.md`, `estados/organizacao-suspensa.md` and
`estados/credencial-do-operador.md` —, rendered with the same `mermaid-cli@11.17.0` on that date.
With them, **29 documents and 47 diagrams**; the full recount of the index was not redone.

### Where to start

If you just arrived at the project, read in this order. Each of these four is a **census**, and
exists to tell the size of what you are looking at before showing any drawing:

| Start with | Answers |
|---|---|
| [`arquitetura/visao-geral.md`](arquitetura/visao-geral.md) | how the system is assembled and where data comes in — in C4 |
| [`banco/mapa-das-tabelas.md`](banco/mapa-das-tabelas.md) | how many tables exist, and which ERD covers each one |
| [`classes/mapa-dos-schemas.md`](classes/mapa-dos-schemas.md) | how many schemas exist — and why `Repo.preload/2` almost never works here |
| [`estados/mapa-dos-ciclos-de-vida.md`](estados/mapa-dos-ciclos-de-vida.md) | where state lives, since only 3 of the 66 tables have a `status` column |

### Architecture

| Document | Diag. | Derived from |
|---|--:|---|
| [`arquitetura/visao-geral.md`](arquitetura/visao-geral.md) | 9 | `application.ex`, `router.ex`, `compose.yaml`, `hooks.ex`, `access.ex`, `ingestion/*`, `config/config.exs` |

The structure is **C4** — context, containers and two component views (collection and access). What
is **dynamic** — the collection sequence, the knowledge base boot, the tenant chain, the CD
pipeline — remains a `flowchart`, and the document says why. **C4 support in Mermaid is
experimental**: an old viewer shows the block as text, and the diagrams were written to stay
readable that way.

### Classes — what exists, and what each thing carries

| Document | Diag. | Covers |
|---|--:|---|
| [`classes/mapa-dos-schemas.md`](classes/mapa-dos-schemas.md) | 0 | **census**: 65 schemas, 3 Ecto associations, 214 `:binary_id` fields |
| [`classes/eo-estrutura-organizacional.md`](classes/eo-estrutura-organizacional.md) | 1 | organization, person, team, role, team membership |
| [`classes/tenants-e-acesso.md`](classes/tenants-e-acesso.md) | 1 | tenant, account, grant, deactivation |
| [`classes/ingestao-e-observacao.md`](classes/ingestao-e-observacao.md) | 1 | tool, credential, collection, repository |
| [`classes/trabalho-e-mudanca.md`](classes/trabalho-e-mudanca.md) | 2 | issue, promotion, PR, commit, check |
| [`classes/projetos-e-processo.md`](classes/projetos-e-processo.md) | 2 | project, board, item, sprint, activity |
| [`classes/perfis-e-modelo.md`](classes/perfis-e-modelo.md) | 1 | model credential, run, profile |
| [`classes/declaracoes-da-organizacao.md`](classes/declaracoes-da-organizacao.md) | 1 | **new** — the 9 declaration schemas, including the 3 from feature 066 |

### Database — tables, keys and partial indexes

| Document | Diag. | Covers |
|---|--:|---|
| [`banco/mapa-das-tabelas.md`](banco/mapa-das-tabelas.md) | 1 | **census** of the 66 domain tables + the high-level map of the groups |
| [`banco/eo-e-acesso.md`](banco/eo-e-acesso.md) | 1 | 14 tables |
| [`banco/ingestao-e-observacao.md`](banco/ingestao-e-observacao.md) | 1 | 10 tables |
| [`banco/trabalho-e-mudanca.md`](banco/trabalho-e-mudanca.md) | 2 | 17 tables |
| [`banco/projetos-e-processo.md`](banco/projetos-e-processo.md) | 2 | 17 tables |
| [`banco/perfis-e-modelo.md`](banco/perfis-e-modelo.md) | 1 | 5 tables |
| [`banco/declaracoes-da-organizacao.md`](banco/declaracoes-da-organizacao.md) | 1 | **new** — 9 declaration tables, 12 partial indexes, declared FK × raw column |
| [`banco/operador-da-plataforma.md`](banco/operador-da-plataforma.md) | 1 | **new (070)** — 5 operator and suspension tables, the new FK on `api_access_tokens`, 17 `CHECK`s and the first deferred trigger |

### States — which situations a record goes through

| Document | Diag. | Covers |
|---|--:|---|
| [`estados/mapa-dos-ciclos-de-vida.md`](estados/mapa-dos-ciclos-de-vida.md) | 0 | **census**: 51 tables with a lifecycle, 3 with `status`, and the `expires_at` column that **does not exist** |
| [`estados/declaracao-revogavel.md`](estados/declaracao-revogavel.md) | 2 | **new** — the family of 9 tables: in force, revoked, redeclared |
| [`estados/observacao.md`](estados/observacao.md) | 2 | **new** — `no_longer_observed_at` in 23 tables, and `excluded_at`, which is something else |
| [`estados/atividade-executada.md`](estados/atividade-executada.md) | 1 | **new** — why the occurrence is never updated; promotion and complementation |
| [`estados/conta.md`](estados/conta.md) | 2 | **new** — deactivating × revoking the link, and why confusing them was a security finding |
| [`estados/coleta.md`](estados/coleta.md) | 4 | **new** — the run, the tool (state by event) and the credential |
| [`estados/projeto-declarado.md`](estados/projeto-declarado.md) | 2 | **new** — the project and its four links; the only final state that does not come back |
| [`estados/vinculo-de-equipe.md`](estados/vinculo-de-equipe.md) | 2 | four fields, five situations |
| [`estados/organizacao-suspensa.md`](estados/organizacao-suspensa.md) | 2 | **new (070)** — `active`/`suspended` tied to the episode by the deferred trigger; the open and closed episode |
| [`estados/credencial-do-operador.md`](estados/credencial-do-operador.md) | 2 | **new (070)** — the three registration steps, sign-in, the lockout at 10, reset and revocation; and the session |

### DSM — what must come before what

| Document | Diag. | Covers |
|---|--:|---|
| [`dsm/modulos-de-lib.md`](dsm/modulos-de-lib.md) | 0 | **new** — 37 contexts of `lib/the_band/`, 136 edges, **2 named cycles** |
| [`dsm/060-tela-da-equipe.md`](dsm/060-tela-da-equipe.md) | 0 | US1 to US9 of feature 060 |

> **The index is maintained by hand, and that is why it lies first.** On 2026-09-12 it still said
> *"`banco/` is still empty"* (*"`banco/` ainda está vazia"*) while the folder had six documents and
> seven ERDs. The rule left from this: whoever adds a document **updates this table in the same
> commit** — an index that contradicts the directory is worse than no index, because whoever reads
> it will not check.

## Three things that surprise newcomers

They are measured in the censuses, and they change how everything else is read:

1. **State is almost never a column.** Three of the 66 tables have `status`; the rest encode the
   situation in pairs of nullable dates, to preserve *since when*.
   → [`estados/mapa-dos-ciclos-de-vida.md`](estados/mapa-dos-ciclos-de-vida.md)
2. **There is almost no Ecto association.** There are 3 in 65 schemas, against 214 `:binary_id`
   fields. The foreign key exists in the database (201 of them) and is **not** modelled in Ecto: the
   `join` is always explicit. → [`classes/mapa-dos-schemas.md`](classes/mapa-dos-schemas.md)
3. **Nothing is deleted.** Ending, revoking, excluding and marking absence are all `UPDATE`s, with
   author and instant. The only row that disappears is the one that was never written.
   → [`estados/observacao.md`](estados/observacao.md)

## How to read a DSM

Rows and columns are the same items, in the same order. A marked cell `(i, j)` means
**i depends on j**, and the mark says the nature: `D` data · `T` screen · `R` rule · `E` schema.
After reordering, what stays **below** the diagonal is a possible order; what is left **above** is a
cycle, and a cycle is a finding — the document names it and proposes the cut. Blocks on the diagonal
are the slices that travel together in a PR; the slicing recommendation is offered to the Product
Owner, who decides.
