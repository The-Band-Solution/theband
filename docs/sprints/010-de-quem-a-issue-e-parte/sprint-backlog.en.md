# Sprint 010 — what each issue is part of {#sprint-010--de-quem-cada-issue-é-parte}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [011 — what each issue is part of](../../../specs/011-de-quem-a-issue-e-parte/spec.md)
**Plan**: [plan.md](../../../specs/011-de-quem-a-issue-e-parte/plan.md)
**Origin**: [#246](https://github.com/The-Band-Solution/theband/issues/246), requested during sprint 009
**Analysis**: run before the code, **four corrections** — two of them requirements **with no task at all**

## Sprint goal {#objetivo-do-sprint}

At the end of this sprint, a repository's issue list says, on each row, **what that issue is part
of** — and says **which** relation it is.

There are **1,630** issues with a parent and **2,899** without. Of the 1,666 relations, **293 violate `sro.rule07`** and
**33** are not named by the ontology network. The column exists so as not to flatten this into one word.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md), 39 lessons. The ones that come in as a **constraint**:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L08** | Sprint 002 | contract before the first public function — `contracts/issue-parent.md` |
| **L18** | Sprint 003 | acceptance evaluates the 13 SC with evidence, never the green suite |
| **L20** | Sprint 003 | deterministic `order_by` in `list_parents/2`; it is the lesson that **found** the `fetch_parent/2` defect |
| **L21** | Sprint 004 | F1 are queries with no consumer; the column is in the same sprint |
| **L22**, **L23** | Sprint 004 | gate by exit code |
| **L25** | Sprint 004 | the issue number **does not identify** — 57 links have a parent in another repository |
| **L27** | Sprint 005 | full cycle before the code — sixth feature in a row |
| **L28** | Sprint 005 | "the function returns" and "the screen shows" are different claims: the tests go to the HTML |
| **L30** | Sprint 005 | the numbers come from the database — and **they caught a mistake of mine**: 1,666 is links, not issues |
| **L32** | Sprint 006 | the screen does not claim what it did not observe: the parent without a concept is stated, not invented |
| **L34** | Sprint 007 | **two different `nil`s** — "has no parent" and "parent without a concept" — separated by clause |
| **L36** | Sprint 008 | when two measures seem to contradict each other, the link is a hypothesis |
| **L38** | Sprint 009 | cost is measured by the **difference** and by **constancy**, and `live/2` does two renders |

**L30 caught a mistake inside the spec itself.** The first version wrote "1,666 issues with a parent" and
derived 2,863 as the complement. 1,666 is the count of **links**; the issues are **1,630**, and the
difference of 36 is exactly the issues with more than one parent. Two quantities with similar names,
added up without checking against the source — in the document that exists to measure.

**L34 comes in before it hurts, again.** Here the dangerous word is the `nil` of the parent's concept: in
`rule07/2` it means **has no parent**, and in the column it means **the parent was not promoted**. Passing one
off as the other would make the screen say *task without parent* about an issue that has a parent.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration**: **does not exist for this sprint** — limitation declared since sprint 004. Configuring
ProjectV2 iterations recreates the existing ones (L11), and it has already cost reassigning 96 items.

