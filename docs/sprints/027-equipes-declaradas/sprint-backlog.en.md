# Sprint 027 — The organization declares its teams {#sprint-027--a-organização-declara-suas-equipes}

**Period**: 2026-09-01 to 2026-09-08 (one-week cadence, decided on 2026-08-10)
**Inheritance**: [#621](https://github.com/The-Band-Solution/theband/issues/621) and
[#620](https://github.com/The-Band-Solution/theband/issues/620) — the two user
stories of 050 **not accepted** in
[sprint 026](../026-heranca-e-a-producao/aceitacao.md)
**Feature**: [055-equipes-declaradas](../../../specs/055-equipes-declaradas/spec.md) ·
[plan](../../../specs/055-equipes-declaradas/plan.md) ·
[contract](../../../specs/055-equipes-declaradas/contracts/equipes-declaradas.md)

## Sprint goal {#objetivo-do-sprint}

**The platform comes to know whom the people it measures belong to.** Today a team
is only born from the collection: there is no way to create one that GitHub does not know, put one
inside another, or say that someone left without erasing what they did while they were there.

Before that, the inheritance: **the restore rehearsal executed** and **the next
release timed** — the two things production has owed since v0.1.0.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md):

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L91** | Sprint 026 | the 18 issues were created **before** implementation, and checked by count. It was the lesson born from two consecutive features skipping this step |
| **L89** | Sprint 026 | review requested **and checked** through the JSON in T015 — the request command exits zero even when requesting nobody |
| **L90** | Sprint 026 | T005 asserts **both sides** of the race: the team membership that is born and what the loser returns |
| **L81** | Sprint 025 | T008 is the sibling hunt: derive the pattern of "in force" and sweep the repository **before** delivering |
| **L77** | — | T004 and T011 are born failing through absence of the function, not through syntax |
| **L60/XI** | — | the gates' exit code is read **inside** the log, in T001 and T015 |
| **L93** | Sprint 026 | the release measurement (inheritance H2) waits for the old container's `SIGTERM` — during the deploy, two versions serve |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

⚠️ **Declared limitation: iteration 027 was not created.** The project's iteration
field exists, and iterations 023 to 026 are there — but **with dates that do not
match when the work happened**:

| iteration | date in the project | when it ran |
|---|---|---|
| Sprint 025 | 2026-09-12 | 2026-08-29 |
| Sprint 026 | 2026-09-19 | 2026-08-29 to 09-01 |

Three weeks of difference. **The platform reads sprints from these dates** — that is where
`flow.throughput.rate` comes from. And reconfiguring iterations **recreates the existing ones and
reassigns the items** (L11/L72: 53 values captured, recreated and checked
last time).

Fixing this is work with its own risk, and comes in as a **named pending item**
instead of being done in the middle of this sprint. Until it is, the throughput measured on
this repository is shifted — and that is stated, not hidden.

## Inheritance — first in the queue {#herança--primeira-da-fila}

| # | What | Issue | State |
|---|---|---|---|
| H1 | The restore rehearsal, executed in production | [#621](https://github.com/The-Band-Solution/theband/issues/621) | **named blocker**: access to the Dokploy panel |
| H2 | The three release measures — session survives, window, first access | [#620](https://github.com/The-Band-Solution/theband/issues/620) | waits for the next merge into `main` |

**Neither of the two is code.** H1 is execution; H2 is timing. Both
fall if nobody does them at the right moment — and that is why they are first,
not at the end.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Issue | Priority | Criteria |
|---|---|---|---|---|
| US1 | The organization creates the team that GitHub does not know | [#702](https://github.com/The-Band-Solution/theband/issues/702) | P1 | 4 |
| US2 | The person joins, leaves, and what they did is still there | [#703](https://github.com/The-Band-Solution/theband/issues/703) | P1 | 5 |
| US3 | Team inside a team | [#704](https://github.com/The-Band-Solution/theband/issues/704) | P2 | 4 |

## Tasks {#tarefas}

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T001 | Open the gates baseline | — | [#687](https://github.com/The-Band-Solution/theband/issues/687) | to do |
| T002 | The composition concept enters the ontology | — | [#688](https://github.com/The-Band-Solution/theband/issues/688) | to do |
| T003 | The migration: the composition and the mistake | — | [#689](https://github.com/The-Band-Solution/theband/issues/689) | to do |
| T004 | The violation: recording a departure cannot erase | US2 | [#690](https://github.com/The-Band-Solution/theband/issues/690) | to do |
| T005 | Link a person, with role and start | US2 | [#691](https://github.com/The-Band-Solution/theband/issues/691) | to do |
| T006 | Record the departure | US2 | [#692](https://github.com/The-Band-Solution/theband/issues/692) | to do |
| T007 | Record the mistake, without erasing | US2 | [#693](https://github.com/The-Band-Solution/theband/issues/693) | to do |
| T008 | In force comes to have two conditions, everywhere | US2 | [#694](https://github.com/The-Band-Solution/theband/issues/694) | to do |
| T009 | The structural team, alongside the project team | US1 | [#695](https://github.com/The-Band-Solution/theband/issues/695) | to do |
| T010 | The screen creates, and says where the team came from | US1 | [#696](https://github.com/The-Band-Solution/theband/issues/696) | to do |
| T011 | The violation: the cycle of length 3 | US3 | [#697](https://github.com/The-Band-Solution/theband/issues/697) | to do |
| T012 | Compose and decompose, with the refusal that states the path | US3 | [#698](https://github.com/The-Band-Solution/theband/issues/698) | to do |
| T013 | The structure on both screens | US3 | [#699](https://github.com/The-Band-Solution/theband/issues/699) | to do |
| T014 | The two statements, when collection and declaration disagree | US1/US2 | [#700](https://github.com/The-Band-Solution/theband/issues/700) | to do |
| T015 | Green gates, PR to the standard and review CHECKED | — | [#701](https://github.com/The-Band-Solution/theband/issues/701) | to do |

**MVP**: T001 to T008 — the correct domain, with the history that survives. No screen
yet.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **The skills rollup** ([#397](https://github.com/The-Band-Solution/theband/issues/397)) — depends on this feature. Joining the two would hide which one broke;
- **049 (sign in with GitHub)** — spec ready, postponed by a decision of 2026-09-01. It comes back as a **prerequisite** of the setup wizard, not as a queue item;
- **The team dashboard** ([#504](https://github.com/The-Band-Solution/theband/issues/504) and [#507](https://github.com/The-Band-Solution/theband/issues/507)) — scope decided, **no spec**. They come in when they have one;
- **Fixing the iteration dates** — its own risk, see above;
- **The four secret rotations** — pending since v0.1.0, and they belong to the maintainer.

## Risks and dependencies {#riscos-e-dependências}

- **H1 depends on access to the panel** that the team does not have. It is the named blocker
  that the rule requires to free up new work — without it, nothing moves on it;
- **H2 depends on there being a release** in this sprint. If there is none, it does not fall
  through effort, it falls through lack of occasion — and that must be said in the review, not
  become "not done";
- **The domain certificate renewal became manual** (`§9-B` of the runbook). It does not
  expire in this sprint, but it slips from memory if not written down;
- **T008 is the one most likely to slip.** It sweeps existing queries; whatever the
  sweep does not find keeps counting invalidated team memberships, and nobody will know which.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] quality gates green, with `EXIT` read **inside** the log (L60)
- [ ] knowledge base valid, with the new concept **declared in `modules:`** (#527)
- [ ] issues #687–#704 closed AFTER acceptance
- [ ] `sprint-review.md` written
- [ ] `licoes-aprendidas.md` updated
- [ ] PRs with review requested **and checked through the JSON** (L89)
