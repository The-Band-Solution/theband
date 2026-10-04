# Sprint 032 — Review {#sprint-032--review}

**Period**: 2026-09-13 (one day) · **ended on 2026-09-13**
**Feature**: [065 — the label as a field of the work item](../../../specs/065-rotulos-no-item/spec.md)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 executed · **1 accepted** (pending confirmation) · **2 not accepted** |
| Tasks | 14 | 14 closed · **4 unsuccessful** (T005, T007, T011, T012) |
| Tests promised in `tasks.md` | 7 files | **2** |
| `mix gates` | — | **`success`** — CI run [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) on `0ccf02b` |

**All three user stories were executed on the day, and only one holds up against the criteria.** The
listing — the volume, the reason US1 is P1 — is conforming on every measured criterion; what
refuses US1 is the **detail**, which the US promised and nobody looked at. US2 is refused for a reason
prior to the code: the spec and the mechanism call different things "label".

## What was done {#o-que-foi-feito}

| User story | Issue | Tasks | What reached the screen |
|---|---|---|---|
| US1 — see, in the list, what the team called each item | [#904](https://github.com/The-Band-Solution/theband/issues/904) | T001–T003, T005–T007 | the eighth column of `/work`: the field's label in **solid** (observed), the title prefix's one in **hatching with an outline** (derived), `no label` written where there is none, three per row and `+N` that opens the issue. **One query** for 10, 100 or 1,000 items |
| US3 — the label never becomes a concept | [#906](https://github.com/The-Band-Solution/theband/issues/906) | T004, T008 | nothing — it is the rule that does **not** change: `bug` on a task item does not make it a defect; `prioridade:alta` comes out as text; `[Devops]` is a label and never a type |
| US2 — see the claim next to the verdict | [#905](https://github.com/The-Band-Solution/theband/issues/905) | T011, T012 | **nothing new** — both tasks were closed "without code", with the justification that the divergence already showed up per row in the main table |
| — (FR-016, FR-017) | [#898](https://github.com/The-Band-Solution/theband/issues/898), [#899](https://github.com/The-Band-Solution/theband/issues/899) | T009, T010 | the repository on **every** row of the detail's sub-lists, with the `other repository` mark on the 5 (out of 1,953) that cross; the ontology in the drawing — a rule line for `part_whole`, an arrow for `association` |

T001–T012 in PR [#907](https://github.com/The-Band-Solution/theband/pull/907) (16:59Z); the
rewrite of phase 4's scope in [#908](https://github.com/The-Band-Solution/theband/pull/908)
(19:56Z); T014 closed at 20:59Z with the CI evidence.

## What the acceptance found, and the code did not say {#o-que-a-aceitação-achou-e-o-código-não-dizia}

The Product Owner role's evaluation, on 2026-09-13, with executed evidence — the details in
[`aceitacao.md`](aceitacao.md):

1. **The detail does not do what the listing does.** The `labels` field of `/work/issues/:id`
   shows only the labels from GitHub's field, as `badge-ghost`, **without origin and without the derived one**.
   An issue `[Devops] …` with label `backend` shows `backend` and `Devops` in the list, and only
   `backend` when opened. It is US1's own independent test, and it fails. None of the three
   prototypes covers this field — the fix goes back to the prototype before the code;
2. **US2 rests on a homonym.** "Rótulo" in the spec is GitHub's *label*; "label" in the divergence
   mechanism (`ConceptLabel`) is the **declared type**. The US's example issue — label `task`,
   concept defect — has `divergence_kind: nil`: the platform **does not see it as a divergence**.
   Of the 512 real divergences, all are `user_story_without_parts`; `label_vs_structure` exists
   in the code and **is never produced**. The row shows both sides and says neither that they diverge nor
   which was followed;
3. **SC-002 does not reproduce.** The spec says 1,519 issues with a recognized prefix; the delivered function
   derives **1,489** over the 5,033 real titles. There are **47** case variants (`[backend]` 13,
   `[DADOS]` 12, `[DevOps]` 7, `[FRONT]` 7, `[BACKEND]` 4, `[Back-End]` 2, `[Front-End]` 2) that
   do not derive, because the comparison is case-sensitive — consistent with the catalog. 1,519 is
   neither one number nor the other;
4. **Five promised test files do not exist**: `prefixos_test.exs` (T001), the screen
   tests of T005, T007 and T012, and `divergencia_com_rotulo_test.exs` (T011). #907 delivered two
   test files, not seven.

## Evidence {#evidências}

| What | Measure |
|---|---|
| `mix gates` | **`success`**, CI run 34779226200 on `0ccf02b` (step *treze quality gates*) |
| `test/the_band/work_items/rotulos_na_listagem_test.exs` | **7 passed**, exit 0 |
| `test/the_band/work_items/prefixo_vira_rotulo_test.exs` | **9 passed**, exit 0 |
| cost of the listing | **1 query** for 10, 100 and 1,000 items (test T003 and real database) |
| cost of the detail | **46** queries per render — the first version of T009 went up to 50 and was caught |
| real data | 5,033 issues · **2,811** with no label at all · **238** with both origins · **1,489** derive from the prefix · 512 divergences, all `user_story_without_parts` |
| role probes | two screen ones (LiveView rendered over `cenario_real/1`) and one read-only over the database; the role's instruments, outside the repository |

## What was not done {#o-que-não-foi-feito}

| Task | Issue | Reason | Destination |
|---|---|---|---|
| T011 — labels in the divergences | [#900](https://github.com/The-Band-Solution/theband/issues/900) | closed **without code**: `list_divergences/2` did not receive labels | `sro.non_successfully_performed_scrum_development_task`; **do not reopen** — a new task is born after US2's three decisions |
| T012 — both sides and which one won | [#901](https://github.com/The-Band-Solution/theband/issues/901) | same; the row says neither that they diverge nor which was followed | same |
| T005, T007 (part) — the screen tests | [#894](https://github.com/The-Band-Solution/theband/issues/894), [#896](https://github.com/The-Band-Solution/theband/issues/896) | the screen exists; the promised **test** does not | tests owed go in as a task of US1's next sprint |
| T013 — check against the prototype | [#902](https://github.com/The-Band-Solution/theband/issues/902) | done **by reading code, by whoever implemented it**; T013 itself declares it did not look at the rendered screen | QA check with a real capture, including in grayscale (SC-003, FR-015) |

## Deliverables not accepted {#entregáveis-não-aceitos}

**US1** — fails the independent test and FR-001/FR-002 **in the detail**; SC-003 and FR-015 without
evidence. **Proposed destination**: next sprint backlog, first in line, with four new
tasks — the detail's `labels` field (prototype first), the QA check, the decision on the
47 variants with the correction of SC-002, and the tests owed.

**US2** — fails AC1(b), AC3, SC-008 and the independent test; AC2 ambiguous. **Proposed
destination**: **product backlog**, not the next sprint — a task without a decided criterion is announced
rework. The three decisions are in [`aceitacao.md`](aceitacao.md).

## The independent review {#a-revisão-independente}

**There was none.** #907 and #908: empty `reviewRequests`, empty `reviews`, outside the project. It is an *unrequested
review* — the maintainer is the `author` of record and did not write the code, so is a
legitimate reviewer, but the attestation was not written. The role's acceptance **is** the independent
reading the sprint had, and it found the four items above.

## Debt generated {#dívida-gerada}

- **the spec's number** — SC-002 says 1,519 and the measure is 1,489; the spec needs the correction and the
  decision on the case variants (the role's recommendation: keep it case-sensitive, which is the
  catalog's rule, and write 1,489);
- **the prototype is not recorded** as the Design role requires — no
  `specs/065-rotulos-no-item/prototipo/PROMPT.md`, no item in `docs/backlog/`; the three links
  live only in the body of #903;
- **seven criteria without a user story** — FR-011, FR-015 to FR-018, SC-009, SC-010: T009 and T010 do not
  have `[US]`, and no deliverable evaluates them. Measured in passing and conforming where possible; the
  `other repository` mark **was not exercised on screen**;
- **`label_vs_structure`** exists in `ConceptLabel` and is never produced — code that promises
  a case the platform does not compute.

## Lessons from this sprint {#lições-deste-sprint}

For the [accumulated record](../licoes-aprendidas.md):

- **L109** — a task closed "without code" redefining the target, with the spec's criterion intact,
  is a not-accepted deliverable disguised as a done task;
- **L110** — the spec named an existing mechanism with a word it uses for something
  else, and the US's example was never checked in the data;
- **L30, applied late** — the issue numbers were checked against GitHub; SC-002's
  number was not;
- **L95, recurred** — two PRs without a reviewer and outside the project, on the same day that six others
  were born that way (see L95).
