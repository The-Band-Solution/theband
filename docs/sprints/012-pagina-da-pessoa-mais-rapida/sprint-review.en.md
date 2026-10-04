# Sprint 012 — Review {#sprint-012--review}

**Period**: 2026-08-12 · **Feature**: [013](../../../specs/013-pagina-da-pessoa-mais-rapida/spec.md)
**Acceptance**: [aceitacao.md](../../../specs/013-pagina-da-pessoa-mais-rapida/aceitacao.md)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 10 | **10** |
| Functional requirements accepted | 10 | **10** |
| Success criteria accepted | 9 | **9** |

**The worst page in the system dropped from 6.12 s to 0.031 s** — 197 times. The variation between people went
from seventy times to 1.4.

## What was done {#o-que-foi-feito}

| Task | Deliverable | Accepted |
|---|---|---|
| T001 | the count of ties — **zero**, and the discovery that `inserted_at` has microsecond precision | yes |
| T002 | five cases locking down the answer before the rewrite | yes |
| T003 | six deterministic snapshots | yes |
| T004 | lateral resolution per issue, with `inner`/`left` preserved and named bindings | yes |
| T005 | index `(person_id, no_longer_observed_at)`, with up and down | yes |
| T006 | the second definition aligned, and the duplication declared in the code | yes |
| T007 | **six empty `diff`s** | yes |
| T008 | the invariant `coletadas == promovidas + lacunas`, with and without an unpromoted issue | yes |
| T009 | the measurement of the eight people, `/work` and `/people`, five times each | yes |
| T010 | a doubled history does not double the rows read | yes |

**No task was left open**, and none depended on the master key — unlike the two previous
sprints.

## Evidence {#evidências}

```
mix gates → 10 gates verdes, código de saída 0
diff dos seis retratos → vazio
tadeuaugustovs: 6,12 s → 0,031 s   (5 medidas, variação < 8%)
/work: 322 ms → 120 ms
```

## Debt generated {#dívida-gerada}

| Debt | Why it was accepted |
|---|---|
| `mapping/queries.ex` keeps the second definition of in-force promotion | reusing it would require exposing a subquery across the boundary, which ADR 0003 forbids. The orderings were aligned and the duplication is written in the code |
| `DISTINCT ON` remains where the question is aggregated | lateral per row only wins when there are few rows to decorate |

## What the analysis and the plan found before the code {#o-que-a-análise-e-o-plano-acharam-antes-do-código}

**Seven findings, none from running a test** — all from measuring the database, reading the code or looking at the plan:

| Phase | Finding |
|---|---|
| measurement | paginating does not solve it: `LIMIT 5` costs 6,300 ms and `LIMIT 100` costs 6,648 |
| measurement | trimming the projection does not solve it: 5,738 ms |
| analysis | eight of the fourteen calls are `inner`, and `left` would make the screen gain rows |
| analysis | `parent_as` requires a named binding — L39 |
| analysis | the `EXPLAIN` test would fail with the right code |
| analysis | the timing test measured a clock inside the suite — L22 |
| analysis | the snapshot in raw HTML would never give an empty `diff` |

**Eighth feature in a row** in which the analysis finds a design defect before the first line.

## Lessons from this sprint {#lições-deste-sprint}

- **L49** — one measurement does not describe a screen whose cost depends on the execution plan;
- **L50** — a test that compares two measurements needs to prove it measured something;
- **L51** — asserting about the schema without checking contradicts the documentation already in the code.
