# Sprint 014 — the design system {#sprint-014--o-design-system}

**Period**: 2026-08-13 · **Features**: [016 breadcrumb](../../../specs/016-migalha-de-pao/spec.md) · [017 table](../../../specs/017-tabela-que-busca-ordena-e-pagina/spec.md)
**Origin**: [#285](https://github.com/The-Band-Solution/theband/issues/285) and [#289](https://github.com/The-Band-Solution/theband/issues/289)

## Goal {#objetivo}

The screens start to say **where the person is** and let them **find the row** without scanning the list.

## The base decision came from a prototype {#a-decisão-de-base-veio-de-protótipo}

#289 started with a question — *"is there some framework like NuxtUI for Phoenix?"* — and ended with
three working prototypes of the same table, with the same 34 real data points, used side by side.
**Our own component**, decided after using them.

| Refused | Why |
|---|---|
| Petal | a second class vocabulary next to daisyUI |
| Backpex | it becomes the owner of the screen, and these screens say what the platform **refuses to claim** |

## Lessons applied {#lições-aplicadas}

| Lesson | How |
|---|---|
| **L21** | a component without a consumer is not a delivery: both features touch a screen in the same sprint |
| **L28** | "the query sorts" and "the screen sorts" are different claims — each has a test |
| **L30** | the numbers come from the measure: 6.8 ms to count, 14.2 ms to sort by a derived value |
| **L42** | the query counter excludes Oban |
| **L49** | measure the tail: the largest repository's list has 2,514 rows |
| **L52** | **one feature per branch** — and it charged its price again this sprint |
| **L53** | a test ceiling comes from measuring both sides |

## Scope {#escopo}

| # | Feature | State |
|---|---|---|
| 016 | breadcrumb | **delivered** — PR #291, merged |
| 017 | table that searches, sorts and paginates | **delivered** — with two declared cuts |

## The declared cuts of 017 {#os-cortes-declarados-da-017}

| What | Why | Destination |
|---|---|---|
| state in the URL | requires `handle_params` and composing with the filter that already uses `push_patch` | [#292](https://github.com/The-Band-Solution/theband/issues/292) |
| the smaller tables | 12 rows and 4,529 do not call for the same solution | when someone needs to search in them |
| 360 px | an assertion on markup does not replace looking | `RETOMAR.md` |

## Definition of Done {#definition-of-done}

- [x] `mix gates` green by exit code — **12 gates**
- [x] acceptance of both, criterion by criterion
- [ ] `sprint-review.md`
- [ ] lessons updated
