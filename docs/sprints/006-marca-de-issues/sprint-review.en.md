# Sprint 006 — Review {#sprint-006--review}

**Period**: 2026-08-12 to 2026-08-18
**Feature**: [007 — issue mark](../../../specs/007-marca-de-issues/spec.md)
**PR**: [#195](https://github.com/The-Band-Solution/theband/pull/195), base
`007-interface-em-ingles`

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 2 | 2 |
| Tasks | 7 | 7 |
| Accepted deliverables | 7 | **7** |

**Incorporated on 2026-08-12T12:21:51Z**, PR [#195](https://github.com/The-Band-Solution/theband/pull/195),
after #184 — the order mattered, because the mark applies the design system that lives there.

`main` at `277d159` with **10 gates green by exit code**. The criterion-by-criterion
assessment is in [aceitacao.md](../../../specs/007-marca-de-issues/aceitacao.md): **10 of the 11 SC
met**, and the remaining one — SC-009, readability at 360 px — is declared **not
verified**, because the structure exists and nobody looked at the screen. Declaring it met would be declaring
success without evidence.

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | State |
|---|---|---|---|
| T001 | [#188](https://github.com/The-Band-Solution/theband/issues/188) | `count_collected_by_repository/2` — grouped query of in-force issues, with 5 tests | accepted |
| T002 | [#189](https://github.com/The-Band-Solution/theband/issues/189) | `por_repositorio/2` makes **1** query instead of 135 | accepted |
| T003 | [#190](https://github.com/The-Band-Solution/theband/issues/190) | `issues_collected_at` migration, field in the schema and in `list_observed/2`; round trip checked | accepted |
| T004 | [#191](https://github.com/The-Band-Solution/theband/issues/191) | `CMPO.mark_issues_collected/3`, stored at the same point as the checkpoint, with 2 ingestion tests | accepted |
| T005 | [#192](https://github.com/The-Band-Solution/theband/issues/192) | the mark with three channels, the count deciding first | accepted |
| T006 | [#193](https://github.com/The-Band-Solution/theband/issues/193) | `no current work` — there was work and there is none in force | accepted |
| T007 | [#194](https://github.com/The-Band-Solution/theband/issues/194) | the 135 remain clickable, including the 94 without work | accepted |

## What was not done {#o-que-não-foi-feito}

| Item | Reason | Destination |
|---|---|---|
| the sprint's own iteration in ProjectV2 | configuring iterations recreates the existing ones — L11, it cost reassigning 96 items | product backlog, maintainer's decision |
| `Epic` and `User Story` types in the organization | creating a type changes the organization's configuration | product backlog |
| visual verification of V1 and V7 (eyes on the screen, 360 px) | the three states are asserted in the rendered HTML, and nobody **looked** | pending — SC-009 recorded as not verified in the acceptance |

## Two design changes during execution, and both are declared {#duas-mudanças-de-desenho-durante-a-execução-e-as-duas-são-declaradas}

### The contract gained a third function {#o-contrato-ganhou-uma-terceira-função}

`repositories_with_absent_issues/2`. The contract declared two, and the fourth text —
`no current work` — **is not derivable** from them: the in-force count does not distinguish "never had
an issue" from "had and no longer has". The correction went in the same commit, and the contract records the
why.

### The text of the third state changed, and the reason was measured {#o-texto-do-terceiro-estado-mudou-e-a-razão-foi-medida}

It was `not collected yet`, which **asserts** that the collection did not occur. Measured in the database after the
migration: 94 repositories with a null date, and the collection visited **61** of them and found nothing. Saying
"not collected" about them is the screen asserting what it did not observe.

It became **`no collection recorded`** — it names the absence of the **record**, which is what exists. It is the
same principle as finding A1, in the opposite direction: do not assert a collection that did not happen, and do not assert
the absence of a collection that did.

## The defect that this feature's test found in code that already existed {#o-defeito-que-o-teste-desta-feature-achou-em-código-que-já-existia}

T004's test reproduces the real race — the repository leaves observation **during** the phase — and
the phase died with `MatchError` at `{:ok, _} = CMPO.clear_inaccessible/2`, **one point before** the
new code. Both calls now log with the repository name and move on.

It is not a silent fallback: the log names it, and nothing afterwards reads the date as if it existed.

## Evidence {#evidências}

**The ten gates, by exit code:**

```
$ mix gates > /tmp/gates2.txt 2>&1; echo "exit=$?"
exit=0

10 gates verdes.
```

370 tests, 19 new.

**V9 on the real data** — the measure the analysis asked for, against the development database **after**
the migration:

```
observados=135  com_data=0  sem_data_com_issues=41  sem_issues_vigentes=94
```

No previous collection recorded the date. The 41 appear with work because the count decides
first; if the date decided, the 41 would appear as not collected.

**The two defects, verified by failure** — inverting the code on purpose:

| Defect introduced | Tests that failed |
|---|---|
| date deciding before the count | **5**, including the FR-005a one with the message about the 41 |
| same shape in the three states, distinguishing only by color | **1**, the WCAG 1.4.1 one |

A test that does not fail when the defect exists is evidence of nothing — it is L18.

## Debt generated {#dívida-gerada}

| Debt | Why |
|---|---|
| the mark only exists in `/work` | FR-013 closed the scope; the second caller is what justifies the component — R1 |
| the 135 remain without `issues_collected_at` until the next collection | the migration does not invent a date that was not observed; the collection stores it |
| two sprints without an iteration in ProjectV2 | `flow.throughput` and `flow.wip.count` do not separate 003 to 006 |

## Lessons from this sprint {#lições-deste-sprint}

**L32 — Text that asserts what the platform did not observe is the same defect, in the opposite
direction.** The feature was born to prevent absence from being drawn as zero, and the first
version of the text said `not collected yet` about 94 repositories of which the platform only knows it has
no record. Watching one direction and not the other is easy: both are the same question — *what
does this sentence assert, and did the platform observe it?*

**L33 — The question that the analysis asks and the unit test does not is "what does the screen say on the day of the
migration".** Each piece of A1 worked. The defect only shows up when one asks about the state of the
world in the instant after the schema change — and no unit test has that instant
as a scenario.

Details in [licoes-aprendidas.md](../licoes-aprendidas.md).
