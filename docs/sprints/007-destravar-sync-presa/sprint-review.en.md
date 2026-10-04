# Sprint 007 — Review {#sprint-007--review}

**Period**: 2026-08-12 to 2026-08-18
**Feature**: [008 — unblock stuck sync](../../../specs/008-destravar-sync-presa/spec.md)
**PR**: [#212](https://github.com/The-Band-Solution/theband/pull/212), incorporated on
2026-08-12T13:37:23Z · `main` at `f09e467`

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 9 | 9 |
| Accepted deliverables | 9 | **9** |

**10 gates green by exit code**, 402 tests. The criterion-by-criterion assessment is in
[aceitacao.md](../../../specs/008-destravar-sync-presa/aceitacao.md): **14 of 14 SC met**, two
with a declared caveat.

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#202](https://github.com/The-Band-Solution/theband/issues/202) | `interrupted_by_user_id`, nullable and without a check constraint | yes |
| T002 | [#203](https://github.com/The-Band-Solution/theband/issues/203) | the sync↔job link through the args, with the states derived from the queue | yes |
| T003 | [#204](https://github.com/The-Band-Solution/theband/issues/204) | `reconcile_stuck_syncs/0`, with a 1-minute grace period | yes |
| T004 | [#205](https://github.com/The-Band-Solution/theband/issues/205) | the reason by cause, without inventing a failure | yes |
| T005 | [#206](https://github.com/The-Band-Solution/theband/issues/206) | idempotence: it acts only on `running` | yes |
| T006 | [#207](https://github.com/The-Band-Solution/theband/issues/207) | the result of creating the job checked | yes |
| T007 | [#208](https://github.com/The-Band-Solution/theband/issues/208) | the periodic worker, and the test that prevents `Lifeline` from coming back | yes |
| T008 | [#209](https://github.com/The-Band-Solution/theband/issues/209) | `interrupt_sync/3` with author, `:job_alive` and `:not_found` | yes |
| T009 | [#210](https://github.com/The-Band-Solution/theband/issues/210) | who ended it, spelled out | yes |

## What was not done {#o-que-não-foi-feito}

| Item | Reason | Destination |
|---|---|---|
| the proof on the real data — the orphan ended by the platform | **there is no `running` run linked to the orphan job**: the two there were had been unblocked by SQL before this feature. There is nothing to reconcile | pending until the next collection that dies |
| the sprint's own iteration in ProjectV2 | configuring iterations recreates the existing ones — L11 | product backlog, #176 |
| visual verification of the screen at 360 px | the markup is the same as the existing card, and nobody **looked** | check before closing the next sprint |

## The design change during execution, and it is the learning of the sprint {#a-mudança-de-desenho-durante-a-execução-e-ela-é-o-aprendizado-do-sprint}

The plan had **one** notion of "live job". Running against the real data showed it was
wrong: the orphan job of 2026-08-09 is `executing`, and `executing` would block both the automatic
ending and the human one — **the feature would leave stuck exactly the case that motivated it**.

```
não terminal (bloqueia o automático):  suspended scheduled available executing retryable
vai executar (bloqueia a pessoa):      suspended scheduled available           retryable
```

**A job in execution is not proof of life**: it is the record that some process claimed the
job, and the claim survives the process. The platform does not end it on its own — if the collection
is running, releasing the constraint would make a second one start in parallel. The person can, because
only they know they restarted the application.

## Evidence {#evidências}

```
$ mix gates > /tmp/gates_main2.txt 2>&1; echo "código de saída: $?"
código de saída: 0
10 gates verdes.
Result: 402 passed
```

**Two defects checked by failure**, inverting the code on purpose:

| defect introduced | tests that failed |
|---|---|
| the result of creating the job discarded | **3 of 3** in the `enqueue_failure` file |
| `executing` blocking the person | the two new `executing` cases, in both directions |

**The tests' jobs go to the `oban_jobs` table**, not to a mock: the decision queries the queue, and
a mock would test the mock.

## Debt generated {#dívida-gerada}

| Debt | Why |
|---|---|
| two historical `interrupted` records will say `the platform` | they were unblocked by SQL before the column existed; inventing an author would be worse, and it is declared in the acceptance |
| the worker competes for a slot in the `ingestion` queue | with 5 collections in progress the reconciliation waits — it delays, it does not prevent |
| the proof on the real data is pending | it depends on a collection dying; fabricating the scenario in the database to tick the item would be declaring success without evidence |

## What checking against the source found, and it is not from this feature {#o-que-a-conferência-contra-a-origem-achou-e-não-é-desta-feature}

L30 applied to `leds-conectafapes` found **two live defects**:

| # | Defect | Measured cost |
|---|---|---|
| [#213](https://github.com/The-Band-Solution/theband/issues/213) | the inaccessible mark **does not heal**: the marked repository is filtered before the collection, and the function that would clear the mark never reaches it | **39 repositories, 899 issues** out of every future collection |
| [#214](https://github.com/The-Band-Solution/theband/issues/214) | GitHub **internal** error — HTTP 200 with `errors` — classified as a permanent failure | created the 39th mark today, at 12:32:29 |

And the answer to the question that motivated the check: **the collection is not losing issues through
archiving or through state.** 4,283 at the source, 4,280 in the database; the 3 missing were born after the
last collection. `OPEN` and `CLOSED` both come, and the 7 archived repositories are all collected.

## Lessons from this sprint {#lições-deste-sprint}

**L34** — the same word for two different things hides the case the feature exists to
solve.

**L35** — checking against the source finds defects **outside** the feature being delivered.

Details in [licoes-aprendidas.md](../licoes-aprendidas.md).
