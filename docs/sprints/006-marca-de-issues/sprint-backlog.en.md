# Sprint 006 — the work mark on the repository {#sprint-006--a-marca-de-trabalho-no-repositório}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [007 — issue mark](../../../specs/007-marca-de-issues/spec.md)
**Plan**: [plan.md](../../../specs/007-marca-de-issues/plan.md) ·
**Analysis**: run before the code, six corrections applied

## Sprint goal {#objetivo-do-sprint}

At the end of this sprint, whoever opens `/work` knows **where there is work without reading any number** — and the
screen never asserts a collection that did not happen.

70% of the 135 rows have no work to show. Today finding that out requires going through 135
counts; the mark answers at a glance, with shape, text and an accessible label.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), 31 lessons. The ones that enter as a **constraint**
of this sprint:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L08** | Sprint 002 | API contract written **before** the first public function — [contracts/repository-work-mark.md](../../../specs/007-marca-de-issues/contracts/repository-work-mark.md), committed before any code |
| **L11** | Sprint 002 | I will **not** touch the iterations configuration. See "Sprint on GitHub" |
| **L18** | Sprint 003 | a met criterion is not enough: the acceptance assesses each of the 11 SC with evidence, never the green suite |
| **L21** | Sprint 004 | no public function without a visible consumer: F1's grouped query is only delivered with F3's mark in the same slice |
| **L22**, **L23** | Sprint 004 | gate checked by **exit code**, `mix gates`, without `\| tail`; a skipped-check warning is a failure |
| **L27** | Sprint 005 | full cycle before the code — spec, checklist, research, plan, data-model, contract, quickstart, tasks and **analysis**. It is the second feature to follow this in order, and the first in which the analysis found a design defect |
| **L28** | Sprint 005 | "computes" and "is stored" are different claims: T004 has a test that checks the date **in the database**, not just the call |
| **L29** | Sprint 005 | an inaccessible repository does **not** receive the date, and its absence is information — not a permanent state that takes data out of circulation. The collection that reaches it stores it |
| **L30** | Sprint 005 | V9 measures the 41 repositories **on the real data**, with SQL against the database, and not only in the suite |
| **L31** | Sprint 005 | T002 changes the meaning of the count column — from all to in-force. The change is declared in R3 and in the plan, and was not resolved by adjusting an expected number |

**L27 is the one this sprint truly verifies.** It says that a design decision examined
after the code has already been made. Here the analysis ran before and found defect A1 — the mark
deciding by the date before the count, which would make the screen lie about 41 repositories. No
unit test would catch it: each piece works. The question that caught it was *what does the screen say on the day
of the migration?*, and it only exists because there was an analysis phase.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration**: **does not exist for this sprint**, and it is a declared limitation — not forgetfulness.

The `Iteration` field has a single iteration (`Sprint 002 — Escopo por organização`, 2026-08-10).
Sprints 003, 004, 005 and now 006 run without their own iteration for the same reason:
**configuring ProjectV2 iterations recreates the existing ones** — it is L11, and it cost reassigning 96
items.

Accepted consequence: `flow.throughput` and `flow.wip.count` do not separate 003 to 006 by iteration.

