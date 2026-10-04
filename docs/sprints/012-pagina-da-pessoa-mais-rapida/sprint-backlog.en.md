# Sprint 012 — the person page that does not scan everything {#sprint-012--a-página-da-pessoa-que-não-varre-tudo}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [013 — the person page that does not scan everything](../../../specs/013-pagina-da-pessoa-mais-rapida/spec.md)
**Plan**: [plan.md](../../../specs/013-pagina-da-pessoa-mais-rapida/plan.md)
**Origin**: request from the maintainer — *"a study of how to optimize the people screen"* *(original: "estudo de como otimizar a tela de pessoas")*
**Analysis**: run before the code, **five corrections** — two of silent correctness errors, three of
tests that could not work

## Sprint goal {#objetivo-do-sprint}

By the end of this sprint, the page of any person opens in **under 200 ms**. Today it goes from
**0.09 s to 6.12 s** depending on who it is.

## The L44 and L45 check, done before anything else {#a-conferência-da-l44-e-da-l45-feita-antes-de-tudo}

```text
docs/sprints/011-vinculo-que-sumiu-na-origem/sprint-backlog.md   ✓
docs/sprints/011-vinculo-que-sumiu-na-origem/sprint-review.md    ✓
specs/012-vinculo-que-sumiu-na-origem/aceitacao.md               ✓
```

**And where they are** — which is L45: all three are on `main`, merged by PRs #278, #279 and
#280. This branch came out of `main` and sees everything. It did not need stacking.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), 48 lessons. The ones that come in as a **constraint**:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L18** | Sprint 003 | the acceptance assesses the SCs one by one, with evidence |
| **L21** | Sprint 004 | there is no function without a consumer: the change is in a query that 14 screens already use |
| **L22** | Sprint 004 | **T010 measures rows read, not milliseconds** — a clock inside the suite cannot tell what worked |
| **L27** | Sprint 005 | full cycle before the code — the **eighth** feature in a row |
| **L28** | Sprint 005 | "the query got fast" and "the screen shows the same thing" are different assertions: F3 exists for the second |
| **L30** | Sprint 005 | **it bit within this study**: the first measurement said 85 ms, and it was the fast exception |
| **L34** | Sprint 007 | two things with the same name — `inner` and `left` lateral look like the same swap and are not |
| **L36** | Sprint 008 | when two measurements seem to contradict each other, the link is a hypothesis: the one that column width was costly was false |
| **L38** | Sprint 009 | cost is measured by **difference** and **consistency**; `live/2` does two renders |
| **L39** | Sprint 009 | **it is the central risk of this sprint**: a new join in the shared scope shifts positional bindings |
| **L44**, **L45** | Sprints 010 and 011 | the check above, including **where** the previous closure is |

**L30 bit within the study itself, and it is worth recording before the sprint starts.** The first
version of the spec said the screen cost 85 ms — measured on one person. The maintainer pointed to a
2 s page, and the eight largest showed up to 6.12 s. **One measurement does not describe a distribution**,
and the one I took was the exception.

**L36 bit right after**: the hypothesis that the 18 columns multiplied the cost seemed to explain
everything. Trimming to nine gives **5,738 ms** against 6,326 — almost nothing. The link between two
true measurements was a hypothesis.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration**: **not assigned** — same limitation since sprint 004: reconfiguring ProjectV2
iterations recreates the existing ones (L11), and it has already cost reassigning 96 items.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Priority | Estimate | Criteria |
|---|---|---|---|---|
| US1 | The person page opens without scanning the tenant | P1 | 8 | 4 |
| US2 | Find a person's issues without reading everyone's assignments | P1 | 3 | 3 |
| US3 | The same fix applies to the other screens | P2 | 5 | 3 |

**US3 is P2 and comes in all the same**: the cause is a single one, and the fix happens in the function the 14 queries
use. Leaving it out would mean fixing in one place what exists in fourteen — and checking fourteen
anyway.

## Tasks {#tarefas}

Detailed in [013/tasks.md](../../../specs/013-pagina-da-pessoa-mais-rapida/tasks.md).

