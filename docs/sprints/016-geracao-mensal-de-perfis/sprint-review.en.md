# Sprint 016 — Review {#sprint-016--review}

**Period**: 2026-08-16 · **Feature**: [027](../../../specs/027-geracao-mensal-de-perfis/spec.md)
**PR**: [#360](https://github.com/The-Band-Solution/theband/pull/360)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| Sprint issues | 23 | **23** |
| Feature issues | 28 | 23 — five declared out when the sprint opened |
| Quality gates | 13 | **13**, exit code 0 |
| Tests | — | 917, **34 new** |

## What was done {#o-que-foi-feito}

| Task | Deliverable | Accepted |
|---|---|---|
| T003 | dedicated `:perfis` queue, separate from collection | yes |
| T004, T005 | `profile_thresholds.yaml` with N and M; validation **refuses** a missing threshold | yes |
| T006 to T009 | three migrations and three schemas — events, rounds, entries | yes |
| T010 | thresholds read from the knowledge base, with no default built into the code | yes |
| T011 | who goes into the round, and the three separate reasons for who does not | yes |
| T012 | turning on and off with an **author**, derived from an event and not from a column | yes |
| T013, T015 | round opened, recorded and closed, sequential with a checkpoint in a table | yes |
| T014, T014a | the generation returns the consumption; the material is still the whole history | yes |
| T016, T016a | a refused credential ends the round; whoever failed comes back in the next one by the normal criterion | yes |
| T017, T017a | monthly cron, one round per organization; bumping the version **generates nothing** | yes |
| T018 to T021 | `/profiles` screen, the nine numbers by aggregation, turning on triggers, round by hand, isolation between organizations | yes |

## What was not done {#o-que-não-foi-feito}

Five issues, declared out **when opening** the sprint and not when closing it.

| Task | Issue | Reason | Destination |
|---|---|---|---|
| T022 | [#354](https://github.com/The-Band-Solution/theband/issues/354) | US3, P2 — the value shows up when someone wants to adjust the threshold | product backlog |
| T023 | [#355](https://github.com/The-Band-Solution/theband/issues/355) | polish | product backlog |
| T024 | [#356](https://github.com/The-Band-Solution/theband/issues/356) | requires a real key and 15 to 35 minutes of round against the provider | **maintainer** |
| T025 | [#357](https://github.com/The-Band-Solution/theband/issues/357) | runs at closing — **done**, 13 green | closed with the sprint |
| T026 | [#358](https://github.com/The-Band-Solution/theband/issues/358) | walk through the quickstart by hand, with the application running | **maintainer** |

## Evidence {#evidências}

```
mix gates → 13 gates verdes, código de saída 0, sem pipe
917 testes, 34 novos
knowledge.validate → base válida, 100 artefatos
```

## Definition of Done — item by item {#definition-of-done--item-a-item}

| Item | State |
|---|---|
| the 23 issues closed, or reprioritized with a written justification | **close on the merge** of #360, through `Fecha #331…#353` |
| `mix gates` with exit code 0, never with `\| tail` | **fulfilled** — and see the lesson below, because the first run of this session violated it |
| `mix knowledge.validate` passing with the new `regeneration` rule | fulfilled |
| PR opened with a reviewer requested from the `the-band` team, and the request **checked** | fulfilled — `reviewRequests` returns the team, not an empty list |
| `sprint-review.md` written, separating delivered from not delivered | this document |
| `licoes-aprendidas.md` updated | fulfilled — L60 |
| the independent review gap **declared**, if it persists | **it persists, and it is declared below** |

## The independent review gap — declared, not fulfilled {#a-lacuna-da-revisão-independente--declarada-não-cumprida}

The review request was made to the `the-band` team and **checked** with
`gh pr view 360 --json reviewRequests`, which returned the team and not an empty list. That proves
the request arrived; it does **not** prove the review happened.

At the time of writing this document, `pulls/360/reviews` is empty. #330 was
merged without an independent review, and this sprint closes with the same risk open — the
difference is that now the request exists and is recorded.

**Not marking it as fulfilled is the point.** Principle VII asks for review by another agent or
person; a request sent is a necessary condition, not a sufficient one.

## Debt generated {#dívida-gerada}

| Debt | Where it is |
|---|---|
| **N and M go in without measurement** | `FR-021` requires measuring the real cost before the thresholds take effect. The values are in the YAML as **initial**, and `SC-002` says they change along with the recount. T024 ([#356](https://github.com/The-Band-Solution/theband/issues/356)) is what closes this, and it depends on a real key |
| **the quickstart was not walked through by hand** | [#358](https://github.com/The-Band-Solution/theband/issues/358). The green suite does not replace it: the project's lesson is that three defects of the previous round only showed up with the application running |
| **fourteen dead `form-control`** | `roles_live` and `source_live` still have the class that daisyUI 5 removed. Only the two in `/ai` were fixed, in `5c96a41`, and the reason is in the commit |

## Lessons from this sprint {#lições-deste-sprint}

Recorded in [licoes-aprendidas.md](../licoes-aprendidas.md) — **L60**, the recurrence of the
pipe in `mix gates`.
