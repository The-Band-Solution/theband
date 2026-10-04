# Sprint 017 — Boards, fields and backlogs {#sprint-017--quadros-campos-e-backlogs}

**Period**: 2026-08-16 onwards
**Feature**: [004](../../../specs/004-issues-e-projetos/spec.md), phase F7 (convergence of F4)
**Plan**: [plan.md](../../../specs/004-issues-e-projetos/plan.md)

## Sprint goal {#objetivo-do-sprint}

The platform starts to see whole boards — entity, fields and values per item —
and to derive the two backlogs; and the decision to exclude a repository gets the path on the
screen that had been missing since 004.

## Where this sprint came from {#de-onde-este-sprint-veio}

F4 of feature 004 was specified and not implemented; feature 024 delivered the
iterations by its own path (`sro_sprints`, 220 iterations, 2,225 links). The
convergence of 2026-08-16 measured the spec against the code and wrote the eleven tasks that
are missing — **reconciling, never redoing**: the started-iteration→sprint promotion, the
`campo:iteração` identity and the idempotency of 024 stay.

What this closes and unblocks: it closes [#181](https://github.com/The-Band-Solution/theband/issues/181)
and [#107](https://github.com/The-Band-Solution/theband/issues/107); it unblocks
[#180](https://github.com/The-Band-Solution/theband/issues/180) (map field→attribute),
[#317](https://github.com/The-Band-Solution/theband/issues/317) (suggest role) and the
Conecta Fapes question about what *done* is
([#367](https://github.com/The-Band-Solution/theband/issues/367)), which depends on the
`Status` field — not collected today.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md):

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L11** | Sprint 002 | configuring iterations **recreates the existing ones** and cost reassigning 96 items. This sprint **does not create an iteration** — collection is reading; the limitation of its own iteration is declared below |
| **L19** | Sprint 003 | T053's absence mark is **per board observed in the run**, never per tenant — marking per tenant would hit boxes the run did not look at |
| **L26** | Sprint 006 | an organization without boards (T055) is an **answer**, never a silent empty list |
| **L57** | Sprint 015 | the new tables are born with a consumer in the same sprint (T057 is the screen) — a type nobody produces and a check nobody reaches are the same defect |
| **L59/L60** | Sprint 015/016 | gates always via `mix gates > log; ec=$?; exit $ec` — never a pipe, never `echo EXIT=$?` in the background |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: **not created, and that is a decision** — L11 records that configuring ProjectV2
iterations recreates the existing ones. The project has a single iteration (`Sprint 002`), and
creating the one for 017 would risk reassigning everything again. The issues enter the board with `Status: Ready`
and without an iteration; [#176](https://github.com/The-Band-Solution/theband/issues/176) is the
pending decision about that cost.
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)
**Types**: `Epic` and `User Story` do not exist in the organization; creating them changes the org's
configuration and awaits the maintainer's confirmation. The tasks are `Task`, children of the user
stories by sub-issue — the hierarchy carries what the type does not say.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Type | Issue | Priority | Criteria |
|---|---|---|---|---|---|
| US2 (004) | See the boards and what each item carries | no type of its own | [#107](https://github.com/The-Band-Solution/theband/issues/107) | P2 | FR-020…FR-032b, SC-008, SC-009\* |
| US3 (004) | Restrict which repositories are observed | no type of its own | [#108](https://github.com/The-Band-Solution/theband/issues/108) | P3 | FR-005, FR-006 |

## Tasks {#tarefas}

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T047 | The board entity, without promoting | US2 | [#373](https://github.com/The-Band-Solution/theband/issues/373) | done |
| T048 | The definitions of the configurable fields | US2 | [#374](https://github.com/The-Band-Solution/theband/issues/374) | done |
| T049 | The items of each board, linked to the issues | US2 | [#375](https://github.com/The-Band-Solution/theband/issues/375) | done |
| T050 | The draft is recorded, not discarded | US2 | [#376](https://github.com/The-Band-Solution/theband/issues/376) | done |
| T051 | The value of each field on each item | US2 | [#377](https://github.com/The-Band-Solution/theband/issues/377) | done |
| T052 | A future iteration becomes an intended process | US2 | [#378](https://github.com/The-Band-Solution/theband/issues/378) | done |
| T053 | The removed sprint is marked, never deleted | US2 | [#379](https://github.com/The-Band-Solution/theband/issues/379) | done |
| T054 | The two derived backlogs, and the sum proves it | US2 | [#380](https://github.com/The-Band-Solution/theband/issues/380) | done |
| T055 | An organization without boards is an answer | US2 | [#381](https://github.com/The-Band-Solution/theband/issues/381) | done |
| T056 | The broadened GraphQL queries | US2 | [#382](https://github.com/The-Band-Solution/theband/issues/382) | done |
| T057 | The boards and backlogs screen | US2 | [#383](https://github.com/The-Band-Solution/theband/issues/383) | done |
| T058 | The control to exclude a repository on the screen | US3 | [#384](https://github.com/The-Band-Solution/theband/issues/384) | done |

A task does not get a `Priority`: it inherits the one of the user story it serves. `Estimate` stays blank
— unknown, never zero.

## Out of this sprint's scope {#fora-do-escopo-deste-sprint}

| What | Issue | Why |
|---|---|---|
| Map a board field to an ontology attribute (US3 of F6, T041–T044) | [#180](https://github.com/The-Band-Solution/theband/issues/180) | depends on the fields **existing** — T048 and T051 are the prerequisite. Goes into the next sprint |
| Suggest a role from evidence | [#317](https://github.com/The-Band-Solution/theband/issues/317) | new functionality, unblocked but not pulled |
| Competence as the unit of the profile | [#363](https://github.com/The-Band-Solution/theband/issues/363)/[#364](https://github.com/The-Band-Solution/theband/issues/364) | new functionality — maintainer's decision: *later* *(original: "depois")* |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Why | What to do |
|---|---|---|
| **Volume of items** | DevOps has 677 items in 7 pages; now they come with field values — the response grows | pagination already exists; the real cost shows up on the first collection and becomes a measurement |
| **Migrating `sro_sprints` to point to the board** | 220 live iterations; getting the link wrong loses the 2,225 links | the migration links by `board_number` + organization, and the reproducibility gate runs before and after |
| **Independent review** | the four PRs of 2026-08-16 went in without human review | request it from the `the-band` team when opening, check `reviewRequests`, and **declare** the gap if it persists |

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] the 12 issues closed, or reprioritized with a written justification
- [ ] `mix gates` with exit code 0 — `> log; ec=$?; exit $ec`, never a pipe
- [ ] SC-009b proven by a test: product + sprints = total items
- [ ] real collection run and measured (The Band board has 17 fields and 107 items)
- [ ] PR with a reviewer requested from the `the-band` team, request **checked**
- [ ] `sprint-review.md` written, separating delivered from not delivered
- [ ] `licoes-aprendidas.md` updated
- [ ] the independent review gap **declared**, if it persists
