# DSM — feature 060, the team screen

<!-- DERIVED from specs/060-tela-da-equipe/spec.md (US1 to US9, FR-001 to FR-083, SC-001 to SC-021),
     specs/060-tela-da-equipe/tasks.md (T001 to T025, "Dependências e ordem", "Dependências
     externas desta PR"), specs/060-tela-da-equipe/plan.md (D1 to D6, "Ordem de implementação",
     "Perguntas abertas"), specs/060-tela-da-equipe/data-model.md (§1, §2, §3.1, §3.2, §5);
     code: lib/the_band_web/live/teams_live/show.ex:62-181,
     lib/the_band/ontology/seon/eo/commands.ex:110, 155, 214-241, 683-691, 1453,
     lib/the_band/ontology/seon/eo/queries.ex:110-242, 391-453,
     lib/the_band/ontology/seon/eo/visibility.ex:102-160,
     lib/the_band/tenants/access.ex:175-195, 261-299;
     priv/repo/migrations/20260901230000_composicao_de_equipes_e_o_equivoco.exs:52,
     20260827060000_concessao_de_visibilidade.exs:45-74
     on 2026-09-07. Checked against the sources on this date. Regenerate when the source changes. -->

## What this matrix answers

Nine stories, four proposed PRs. The question is **what must come before what**, and where slicing into
PRs creates rework. The ordering recommendation is a **proposal**, addressed to the Product Owner — who
decides.

## The legend

| Code | Story | Priority |
|---|---|---|
| **US1** | Who is on the team, and where each statement came from — the Structure tab and the list by team membership | P1 |
| **US2** | Declaring the role of whoever the source shows, and changing it | P1 |
| **US3** | The person left, and what they did still counts | P1 |
| **US4** | The team membership that never was — the mistake with a reason | P1 |
| **US5** | Creating the organization's role from the Structure | P1 |
| **US6** | The subteams: who makes up this team, since when | P2 |
| **US7** | The reorganized Dashboard: measures with composition, declared projects, and what is outside them | P2 |
| **US8** | The manager's overview: *Problems now* (*Problemas agora*) and *People* (*Pessoas*) | P2 |
| **US9** | The flow of the whole team: burn, *Promised × Delivered* (*Prometido × Entregue*), Monte Carlo | P3 |

Nature of the mark: `D` data (i reads what j writes) · `T` screen (i shows what j produces, or lives on
the screen j creates) · `R` rule (i needs the declaration j creates) · `E` schema (i needs j's column or
table).

## Matrix 1 — in the spec's order

Marked cell `(i, j)` = **i depends on j**.

|         | US1 | US2 | US3 | US4 | US5 | US6 | US7 | US8 | US9 |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **US1** |  —  |     |  E  |     |     |     |     |     |     |
| **US2** |  T  |  —  |     |     |  R  |     |     |     |     |
| **US3** |  T  |     |  —  |     |     |     |     |     |     |
| **US4** |  T  |     |     |  —  |     |     |     |     |     |
| **US5** |  T  |  T  |     |     |  —  |     |     |     |     |
| **US6** |  T  |     |     |     |     |  —  |  T  |     |  T  |
| **US7** |  T  |     |     |     |     |  D  |  —  |     |     |
| **US8** |  T  |     |     |     |     |  D  |  D  |  —  |     |
| **US9** |  T  |     |     |     |     |  D  |  T  |     |  —  |

### Where each mark comes from