**Types**: the organization has `Task`, `Bug` and `Feature`. Epic and user stories are typed `Feature`.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | See what the issue is part of, without opening the issue | [#248](https://github.com/The-Band-Solution/theband/issues/248) | [#249](https://github.com/The-Band-Solution/theband/issues/249) | P1 | 8 | to do |
| US2 | Know which relation it is, and when it is wrong | [#248](https://github.com/The-Band-Solution/theband/issues/248) | [#250](https://github.com/The-Band-Solution/theband/issues/250) | P1 | 8 | to do |
| US3 | Not be misled when there is more than one parent | [#248](https://github.com/The-Band-Solution/theband/issues/248) | [#251](https://github.com/The-Band-Solution/theband/issues/251) | P2 | 8 | to do |

**US3 is P2 and comes in all the same.** It is 36 issues out of 1,630 — and it is exactly where a silent choice goes
unnoticed. Leaving it out would deliver a column that lies on 36 rows.

## Tasks {#tarefas}

Detailed in [011/tasks.md](../../../specs/011-de-quem-a-issue-e-parte/tasks.md). Each task is a child of the
**user story it serves** — never of the epic.

| # | Task | Serves | Issue | Estimate | Phase | State |
|---|---|---|---|---|---|---|
| T001 | Name the link's relation | US2 | [#252](https://github.com/The-Band-Solution/theband/issues/252) | 3 | F1 | to do |
| T002 | Fetch the parents in batch | US1 | [#253](https://github.com/The-Band-Solution/theband/issues/253) | 3 | F1 | to do |
| T003 | Show the parent on the row | US1 | [#254](https://github.com/The-Band-Solution/theband/issues/254) | 5 | F2 | to do |
| T004 | Say which relation it is | US2 | [#255](https://github.com/The-Band-Solution/theband/issues/255) | 5 | F2 | to do |
| T005 | Name the parent's repository | US3 | [#256](https://github.com/The-Band-Solution/theband/issues/256) | 3 | F2 | to do |
| T006 | Say there is more than one parent | US3 | [#257](https://github.com/The-Band-Solution/theband/issues/257) | 3 | F2 | to do |
| T007 | Mark the absent link | US2 | [#258](https://github.com/The-Band-Solution/theband/issues/258) | 3 | F3 | to do |
| T008 | Say parent without a concept | US2 | [#259](https://github.com/The-Band-Solution/theband/issues/259) | 2 | F3 | to do |
| T009 | Measure the render cost | US1 | [#260](https://github.com/The-Band-Solution/theband/issues/260) | 3 | F3 | to do |

**Total: 30 of complexity, nine tasks.** One below sprint 009, and no migration: the feature only reads.

## What the analysis changed, before the code {#o-que-a-análise-mudou-antes-do-código}

| # | Finding | Correction |
|---|---|---|
| **A1** | **FR-003 and SC-004 had no task at all.** The relation texts — `attends`, `composes` — do not name the parent's **concept**, and without it the 12 links whose parent is a defect would be left unnamed. It is the reduction the original request made and that FR-003 exists to prevent | T003 shows the concept, and the test builds the defect-parent case |
| **A2** | FR-016 and SC-011 were **without an assertion** | the T003 test requires not found for another tenant's repository |
| **A3** | the T002 test cited `Ecto.Adapters.SQL.query_count/1`, which **does not exist** | `contar_consultas/1`, via telemetry, which already exists in `person_detail_test.exs` |
| **A4** | T009 would measure **four** and fail with no defect at all: `live/2` does **two** renders | the raw difference is divided by two, as feature 010 already does |

**And the plan had found three before that**, all by measurement: the count of links confused with
issues, the relation decided by the pair instead of the child's concept, and the second boundary of the
repository name — the same one the analysis of feature 010 found in its A1.

## The two defects the measurement found outside the feature {#os-dois-defeitos-que-a-medida-achou-fora-da-feature}

| # | What it is | Record |
|---|---|---|
| 1 | `fetch_parent/2` with `limit: 1` **without `order_by`** — arbitrary parent for the 36 issues with more than one, and it **hides** that there is another | [#261](https://github.com/The-Band-Solution/theband/issues/261) |
| 2 | a child promoted to **defect** does not fall into `list_composition/2`, nor `list_attendance/2`, nor `list_unpromoted_parts/2` — **33 links** invisible in the parent's detail | [#262](https://github.com/The-Band-Solution/theband/issues/262) |

**Neither is fixed in this sprint**: both belong to another screen. **Recording is what distinguishes
debt from omission.**

## Confirmed scope {#escopo-confirmado}

**Feature 011 complete — F1 to F3, T001 to T009.**

F1 is function and query with no consumer, and **L21** says that is not delivered functionality.

**The possible cut is by user story**: US1 alone — T002 and T003 — already delivers the literal request. What
it does not deliver is the distinction between the relations, and that is where the 293 violations are.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| giving `fetch_parent/2` an `order_by` | it is #261, and it is another screen |
| showing the 33 defect links in the parent's detail | it is #262, and it is another screen |
| fixing the 293 violations at the source | the platform observes and warns; fixing is the team's decision |
| choosing which parent counts, among the 36 | the platform does not decide that for the team |
| the full lineage in the column | it is another question — principle X; the detail already answers it |
| the same column in `/work` | the list there is for the whole tenant, and the question there is another |
| filtering the list by parent | it was not requested |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **filling 2,091 cells with warnings** by calling the axiom with a null parent | `relacao/2` is only called when there is a parent; the test does `refute` on the cell of the task without a parent |
| saying *task without parent* about an issue that **has** a parent | the `:pai_sem_conceito` clause comes first; the test separates the two `nil`s |
| calling the defect link composition | FR-004a; the test requires the "not named" text on the 33 |
| `KeyError` on 2,899 rows | `Map.get(pais, id, [])` — `list_parents/2` creates no key for an issue without a parent |
| arbitrary parent on the 36 | order `number, id`; the test renders twice and compares |
| `#12` pointing to the wrong issue | the repository name when it differs; 57 links |
| query per row | two queries, one per boundary; the test measures difference **and** constancy |

**No dependency on another branch.** `015-de-quem-a-issue-e-parte` comes off `main`, and there is no
migration.

## Definition of Done for the sprint {#definition-of-done-do-sprint}

- [ ] `mix gates` green by **exit code** — ten gates
- [ ] V1 to V12 of the [quickstart](../../../specs/011-de-quem-a-issue-e-parte/quickstart.md) verified
- [ ] **on real data**: a repository's list shows parent, concept and relation, with the 293 warning
- [ ] the invariant checked: attendance + violation + composition + not named = **1,666**
- [ ] the nine issues closed or reprioritized with justification
- [ ] PR with reviewer requested and **checked** via `requested_reviewers` (L14), linked to the project
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `licoes-aprendidas.md` updated
- [ ] `aceitacao.md` with the 13 SC evaluated one by one
- [ ] **the screen looked at at 360 px** — and not just asserted in HTML, which is the debt that has crossed four
      sprints
