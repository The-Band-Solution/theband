# Sprint 008 — Review {#sprint-008--review}

**Period**: 2026-08-12 to 2026-08-18
**Feature**: [009 — mark that heals](../../../specs/009-marca-que-se-cura/spec.md)
**PR**: [#230](https://github.com/The-Band-Solution/theband/pull/230), `MERGEABLE · CLEAN`,
CI green in 2m4s

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 9 | 9 |
| Accepted deliverables | 9 | **9** |

**10 gates green by exit code**, **430 tests**, 28 of them the feature's own. The criterion-by-criterion
assessment is in [aceitacao.md](../../../specs/009-marca-que-se-cura/aceitacao.md): **12
of 12 SC met**, two with the caveat of not having been exercised in production.

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#220](https://github.com/The-Band-Solution/theband/issues/220) | `inaccessible_reason` from `varchar(255)` to `text`, truncation at the edge | yes |
| T002 | [#221](https://github.com/The-Band-Solution/theband/issues/221) | `transient?/1` judges a GraphQL error, with the real payload in the test | yes |
| T003 | [#222](https://github.com/The-Band-Solution/theband/issues/222) | a momentary failure does not mark — assertion in the database | yes |
| T004 | [#223](https://github.com/The-Band-Solution/theband/issues/223) | `list_collectable/2` rejects only the excluded; 96 → **135** collectable | yes |
| T005 | [#224](https://github.com/The-Band-Solution/theband/issues/224) | the date preserves the beginning; the reason carries the last failure | yes |
| T006 | [#225](https://github.com/The-Band-Solution/theband/issues/225) | the mark goes away **and** the issues come in, in the same run | yes |
| T007 | [#226](https://github.com/The-Band-Solution/theband/issues/226) | the collection completes with everything failing; the excluded gets no request | yes |
| T008 | [#227](https://github.com/The-Band-Solution/theband/issues/227) | `repositories_unreachable`, incremented at each failure | yes |
| T009 | [#228](https://github.com/The-Band-Solution/theband/issues/228) | the list says since when and why, readable without color | yes |

## What was not done {#o-que-não-foi-feito}

| Item | Reason | Destination |
|---|---|---|
| the proof on the real data — the 39 marks cleared by a collection | **it requires the master key and the token**, which belong to the maintainer. I neither ask for them nor receive them | pending, with the procedure in V2 and V3 of the quickstart |
| the sprint's own iteration | configuring iterations recreates the existing ones — L11 | product backlog, #176 |
| visual verification of the screen at 360 px | the state cell grew, and nobody **looked** | check before closing the next sprint |

## What the analysis changed, before the code {#o-que-a-análise-mudou-antes-do-código}

Six corrections, and the critical one **was not about the feature's logic**:

`inaccessible_reason` was `varchar(255)`. The largest stored reason has 181 characters, and the one for the internal
failure comes to **~228** with the prefix — **27 of slack**. Without `validate_length`, the long value goes to the
database and **raises**; `registrar_ou_seguir/2` covers an invalid changeset, not a driver exception: the collection
phase would go down.

What made this urgent was the feature itself: it makes the platform write that field **at each
collection that fails**, instead of once.

And **three suspicions were taken down by measurement** instead of being accepted: the source's budget
(`cost = 1`, 160 points of 5,000), another consumer of `list_collectable/2` (one in production, zero in
test), and `clear_inaccessible/2` leaving the reason behind (it clears both fields).

## Evidence {#evidências}

```
$ mix gates > /tmp/g9b.txt 2>&1; echo "código de saída: $?"
código de saída: 0
10 gates verdes.
Result: 430 passed
```

```sql
observados=135   coletáveis antes=96   coletáveis depois=135
voltam a ser tentados=39   issues dentro deles=899
```

**Two defects checked by failure**, inverting the code on purpose:

| defect reintroduced | tests that failed |
|---|---|
| `list_collectable/2` filtering the inaccessible again | **3** |
| GraphQL error always permanent | **3** |

## Debt generated {#dívida-gerada}

| Debt | Why |
|---|---|
| a repository deleted at the source will be queried at each collection | it is the price of not giving up; the review criterion is the **nature of the error**, never time |
| the classification of the internal failure depends on the message **text** | third-party text changes; the test uses the real payload, and the cure makes the mark reversible |
| the proof on the real data is pending | it depends on a credential that is not mine |

## The defect this sprint found outside of it {#o-defeito-que-este-sprint-achou-fora-dele}

The orphan `@doc` that I introduced in the feature 008 commit **passed the ten gates and the CI**. In a
clean compilation, `main` fails:

```
$ git stash && rm -rf _build/dev/lib/the_band && mix compile --warnings-as-errors
main limpo: código de saída 1
redefining @doc attribute previously set at line 395
```

**And the mechanism I published was wrong.** The experiment that isolated it, done later, showed
something else: the warning **is** emitted — three times in the output —, and the gate exits **zero** because
`execute({:mix, ...})` **discarded the return** of `Mix.Task.run/2`. `mix compile
--warnings-as-errors` does not raise: it returns `{:error, diagnostics}`.

The compilation gate **never failed on a warning**, neither locally nor in CI. Recorded in
[#229](https://github.com/The-Band-Solution/theband/issues/229), **Bug, P0**, with the corrected
diagnosis, and L36 rewritten.

The fix came along in this branch because without it the feature itself does not pass the gates — and it is
declared in the PR.

## The gate defect, fixed afterwards {#o-defeito-do-gate-corrigido-depois}

The orphan `@doc` finding led to a second fix, in
[PR #231](https://github.com/The-Band-Solution/theband/pull/231): **the compilation gate never
failed on a warning**, because `execute({:mix, ...})` discarded the return of `Mix.Task.run/2` — and that
applied to every `{:mix, ...}` gate.

The verdict became the **exit code**, with each gate in a subprocess. Full `mix gates` in
**78.6 s**, and **2.46 s** to fail with the defect present. The CI went green with the honest gate,
which means no invisible debt was hidden behind it.

## Lessons from this sprint {#lições-deste-sprint}

**L36** — a gate that discards the task's return is not a gate. And the corollary about method: when two
true measurements seem to contradict each other, the link between them is a **hypothesis**, not a conclusion.

**L37** — the narrow column only falls when the write becomes frequent.

Details in [licoes-aprendidas.md](../licoes-aprendidas.md).