| Cell | Nature | The source's sentence |
|---|---|---|
| (US1, US3) | `E` | FR-011: *"An ended team membership MUST remain in the list, marked left on D, with the period and who recorded it"* — and FR-021 says *"Today the end command writes only the date"*. The columns `ended_by_user_id` and `end_declared_at` come from `data-model.md` §1, and without them the US1 row has nothing to render |
| (US2, US1) | `T` | FR-015: *"declare the role **on the person's row**"*. The row belongs to US1 |
| (US2, US5) | `R` | FR-034: the selector *"MUST offer new role…, which opens the FR-030 form without leaving the row"*; `tasks.md` T019 leaves scenario 4 as `@tag :pending` until T022 |
| (US3, US1) | `T` | US3: *"records, on the person's row, that they left"*; `tasks.md` T015 |
| (US4, US1) | `T` | US4: *"marks, with a written reason"*, on the row; `tasks.md` T017 |
| (US5, US1) | `T` | FR-029: *"The **Structure** MUST list the organization's roles"* — the tab belongs to US1 |
| (US5, US2) | `T` | `tasks.md` T022: *"When creating with `linha_de_retorno`, reopen the row (unlocks T019 c4)"* — the US5 form has to know how to return to the US2 row |
| (US6, US1) | `T` | FR-035: the list of compositions lives in the Structure tab |
| (US6, US7) | `T` | FR-041 and US6 scenario 6: *"clicking on a subteam's card … opens that subteam's Dashboard"*. The card is a Dashboard artifact, which US7 reorganizes |
| (US6, US9) | `T` | FR-041 and US6 scenario 6 speak of the card's *"small chart"*; the small chart is FR-058, a US9 requirement |
| (US7, US1) | `T` | FR-001 to FR-003 (the tabs) and FR-043 (*N members — X observed, Y declared* on every measure), which reads the aggregation of the US1 roster |
| (US7, US6) | `D` | FR-056: the set is the distinct union *"by the composition in force **on the date of the event**"*. Today `compose_teams/4` requires `started_at` and writes *now* (`commands.ex:233`; migration `20260901230000:52`; spec, *Modules* table), so the composition has no past — and the measure for a previous period would come out wrong |
| (US8, US1) | `T` | FR-065 (the section comes before the measures, on the Dashboard) and FR-068 (*"(f) leads to the Structure tab"*) |
| (US8, US6) | `D` | FR-070 (**distinct** count over the FR-056 set) and FR-073 (*People* grouped by subteam) |
| (US8, US7) | `D` | FR-065 (g): the *work outside a declared project* card counts what FR-053 (US7) defines; FR-071: the pipeline card depends on the declared projects US7 reads |
| (US9, US1) | `T` | the charts live on the Dashboard, which exists as a tab from US1 on |
| (US9, US6) | `D` | FR-056, same as (US7, US6) |
| (US9, US7) | `T` | FR-058: *"and a small chart on each subteam card"* — the card belongs to US7 |

### What the source does **not** support, and therefore was not marked

- **(US1, US2)** — US1 shows the role *or* `role not declared` (FR-010). Without US2 the list works,
  with every row saying *not declared*. It is completeness, not a block.
- **(US1, US4)** — the mistake trio already exists in the schema since migration
  `20260901230000:76-80`. US1 reads columns that are there.
- **(US4, US3)** — FR-028 requires the **texts** to be distinct, and US4 scenario 4 reads the two rows
  side by side. It is label co-design, not a construction dependency.
- **(US7, US9)** — see cycle 3 below: FR-041 puts the small chart on the card, but US7's acceptance
  scenarios do not mention it. The mark stayed at (US6, US9), and the ambiguity is declared.
- **(US8, US2)** — card (f) counts members without a role through `count_memberships_pending_role/2`,
  which already exists (055 FR-018).

## Matrix 2 — reordered

Order: **US1, US3, US2, US5, US4, US6, US7, US9, US8**.

|         | US1 | US3 | US2 | US5 | US4 | US6 | US7 | US9 | US8 |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **US1** |  —  |  E  |     |     |     |     |     |     |     |
| **US3** |  T  |  —  |     |     |     |     |     |     |     |
| **US2** |  T  |     |  —  |  R  |     |     |     |     |     |
| **US5** |  T  |     |  T  |  —  |     |     |     |     |     |
| **US4** |  T  |     |     |     |  —  |     |     |     |     |
| **US6** |  T  |     |     |     |     |  —  |  T  |  T  |     |
| **US7** |  T  |     |     |     |     |  D  |  —  |     |     |
| **US9** |  T  |     |     |     |     |  D  |  T  |  —  |     |
| **US8** |  T  |     |     |     |     |  D  |  D  |     |  —  |

**Four marks remain above the diagonal** — `(US1, US3)`, `(US2, US5)`, `(US6, US7)` and
`(US6, US9)`. Each one is a cycle, and no reordering removes them.

### The blocks

| Block | Stories | What keeps it together |
|---|---|---|
| **B1** | US1, US3 | the exit column: US1 **reads** it, US3 **writes** it |
| **B2** | US2, US5 | the role selector opens the role form, and the form returns to the row |
| **B3** | US4 | nothing depends on it; it depends only on the US1 row |
| **B4** | US6, US7, US9 | the subteam card: US6 clicks it, US7 draws it, US9 puts the chart inside — and US7 and US9 read the dated composition US6 declares |
| **B5** | US8 | reads US1, US6 and US7; nobody reads it |

