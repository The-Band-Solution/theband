# Sprint 032 — Acceptance record {#sprint-032--registro-de-aceitação}

**Feature**: [065 — the label as a field of the work item](../../../specs/065-rotulos-no-item/spec.md)
**Evaluated on**: 2026-09-13, on `development` at `0ccf02b` (PRs #907 and #908 merged), with
evidence executed in this evaluation — named tests, screen probes over a real scenario, and
read-only queries against the development database.
**Role**: Product Owner — evaluation **proposed by the agent** in the `sro.product_owner_role` role,
published as a comment on each user story issue on 2026-09-13
([#904](https://github.com/The-Band-Solution/theband/issues/904#issuecomment-5656207868),
[#905](https://github.com/The-Band-Solution/theband/issues/905#issuecomment-5656210973),
[#906](https://github.com/The-Band-Solution/theband/issues/906#issuecomment-5656213669)).
**Confirmation by the person allocated to the role: PENDING.** No issue was closed.
**PO type**: `sro.product_owner_client` — whoever demands is whoever maintains.
**Rule**: `sro.rule03` — the phase follows from the criteria, with executed evidence; a criterion without
evidence does not become accepted.

## Summary {#resumo}

| | Count |
|---|---:|
| Deliverables evaluated | 3 |
| Accepted | 1 (US3 — pending confirmation and the review of #907) |
| Not accepted | 2 (US1, US2) |
| Criteria evaluated | 37 — 26 conforming · 7 non-conforming · 2 ambiguous · 2 not measured |
| Tasks performed successfully | 6 (T001, T002, T003, T004, T006, T008) + 4 without a user story (T009, T010, T013, T014) |
| Tasks performed unsuccessfully | 4 (T005, T007 through D1; T011, T012 through D2) |

**The two refusals are of different natures.** US1 is refused for a **measured defect** — the detail
does not do what the listing does — and for two criteria without evidence. US2 is refused for something
**prior to the code**: the spec and the mechanism call different things "label", and the US's example
is not a divergence for the platform. Rewriting the screen without deciding this would be announced
rework.

### Executed evidence, common to all three {#evidência-executada-comum-aos-três}

| command | output | code |
|---|---|---:|
| `mix test test/the_band/work_items/rotulos_na_listagem_test.exs` | 7 passed | 0 |
| `mix test test/the_band/work_items/prefixo_vira_rotulo_test.exs` | 9 passed | 0 |
| `mix test test/the_band/work_items/divergencia_com_rotulo_test.exs` (promised by T011) | **file does not exist** | — |
| role probe — `/work` and the detail rendered over `cenario_real/1`, HTML printed | 6/9 — the 3 failures are from US2 and from a probe marker | 2 |
| role probe, part 2 — `WorkItems.decide/2` with and without prefix; fabricated divergent promotion | 3 passed | 0 |
| read-only `mix run --no-start` (Repo + KnowledgeBase, no Oban) + `psql` via `docker exec` on `the_band_dev` | counts below | 0 |
| `mix gates` — **not rerun**; CI run [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) on `0ccf02b` | success | — |

The probes are the role's instrument and do not stay in the repository.

---

## D1 — The labels in the list, with the origin of each {#d1--os-rótulos-na-lista-com-a-origem-de-cada-um}

**Produced by**: 065/T001–T003, T005–T007 · [#890](https://github.com/The-Band-Solution/theband/issues/890),
[#891](https://github.com/The-Band-Solution/theband/issues/891), [#892](https://github.com/The-Band-Solution/theband/issues/892),
[#894](https://github.com/The-Band-Solution/theband/issues/894), [#895](https://github.com/The-Band-Solution/theband/issues/895),
[#896](https://github.com/The-Band-Solution/theband/issues/896) · PR [#907](https://github.com/The-Band-Solution/theband/pull/907)
**Materializes**: 065/US1 — see, in the list, what the team called each item · [#904](https://github.com/The-Band-Solution/theband/issues/904) · P1

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AC1 — label from the field in the row, with the **observed** mark | functional | yes | HTML of row `#2`: `bg-success text-success-content`, `title="observed — set on the label field at the source"` wrapping `backend` |
| AC2 — recognized prefix becomes a **derived** label, distinguishable **without color** | functional | yes | same row: `Back-end` with `outline` + `repeating-linear-gradient(135deg…)` (shape) and `title="derived — read from the bracketed prefix in the title"` (text) |
| AC3 — item without a label states **absence** in writing | functional | yes | row `#3`: `<span class="text-xs italic opacity-60">no label</span>`; never an empty cell |
| AC4 / FR-013 / SC-005 — queries do not grow with the rows | non-functional | yes | test T003: 1 query for 10 and for 100 (`assert cem == 1`); real database: **1 query** for 10, 100 and 1,000 items |
| **Independent test** — "the same labels appear when opening each item" | functional | **no** | issue `[Devops] …` with label `backend`: `/work` shows `backend` (observed) **and** `Devops` (derived); `/work/issues/:id` shows only `backend`, as `badge-ghost`, **without origin and without the derived one** |
| FR-001 — labels in the **listing and in the detail** | functional | listing yes · **detail no** | same evidence: the detail exposes only the field's ones |
| FR-002 — the label declares **where it came from** | functional | listing yes · **detail no** | `Rotulos.de/2` returns `origem: :campo \| :titulo` (test); on screen, `title` per origin; the detail's `labels` field declares nothing |
| FR-003 — distinction without color | non-functional | yes, in the listing | shape (solid × hatching+outline) **and** text (`title`), measured in the HTML |
| FR-004 — only prefixes from the declared list | functional | yes | test: `[Portal ADM]` (68 real issues) and `[Qualquer Coisa]` → `nil` |
| FR-005 — the list lives with the refusal, without repetition | non-functional | yes | `Mapping.prefixos_recusados_como_tipo/0` returns the 8 from `not_type_patterns` of the loaded base; `grep` in `lib/` and `priv/knowledge_base/`: no literal outside the catalog. **Without the promised test** of adding a prefix and seeing it appear |
| FR-006 — a type prefix does not become a label | functional | yes | test: `[TASK]`, `[FEATURE]`, `[BUG]` → `nil` |
| FR-010 / SC-007 — absence in writing | functional | yes | `no label` in the row; **2,811 of the 5,033** real issues fall into this case |
| FR-012 / SC-006 — same order on every read | non-functional | yes | test (two identical reads; `ORDER BY` inside the `array_agg`); real database: two reads of 5,033 identical rows |
| SC-001 — labels of **all** items visible without opening any | functional | yes | 50 rows on the page, 50 with a label or a written absence |
| SC-002 — "the 1,519 issues with a prefix come to have a queryable label" | functional | **mechanism yes; number does not reproduce** | by the delivered function over the real titles: **1,489** derive (`Devops` 369 · `Back-end` 316 · `Front-end` 303 · `Dados` 267 · `QA` 113 · `Backend` 83 · `Front` 35 · `Infra` 3). With `ILIKE` it would be 1,536: **47** case variants do not derive. 1,519 is neither of the two |
| SC-003 — origin right in 100%, including in **grayscale** | non-functional | **not measured** | requires the rendered screen; T013 read **code**, by whoever implemented — it is not independent evidence |
| FR-015 — screen **exactly** the one of the approved prototype | non-functional | **not measured** | no capture of the real screen, no `PROMPT.md`; T013 declares it did not look at the rendered screen |
| maintainer's decisions: column **last**; **3 + `+N`** that opens the issue; GitHub color **not** used | functional | yes | `labels` is the 8th and last `<td>`; with 5 labels the row shows `a b c` and `+2` as `<a href="/work/issues/…">`; fixed class, no color `style` |

**Derived phase**: **`sro.not_accepted_deliverable`**. It fails the US's own independent test
and FR-001/FR-002 in the detail; SC-003 and FR-015 without evidence. The listing, on its own, is
conforming on every measured criterion — the refusal is for what the US promises and the detail does not deliver, and
for what nobody looked at.
**Phase of the tasks**: T005 and T007 → `sro.non_successfully_performed_scrum_development_task`;
T001, T002, T003, T006 → `sro.successfully_performed_scrum_development_task`. No task
issue is reopened.

**What is missing, exactly**:

1. the detail's `labels` field (`show.ex`, today `badge-ghost` over `@issue.labels`) comes to
   use the same grammar as the listing — both origins, with a mark. **Prototype first**:
   none of the three approved ones covers this field;
2. QA check of the real screen against the prototype, with a capture, including in grayscale
   (SC-003, FR-015), by someone who did not implement it;
3. the maintainer's decision on the **47 case variants** and correction of SC-002's
   number. The role's recommendation: keep the comparison case-sensitive — it is the catalog's, and
   normalizing would be FR-009 applied to the name — and write **1,489**;
4. the screen tests of T005/T007 and T001's `prefixos_test.exs`, as a regression guard.

---

## D2 — The claim next to the verdict {#d2--a-alegação-ao-lado-do-veredito}

**Produced by**: 065/T011, T012 · [#900](https://github.com/The-Band-Solution/theband/issues/900),
[#901](https://github.com/The-Band-Solution/theband/issues/901) — **closed without code** in #907,
with the justification that the divergence "already shows up per row in the main table"
**Materializes**: 065/US2 — see the claim next to the verdict · [#905](https://github.com/The-Band-Solution/theband/issues/905) · P2

**What the real data says before the screen.** The US's example issue — `[TASK] Desativar/corrigir o
GitHub Issues Bot…` (`#2`) — has `issue_type: Bug`, labels `["bug", "oráculo", "task"]`,
`declared_concept: osdef.defect`, `derived_concept: osdef.defect`, **`divergence_kind: nil`**.
For the platform it **is not a divergence**: divergence here is *declared type ×
structure*, not *label × concept*. In the tenant's 512 divergences in force, the kind is always
`user_story_without_parts`; `label_vs_structure` exists in `ConceptLabel` and **is never
produced**. Where label and concept actually disagree — `bug` × task (47), `feature` × task
(69), `enhancement` × task (46) — `divergence_kind` is null in all of them. And `list_divergences/2`
**did not receive labels**.

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AC1 (a) — label and concept **side by side** | functional | yes | row `#200` (Bug→defect, label `task`): `promoted to` = `defect`, `labels` = `task`, in the same `<tr>` |
| AC1 (b) — **the row says they diverge** | functional | **no** | no word of divergence in the row; in the real data the Bot has `divergence_kind: nil` |
| AC2 — item without a label among the divergences says **"nothing to compare"** | functional | **ambiguous** | divergent row without a label shows `user story with no parts or tasks` and `no label`. Non-empty cell: yes. Phrase "nothing to compare": **no**. The role's decision; **348 of the 512** real divergences are in this case |
| AC3 — it is clear **which side the platform followed** | functional | **no, in the row** | only the aggregate card, **per kind**, says `concept kept — signal` / `concept decided by the axiom` |
| FR-014 — show **both** and say **which was followed** | functional | partial | both: yes; "which was followed": only on the per-kind card |
| SC-008 — claim and verdict on the same row, and which was followed **without opening anything else** | functional | **no** | same evidence as AC1(b)/AC3 |
| Independent test — item in which label and concept disagree, the screen shows both **and that they disagree** | functional | **no** | it shows both; one cannot see that they disagree other than by reading and comparing |

**Derived phase**: **`sro.not_accepted_deliverable`** — fails AC1(b), AC3, SC-008 and the
independent test; AC2 awaits a decision.
**Phase of the tasks**: T011 and T012 → `sro.non_successfully_performed_scrum_development_task`.
The spec's criterion did not change, and the deliverable does not meet it. **Do not reopen**: new tasks
are born after the decisions.

**The cause, which needs a decision before a new task.** The spec wrote "label" (GitHub's *label*)
over a mechanism in which the word "label" means *declared type*. The example
chosen is precisely a case in which the platform **sees no divergence**. Without deciding this,
AC1(b) is unreachable as written:

1. **is label × concept a divergence that the platform computes and states?** If yes, it is a new
   derivation rule — and which label "names a concept" is an interpretation of the content, which FR-009
   forbids. If not, US2 needs to be rewritten as *declared type × structure*, which is what
   exists;
2. **does the row say which side was followed?** Today only the aggregate card says it — and for
   `user_story_without_parts` the side followed is the **declared** one ("concept kept"), the opposite of
   what AC3 presupposes;
3. **AC2**: is `no label` enough, or does the divergent row without a label say "nothing to compare"?

A new screen in any of the answers → prototype → code.

---

## D3 — The label never becomes a concept {#d3--o-rótulo-nunca-vira-conceito}

**Produced by**: 065/T004, T008 · [#893](https://github.com/The-Band-Solution/theband/issues/893),
[#897](https://github.com/The-Band-Solution/theband/issues/897) · PR [#907](https://github.com/The-Band-Solution/theband/pull/907)
**Materializes**: 065/US3 — the label never becomes a concept · [#906](https://github.com/The-Band-Solution/theband/issues/906) · P1

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AC1 — task item gets the `bug` label, the classification stays **task** | functional | yes | test T004 (`assert depois == antes`, `refute depois == "osdef.defect"`), exit 0 |
| AC2 — area prefix **does not take part** in the type decision | functional | yes | `decide/2`: `Task` + `[Devops] x` = `Task` + `x`; no type + `[Devops] x` = no type + `x` → `skip type_absent`; `Feature`+`[QA] x`+parts `Task` = without prefix. Three identical pairs |
| AC3 — `chave:valor` appears **as written**, no field filled in | functional | yes | FR-009 test (`prioridade:alta`, `epic:base`, `tipo:infra` literal); screen: `>prioridade:alta<` and `>epic:base<` in row `#201`; no item field derived from a label. Real data: 48 `prioridade:alta`, 37 `prioridade:media`, 21 `epic:qualidade`, all text |
| FR-007 — a label never changes the classification | functional | yes | T004; SC-004; real data: `bug` × task (47), `feature` × task (69), `epic` × atomic (5) coexist with null `divergence_kind` |
| FR-008 — distinct origins **neither unified nor normalized** | functional | yes | `Rotulos.de(["backend"], "[Back-end] …")` → 2 elements; screen: row `#2` with two labels and two `title`s; real data `#2212` has `["backend"]` in the field and `[Back-end]` in the title; 238 issues with both origins |
| FR-009 — label content not interpreted | functional | yes | same as AC3 |
| SC-004 — any label, **100%** without change | non-functional | yes | probe: `#1`, `#3`, `#98`, `#200`, `#201` — before = after following `bug task feature epic prioridade:alta epic:base` on each one: 5/5 |
| Independent test — put `bug` on a task item, the classification does not change | functional | yes | T004 |

**Derived phase**: **`sro.accepted_deliverable`** — 8 of 8 conforming.
**Phase of the tasks**: T004, T008 → `sro.successfully_performed_scrum_development_task`.
**Acceptance is not consummated**: it requires (a) confirmation by the person allocated to the role, and
(b) a post-merge review recorded on #907 by `Adylla027` or `EduardoNFraiz`, **or** the maintainer's
dated attestation with the exception recorded — the role does not accept a deliverable whose PR
was born without a requested reviewer and outside the project. Once both are done: `gh issue close 906 --reason completed`.

---

## Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

**The scope of phase 4 (T009, T010) was rewritten in #908**, after #907: the tasks were born
describing the listing, where there was no defect, and came to describe the detail. It is a change of
**task**, not of a spec criterion — FR-016 and FR-017 did not change. US2 did **not** have its criterion
changed when T011/T012 were closed without code; that is why their phase is what it is.

## Criteria without evidence {#critérios-sem-evidência}

| Criterion | User story | What is missing |
|---|---|---|
| SC-003 — origin right in 100%, in grayscale | 065/US1 | look at the rendered screen, by someone who did not implement it |
| FR-015 — screen exactly the prototype's | 065/US1 | capture next to the prototype; `PROMPT.md` |
| AC2 — "nothing to compare" | 065/US2 | the role's decision on what is enough |

## Criteria without a user story {#critérios-sem-user-story}

FR-011, FR-015, FR-016, FR-017, FR-018, SC-009 and SC-010 are not tied to any US — T009 and
T010 have no `[US]`. Measured in passing and conforming where possible: `#2393` composes `#205` and `#512`
from two other repositories, with `repositorio` on each part; 1,953 links in force, 5 cross
repositories; rule `border-l-[3px]` for composition and `→` for fulfilment. The
`other repository` mark **was not exercised on screen**.

## Process gaps {#lacunas-de-processo}

1. **PRs #907 and #908 without a requested reviewer and outside Projects v2** — zero
   `review_requested` events, empty `reviews`, empty `projectItems`. It is an *unrequested review*: the
   maintainer is the `author` of record and did not write the code, so is a legitimate reviewer; the
   attestation was not written;
2. **the approved prototype is not recorded** as the role requires — no
   `specs/065-rotulos-no-item/prototipo/PROMPT.md`, no item in `docs/backlog/`;
3. **T013 was done by whoever implemented it**, by reading code — the independent check of the screen
   did not happen;
4. **five test files promised in `tasks.md` do not exist** (T001, T005, T007, T011, T012);
5. **this record was written afterwards** — the sprint ran without a `sprint-backlog.md`, and the evaluation
   was born as a comment on the issues because there was no sprint folder for it to live in.

## What happens to the issues, after confirmation {#o-que-acontece-com-as-issues-depois-da-confirmação}

**Proposed**, and nothing executed until confirmation:

| Issue | Action | Reason |
|---|---|---|
| #906 (US3) | **close** | accepted deliverable — after the confirmation **and** the review of #907 (or the attestation with exception) |
| #904 (US1) | **stays open**, with a destination | next sprint backlog, first in line, with the four new tasks from D1 |
| #905 (US2) | **stays open**, with a destination | product backlog, until the three decisions of D2 |
| #890–#903 (T001–T014) | **stay closed** | executed; the phase of T005, T007, T011 and T012 is `non_successfully_performed`, and that is written here — closing the issue does not erase the phase |

## Destination of the user stories {#destino-das-user-stories}

| User story | Issue | Destination |
|---|---|---|
| 065/US1 | [#904](https://github.com/The-Band-Solution/theband/issues/904) | **next sprint**, first — the detail via prototype, the QA check, the decision on the 47 variants with SC-002 corrected, the tests owed |
| 065/US2 | [#905](https://github.com/The-Band-Solution/theband/issues/905) | **product backlog** — three decisions before any task |
| 065/US3 | [#906](https://github.com/The-Band-Solution/theband/issues/906) | **accepted**, close after confirmation and review |
