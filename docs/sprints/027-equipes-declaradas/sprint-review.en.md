# Sprint 027 — Review {#sprint-027--review}

**Period**: 2026-09-01 to 2026-09-08 · closed early on 2026-09-02
**Feature**: [055 — declared teams](../../../specs/055-equipes-declaradas/spec.md)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 15 | 13 |
| Deliverables accepted | 15 | **13 with caveat** |

The three user stories are complete in code. **No issue was closed** —
all 18 remain open at the source, and that is the first thing this review fixes.

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#687](https://github.com/The-Band-Solution/theband/issues/687) | gates baseline opened | yes |
| T002 | [#688](https://github.com/The-Band-Solution/theband/issues/688) | `eo.team_part_of_team` in the ontology, acyclic by constraint | yes |
| T003 | [#689](https://github.com/The-Band-Solution/theband/issues/689) | `eo_team_compositions` + the three invalidation columns | yes |
| T004 | [#690](https://github.com/The-Band-Solution/theband/issues/690) | recording a departure does not erase: the violation test | yes |
| T005 | [#691](https://github.com/The-Band-Solution/theband/issues/691) | `declare_team_membership/5` | yes |
| T006 | [#692](https://github.com/The-Band-Solution/theband/issues/692) | `record_team_departure/5` | yes |
| T007 | [#693](https://github.com/The-Band-Solution/theband/issues/693) | `record_team_membership_mistake/5` | yes |
| T008 | [#694](https://github.com/The-Band-Solution/theband/issues/694) | "in force" with two conditions, in the six queries | yes |
| T009 | [#695](https://github.com/The-Band-Solution/theband/issues/695) | `declare_structural_team/4` | yes |
| T010 | [#696](https://github.com/The-Band-Solution/theband/issues/696) | screen creates and says where the team came from | yes |
| T011 | [#697](https://github.com/The-Band-Solution/theband/issues/697) | refusal of the cycle of length 3 | yes |
| T012 | [#698](https://github.com/The-Band-Solution/theband/issues/698) | `compose_teams/4` and `decompose_teams/4` | yes |
| T013 | [#699](https://github.com/The-Band-Solution/theband/issues/699) | structure on both screens | yes |

**User stories**: [US1 #702](https://github.com/The-Band-Solution/theband/issues/702) ·
[US2 #703](https://github.com/The-Band-Solution/theband/issues/703) ·
[US3 #704](https://github.com/The-Band-Solution/theband/issues/704) — all three complete.

## What was not done {#o-que-não-foi-feito}

| Task | Issue | Reason | Destination |
|---|---|---|---|
| T014 | [#700](https://github.com/The-Band-Solution/theband/issues/700) | the two statements when collection and declaration disagree were never implemented. The section that exists today in `show.ex` is the one for evidence pending confirmation, which answers another question | **sprint 028**, within feature 057 — the team screen is rewritten there, and doing the two statements now would be wasted work |
| T015 | [#701](https://github.com/The-Band-Solution/theband/issues/701) | gates and PR to the standard happened; **the independent review did not** | **sprint 028**, as an entry condition for the PRs — see the caveat below |

## Deliverables accepted with caveat {#entregáveis-aceitos-com-ressalva}

**The thirteen deliverables passed the task's criteria and were incorporated without
independent review.** The four PRs — #706, #710, #712, #713 — have **2 reviewers
requested and 0 reviews** each. The merge did not wait.

Principle VII is explicit: *"Approving one's own PR, or merging without independent
review, MUST NOT happen. When independent review cannot be
obtained, the gap MUST be declared — never marked as met."*

**The gap is declared here.** T015 is not marked as done, and the condition
moves to the next sprint.

## Evidence {#evidências}

| What | Where |
|---|---|
| code on the integration line | `origin/development` — commits `c2a2df9`, `f61f5f2`, `7392deb`, `1ca621c`, `8459cfb` |
| feature functions in the code | `compose_teams`, `decompose_teams`, `record_team_departure`, `record_team_membership_mistake`, `declare_structural_team` — all in `lib/the_band/ontology/seon/eo/commands.ex` |
| PRs incorporated | [#706](https://github.com/The-Band-Solution/theband/pull/706), [#710](https://github.com/The-Band-Solution/theband/pull/710), [#712](https://github.com/The-Band-Solution/theband/pull/712), [#713](https://github.com/The-Band-Solution/theband/pull/713) |
| reviews on those PRs | **zero** — measured on 2026-09-02 with `gh pr view --json reviews` |

## Debt generated {#dívida-gerada}

**The measure ignores the team membership this sprint created.** Feature 055 delivered
`started_at`, `ended_at` and the invalidation — and `Profiles.TeamSkills` keeps reading
the evidence the source lists today. Whoever left keeps counting, and today's set of
members is applied to past months.

It is the **same defect that this feature's SC-003 forbids in the team membership**, happening in the
measure. It is already recorded in [`docs/backlog/tela-da-equipe-complexa.md`](../../backlog/tela-da-equipe-complexa.md)
and is US1 of feature 057 — the first item of sprint 028.

**An older defect, found while planning 057**: the in-force condition uses
`started_at <= data`, and `started_at` is nullable on purpose. Against null the
comparison evaluates to unknown, and the row is discarded — whoever has an unknown start
date **is not a member on any date**, with no error and no warning.
Present in `count_team_members_at/3` since this sprint. Fixed by 057's T034.

## Lessons from this sprint {#lições-deste-sprint}

Three, and the first is the one that cost the most.

### L95 — Requesting a reviewer is not obtaining a review, and the merge does not wait {#l95--pedir-revisor-não-é-obter-revisão-e-o-merge-não-espera}

The four PRs had reviewers requested and none reviewed. L89 said that a PR without a
reviewer requested is not a reviewed PR; this is the next variant — **request and move
on**. The merge button does not know the difference.

### L96 — An issue nobody closes makes the sprint look undelivered {#l96--issue-que-ninguém-fecha-faz-o-sprint-parecer-não-entregue}

Thirteen tasks completed and incorporated, **zero issues closed**. Whoever looked at the
source on 2026-09-02 would see a sprint with no delivery at all. The flow measure that the
platform exists to compute would come out wrong about its own repository.

### L97 — A feature that fixes the team membership does not fix whoever reads the team membership {#l97--feature-que-corrige-o-vínculo-não-corrige-quem-lê-o-vínculo}

055 delivered the team membership period and none of the measure queries started
using it. The defect was born **in the same sprint** that created the data to avoid it, and only
showed up when someone went to design the screen that consumes it.