| # | Task | Serves | Estimate | Phase | State |
|---|---|---|---|---|---|
| T001 | Count the ties that exist today | US1 | 1 | F1 | **done** — zero, and `inserted_at` has microsecond precision |
| T002 | Pin down the in-force rule and the tie-break in a test | US1 | 3 | F1 | to do |
| T003 | Record the snapshot of each affected screen | US3 | 3 | F1 | to do |
| T004 | Resolve the in-force promotion per displayed issue | US1 | 8 | F2 | to do |
| T005 | Index the assignment by person | US2 | 2 | F2 | to do |
| T006 | Unify the second definition of in-force promotion | US3 | 3 | F2 | to do |
| T007 | Compare each screen with the snapshot | US3 | 3 | F3 | to do |
| T008 | Pin down the counts the axiom produces | US3 | 2 | F3 | to do |
| T009 | Measure the three screens, before and after | US1 | 3 | F4 | to do |
| T010 | Prove that the cost stopped growing with the history | US1 | 3 | F4 | to do |

**Total: 31 of complexity, ten tasks.** One migration, for an index. No screen changed — and that is a
requirement, not a side effect.

## What the analysis changed, before the code {#o-que-a-análise-mudou-antes-do-código}

| # | Finding | Correction |
|---|---|---|
| **A1** | **eight of the fourteen calls are `inner`**, and `inner` excludes an issue without a promotion. Swapping for `left lateral` would make the screen **gain rows** it does not have, without anything failing | T004 separates `inner_lateral_join` from `left_lateral_join`, and the test sets up the issue without a promotion |
| **A2** | **`parent_as` requires a named binding**, and a new join in the shared scope shifts the positional ones — it is **L39**, which already swapped promotion for assignment once | T004 forbids positional bindings in the affected `select`s |
| **A3** | the `EXPLAIN` test **would fail with the right code**: in the test database the tables have dozens of rows, and Postgres scans on purpose | T005 asserts the index in `pg_indexes`; the proof of the plan is on real data |
| **A4** | T010 measured **a clock inside the suite** — it is L22 | it now measures **rows read** |
| **A5** | the snapshot in raw HTML would **never** give an empty `diff`: `csrf_token` and LiveView markers change on every render | T003 records the text of the cells, and declares what was removed |

**And the study had found two before that, both by measuring**: paginating does not solve it (`LIMIT 5` costs
6,300 ms and `LIMIT 100` costs 6,648), and trimming the projection does not solve it (5,738 ms).

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| reducing, archiving or deleting the promotion history | the history is provenance — principle III, FR-005 |
| cache of any kind | with the query fixed it is 3 ms; a cache would hide the cost and the first visit would keep paying |
| paginating 100 at a time | measured: the scan happens **before** the limit |
| changing anything in the appearance | FR-008 — if the screen changes, it is a defect |
| `/syncs` and the ephemeral key error | it is environment, not code |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **the screen gaining rows** when swapping `inner` for `left` | T004 separates the variants; the test sets up an issue without a promotion and requires that it does **not** appear |
| **shifted positional binding** — L39 | no affected `select` stays positional; T007 compares the content |
| the answer changing in any of the 14 queries | T003 records the before, T007 requires an empty `diff`, T008 pins 520 and 293 |
| measuring wrongly and declaring victory | T009 uses the same method on both sides, five measurements, and reports consistency alongside |
| the index weighing on writes | the collection runs `replace_assignees/3` 4,529 times; measure before and after |
| `LATERAL` losing on a very large page | measured up to `LIMIT 100`: 3.0 ms. Above that, the threshold is declared in the plan |

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] `mix gates` green by **exit code**
- [ ] empty `diff` on all snapshots — the whole of F3
- [ ] the ten tasks closed or reprioritized with justification
- [ ] PR with review requested from the `the-band` team and an item in the project
- [ ] `aceitacao.md` assessing the 10 FRs and the 9 SCs one by one
- [ ] `sprint-review.md` written **in this** sprint — L44
- [ ] `licoes-aprendidas.md` updated
- [ ] **and the issue closing keyword in English** — L48