Order between blocks: **B1 → {B2, B3} → B4 → B5**. B2 and B3 are independent of each other.

## The cycles, and the cut for each one

### Cycle 1 — `US1 ⇄ US3`: the column one reads and the other writes

US1 needs to render *"left on D, recorded by X"* (FR-011, FR-022); the columns
`ended_by_user_id` and `end_declared_at` do not exist (`data-model.md` §1). US3 needs the US1 row to
place the button.

**Proposed cut**: **declare the schema before both**. It is what `tasks.md` already does — T008
(migration + schema) is in **Phase 2**, before the list (T009, T011) and three phases before the exit
(T014). The DSM confirms T008's position and says why it is not arbitrary: without separating the column
from the story, the two stories wait for each other.

*Cost if the cut is not made*: US1 is born without the author column, renders `left on D` without who
recorded it, and is reopened in the exit phase — the same table row edited twice.

### Cycle 2 — `US2 ⇄ US5`: the selector and the form

US2 needs *"＋ new role…"* in the selector (FR-034); US5 needs to reopen the US2 row after creating
(T022).

**Proposed cut**: **declare the return contract before both** — the `linha_de_retorno` that T022 already
names — and **keep the two in the same PR**. It is a block, not an order: splitting them into two PRs
would make the first deliver a path that leads nowhere. `tasks.md` already orders them T019 → T022 with
US2 scenario 4 as `@tag :pending`, which is the honest way to cross a cycle inside a PR: the gap stays
**marked**, not hidden.

### Cycle 3 — `US6 ⇄ US7 ⇄ US9`: the subteam card

It is the expensive cycle, and the only one that **goes against the proposed slicing**.

The subteam card on the Dashboard appears in three places in the spec:

- **FR-041**, under the heading *"The subteams"* — hence a requirement of **US6** —, and it says *"each
  subteam MUST be a card with the same measures as the table **and a small chart**, and clicking the card
  or the chart MUST open that subteam's Dashboard"*;
- **US6, scenario 6**, which is a US6 acceptance criterion: *"clicks on a subteam's card **or on its small
  chart**"*;
- **FR-058**, under *"The flow of the whole team"* — a requirement of **US9** —, which says *"and a small
  chart on each subteam card"*.

And the card is a Dashboard artifact, whose reorganization is **US7** (FR-002, FR-044).

**Cut proposed to the Product Owner**: move FR-041.

