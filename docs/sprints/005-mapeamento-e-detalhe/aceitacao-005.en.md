# Acceptance — Feature 005: mapping rules per organization {#aceitação--feature-005-regras-de-mapeamento-por-organização}

Assessment of each success criterion of the [spec](../../../specs/005-regras-de-mapeamento/spec.md),
**one by one, with evidence**. It is L18: a criterion met is not a sufficient criterion, and a green
suite is not evidence that *this* criterion passed.

**Date**: 2026-08-12 · **PRs**: [#182](https://github.com/The-Band-Solution/theband/pull/182)
and [#183](https://github.com/The-Band-Solution/theband/pull/183), **merged**

Real data at the time of the assessment, after the recomputation:

```
4474 issues · 4474 com conceito · 1023 high · 3451 low · 488 divergências
35 764 promoções acumuladas (append-only) · 0 regras cadastradas
```

---

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| SC-001 | declared types mapped, no issue with a type remains without a concept | **accepted** | the 110 issues with type `Task` and the 186 `Bug` ones have a concept; no issue with a declared type was left without one |
| SC-002 | `começa com [TASK]` ("starts with [TASK]") promotes only those that start with it, not those that contain it | **accepted** | test `começa com não é contém`, with the `"STATUS"` case explicit |
| SC-003 | no issue with a declared type is classified by a title rule | **accepted** | test `tipo declarado vence regra de título`; stage 2 **is not reached** when stage 1 decides |
| SC-004 | 100% of rule-based promotions record rule, version, source and confidence | **accepted** | SQL: 1023 `high` + 3451 `low`, and no new row without `evidence_source` |
| SC-005 | promotion by title is distinguishable from promotion by declared type | **accepted** | `evidence_source` and `confidence` on every new row; the screen shows both |
| SC-006 | no invalid, empty-matching or slow expression is recorded | **accepted** | `pattern_validator_test.exs` — each refusal is a case, and the test is the violation |
| SC-007 | the preview shows the same count that the recomputation produces | **accepted, with the meaning corrected** | see below |
| SC-008 | recording a rule does not generate a request to the source | **accepted by construction** | no `Mapping` function calls `Client.graphql/4`; the recomputation runs without the master key, and that is how I ran it on the real data |
| SC-009 | running the recomputation twice produces the same result | **accepted, measured on the real data** | second run: `gravadas 0` in all three organizations |
| SC-010 | the screen distinguishes a pattern that is a type from a pattern that is not | **accepted** | two separate lists; a test refuses `[Devops]` among the proposals |
| SC-011 | activating a proposal records the person, never "system" | **accepted** | test `ativar registra a pessoa como autora`; `created_by_id` is *not null* |
| SC-012 | a catalog update does not overwrite an edit | **accepted** | composition at read time; a test checks that the YAML does not change when editing the rule |
| SC-013 | the screen shows how much of the total still has no concept | **accepted** | `gap_summary/2` in the component header |
| SC-014 | a deactivated rule stops applying and remains queryable | **accepted** | test `desativar não apaga`; there is no `delete_rule` |
| SC-015 | the order between rules is deterministic and visible | **accepted** | unique index on `(organization_id, position)`; a test inverts the order and the decision follows |
| SC-016 | one tenant does not reach another's rule | **accepted** | the test returns `:not_found` and **refuses** the word "permission" |
| SC-017 | no measure adds inference and declaration without saying so | **accepted** | there is no query that aggregates without `evidence_source`; the screen always shows the confidence |

**17 accepted. None without evidence.**

---

## SC-007, and why the verdict has a caveat {#sc-007-e-por-que-o-veredito-tem-ressalva}

The criterion says the preview shows the same count that the recomputation produces. It **caught a
real defect**: the preview said 1 and the recomputation recorded 90, because each had its own
"changed" comparison.

After the fix, the structural rule changed the **meaning** of the question. Today there are two
pairs of numbers, and both match:

| preview | recomputation | what it measures |
|---|---|---|
| `would_change` | — | the effect **of the rule**: with it versus without it |
| `rows_to_write` | `written` | what the write produces versus what is recorded |

The distinction is not nitpicking: without it, the preview would attribute to the rule everything the structural
stage decides — and the structure would decide anyway. Two tests measured the old meaning and were
rewritten.

---

## What the feature delivered, and what it did **not** decide {#o-que-a-feature-entregou-e-o-que-ela-não-decidiu}

**The screen exists and no rule was registered.** That is not a failure: the 4474 issues got a
concept through **structure**, which requires no rule. The catalog is still proposed, and the decision to
activate belongs to whoever administers.

The number that matters is not "100% classified" — it is the proportion:

```
1023 por evidência forte (tipo declarado)
3451 pela mais fraca (estrutura)
```

And the **488 divergences** are the other side of that: user stories the team declared and that, by
structure alone, would be tasks. They remain user stories, with the warning visible.

---

## The two defects that checking against the source found {#os-dois-defeitos-que-a-conferência-com-a-origem-achou}

Neither appeared in the suite. Both appeared when comparing a platform number with the source.

**899 issues outside any collection.** 38 repositories marked inaccessible by an `:nxdomain`, and
the mark was in practice permanent. Fixed at both ends: a transient error does not mark, and the collection
that reaches the repository clears it.

**488 divergences computed and not recorded.** `mudou_registro?/2` did not compare the
divergence. The screen showed zero, and whoever read it would conclude that nothing diverges.

---

## Gates verification {#verificação-dos-gates}

```text
mix gates → 9 gates verdes        (código de saída 0, não o texto — L22)
mix test  → 341 passed            (218 no início do sprint)
CI        → quality-gates SUCCESS nos dois PRs
```

## What was **not** verified, and is declared {#o-que-não-foi-verificado-e-é-declarado}

| Item | Why |
|---|---|
| the screen with a registered rule, on the real data | no rule was created; the screen was exercised by a LiveView test |
| the regex time limit over 4474 real titles | measured on a sample of 200; the limit is per expression, not per batch |
| independent review by another agent | the constitution requires it, and this session does not invoke an agent without an explicit request — **declared gap**, never marked as fulfilled |
