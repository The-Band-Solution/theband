# Sprint 023 — Authentication and access {#sprint-023--autenticação-e-acesso}

**Period**: 2026-08-28 to 2026-09-04
**Feature**: [045-autenticacao-e-acesso](../../../specs/045-autenticacao-e-acesso/spec.md)
**Plan**: [plan.md](../../../specs/045-autenticacao-e-acesso/plan.md)

## Sprint goal {#objetivo-do-sprint}

The platform gains a door and gradation: signing in requires an e-mail or GitHub username with
a password; the view is the union of the scopes — person at the floor, team/project derived or
granted, organization granted — administering stops being the same as seeing; and Syncs/Tools/AI
only exist for those who administer or answer for an organization. The axiom:
**a person has access to the data they are related to.**

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md), considered in this sprint:

| Lesson | Origin | How it is being applied |
|---|---|---|
| L60 | Sprint 016/022 | full form in T001/T014: `mix gates > log 2>&1; echo "EXIT=$?" >> log` — verdict INSIDE the log |
| L71 | Sprint 022 | directed search done in the plan ("Busca dirigida — testes do requisito antigo"): 4 revoked invariants mapped to a destination before the code |
| L03 | Sprint 001 | every security test starts from the violation: ambiguous username, revoked link, dead session, leak between tenants, org A seeing org B's tool |
| L38 | Sprint 009 | `Access.scopes/2` in fixed passes per collection; the contract forbids query-per-row |
| L61 | Sprint 021 | limitations become branches: an account without a password refuses with guidance; derived closes with the fact |
| Contract first (memory/constitution VI) | — | `contracts/auth.md` and `contracts/access-scopes.md` written before T004/T005 |
| Clean baseline (022) | Sprint 022 | T001 requires the gates run to be FINISHED before any edit |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 023 — Autenticação e acesso · 2026-08-29 · 7 days (id `a61c4aa5`)
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Recorded incident**: when creating the iteration, the mutation
`updateProjectV2Field.iterationConfiguration` replaced the entire active list and
deleted the Sprint 022 iteration — its 15 items were left without an Iteration. Repaired on the
spot: both iterations recreated (022 with its real duration of 1 day) and the 15 items
reassigned, checked by query. The lesson goes to this sprint's closing:
**the list of iterations is replaced as a whole; always resend the ones in force**.

**Inherited limitations**: types `Epic`/`User Story` remain nonexistent in the organization
(creating them requires approval); hierarchy through sub-issues is not used — a task references the US in
its body.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Type | Epic | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|---|
| US1 | Sign in with e-mail or GitHub username, and sign out | (untyped — limitation) | — | [#545](https://github.com/The-Band-Solution/theband/issues/545) | P1 | 8 | 8 |
| US2 | Cumulative access scopes | (untyped) | — | [#546](https://github.com/The-Band-Solution/theband/issues/546) | P1 | 8 | 11 |
| US3 | Configure one's own profile | (untyped) | — | [#547](https://github.com/The-Band-Solution/theband/issues/547) | P2 | 3 | 5 |

`Priority` is the SRO *importance*; `Estimate` is the *complexity*. Blank =
unknown, not zero.

## Tasks {#tarefas}

| # | Task | Serves | Type | Issue | Estimate | State |
|---|---|---|---|---|---|---|
| T001 | Open the branch and record the gates baseline | US1 | Task | [#548](https://github.com/The-Band-Solution/theband/issues/548) | 1 | done |
| T002 | bcrypt_elixir dependency with justification | US1 | Task | [#549](https://github.com/The-Band-Solution/theband/issues/549) | 1 | done |
| T003 | Migrations: credential and grants | US1 | Task | [#550](https://github.com/The-Band-Solution/theband/issues/550) | 3 | done |
| T004 | Domain authentication per the contract | US1 | Task | [#551](https://github.com/The-Band-Solution/theband/issues/551) | 5 | done |
| T005 | Domain scopes per the contract | US2 | Task | [#552](https://github.com/The-Band-Solution/theband/issues/552) | 5 | done |
| T006 | Prototype's login screen and real session | US1 | Task | [#553](https://github.com/The-Band-Solution/theband/issues/553) | 3 | done |
| T007 | Session validated by token and expiration | US1 | Task | [#554](https://github.com/The-Band-Solution/theband/issues/554) | 3 | done |
| T008 | Accounts: create and reset password (admin) | US1 | Task | [#555](https://github.com/The-Band-Solution/theband/issues/555) | 3 | done |
| T009 | Grants screen with declared derived scopes | US2 | Task | [#556](https://github.com/The-Band-Solution/theband/issues/556) | 3 | done |
| T010 | The single verdict on the person screens | US2 | Task | [#557](https://github.com/The-Band-Solution/theband/issues/557) | 3 | done |
| T011 | Operational screens restricted and filtered (FR-023) | US2 | Task | [#558](https://github.com/The-Band-Solution/theband/issues/558) | 3 | done |
| T012 | Profile screen | US3 | Task | [#559](https://github.com/The-Band-Solution/theband/issues/559) | 3 | done |
| T013 | Check against the source and evidence | US3 | Task | [#560](https://github.com/The-Band-Solution/theband/issues/560) | 1 | done |
| T014 | Green gates and closing | US3 | Task | [#561](https://github.com/The-Band-Solution/theband/issues/561) | 1 | done |

A task does not get a `Priority`: it inherits the one of the user story it serves.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started)

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **Password recovery by e-mail** — there is no e-mail sending; the path is a reset by
  whoever administers (spec assumption).
- **Self-registration / invitation by link** — sign-up remains an administrative act.
- **Issue types and hierarchy on GitHub** — approval pending.
- **Multiple management roles / transfer of "owner"** — organization by
  grant covers today's case (assumption).

## Risks and dependencies {#riscos-e-dependências}

- Reworking `Visibility` (FR-022) touches an access rule in force — the regression of
  FR-018 (a declared leader keeps seeing) is the most tested violation of the sprint.
- The `log_in/2` helper feeds ~hundreds of tests: T007 changes its contract; the whole
  suite is the regression test.
- The seed migration depends on organizations observed per tenant — empty tenants yield
  0 grants (correct: nothing to preserve).

## Sprint Definition of Done {#definition-of-done-do-sprint}

In addition to the per-task DoD:

- [x] quality gates green (L60's full form, EXIT in the log) — 13/13, EXIT=0
- [x] knowledge base valid (part of the gates)
- [x] issues closed or reprioritized with justification — #548–#561 closed;
      the FR-008 slice reprioritized as [#568](https://github.com/The-Band-Solution/theband/issues/568)
- [x] `sprint-review.md` written
- [x] `licoes-aprendidas.md` updated (iteration incident included — L72)
