# Sprint 011 — Review {#sprint-011--review}

**Period**: 2026-08-12 · **Feature**: [012 — the link that disappeared at the source](../../../specs/012-vinculo-que-sumiu-na-origem/spec.md)
**PR**: [#278](https://github.com/The-Band-Solution/theband/pull/278) · **Acceptance**: [aceitacao.md](../../../specs/012-vinculo-que-sumiu-na-origem/aceitacao.md)

Written **in this** sprint, and not in the next one. It is L44 applied to itself.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3, one of them proven only in tests |
| Tasks | 9 | 8 done · 1 pending on a person |
| Functional requirements accepted | 14 | **14** |
| Success criteria accepted | 7 | **3** — four depend on real data |

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#269](https://github.com/The-Band-Solution/theband/issues/269) | `mark_decomposition_links_no_longer_observed/3`, scoped by the parent's repository | yes |
| T002 | [#270](https://github.com/The-Band-Solution/theband/issues/270) | test that pins down the resurrection and the preservation of `observed_at` | yes |
| T003 | [#271](https://github.com/The-Band-Solution/theband/issues/271) | idempotency, and the old mark that is not rewritten | yes |
| T004 | [#272](https://github.com/The-Band-Solution/theband/issues/272) | the tenant boundary, asserted via the neighbor's link | yes |
| T005 | [#273](https://github.com/The-Band-Solution/theband/issues/273) | the call in the success branch, after `vincular/2` and before `promover/2` | yes |
| T006 | [#274](https://github.com/The-Band-Solution/theband/issues/274) | five "nothing happened" cases, including `refused_links` | yes |
| T007 | [#275](https://github.com/The-Band-Solution/theband/issues/275) | a log that names repository and number, and stays silent when it is zero | yes |
| T008 | [#276](https://github.com/The-Band-Solution/theband/issues/276) | screen receiving the data **through the collection**, not by direct write | yes |

## What was not done {#o-que-não-foi-feito}

| Task | Issue | Reason | Destination |
|---|---|---|---|
| T009 | [#277](https://github.com/The-Band-Solution/theband/issues/277) | requires the **master key** and the source responding, and a human eye on the `eo_lib` screen | maintainer; stays open |

**T009 is the only one, and it is not a delay**: it was never executable by me. It has been declared as
pending since the backlog, and remains declared — never counted as fulfilled.

## Evidence {#evidências}

```
mix gates → 10 gates verdes, código de saída 0
18 testes novos em três arquivos:
  test/the_band/work_items/decomposition_absence_test.exs        6 casos
  test/the_band/ingestion/decomposition_absence_test.exs        10 casos
  test/the_band_web/live/decomposition_absence_screen_test.exs   2 casos
```

The measurement that originated the feature, checked in the database before any code existed:

```
1666 vínculos · 0 marcados · 52 que a última coleta não reviu
eo_lib 29 · theband 15 · ResearchDomain 8
nos 52, pai e filha vigentes: 0 e 0
```

## Debt generated {#dívida-gerada}

| Debt | Why it was accepted |
|---|---|
| **fourth** absence-marking function, with no common abstraction | the cutoffs are not the same: issue cuts off by date, assignee and label cut off by list. Generalizing would join different things |
| the total of links marked per run exists only in the log | the question "what did this collection stop seeing" has not yet been asked by anyone; inventing the field now is a pattern without a problem |
| this PR is **stacked** on top of #264 | the alternative was to wait for the review of a PR that had already been ready for a day |

## What the analysis and the plan found before the code {#o-que-a-análise-e-o-plano-acharam-antes-do-código}

**Six findings, and none came from running tests** — all from measuring the database or reading the code:

| Phase | Finding |
|---|---|
| plan | FR-002 asked to write `started_at` into the mark, against the convention of the three siblings |
| plan | FR-013 asked for a new number on the syncs screen — the concrete case of principle X |
| analysis | 12 of the 52 links support `sro.rule07` violations: the dashboard drops from 293 to 281 |
| analysis | the order relative to `promover/2` became load-bearing: `classification/2` counts only those in force |
| analysis | FR-014 had no task, and it was testable |
| analysis | T008 was **blocked**, not pending |

**Seventh feature in a row** in which the analysis phase finds a design defect.

## Lessons from this sprint {#lições-deste-sprint}

Three, and all three were born from a mistake made inside the sprint — not from theory.

- **L45** — a new sprint taken from `main` does not see the closing of the previous one while the PR is open;
- **L46** — a test with a time cutoff and data built at the same instant passes or fails by luck;
- **L47** — a cross-repository link only exists from the **second** collection on.

Detailed in [licoes-aprendidas.md](../licoes-aprendidas.md).

---

## After the merge {#depois-do-merge}

PRs [#264](https://github.com/The-Band-Solution/theband/pull/264) and
[#278](https://github.com/The-Band-Solution/theband/pull/278) were approved and merged in the
right order. `main` at `8677752`, **10 gates green by exit code**, branches deleted.

**And the merge left one thing undone, which no one would have noticed:** **#263** stayed open. The
PR body said *"Fecha #263"* (Portuguese for "Closes #263"), and GitHub only recognizes the English word — the cross-reference
appears the same in both cases, and the issue stays open looking like undone work. Closed by hand,
with the evidence, and it became **L48**.

**A fourth lesson from the sprint**, and from the same family as the other three: no error, and the wrong
result.

## What remains pending {#o-que-continua-pendente}

| # | What | Why |
|---|---|---|
| [#277](https://github.com/The-Band-Solution/theband/issues/277) | the check on real data | requires the master key and the source responding |
| [#265](https://github.com/The-Band-Solution/theband/issues/265) | the epic | stays open as long as #277 is — an epic with pending verification is not done |

Four of the seven success criteria remain **declared as pending**. The code is in `main`;
its effect on the data has not been observed.

### The recurrence, found by the maintainer {#a-reincidência-achada-pela-pessoa-mantenedora}

The question was *"look at the issue list, why are they still open?"* *(original: "olhe a lista de issues, por que estão abertas ainda?")*, and the list answered:
**#246** — the request that originated feature 011 — had been open since the merge of PR #264, for the same
reason as #263. **Two PRs, the same mechanism.**

Closed with the evidence. And the check that found it became part of L48: **the list of open issues
is the check**, and it applies when closing the sprint — not only the issue one remembers to look at.
