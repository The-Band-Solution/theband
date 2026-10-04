# Sprint 008 — the inaccessible mark heals {#sprint-008--a-marca-de-inacessível-se-cura}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [009 — mark that heals](../../../specs/009-marca-que-se-cura/spec.md)
**Plan**: [plan.md](../../../specs/009-marca-que-se-cura/plan.md)
**Origin**: [#213](https://github.com/The-Band-Solution/theband/issues/213) and
[#214](https://github.com/The-Band-Solution/theband/issues/214), **Bug, P0**
**Analysis**: run before the code, **six corrections**, one of them critical

## Sprint goal {#objetivo-do-sprint}

At the end of this sprint, **899 issues are reached again** — and the next outage does not go by
silently.

A momentary network failure took 39 repositories out of the collection. Two collections completed after
that and **none cleared anything**, because the inaccessible repository is filtered **before** the phase that
would clear the mark.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), 35 lessons. The ones that enter as a **constraint**:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L05** | Sprint 001 | it is the lesson the analysis brought back: `inaccessible_reason` is `varchar(255)` with **27 characters of slack**, and a diagnostic column has no arbitrary limit. T001 |
| **L28** | Sprint 005 | "the function classifies" and "the repository is not marked" are different claims: T003 is the end-to-end test, with an assertion **in the database** |
| **L29** | Sprint 005 | it is the defect this feature corrects, and the second time it appears |
| **L30** | Sprint 005 | the numbers come from the source and the database, not from estimates — and measuring the cost (`cost = 1`, 160 of 5,000) took down a suspicion |
| **L32** | Sprint 006 | zero in `repositories_unreachable` **asserts** that everything was reached; that is why the number is incremented at each failure, and not at the end |
| **L34** | Sprint 007 | "inaccessible" covered two things — a tenant decision and a platform inference — and `list_collectable/2` treated the two as one |
| **L35** | Sprint 007 | **it is the corollary that opened this sprint**: *a cure that presupposes a step the filter prevents is not a cure* |
| L08, L18, L22, L23, L27 | 002 to 005 | contract before the function; acceptance with evidence per criterion; gate by exit code; full cycle before the code |

**L35 is the reason this sprint exists**, and it was written two hours ago. The L29 correction
declared *"the cure is the collection itself — reached it, clears it"*, and the L35 corollary asks to check whether
the cure's path is **reachable**. It was not.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration**: **does not exist for this sprint** — a declared limitation, not forgetfulness. Configuring
ProjectV2 iterations recreates the existing ones (L11), and it has already cost reassigning 96 items.

**Types**: the organization has `Task`, `Bug` and `Feature`. Epic and user stories are typed `Feature`.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | The collection reaches again what failed | [#216](https://github.com/The-Band-Solution/theband/issues/216) | [#217](https://github.com/The-Band-Solution/theband/issues/217) | **P0** | 11 | done |
| US2 | A momentary failure does not become a permanent decision | [#216](https://github.com/The-Band-Solution/theband/issues/216) | [#218](https://github.com/The-Band-Solution/theband/issues/218) | **P0** | 8 | done |
| US3 | See since when it is not reached, and why | [#216](https://github.com/The-Band-Solution/theband/issues/216) | [#219](https://github.com/The-Band-Solution/theband/issues/219) | P1 | 5 | done |

**US1 and US2 are P0**: while they are not in, 899 issues are out of every future collection and the
number grows on its own.

## Tasks {#tarefas}

Detailed in [009/tasks.md](../../../specs/009-marca-que-se-cura/tasks.md). Each task is a child of the
**user story it serves** — never of the epic.

| # | Task | Serves | Issue | Estimate | Phase | State |
|---|---|---|---|---|---|---|
| T001 | Remove the limit from the reason column | US2 | [#220](https://github.com/The-Band-Solution/theband/issues/220) | 2 | F1 | done |
| T002 | Judge the nature of the source's error | US2 | [#221](https://github.com/The-Band-Solution/theband/issues/221) | 5 | F1 | done |
| T003 | Do not mark on a momentary failure | US2 | [#222](https://github.com/The-Band-Solution/theband/issues/222) | 2 | F1 | done |
| T004 | Try the marked repository again | US1 | [#223](https://github.com/The-Band-Solution/theband/issues/223) | 3 | F2 | done |
| T005 | Preserve since when it has not been reached | US1 | [#224](https://github.com/The-Band-Solution/theband/issues/224) | 2 | F2 | done |
| T006 | Clear the mark on reaching it | US1 | [#225](https://github.com/The-Band-Solution/theband/issues/225) | 2 | F2 | done |
| T007 | Complete even with everything failing | US1 | [#226](https://github.com/The-Band-Solution/theband/issues/226) | 3 | F2 | done |
| T008 | Count the repositories not reached | US3 | [#227](https://github.com/The-Band-Solution/theband/issues/227) | 3 | F3 | done |
| T009 | Say since when, and why | US3 | [#228](https://github.com/The-Band-Solution/theband/issues/228) | 2 | F3 | done |

**Total: 24 of complexity, nine tasks.**

## What the analysis changed, before the code {#o-que-a-análise-mudou-antes-do-código}

| # | Finding | Correction |
|---|---|---|
| **A1** | `inaccessible_reason` is `varchar(255)`; the real reason comes to **~228** with the prefix, and the largest stored today has 181. Without `validate_length`, the long value goes to the database and **raises** — and the collection's error handling covers an invalid changeset, not an exception. **The phase goes down** | T001: the column becomes `text`, truncation at the edge |
| A2 | SC-001 said "zero of the 39", and it was unverifiable | "no repository **that the source reaches**" |
| A3 | the number of unreached stored at the end would leave **zero** in an interrupted collection | increment at each failure — the checkpoint rule |
| A4 | the justification for the F1→F2 order was **false** | F1 stops the bleeding, F2 heals; preferred order, not a dependency |
| A5 | "33 of the 39 have zero issues" was measured with a credential different from the platform's | declared limitation; the cost is a **floor** |
| A6 | the reason went to the screen without a limit | truncated on display, complete in the `title` |

**A1 is the finding that justifies the phase having existed**, and it is not about the feature's logic: it is about
the feature **multiplying the frequency** of a write that was already 27 characters away from bringing down the
collection.

## Confirmed scope {#escopo-confirmado}

**Feature 009 complete — F1 to F3, T001 to T009.**

**The MVP is F1+F2**: the 39 return to the collection and the 899 issues are reached again. **F3 is not
optional to declare the feature complete** — without the number of unreached, the next outage
completes with success and 100%, because the denominator only counts what the platform decided to look at. That is how
this defect lived for two days.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| incident history per repository | requires an append-only event and its own information need |
| give up on a repository that has been failing for a long time | it is the defect this feature corrects |
| error classification module | the question already has a place — principle X |
| `last_attempt_at` | the sync record already dates the last attempt |
| **person detail page** | [#211](https://github.com/The-Band-Solution/theband/issues/211), with its own cycle |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **a long reason bringing down the collection phase** | T001 first: `text` column and truncation at the edge |
| zero asserting that everything was reached | increment per failure; test with total failure **and** with interruption |
| a deleted repository queried forever | `NOT_FOUND` is permanent; measured cost of 1 query per collection |
| the classification depending on third-party text | test with the **real payload**; and the cure makes the mark reversible |
| an exclusion being undone by mistake | an excluded one is **never** tried; the test counts the requests |

**No dependency on another branch.** `012-marca-que-se-cura` comes out of `main`.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] `mix gates` green by **exit code** — ten gates, on `main` (`26f8a45`), 430 tests
- [x] V1 and V4 to V9 of the [quickstart](../../../specs/009-marca-que-se-cura/quickstart.md) verified
- [ ] **V2 and V3 — on the real data**: they require the master key and the token, which belong to the maintainer.
      Declared as pending in the [acceptance](../../../specs/009-marca-que-se-cura/aceitacao.md), and the
      mechanism is measured in the database: **96 → 135** collectable repositories
- [x] the nine issues closed — #216 to #228, all `Done` in the project
- [x] PR [#230](https://github.com/The-Band-Solution/theband/pull/230) with reviewer `the-band`
      **checked** via `requested_reviewers`, linked to the project, merged at `26f8a45`
- [x] [`sprint-review.md`](sprint-review.md) written, separating done from not done
- [x] `licoes-aprendidas.md` updated — L36 and L37, and **L36 was rewritten** when the experiment
      showed that the mechanism I had published was wrong
- [x] [`aceitacao.md`](../../../specs/009-marca-que-se-cura/aceitacao.md) with the 12 SC assessed one by one

**The sprint closes with one open item and it is named**: the proof on the real data. Marking as done what
depends on a credential that is not mine would be declaring success without evidence.
