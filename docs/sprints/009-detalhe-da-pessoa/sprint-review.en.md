# Sprint 009 — Review {#sprint-009--review}

**Period**: 2026-08-12 · **Feature**: [010 — person detail](../../../specs/010-detalhe-da-pessoa/spec.md)
**Acceptance**: [aceitacao.md](../../../specs/010-detalhe-da-pessoa/aceitacao.md) — **12 of 13** criteria
**Written on**: 2026-08-12, **after** sprint 010 opened — and that is the first finding of this review

## Why this review arrived late {#por-que-esta-review-chegou-atrasada}

Sprint 009 was delivered and merged — PR [#247](https://github.com/The-Band-Solution/theband/pull/247),
the thirteen issues closed — **without a review, without acceptance and without lessons**. The absence only showed up when
sprint 010 cited lessons **L38** and **L39** as a constraint: they had been drafted in the feature's
commit and **never consolidated** in the accumulated record.

**Citing a lesson that does not exist is worse than not citing it**: the document starts to look complete.
Recorded as **L44**.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 9 | 9 |
| Accepted deliverables | 9 | 9 |

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#237](https://github.com/The-Band-Solution/theband/issues/237) | `EO.list_person_teams/2` — one query, with organization and promotion | yes |
| T002 | [#238](https://github.com/The-Band-Solution/theband/issues/238) | `EO.count_roles/1` | yes |
| T003 | [#239](https://github.com/The-Band-Solution/theband/issues/239) | `count_assigned_to/2` and `count_authored_by/2`, **separate** | yes |
| T004 | [#240](https://github.com/The-Band-Solution/theband/issues/240) | `assigned_to:` and `authored_by:` in `escopo/2` — two names, never `person_id` | yes |
| T005 | [#241](https://github.com/The-Band-Solution/theband/issues/241) | `repositories_of_person/2` | yes |
| T006 | [#242](https://github.com/The-Band-Solution/theband/issues/242) | `/people/:id`, with the three sections | yes |
| T007 | [#243](https://github.com/The-Band-Solution/theband/issues/243) | the name became a link in `/people` | yes |
| T008 | [#244](https://github.com/The-Band-Solution/theband/issues/244) | the explanation of the non-promotion, coming from the **data** | yes |
| T009 | [#245](https://github.com/The-Band-Solution/theband/issues/245) | assignment and authorship shown without summing | yes |

**The sprint's thirteen issues are closed** — epic, three user stories and nine tasks.

## What was not done {#o-que-não-foi-feito}

| Item | Reason | Destination |
|---|---|---|
| the page looked at at **360 px** | it needs a browser and a human eye | maintainer |
| the `vinicius-je` page **on the real data** — 350 and 609, never 959 | the platform starts with the master key | maintainer |
| **the review and the lessons** | they were not written at closing | **done now**, late |

## Evidence {#evidências}

```
mix gates → 10 gates verdes, 460 testes (na entrega)
PR #247 mergeado em main — 13 arquivos, 1 443 linhas
```

Numbers measured on the real data on 2026-08-12: **75 people, 12 teams, 88 pieces of team membership evidence, zero
materialized team memberships, zero roles**, 4,232 assignments and 4,241 authorships.

## The three defects the tests found during implementation {#os-três-defeitos-que-os-testes-acharam-durante-a-implementação}

| # | What it was | How it showed up |
|---|---|---|
| 1 | a `join` in `escopo/2` **shifted the bindings** of `list_issues/2` | `field derived_concept in select does not exist in schema IssueAssignee` — fixed with a subquery |
| 2 | `sum/1` returns a `Decimal`, and the test expected an integer | `left: Decimal.new("1")` — fixed with `type(..., :integer)` |
| 3 | `@por_pagina` in the template is an **assign**, not a module attribute | `KeyError` on render — fixed with an explicit assign |

## Debt generated {#dívida-gerada}

| Debt | What it is |
|---|---|
| the `origem/1` component has **two** uses, not three | it is on the threshold of the project's criterion, and was declared in the plan instead of hidden |
| `TeamsLive.Show` is still in Portuguese | the migration to English went past it without touching it |
| the **88 pieces of evidence** do not become team memberships | depends on the role existing — #99 and #100 |

## Lessons from this sprint {#lições-deste-sprint}

Consolidated now in [licoes-aprendidas.md](../licoes-aprendidas.md) as **L38**, **L39** and **L44**.

1. **The cost of a screen is measured by the difference and the constancy**, never by the total: the test
   expected 8 on a page that makes 24, because 16 are framework and authentication. → **L38**
2. **A `join` added to a shared scope shifts the bindings of whoever composes on top of it.**
   → **L39**
3. **A sprint that closes without a review leaves the lesson drafted and not recorded** — and the next feature
   cites it as if it existed. → **L44**
