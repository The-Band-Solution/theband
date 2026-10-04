# Sprint 010 — Review {#sprint-010--review}

**Period**: 2026-08-12 · **Feature**: [011 — what each issue is part of](../../../specs/011-de-quem-a-issue-e-parte/spec.md)
**Acceptance**: [aceitacao.md](../../../specs/011-de-quem-a-issue-e-parte/aceitacao.md) — **12 of 13** criteria

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 9 | 9 |
| Accepted deliverables | 9 | 9 |
| Success criteria | 13 | 12 |

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#252](https://github.com/The-Band-Solution/theband/issues/252) | `Axioms.relacao/2` — five answers, calling `rule07/2` | yes |
| T002 | [#253](https://github.com/The-Band-Solution/theband/issues/253) | `WorkItems.list_parents/2` — one query, all parents, deterministic order | yes |
| T003 | [#254](https://github.com/The-Band-Solution/theband/issues/254) | the `part of` column, with the parent's **concept** and the named absence | yes |
| T004 | [#255](https://github.com/The-Band-Solution/theband/issues/255) | the five texts in `ConceptLabel.relacao/1` | yes |
| T005 | [#256](https://github.com/The-Band-Solution/theband/issues/256) | the parent's repository name, only when it differs | yes |
| T006 | [#257](https://github.com/The-Band-Solution/theband/issues/257) | more than one parent stated, counting only the one in force | yes |
| T007 | [#258](https://github.com/The-Band-Solution/theband/issues/258) | absent link dashed, with the date | yes |
| T008 | [#259](https://github.com/The-Band-Solution/theband/issues/259) | parent without a concept stated, without inventing | yes |
| T009 | [#260](https://github.com/The-Band-Solution/theband/issues/260) | the cost measured: 10 before, **12** after, and constant | yes |

## What was not done {#o-que-não-foi-feito}

| Item | Reason | Destination |
|---|---|---|
| the screen looked at at **360 px** | needs a browser and a human eye | maintainer, and it is the **fifth** sprint with this item |
| the column seen **on real data** | the platform starts with the master key, which I neither ask for nor receive | maintainer |

**No task was left out.** The two rows above are verification, not implementation.

## Evidence {#evidências}

```
mix gates → 10 gates verdes, 497 testes, veredito por código de saída
```

The invariant on real data:

```
atendimento 1 143 · violação 293 · composição 197 · não nomeada 33  =  1 666 vínculos
```

The cost, measured against `main` on 2026-08-12: the page made **10** queries per render and now
makes **12** — two, one per boundary. A page of 2 issues and a page of 50: **the same**.

## Debt generated {#dívida-gerada}

| Debt | What it is |
|---|---|
| `list_parents/2` and `fetch_parent/2` coexist | two functions for the same relation, seen from below. The new one returns all parents; the old one picks one with no order, and that is #261 |
| the column does not state the **lineage** | it shows the parent, not the grandparent. It is a principle X decision, and becomes debt if someone asks for the chain |

## The three defects found outside the feature {#os-três-defeitos-achados-fora-da-feature}

| # | What it is | Record |
|---|---|---|
| 1 | `fetch_parent/2` with `limit: 1` **without `order_by`** — arbitrary parent on the 36, and it hides that there is another | [#261](https://github.com/The-Band-Solution/theband/issues/261) |
| 2 | a child promoted to **defect** outside the three lists of the parent's detail — **33** invisible links | [#262](https://github.com/The-Band-Solution/theband/issues/262) |
| 3 | decomposition link **never** marked as absent — the column knows how to display it, the data never arrives | [#263](https://github.com/The-Band-Solution/theband/issues/263) |

**All three were born from measuring in order to write the spec**, not from running tests. None of them produces an error:
they all produce a screen that looks complete.

## What the analysis phase found, and is worth telling again {#o-que-a-fase-de-análise-achou-e-vale-contar-de-novo}

**Fifth feature in a row in which the analysis found a defect before the code.** This time there were four, and
**two were requirements with no task at all**:

| # | Finding |
|---|---|
| A1 | **FR-003 and SC-004 without coverage**: `attends` and `composes` do not name the parent's **concept**, and without it the 12 links with a defect parent would be left unnamed — the reduction the original request made |
| A2 | FR-016 and SC-011 **without a tenant assertion** |
| A3 | the test cited `Ecto.Adapters.SQL.query_count/1`, which **does not exist** |
| A4 | T009 would measure **four** and fail with no defect: `live/2` does two renders |

And the plan, before that, found three — all by measurement: link confused with issue, the relation
decided by the pair instead of the child's concept, and the second boundary of the repository name.

## Lessons from this sprint {#lições-deste-sprint}

Four, and all four are actionable. Draft consolidated in
[licoes-aprendidas.md](../licoes-aprendidas.md) as **L40 to L43**.

1. **Two quantities with similar names, and the complement derived from one of them.** I counted 1,666
   links, called them issues and derived "2,863 without a parent" by subtraction. The issues were 1,630 and the
   difference — 36 — was the feature's own edge case. → **L40**
2. **The test that compares a thing with itself always passes.** The cost constancy compared the
   same page twice: equality guaranteed, no measurement at all. → **L41**
3. **A late telemetry message gets into the next count.** A 22 showed up where the page makes
   20, and I almost wrote an explanation for the 22. → **L42**
4. **When the axiom answers the wrong question, the error is not in the axiom.** `rule07/2` treats "task
   without parent" as a violation, and calling it with a null parent would fill 2,091 cells with warnings. The fix was the
   **precondition**, not a filter on its answer. → **L43**
