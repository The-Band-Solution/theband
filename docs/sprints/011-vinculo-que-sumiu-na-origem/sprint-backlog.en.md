# Sprint 011 — the link that disappeared at the source {#sprint-011--o-vínculo-que-sumiu-na-origem}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [012 — the link that disappeared at the source](../../../specs/012-vinculo-que-sumiu-na-origem/spec.md)
**Plan**: [plan.md](../../../specs/012-vinculo-que-sumiu-na-origem/plan.md)
**Origin**: [#263](https://github.com/The-Band-Solution/theband/issues/263), found **during** sprint 010
**Analysis**: run before the code, **four corrections** — three of them design

## Sprint goal {#objetivo-do-sprint}

At the end of this sprint, the platform stops claiming decomposition that the source no longer declares.

There are **1,666** links, **0** marked as absent, and **52** that the last collection did not see again. The
`no_longer_observed_at` column has existed since 2026-08-11 and **nothing in the code writes it**.

## The L44 check, done before anything else {#a-conferência-da-l44-feita-antes-de-tudo}

**Opening a new sprint checks the previous one.** Sprint 010 has the three documents:

```text
docs/sprints/010-de-quem-a-issue-e-parte/sprint-backlog.md   ✓
docs/sprints/010-de-quem-a-issue-e-parte/sprint-review.md    ✓
specs/011-de-quem-a-issue-e-parte/aceitacao.md               ✓  12 de 13 critérios
```

**And the check found something L44 did not foresee**: the three documents, lessons **L38 to L44**
and `RETOMAR.md` live in PR [#264](https://github.com/The-Band-Solution/theband/pull/264), which is
**open**. A branch taken from `main` would open this sprint unable to read the lessons it
needs to cite — which is exactly the defect L44 describes, by another path.

**Resolved by stacking**: `016-vinculo-que-sumiu-na-origem` came off `015-de-quem-a-issue-e-parte`, and
not off `main`. It goes into this sprint's review as a lesson.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md), 44 lessons. The ones that come in as a **constraint**:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L08** | Sprint 002 | contract before the first public function — `contracts/decomposition-absence.md` |
| **L18** | Sprint 003 | acceptance evaluates the SC one by one with evidence, never the green suite |
| **L19** | Sprint 003 | the mark is **per repository**, and there is no arity without it — L19 prevented in the type |
| **L21** | Sprint 004 | T001 is a function with no consumer; T005 calls it in the same sprint |
| **L22**, **L23** | Sprint 004 | `mix gates`, verdict by exit code |
| **L27** | Sprint 005 | full cycle before the code — **seventh** feature in a row |
| **L28** | Sprint 005 | "the function marks" and "the screen shows" are different claims: T008 goes to the HTML |
| **L29** | Sprint 005 | **a transient failure marks nothing** — it is the whole of US3, and it is the lesson that cost 38 repositories |
| **L30** | Sprint 005 | the numbers come from the database: 1,666, 0, 52, 57, 12 — all measured, none remembered |
| **L32** | Sprint 006 | the screen does not claim what it did not observe — it is the defect being fixed, in the direction of the data |
| **L35** | Sprint 007 | checking against the source finds defects outside the feature: the 12 of `sro.rule07` |
| **L43** | Sprint 010 | when the axiom answers another question, the precondition is fixed — here, the **cutoff**, not the date |
| **L44** | Sprint 010 | the mechanical check of the three documents, done above |

**L29 is not a decorative citation in this sprint**: it **is** US3. The whole feature consists of marking
absence, and marking absence of what was not looked at is exactly what took 38 repositories and 899
issues out of circulation, silently.

**L30 has already charged its price here, and before the code.** The plan measured that writing `started_at` into the
mark contradicts the three sibling implementations — and FR-002 was corrected before any function existed.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) · 13 items, `Status =
Backlog`, `Priority = P1` on the epic and on the three user stories, `Estimate` on all of them.

**Iteration**: **not assigned**, and the reason is the same since sprint 004 — the field exists and only has
`Sprint 002` configured. Reconfiguring ProjectV2 iterations **recreates the existing ones** (L11), and it has already
cost reassigning 96 items. It stays declared as a limitation, not as forgetfulness.

**Types**: epic and user stories as `Feature`, tasks as `Task` — the organization has neither `Epic`
nor `User Story`, and the routing rule decides epic by the presence of sub-issues.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Epic | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|
| US1 | The collection stops claiming the decomposition the source dropped | [#265](https://github.com/The-Band-Solution/theband/issues/265) | [#266](https://github.com/The-Band-Solution/theband/issues/266) | P1 | 8 | 5 |
| US2 | The screen stops claiming what the source does not declare | [#265](https://github.com/The-Band-Solution/theband/issues/265) | [#267](https://github.com/The-Band-Solution/theband/issues/267) | P1 | 5 | 4 |
| US3 | A collection that did not look does not mark | [#265](https://github.com/The-Band-Solution/theband/issues/265) | [#268](https://github.com/The-Band-Solution/theband/issues/268) | P1 | 5 | 5 |

**All three are P1, and it is not inflation.** US1 is the defect; US2 is what is seen; US3 is what keeps the
fix from becoming a defect worse than the original.

## Tasks {#tarefas}

Detailed in [012/tasks.md](../../../specs/012-vinculo-que-sumiu-na-origem/tasks.md). Each task is a
child of the **user story it serves** — never of the epic.

| # | Task | Serves | Issue | Estimate | Phase | State |
|---|---|---|---|---|---|---|
| T001 | Mark the link not seen again | US1 | [#269](https://github.com/The-Band-Solution/theband/issues/269) | 5 | F1 | to do |
| T002 | Preserve the validity of what came back | US1 | [#270](https://github.com/The-Band-Solution/theband/issues/270) | 2 | F1 | to do |
| T003 | Pin down the mark's idempotency | US1 | [#271](https://github.com/The-Band-Solution/theband/issues/271) | 2 | F1 | to do |
| T004 | Block reach into another tenant | US3 | [#272](https://github.com/The-Band-Solution/theband/issues/272) | 2 | F1 | to do |
| T005 | Mark at the end of the repository's collection | US1 | [#273](https://github.com/The-Band-Solution/theband/issues/273) | 3 | F2 | to do |
| T006 | Do not mark what was not looked at | US3 | [#274](https://github.com/The-Band-Solution/theband/issues/274) | 5 | F2 | to do |
| T007 | Say in the log what stopped being declared | US1 | [#275](https://github.com/The-Band-Solution/theband/issues/275) | 2 | F2 | to do |
| T008 | Prove that the list says the link ended | US2 | [#276](https://github.com/The-Band-Solution/theband/issues/276) | 5 | F3 | to do |
| T009 | Check on real data | US1·US2·US3 | [#277](https://github.com/The-Band-Solution/theband/issues/277) | 3 | F4 | to do |

**Total: 29 of complexity, nine tasks.** One point below sprint 010, and no migration: the column already
exists.

**Four of the nine assert absence of effect** — T002, T003, T004 and T006. That is where the defect of this
family shows up, and it never raises an error.

## What the analysis changed, before the code {#o-que-a-análise-mudou-antes-do-código}

| # | Finding | Correction |
|---|---|---|
| **A1** | **the mark changes a number on another screen**: 12 of the 52 links support `sro.rule07` violations, and the dashboard drops from **293 to 281** | SC-007 in the spec, and the fourth check in T009 |
| **A2** | **the order relative to `promover/2` becomes load-bearing**: `classification/2` counts only those in force, and promoting before marking would classify an epic by a part the source dropped | declared in T005 and in the collection's `@moduledoc` |
| **A3** | **FR-014 without a task**, and it was testable | assertion in T006: `refused_links` intact after the collection |
| **A4** | **T008 blocked**, not pending: it requires code that is in an unmerged PR | resolved by stacking the branch on top of feature 011's |

**And the plan had found two before that, both by reading the code**: FR-002 asked to write
`started_at` into the mark, against the convention of the three siblings; and FR-013 asked for a new number on the
syncs screen, which is the concrete case of principle X.

**Seventh feature in a row in which the analysis phase finds a design defect** that no unit
test would catch.

## Confirmed scope {#escopo-confirmado}

**Feature 012 complete — F1 to F4, T001 to T009.**

T001 alone is a function with no consumer, and **L21** says that is not delivered functionality. The possible
cut would be T001 + T005 — the MVP —, and what it does not deliver is the proof that a collection that failed
marks nothing, which is US3.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| `order_by` in `fetch_parent/2` | it is [#261](https://github.com/The-Band-Solution/theband/issues/261), and it is another screen |
| child promoted to defect in the parent's detail | it is [#262](https://github.com/The-Band-Solution/theband/issues/262), and it is another screen |
| marking a refusal (`refused_links`) as absent | a refusal was never an asserted link — FR-014 says **not** to touch it |
| generalizing the four absence markings | the cutoffs are not the same: one is by date, two are by list |
| a new field in `syncs` to count what the collection marked | a number next to numbers that answer another question |
| fixing the decompositions at the source | the platform observes; fixing is the team's decision |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **marking what was not looked at** — L19 and L29 together | per-repository scope in the signature; T006 asserts zero in three failure scenarios |
| marking the **57** cross-repository links when collecting the child | the scope is the **parent's** repository; T006 builds the case |
| **cutting off at "now"** and marking what the run itself wrote | the cutoff is `ctx.started_at`; T001 builds the case of the link written during the run |
| marking before `vincular/2` | T005 pins down the order, and the `@moduledoc` now declares it |
| **promoting before marking** and classifying an epic by a dropped part | the mark is inside `coletar_issues/2`, and `promover/2` runs after all repositories |
| rewriting the date of what was already marked | `is_nil(...)` in the `WHERE`; T003 compares the map of dates before and after |
| **T008 without feature 011's code** | the branch was stacked on top of 015; if #264 is changed in review, this branch rebases |
| the proof on real data staying pending | it is declared as pending in T009, and requires the master key — never counted as fulfilled |

## Definition of Done for the sprint {#definition-of-done-do-sprint}

- [ ] `mix gates` green by **exit code** — never with `| tail`
- [ ] knowledge base valid
- [ ] the nine issues closed or reprioritized with justification
- [ ] PR opened with review requested from the `the-band` team and an item in the project
- [ ] `aceitacao.md` evaluating the 14 FR and the 7 SC one by one
- [ ] `sprint-review.md` written **in this sprint**, not in the next one — L44
- [ ] `licoes-aprendidas.md` updated