1. **the card and the door** (clicking opens the subteam's Dashboard) become a requirement and acceptance
   of **US7**;
2. **the small chart inside the card** becomes a requirement and acceptance of **US9**;
3. **US6** keeps FR-035 to FR-040 and FR-042 — the *Subteams* section of the Structure tab — and
   scenarios 1 to 5 and 7. Scenario 6 changes owner.

With this cut, B4 breaks up into `US6 → US7 → US9`, all marks fall below the diagonal, and the slicing
PR 2 → PR 3 → PR 4 becomes valid.

## Does the DSM agree with the proposed slicing?

`tasks.md` proposes **PR 1 = US1–US5 · PR 2 = US6 · PR 3 = US7–US8 · PR 4 = US9**.

| PR | Verdict | Why |
|---|---|---|
| **PR 1 = US1–US5** | **agrees** | blocks B1, B2 and B3 are at the top of the order and depend on nothing in B4 or B5. The DSM adds two orders **inside** the PR: B1 first (the column before the list) and the whole of B2 in a single slice. Both are already in `tasks.md` |
| **PR 2 = US6** | **disagrees as the stories are written** | US6 has two marks above the diagonal — on US7 and on US9. Its scenario 6 **cannot be assessed** at the end of PR 2: the card belongs to PR 3 and the small chart to PR 4. With the cut of cycle 3, it comes to agree |
| **PR 3 = US7–US8** | **agrees** | (US8, US7) is `D` and has no reverse: within the PR, US7 before US8. It is a correct block |
| **PR 4 = US9** | **agrees, with a caveat** | if the card's small chart stays in US9, PR 4 goes back to the card component PR 3 built. It is rework of one component — small, but it is exactly what this matrix exists to show. Alternative: the small chart travels with the card in PR 3, and PR 4 delivers only the whole-team series, *Promised × Delivered* and Monte Carlo |

### An alternative slicing of PR 1, if the size bothers

The DSM allows three PRs instead of one, and recommends none of them — it only says they are possible:

1. **PR 1a** = the exit column (T008) + US1 (the tabs and the list) — B1 without the write;
2. **PR 1b** = US3 and US4 (exit and mistake) — B1 closes, B3 comes in;
3. **PR 1c** = US2 and US5 (role on the row and the organization's roles) — the whole of B2.

*The cost*: `show.ex` has 2 138 lines and is touched in all three; that is three reviews of the same
module and three measurements of the query ceiling (T013). *The gain*: the first screen arrives sooner,
and each PR has a single question. **Product Owner's decision.**

## Matrix 3 — the external dependencies of PR 1

Four items that are not stories and that PR 1 needs before the screen exists.

| Code | Item | Task |
|---|---|---|
| **E1** | `priv/knowledge_base/ontology/seon/eo/modules/role_grants.yaml` (new) + `role_grants` in `eo/ontology.yaml` — declares **both** grants, the visibility one (which has existed in the code since #369 and was never declared) and the management one | T002 |
| **E2** | rule `github_team_membership_evidence.yaml` → **v3**: a declared exit and a mistake on an observed team membership block recreation while observation is continuous | T003 |
| **E3** | migration `saida_declarada_com_autor`: `declared_at`, `ended_by_user_id`, `end_declared_at` and the two `CHECK`s | T008 |
| **E4** | migration `concessao_de_gestao_da_estrutura`: table `eo_role_structure_management_grants` with the partial index | T004 |

Marked cell = the story **depends** on the external item.

|         | E1 | E2 | E3 | E4 |
|---------|:--:|:--:|:--:|:--:|
| **US1** | R  |    | E  | R  |
| **US2** | R  |    | E  | R  |
| **US3** | R  | R  | E  | R  |
| **US4** | R  | R  |    | R  |
| **US5** | R  |    |    | R  |

And among the items: **E4 depends on E1** (`R`) — principle IV, SC-015: the declaration in the base comes
**before** the table and the screen. That is why E1 appears marked on every row: no story reaches E4
without going through it.

### What each column unlocks

- **E1** — without the YAML, the grant cannot be created (SC-015: *100% of new measures and slices have
  YAML in the base before appearing on the screen*). It closes, in passing, the gap inherited from #369:
  the visibility grant is in `eo_role_visibility_grants` (migration `20260827060000:45`) and is not
  declared in the base.
- **E2** — unlocks US3 (FR-026: after the exit, collection does not recreate) and US4 (FR-027: a new
  observation after an established absence is a return). Without it, a declared exit on an observed team
  membership is **undone by the next collection** — see `estados/vinculo-de-equipe.md`, finding 1.
- **E3** — unlocks the **reading** of US1 (FR-010 *declared by X on D*, FR-011 *with who recorded it*,
  FR-022 *declared end × established end*), that of US2 (`declared_at`) and the **writing** of US3.
- **E4** — unlocks every write action (FR-006) and US1 scenario 6 (*whoever does not manage reads the
  whole list and sees no action at all*).

### The external item PR 2 will need, and nobody has listed yet

`eo_team_compositions.started_at` is `null: false` (migration `20260901230000:52`) and
`compose_teams/4` writes *now* (`commands.ex:233`). FR-037 requires *"start date **or blank = unknown**"*.
It is a **fifth** migration, and it is not on the list of external dependencies of PR 1 because it belongs
to PR 2 — but the marks `(US7, US6)`, `(US8, US6)` and `(US9, US6)` of this matrix depend on it: without a
composition with a past, the FR-056 set *on the date of the event* does not exist. **It is worth declaring
it along with the slicing of PR 2.**

## `[NEEDS CLARIFICATION]`

1. **Who owns FR-041?** The requirement is under *"The subteams"* (US6), the card belongs to the
   Dashboard (US7) and the small chart is FR-058 (US9). This document's proposal is the cut of cycle 3;
   the decision belongs to whoever prioritizes. **To whom**: Product Owner.
2. **Which PR owns the FR-056 set** (the distinct union of members of the whole team)? US7, US8 and US9
   require it, and the spec classifies it as *derived, not persisted* (Key Entities). Whoever builds it
   first pays; whoever comes later reuses. And it needs a **measure amendment in the base before the
   screen** (`spec.md`, *Base de conhecimento*, the row *"o conjunto de membros da equipe composta"*),
   which also makes it an external item. **To whom**: Product Owner, with whoever maintains the base.
3. **Can PR 4 touch PR 3's card?** If so, the small chart stays in US9 and the PR 4 caveat is accepted as
   a cost. If not, it travels in PR 3. **To whom**: Product Owner.
