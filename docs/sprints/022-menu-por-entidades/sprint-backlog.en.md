# Sprint 022 — Menu by entities {#sprint-022--menu-por-entidades}

**Period**: 2026-08-28 to 2026-09-03
**Feature**: [046-menu-por-entidades](../../../specs/046-menu-por-entidades/spec.md)
**Plan**: [plan.md](../../../specs/046-menu-por-entidades/plan.md)

## Sprint goal {#objetivo-do-sprint}

Navigation now says what each thing is: a main bar with the entities
(People, Teams, Projects, Organization), the rest under Settings with three sections — and the
Organization screen is born, closing the mirror between the menu and the access scopes.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md), considered in this sprint:

| Lesson | Origin | How it is being applied |
|---|---|---|
| L60 | Sprint 016 | gates read by redirecting to a file, never `\| tail`; T001 and T011 carry the form in their statement |
| L61 | Sprint 021 | the limitation "a project has no declared link to an organization" became a branch in the code (group "no organization identified") and a sentence on the screen — research R3, T008/T009 |
| L38 | Sprint 009 | the Organization screen reads through **one** aggregate query (`organization_overview/1`), not a query per row; the T008 test covers the form |
| L03 | Sprint 001 | the T008 tests exercise the violation (leak between tenants), not just the happy path |
| L02/L20 (family) | — | the T010 check compares the screen with the source database before declaring a number correct |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 022 — Menu por entidades · 2026-08-28 · 7 days — *see limitation below*
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Recorded limitations (inherited from previous sprints, not improvised):**

- The issue types `Epic` and `User Story` **do not exist** in the organization (only Task,
  Bug, Feature). Creating them changes the organization's configuration and requires the
  maintainer's approval — issues remain untyped, as in sprints 003–021, and the divergence
  is recorded here.
- The `Iteration` field exists in the project with only Sprints 001 and 002 (completed);
  sprints 003–021 did not create iterations. An attempt to add this sprint's iteration is
  recorded below the result — if the mutation is not accepted, the limitation remains.
- Hierarchy through sub-issues is not used in the repository; a task references the US in
  its body, as in previous sprints.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Type | Epic | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|---|
| US1 | The bar becomes entities + Settings | (untyped — limitation) | — | [#529](https://github.com/The-Band-Solution/theband/issues/529) | P1 | 5 | 6 |
| US2 | Work carries the views as sub-tabs | (untyped) | — | [#530](https://github.com/The-Band-Solution/theband/issues/530) | P2 | 3 | 3 |
| US3 | Organization screen in the main menu | (untyped) | — | [#531](https://github.com/The-Band-Solution/theband/issues/531) | P3 | 5 | 3 |

`Priority` is the SRO *importance* — value to the organization. `Estimate` is the
*complexity* — difficulty for the team. A blank field means unknown, not zero.

## Tasks {#tarefas}

| # | Task | Serves | Type | Issue | Estimate | State |
|---|---|---|---|---|---|---|
| T001 | Open the branch and record the gates baseline | US1 | Task | [#532](https://github.com/The-Band-Solution/theband/issues/532) | 1 | done |
| T002 | Helper for the menu's active area | US1 | Task | [#533](https://github.com/The-Band-Solution/theband/issues/533) | 2 | done |
| T003 | Reorganize the main bar | US1 | Task | [#534](https://github.com/The-Band-Solution/theband/issues/534) | 3 | done |
| T004 | Settings menu with three sections and gating | US1 | Task | [#535](https://github.com/The-Band-Solution/theband/issues/535) | 3 | done |
| T005 | Old routes respond unchanged | US1 | Task | [#536](https://github.com/The-Band-Solution/theband/issues/536) | 2 | done |
| T006 | Sub-tabs component | US2 | Task | [#537](https://github.com/The-Band-Solution/theband/issues/537) | 2 | done |
| T007 | Sub-tabs on the six screens | US2 | Task | [#538](https://github.com/The-Band-Solution/theband/issues/538) | 2 | done |
| T008 | Aggregate read of the organization | US3 | Task | [#539](https://github.com/The-Band-Solution/theband/issues/539) | 3 | done |
| T009 | Organization screen with named empty states | US3 | Task | [#540](https://github.com/The-Band-Solution/theband/issues/540) | 3 | done |
| T010 | Number checked against the source | US3 | Task | [#541](https://github.com/The-Band-Solution/theband/issues/541) | 1 | done |
| T011 | Green gates and viewport evidence | US3 | Task | [#542](https://github.com/The-Band-Solution/theband/issues/542) | 1 | done |

A task does not get a `Priority`: it inherits the one of the user story it serves. T001/T002 serve
US1 because they enable the MVP; T011 closes the sprint and sits under the last US by convention.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started)

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **Spec 045 (authentication and access scopes)** in full: specified and prototyped,
  it awaits its own sprint. The Operation gating in this sprint uses the model in force
  (`users.role == "admin"`) and 045 extends it later at a single point (research R5).
- **Issue types and hierarchy on GitHub**: depend on approval to change the
  organization's configuration (limitation above).
- **project→organization FK**: research R3 rejected the migration; the link is through
  `source_instance`, with the limitation declared on the screen.

## Risks and dependencies {#riscos-e-dependências}

- `source_instance` may not match the organizations' logins in the real data — T010
  measures it and the result goes in as evidence; divergence blocks US3, it is not an
  observation (research R3).
- GitHub's secondary rate limit delayed the creation of the issues — links marked
  `pendente` (pending) are updated as soon as they are created; no link is invented.

## Sprint Definition of Done {#definition-of-done-do-sprint}

In addition to the per-task DoD:

- [x] quality gates green (`mix gates` with output read from the log, L60)
- [x] knowledge base valid
- [x] issues closed or reprioritized with justification
- [x] `sprint-review.md` written
- [x] `licoes-aprendidas.md` updated