**Issue types**: the organization has `Task`, `Bug` and `Feature` enabled, and does **not** have `Epic`
or `User Story`. Epic and user story are typed `Feature`, as in the previous sprints. Creating a
type changes the organization's configuration, and the decision is the maintainer's — it stays in the product
backlog. The hierarchy carries what the type does not, and it is from it that the routing rule decides:
`Feature` with `Feature` sub-issues is an epic; `Feature` whose children are `Task` is an atomic
user story.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | Find where there is work, without reading a number | [#185](https://github.com/The-Band-Solution/theband/issues/185) | [#186](https://github.com/The-Band-Solution/theband/issues/186) | P1 | 17 | done |
| US2 | Go from the repository to its issues | [#185](https://github.com/The-Band-Solution/theband/issues/185) | [#187](https://github.com/The-Band-Solution/theband/issues/187) | P1 | 1 | done |

`Priority` is the SRO's *importance* — value to the organization. `Estimate` is the *complexity* —
difficulty for the team. A blank field means **unknown**, never zero.

**US2 has complexity 1 because the navigation already exists** since feature 006. What it asks for is
a guarantee: the 94 repositories without work **remain** clickable, because their screen explains
why they are empty.

## Tasks {#tarefas}

Detailed in [007/tasks.md](../../../specs/007-marca-de-issues/tasks.md). Each task is a child of the
**user story it serves** — never of the epic: a task under an epic violates `sro.rule07`, and that is the warning
that feature 006 itself started to show.

| # | Task | Serves | Issue | Estimate | Phase | State |
|---|---|---|---|---|---|---|
| T001 | Count issues per repository in one query | US1 | [#188](https://github.com/The-Band-Solution/theband/issues/188) | 3 | F1 | done |
| T002 | Replace the 135 queries with one | US1 | [#189](https://github.com/The-Band-Solution/theband/issues/189) | 2 | F1 | done |
| T003 | Record when the issues were collected | US1 | [#190](https://github.com/The-Band-Solution/theband/issues/190) | 2 | F2 | done |
| T004 | Store the date at the end of the issues phase | US1 | [#191](https://github.com/The-Band-Solution/theband/issues/191) | 3 | F2 | done |
| T005 | Display the mark with three channels | US1 | [#192](https://github.com/The-Band-Solution/theband/issues/192) | 5 | F3 | done |
| T006 | Say that there was work and there is none in force | US1 | [#193](https://github.com/The-Band-Solution/theband/issues/193) | 2 | F3 | done |
| T007 | Keep every repository clickable | US2 | [#194](https://github.com/The-Band-Solution/theband/issues/194) | 1 | F3 | done |

A task does not get `Priority`: it inherits that of the user story it serves. Two sources would diverge, and the
divergence would have no way of being resolved.

**Total: 18 of complexity, seven tasks.** It is the smallest sprint so far, and on purpose: the
feature adds one column, one query and about 15 lines of markup.

## The criterion the analysis added, and it is the most important of the sprint {#o-critério-que-a-análise-acrescentou-e-é-o-mais-importante-do-sprint}

**After T003's migration, all 135 repositories have `issues_collected_at` null** — no
previous collection recorded the date. And **41 of them have in-force issues**, one with 2,514.

If the mark decides by the date before the count, the screen says `no collection recorded` about those 41.
It is not a gap: it is the platform **asserting** that it never looked at a repository of which it has 2,514
collected issues. The order is fixed:

```
contagem > 0                → cheia,     "N issues"
contagem 0 e data presente  → vazia,     "collected, no issues"
contagem 0 e data nula      → tracejada, "no collection recorded"
```

It is in FR-005a, in T005's description, in the contract, in SC-008, and is measured by V9 against the database.

## Confirmed scope {#escopo-confirmado}

**Feature 007 complete — F1 to F3, T001 to T007.** It is the MVP, and the analysis corrected this: the previous
version of the plan said F1+F3, and without F2's column the mark would say `collected, no issues` about 94
repositories of which **there is no collection record** — asserting a collection it has no way to prove.

**A false claim is not an MVP — it is a defect with less code.**

The only cut that produces an honest state is **F1 alone**: 135 queries become 1, the screen gets
faster, and nothing changes visibly.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| sort or filter the list by work | not requested; the mark solves the scan |
| mark on the sync screen | there the repository is an execution phase — FR-013 |
| the mark stating the observation state | the `state` column already says it — FR-004 |
| `<.work_mark>` component | only one caller; the second justifies it — R1 |
| count that changes with the screen open | the screen is not live; reloading solves it — edge case 4 |
| create the `Epic` and `User Story` types in the organization | changes the organization's configuration; maintainer's decision |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **the mark deciding by the date before the count** | order in FR-005a; V9 measures the 41 on the real data; a test that gives issues without a date and requires `N issues` |
| storing the date for some repositories and not others | store at the **same point** as the checkpoint; a test requires both together |
| `{:error, :not_found}` bringing down the collection phase | T004 logs and moves on; a test deletes the repository before marking |
| column and mark disagreeing | one query, one map, two readers — FR-010, SC-007 |
| mark by color only | shape and text mandatory; a test removes the color |
| the switch to "in force" changing a number silently | in the real data no issue is not in force; the change is declared in R3 |

**Branch dependency**: this feature uses the design system and `stacked`, which live on the branch
`007-interface-em-ingles` — [PR #184](https://github.com/The-Band-Solution/theband/pull/184),
**awaiting human review**. This feature's branch is `008-marca-de-issues` and comes out of there; if
#184 is not merged, this work goes along with it.

The branch number differs from the spec directory on purpose, and is explained in R5 of the research.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] `mix gates` green by **exit code** — ten gates, on `main` (`277d159`)
- [x] valid knowledge base, with the Python validator actually run — 96 artifacts
- [x] V1 to V9 verified, **except V7** (360 px): SC-009 declared **not verified** in the acceptance
- [x] V9 measured **on the real data**: the 41 appear with work; the largest has 2,514 issues and no date
- [x] the seven issues closed
- [x] PR [#195](https://github.com/The-Band-Solution/theband/pull/195) with reviewer `the-band` **checked** via `requested_reviewers`, linked to the project
- [x] [`sprint-review.md`](sprint-review.md) written, separating done from not done
- [x] `licoes-aprendidas.md` updated — L32 and L33
- [x] [`aceitacao.md`](../../../specs/007-marca-de-issues/aceitacao.md) — 11 SC assessed one by one
