# Sprint 026 — Inheritance and production {#sprint-026--herança-e-a-produção}

**Period**: 2026-08-29 to 2026-09-05 — **closed on 2026-09-01** ([review](sprint-review.md))
**Inheritance**: rework of US [#573](https://github.com/The-Band-Solution/theband/issues/573)
and [#598](https://github.com/The-Band-Solution/theband/issues/598)
(acceptance of [sprint 025](../025-contas-e-o-elo-do-github/aceitacao.md))
**Feature**: [050-em-producao](../../../specs/050-em-producao/spec.md) ·
[plan](../../../specs/050-em-producao/plan.md) ·
[pipeline contract](../../../specs/050-em-producao/contracts/pipeline-de-release.md)

## Sprint goal {#objetivo-do-sprint}

First the inheritance, in the class and not in the specimen: the origin-function phrases pass
through the edge (T014) and the search states organization and ended observation (T009). Then
production is born in the repository: image, CD on push to `main` (Gitflow 1.7.0) and the
Dokploy runbook — leaving the first release three human milestones away.

## Lessons applied {#lições-aplicadas}

| Lesson | Origin | How it is being applied |
|---|---|---|
| L81 | Sprint 025 | T014 closes with the SIBLING HUNT through the form `(erro\|ok\|error\|aviso): funcao(` — executed, zero remaining |
| L82 | Sprint 025 | the comment that contradicted the contract was removed, and the contract gained the note of the violation with date and reason (T009) |
| L71 | Sprint 022 | the invariants of the phrases (position, unit in steps) changed vehicle along with the requirement — proven in the catalog |
| L60/L03/L38 | — | EXIT in the log in every gate and in the CD; violations first (docker run without env, repeated tag); batch reads |
| L72 | Sprint 023 | iteration 026 was born through the complete dance: 53 values captured, recreated, reassigned and checked (53/53, 0 failures) |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 026 — Herança e a produção · id `46704707`
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) — 14
items (2 inheritance tasks + 2 PRs + 3 US and 7 tasks from 050).

## The inheritance — first in the queue (delivered in this opening) {#a-herança--primeira-da-fila-entregue-nesta-abertura}

| # | Task | Serves | Issue | PR | State |
|---|---|---|---|---|---|
| 047/T014 | The origin-function phrases pass through the edge | #573 | [#617](https://github.com/The-Band-Solution/theband/issues/617) | [#630](https://github.com/The-Band-Solution/theband/pull/630) | done — merged on 2026-08-30 |
| 051/T009 | The search states the organization and the ended observation | #598 | [#618](https://github.com/The-Band-Solution/theband/issues/618) | [#631](https://github.com/The-Band-Solution/theband/pull/631) | done — merged on 2026-08-30 |
| 047/T015 | The verifier sees the origin-function class (one-node hop) | #573 | [#634](https://github.com/The-Band-Solution/theband/issues/634) | [#635](https://github.com/The-Band-Solution/theband/pull/635) | done — PR opened on 2026-08-31 |

## User stories of 050 {#user-stories-da-050}

| # | User story | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|
| US1 | The platform at a stable address | [#620](https://github.com/The-Band-Solution/theband/issues/620) | P1 | 8 | 5 |
| US2 | The data survives | [#621](https://github.com/The-Band-Solution/theband/issues/621) | P2 | 5 | 3 |
| US3 | Production refuses the development regime | [#622](https://github.com/The-Band-Solution/theband/issues/622) | P2 | 3 | 3 |

## Tasks of 050 {#tarefas-da-050}

| # | Task | Serves | Issue | Estimate | State |
|---|---|---|---|---|---|
| T001 | Open the gates baseline | US1 | [#623](https://github.com/The-Band-Solution/theband/issues/623) | 1 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |
| T002 | The image, through the violation | US1 | [#624](https://github.com/The-Band-Solution/theband/issues/624) | 3 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |
| T003 | CI builds the image when it changes | US1 | [#625](https://github.com/The-Band-Solution/theband/issues/625) | 1 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |
| T004 | The CD workflow according to the contract | US1 | [#626](https://github.com/The-Band-Solution/theband/issues/626) | 3 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |
| T005 | The Dokploy runbook on Contabo | US1 | [#627](https://github.com/The-Band-Solution/theband/issues/627) | 3 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |
| T006 | The restore rehearsal, written to be executed | US2 | [#628](https://github.com/The-Band-Solution/theband/issues/628) | 2 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |
| T007 | Green gates and PR to the standard | US2/US3 | [#629](https://github.com/The-Band-Solution/theband/issues/629) | 1 | done — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), merged on 2026-08-30 |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **The three milestones with people** (plan §Marcos): create the VPS at Contabo + install
  Dokploy; the secrets (the contract's CLOSED list) in GitHub Secrets and in the panel; the
  first release PR `development → main` (Product Owner, FR-016). The sprint
  leaves EVERYTHING on the repository side ready; the milestones happen when the maintainer
  does them — and the first release measures SC-001/002/004/005.
- **049** (depends on the public address) and **#568** (no spec).

## Risks and dependencies {#riscos-e-dependências}

- The webhook step is only truly proven in the first release — the contract requires
  `--fail` and the documented rehearsal; until then it is dry-run/actionlint.
- bcrypt_elixir compiles a NIF: builder and runtime on the SAME glibc base (contract) — the
  quickstart §2 catches divergence before any VPS.
- Review requested on opening in the sprint's four PRs; merges by the maintainer.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] quality gates green on the branches (L60, EXIT in the log) — 14/14, `EXIT=0` on 2026-09-01
- [x] knowledge base valid — 120 YAML, 14 ontologies, 238 concepts
- [ ] issues #617–#618, #620–#629 closed AFTER acceptance — #617, #618 and #634
      closed; **#620–#629 remain open**, awaiting confirmation of the
      [acceptance record](aceitacao.md)
- [x] `sprint-review.md` written — [here](sprint-review.md)
- [x] `licoes-aprendidas.md` updated — L83 to L90
- [ ] PRs with review requested on opening and on the board — **NOT met**: six of the nine
      PRs were merged without a reviewer requested, and none of the nine has a
      recorded review (L89)
