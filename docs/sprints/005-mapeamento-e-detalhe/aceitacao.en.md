# Acceptance — Feature 006: issue detail and navigable decomposition {#aceitação--feature-006-detalhe-da-issue-e-decomposição-navegável}

Assessment of each success criterion of the [spec](../../../specs/006-detalhe-da-issue/spec.md),
**one by one, with evidence**. It is L18 applied: a criterion met is not a sufficient criterion, and a
green suite is not evidence that *this* criterion passed.

**Date**: 2026-08-11 · **PR**: [#149](https://github.com/The-Band-Solution/theband/pull/149) ·
**State**: awaiting human review, **not merged**

Real data at the time of the assessment: **4471 issues**, 135 repositories, 22,877 promotions, 41
tasks with an epic parent and 3 without a parent.

---

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| SC-001 | every field the source provides is persisted or declared out of scope | **accepted** | 3991 issues with a body, 4277 with an author, 2885 with a close reason, 3982 with a board, 4185 with assignees and 1467 labels across 135 distinct names — measured in the database after the real collection |
| SC-002 | no field absent at the source appears filled on the screen | **accepted** | test `ausência de designado e de marco aparece nomeada`: the screen shows "ninguém designado" (nobody assigned), "fora de marco" (no milestone) and "fora de quadro" (no board) |
| SC-003 | composition and service never appear added together | **accepted** | there is no function that returns both together; the contract declares the absence of `count_children/2` with the reason |
| SC-004 | in an epic, show the two counts and **never** the sum | **accepted, and the criterion caught a defect** | `refute html =~ ">39<"` failed the first version, which displayed "partes declaradas 39" (declared parts 39) next to 9 and 30 |
| SC-005 | a user story with nine tasks appears as atomic | **accepted** | test `a user story #3 tem composição vazia e nove tarefas atendendo`, with `classification/2 == :atomic_user_story` |
| SC-006 | the 41 tasks whose parent is an epic appear with the warning, and remain promoted | **accepted** | SQL on the real data returns 41; a test checks that the issue keeps the task `derived_concept` |
| SC-007 | the 3 tasks without a parent appear with the same warning | **accepted** | SQL returns 3; the screen separates them into their own section — they are not a case of the previous one |
| SC-008 | the count by concept adds up to the repository's total issues | **accepted** | test `contagem do cabeçalho soma`, and the screen shows the deviation in red when it does not close |
| SC-009 | the order of the paginated list is the same across two runs | **accepted** | test `a paginação é estável`, comparing the ids of the two reads |
| SC-010 | opening the detail does not generate a request to the source | **accepted by construction** | no screen function calls `Client.graphql/4`; the contract declares the absence of `fetch_issue_from_source/2` |
| SC-011 | no rendered body allows injection of executable content | **accepted** | the collection requests `bodyText` (extracted text, no markup) and HEEx escapes every interpolation |
| SC-012 | one tenant does not reach another's issue or repository | **accepted** | two tests, and both **refuse** the word "permission" in the message |
| SC-013 | two consecutive collections without change produce the same fields | **partially accepted** | idempotence of assignees and labels proven by test; field-by-field equality between two real collections was **not** measured |

**12 accepted, 1 partially accepted. None without evidence.**

---

## The defect that checking against the source found {#o-defeito-que-a-conferência-com-a-origem-encontrou}

**The suite was green and the data was wrong.**

When measuring for this acceptance, 480 issues appeared with a null `body` after a collection that
observed them. Checked against the API: `bodyText` of issue `#1` of `Integrador SIGFAPES` returns `""`
with length zero — the source **has** the answer, and the database recorded `NULL`.

**Cause**: `Ecto.Changeset.cast/4` discards an empty string by default — `empty_values` is `[""]`.
For almost every field that is correct. For `body`, it is not: it is precisely the distinction the feature
declared between "never requested from the source" (`nil`) and "the source has no description" (`""`).

**Effect**: the screen would say "body not collected" about 480 issues that were collected and genuinely empty.

**Fix**: a separate `cast` for `:body` with `empty_values: []`, and a test that **fails without the
fix** — verified by removing the line and running the suite: 14 of 15.

**The 480 rows are fixed on the next collection.** No retroactive repair: filling in `""` by
deduction would assert about the source something that only the collection can say.

It is L13 for the third time, and the second time in this feature — `nil` and `""` are not the same thing. And
it is the lesson of checking the number against the source: the suite had no way to catch it, because the test
scenario never recorded an empty body.

---

## Gates verification {#verificação-dos-gates}

```text
mix gates → 9 gates verdes        (código de saída 0, não o texto — L22)
mix test  → 248 passed            (218 antes da feature)
CI do PR  → quality-gates SUCCESS
```

## What was **not** verified, and is declared {#o-que-não-foi-verificado-e-é-declarado}

| Item | Why |
|---|---|
| SC-013 field by field between two collections | would require two complete collections of the same organization; the idempotence of the parts is proven |
| independent review by another agent | the constitution requires it, and this session does not invoke an agent without an explicit request — declared gap, **never** marked as fulfilled |
| behavior with a body of thousands of lines | edge case 2 of the spec; the screen uses `whitespace-pre-wrap` without truncating |
| author that is a bot | edge case 3; the path is the same as for an uncollected author, and it is exercised |
