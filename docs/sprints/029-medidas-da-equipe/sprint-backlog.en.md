# Sprint 029 — The measures missing from the team screen {#sprint-029--as-medidas-que-faltam-na-tela-da-equipe}

**Period**: 2026-09-02 to 2026-09-09 (one-week cadence)
**Feature**: [058](../../../specs/058-medidas-da-equipe/spec.md)
**Plan**: [plan.md](../../../specs/058-medidas-da-equipe/plan.md) ·
**Research**: [research.md](../../../specs/058-medidas-da-equipe/research.md)

## Sprint goal {#objetivo-do-sprint}

**Close what remains of epic [#504](https://github.com/The-Band-Solution/theband/issues/504)
with what feature 057 already supports** — and leave declared what only feature 042
unlocks.

Two period columns get their first consumer since they were created, and
a measure that is already calculated reaches the screen.

## Where this sprint came from {#de-onde-este-sprint-veio}

Epic #504 had been open since 2026-08-25 with three dependencies. The review of
2026-09-02 found that **all three had changed state without anyone reviewing the
epic** — two had closed, and 057 delivered part of what it asked for without the two
being linked.

It was **L99** at work: checking item by item finds what planning does not.

## Lessons applied {#lições-aplicadas}

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L99** check issue by issue | 028 | it is the origin of this sprint — the review of #504 |
| **L98** a lesson that does not become a rule recurs | 028 | FR/SC traceability was fixed **in `/speckit-tasks`**, and not by waiting for the `/speckit-analyze` that caught it last sprint |
| **L67** two measures with the same name | 022 | it is the reason the actor path is **left out**: two numbers with the same label and different denominators |
| **L95** requesting a reviewer ≠ obtaining a review | 027 | field in the PR template created in #763; measure `reviews` before merging |
| **L96** an issue nobody closes | 028 | `gh issue list --state open` with the `058/` prefix enters the DoD |
| **L30** check against the source | 003 | it is T020 — and the source is inaccessible, which is **declared** instead of estimated |
| **L91** the step without a gate disappears | 025 | the 24 issues linked in `tasks.md`, checked against the source |
| **L60** the verdict is the exit code | 019 | in the DoD, and in the PR template |
| merge, branch and history | 028 | merge type **declared in the PR** — `AGENTS.md` §12 |

**The "defect that produces no error" family** runs through the whole feature:
`{:parcial, _}`, `{:aguardando, _}` and `{:sem_projeto, _}` exist because
absence is not zero.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
24 items added

### Two declared limitations, not worked around {#duas-limitações-declaradas-não-contornadas}

**This sprint has no iteration** — the third in a row. Adding it recreates the
existing ones, and **L11** measured the cost at 97 orphaned items. The gap accumulates, and
fixing it is work of its own, with a snapshot of the `item id`s taken first.

**The user stories stay without a type.** `User Story` does not exist in the organization, and
typing them as `Feature` would make the routing rule classify them wrongly.
**No type is an absence; the wrong type is a false statement.**

The 21 tasks **are** typed as `Task`, and the 13 that serve a user story are
linked as sub-issues.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Issue | Priority | Estimate | Tasks |
|---|---|---|---|---|---|
| US2 | Who worked on this project, and when 🎯 | [#766](https://github.com/The-Band-Solution/theband/issues/766) | P0 | 5 | T004–T007 |
| US1 | The time to first review, for this team | [#765](https://github.com/The-Band-Solution/theband/issues/765) | P0 | 5 | T008–T011 |
| US3 | The pipeline rate of this team's projects | [#767](https://github.com/The-Band-Solution/theband/issues/767) | P1 | 5 | T012–T016 |

`Priority` is the *importance* — value to the organization. `Estimate` is the
*complexity*. **Tasks do not get a `Priority`**: they inherit the story's.

## Tasks {#tarefas}

All in [`tasks.md`](../../../specs/058-medidas-da-equipe/tasks.md), with the four
fields and the issue link. Range:
[#768](https://github.com/The-Band-Solution/theband/issues/768) to
[#788](https://github.com/The-Band-Solution/theband/issues/788).

| Phase | Tasks | Issues | Serves |
|---|---|---|---|
| Foundational | T001–T003 | #768–#770 | blocks everything |
| US2 | T004–T007 | #771–#774 | #766 |
| US1 | T008–T011 | #775–#778 | #765 |
| US3 | T012–T016 | #779–#783 | #767 |
| Polish | T017–T021 | #784–#788 | — |

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started) —
all in **a fazer**.

## Inherited from sprint 028 {#herdado-do-sprint-028}

| Item | Issue | Why it came |
|---|---|---|
| T033 of 057 — gates, PR and **CHECKED** review | [#753](https://github.com/The-Band-Solution/theband/issues/753) | the five PRs of 028 were merged with **zero reviews**. For the third sprint, it is an entry condition |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| What | Why |
|---|---|
| `flow.throughput.rate` and `flow.wip.count` | they depend on the start criterion of **feature 042** — 24 issues without code. They are the only item of epic #504 that still needs it |
| `rework.not_accepted_deliverable_ratio` | **cannot be calculated**: acceptance is never recorded |
| the pipeline rate **per run actor** | answers another question (R1), and offering both is L67 |
| the burn on the person page | [backlog](../../backlog/burn-da-pessoa-sem-linha-de-base.md) — the question needs to be decided before the code |
| [MCP server](../../backlog/servidor-mcp.md) | blocked until authentication and tenant are decided |
| creating the `User Story` and `Epic` types | changes the organization's configuration; requires confirmation |
| fixing the iterations | L11 measured the cost: 97 orphaned items |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Effect | Mitigation |
|---|---|---|
| **data coverage being nearly zero** | US3 delivers only the refusal branch | T020 measures **before** acceptance; if it is zero, that is a **result** and goes into the review |
| **T020 depends on the master key**, which this session does not have | coverage remains unknown | declared in the task, in the plan and here — not hidden behind an estimate |
| **independent review not happening again** | principle VII violated for the third sprint | measure `reviews` before each merge; zero is a blocker |
| `{:parcial, _}` being ignored by whoever consumes it | the silent fallback comes back | the type has three states, and a `case` without the third clause does not pass cleanly |
| query ceiling blowing up | slow screen, red gate | the ceiling of 16 has been a test since 057; T018 measures the increase |

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] `mix gates` with **exit code 0** — the verdict is the code, and no
      command after it (L60)
- [ ] valid knowledge base, with the measures declared (T002, T003)
- [ ] **`gh pr view <n> --json reviews` > 0 on every merged PR** (L95)
- [ ] **merge type declared** in the body of each PR (`AGENTS.md` §12)
- [ ] **`gh issue list --state open --search "058/ in:title"` checked before the
      review**, and every divergence from `tasks.md` resolved (L96, L99)
- [ ] **the three numbers of T020 written in the review** — or the statement that the
      key was not available
- [ ] issues closed or reprioritized with justification
- [ ] `sprint-review.md` written
- [ ] `licoes-aprendidas.md` updated

## Gate baseline {#baseline-dos-gates}

Measured on 2026-09-02, on `development`, after the five merges of sprint 028:

```text
14 gates verdes.
MIX_GATES_NO_DEVELOPMENT=0
```
