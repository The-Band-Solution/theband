# Sprint 005 — Review {#sprint-005--review}

**Period**: 2026-08-11 to 2026-08-12
**Features**: [005 — mapping rules](../../../specs/005-regras-de-mapeamento/spec.md) ·
[006 — issue detail](../../../specs/006-detalhe-da-issue/spec.md)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| Features | 2 | 2 |
| User stories | 8 | 8 |
| Tasks | 25 (005) + 20 (006) | 45 |
| Tests | — | 218 → **341** |
| Accepted deliverables | — | 30 criteria of 30 |

Three PRs merged: [#149](https://github.com/The-Band-Solution/theband/pull/149) (006),
[#182](https://github.com/The-Band-Solution/theband/pull/182) and
[#183](https://github.com/The-Band-Solution/theband/pull/183) (005).

## What was done {#o-que-foi-feito}

### Feature 006 — issue detail {#feature-006--detalhe-da-issue}

| US | Issue | Deliverable | Accepted |
|---|---|---|---|
| US1 | [#145](https://github.com/The-Band-Solution/theband/issues/145) | 9 new fields collected; body, author, assignees, labels, milestone, boards | yes |
| US2 | [#146](https://github.com/The-Band-Solution/theband/issues/146) | composition and service in separate sections, **never added together** | yes |
| US3 | [#147](https://github.com/The-Band-Solution/theband/issues/147) | `sro.rule07` as a pure function, used by both paths | yes |
| US4 | [#148](https://github.com/The-Band-Solution/theband/issues/148) | repository screen with a count that adds up to the total | yes |

Acceptance in [aceitacao.md](aceitacao.md): 12 accepted, 1 partial, none without evidence.

### Feature 005 — mapping rules {#feature-005--regras-de-mapeamento}

| US | Issue | Deliverable | Accepted |
|---|---|---|---|
| US1 | [#140](https://github.com/The-Band-Solution/theband/issues/140) | catalog composed at read time, activation with authorship | yes |
| US2 | [#141](https://github.com/The-Band-Solution/theband/issues/141) | rule by declared type, with validation and preview | yes |
| US3 | [#142](https://github.com/The-Band-Solution/theband/issues/142) | rule by title, with lower confidence | yes |
| US4 | [#143](https://github.com/The-Band-Solution/theband/issues/143) | declare that a pattern is **not** a type, reversible | yes |

Acceptance in [aceitacao-005.md](aceitacao-005.md): 17 of 17, none without evidence.

### Outside the plan, and delivered {#fora-do-plano-e-entregue}

Four things came in during the sprint, requested by the maintainer or discovered when
checking a number against the source:

| What | Why it came in |
|---|---|
| **classification by structure** | new rule: a leaf is a task, whoever has a US is an epic |
| **`divergence_kind`** | the sentence explained but did not allow counting |
| **reorganized run card** | side-by-side bars implied a comparison that does not exist |
| **two collection defects** | 899 issues out of observation; 488 divergences not recorded |

## What was not done {#o-que-não-foi-feito}

| Item | Reason | Destination |
|---|---|---|
| sprint iteration in Projects v2 | configuring recreates the existing ones — L11, 96 items | [#176](https://github.com/The-Band-Solution/theband/issues/176) |
| independent review by an agent | the session does not invoke an agent without an explicit request | **declared gap** |
| defect of the sync stuck in `running` | rose in priority with the new worker, and did not fit | [#175](https://github.com/The-Band-Solution/theband/issues/175) |
| resync with the key | depends on whoever holds the key | next session |

## Deliverables not accepted {#entregáveis-não-aceitos}

**None.** The 30 criteria of the two features were assessed one by one and all have evidence.

Two were accepted **with a written caveat**: SC-013 of 006 (field-by-field idempotence between
two real collections not measured) and SC-007 of 005 (the meaning of "the same count" changed with the
structural rule, and the document says what it is today).

## Evidence {#evidências}

```text
mix gates → 9 gates verdes            (código de saída 0)
mix test  → 341 passed                (218 no início)
CI        → SUCCESS nos três PRs
```

Recomputation run on the real data:

```text
4474 issues · 4474 com conceito · 1023 high · 3451 low · 488 divergências
2,1s para 4280 issues; segunda execução grava zero
```

## Debt generated {#dívida-gerada}

| What | Why it was accepted |
|---|---|
| 3451 issues classified by `low` evidence | the alternative was 77% without a concept; the confidence is recorded on each row |
| the rules screen never used on the real data | no rule was registered — the structure resolved it without a rule |
| `promoções` grew to 35,764 rows | append-only is the choice; the cost shows up if reads become slow |
| replacement that deletes assignee and label | R3 of the research, with a written reversal criterion |

## Lessons from this sprint {#lições-deste-sprint}

Four, and three are the same defect in different clothes: **the number the platform shows
is not the number it has.**

- **L28** — computing and not recording is worse than not computing
- **L29** — a transient failure that marks a permanent state takes data out of circulation silently
- **L30** — checking the number against the source finds what the suite does not find
- **L31** — a new rule changes the meaning of a test that used to pass

Consolidated in [licoes-aprendidas.md](../licoes-aprendidas.md).
