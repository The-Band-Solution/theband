# Sprint 025 — Accounts and the GitHub link {#sprint-025--contas-e-o-elo-do-github}

**Period**: 2026-08-29 to 2026-09-05
**Inheritance**: rework of 047's US1/US2 (refused at the
[sprint 024 acceptance](../024-mensagens-e-o-botao-da-chave/aceitacao.md))
**New feature**: [051-cadastro-por-github](../../../specs/051-cadastro-por-github/spec.md)
**Plan**: [051/plan.md](../../../specs/051-cadastro-por-github/plan.md)

## Sprint goal {#objetivo-do-sprint}

First the inheritance: the "rendered message assign" class goes into the catalog and the
checker, truly closing 047's US1/US2. Then 051: `/accounts` becomes the
single onboarding area — register the person (name, e-mail, temporary password on the spot) and
link the GitHub account there, through the stable identity.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md):

| Lesson | Origin | How it is being applied |
|---|---|---|
| L80 | Sprint 024 | the rework widens the checker BY AST and redoes the leftovers with independent sampling — never grep validating itself |
| L76 | Sprint 024 | the assign class is counted by AST before sizing (T012) |
| L77 | Sprint 024 | the widened checker gains an end-to-end test that does not go through it |
| L60/L03/L38/L71 | — | the usual ones: EXIT in the log; violation first; read by join, never per row; tests of the changing requirement mapped in 051's plan |
| L72 refined | Sprint 025 (opening) | iteration 025 was created by resending the active ones; the 15 values of 022 were lost unrecoverably — the record of membership is the backlog in the repository |
| L79 | Sprint 024 | acceptance agent with an explicit order not to switch branches |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 025 — Contas e o elo do GitHub · id `23bb051e`
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) —
12 items (10 from 051 + 2 from the rework), Estimate/Priority filled in.

**Recorded limitation (L72 refined)**: the Sprint 022 items lost their
iteration value when the active list was recreated — the API refuses to reassign the completed
iteration. Their membership is in 022's sprint-backlog.

## The inheritance — first in the queue {#a-herança--primeira-da-fila}

| # | Task | Serves | Issue | Estimate | State |
|---|---|---|---|---|---|
| 047/T012 | The assign class goes into the catalog and the checker | 047/US1+US2 (#573, #574) | [#609](https://github.com/The-Band-Solution/theband/issues/609) | 3 | done |
| 047/T013 | Leftovers with independent sampling, and the US3 text | 047/US2+US3 | [#610](https://github.com/The-Band-Solution/theband/issues/610) | 2 | done |

## 051's user stories {#user-stories-da-051}

| # | User story | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|
| US1 | Register the person: name and e-mail | [#597](https://github.com/The-Band-Solution/theband/issues/597) | P1 | 3 | 3 |
| US2 | Link the GitHub account, in the same area | [#598](https://github.com/The-Band-Solution/theband/issues/598) | P1 | 5 | 5 |

## 051's tasks {#tarefas-da-051}

| # | Task | Serves | Issue | Estimate | State |
|---|---|---|---|---|---|
| T001 | Open the gates baseline | US1 | [#599](https://github.com/The-Band-Solution/theband/issues/599) | 1 | done |
| T002 | Transactional registration with a temporary password, from the violation | US1 | [#600](https://github.com/The-Band-Solution/theband/issues/600) | 2 | done |
| T003 | The narrow read of the conflict | US2 | [#601](https://github.com/The-Band-Solution/theband/issues/601) | 1 | done |
| T004 | Registration on the screen, with the show-once temporary password | US1 | [#602](https://github.com/The-Band-Solution/theband/issues/602) | 2 | done |
| T005 | The list says who has GitHub, in one query | US2 | [#603](https://github.com/The-Band-Solution/theband/issues/603) | 2 | done |
| T006 | Link with search, and the named conflict | US2 | [#604](https://github.com/The-Band-Solution/theband/issues/604) | 3 | done |
| T007 | Revoke in the area, and login follows | US2 | [#605](https://github.com/The-Band-Solution/theband/issues/605) | 2 | done |
| T008 | Green gates and PR following the standard | US2 | [#606](https://github.com/The-Band-Solution/theband/issues/606) | 1 | done |

A task does not get a `Priority`: it inherits the one of the user story it serves.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **050 (production)** — postponed by decision; **049** depends on it; **#568** has no spec.
- Burning down the other screens of `pendencias.md` (the one redone in T013) — future sprints.
- Complete pt translation — gaps visible through the report.

## Risks and dependencies {#riscos-e-dependências}

- The rework widens the checker: the gate may be born red again if the
  sweep of the assign class finds more than the ~9 mapped — the right number comes from the
  AST (L76), and the sizing accepts growing.
- Declared order: rework (its own PR) BEFORE 051 — the two touch
  different screens, but the widened checker must apply to 051's new code.
- Review BEFORE the merge this time — 024's violation does not repeat: this
  sprint's PRs request review when opened.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] quality gates green on the branches (L60 form, EXIT in the log) — 14/14 on both
- [x] knowledge base valid (part of the gates)
- [x] issues #597–#606, #609–#610 closed AFTER acceptance was confirmed (right order)
- [x] `sprint-review.md` written
- [x] `licoes-aprendidas.md` updated — L81, L82
- [x] PRs with review requested on opening (+1s, timeline) and inside the board
