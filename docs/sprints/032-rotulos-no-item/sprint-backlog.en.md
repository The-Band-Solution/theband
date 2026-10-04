# Sprint 032 — The label as a field of the work item {#sprint-032--o-rótulo-como-campo-do-item-de-trabalho}

**Period**: 2026-09-13 (one day) · **closed on 2026-09-13**
**Feature**: [065 — labels on the item](../../../specs/065-rotulos-no-item/spec.md)
**Plan**: [plan.md](../../../specs/065-rotulos-no-item/plan.md) ·
**Research**: [research.md](../../../specs/065-rotulos-no-item/research.md) ·
**Model**: [data-model.md](../../../specs/065-rotulos-no-item/data-model.md)

> **Written after the sprint, on the same day.** Spec (`b6f945c`), plan, tasks, issues (#890–#906),
> implementation (#907, 16:59Z) and scope correction (#908, 19:56Z) happened on 2026-09-13 without
> this document. The intention below is that of the `tasks.md` of 2026-09-13 — which, unlike 060,
> **does have** issues, created before the implementation. What was missing was the reading of the lessons and the
> selection of scope as a human decision: the sprint took all 14 tasks.

## Sprint goal {#objetivo-do-sprint}

**Whoever opens the item list sees, on each row, the labels the team wrote** — those from GitHub's
field (observed) and those from the bracketed prefix in the title (derived) —, without any
label changing the classification the platform derives.

## Where this sprint came from {#de-onde-este-sprint-veio}

From the maintainer's request on 2026-09-13: the characterization the team gives to items
(`backend`, `[Devops]`, `prioridade:alta`) existed only in the detail, where it helps least to compare. The
spec fixed the rule no task may break — **the label is preserved and not promoted: a
`bug` label does not make the issue a defect** — and three prototypes were approved on the same day
(concept, listing, detail; links in the body of #903).

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md). Recorded afterwards — what the evidence shows:

| Lesson | Origin | How it appears in the evidence |
|---|---|---|
| **L30** — check against the source | 003 | the issue numbers were **checked against GitHub after creating them**, "and not the ones I assumed I had created" (`tasks.md`, *As issues*). **Not applied to SC-002**: the spec's 1,519 was never measured, and the acceptance measured **1,489** |
| **L98** — a lesson that does not become a rule recurs | 028 | the PR template came to require the issues the PR closes, with the closing keyword in English (`40cc15b`) |
| **L38 / L53** — screen cost by difference | 009, 013 | T003: 100 items cost the same as 10, by query count; T009 kept the detail at **46** queries (the first version went up to 50 and was caught) |
| **L60** — the verdict is the exit code | 019 | T014 (#903): CI run 34779226200, `mix gates` `success` |
| **L102** — `git add -A` | 030 | the audit "starts with `git status`" went into `AGENTS.md` in this sprint (`b7200bf`) |
| **L103** — the prototype is not the product | 030 | the design detector ignores `prototipo/` |
| **vertical slice** | constitution VIII | T005 is the first screen and comes right after T001–T004 |
| **L95** — requesting a reviewer is not getting a review | 027 | **not applied**: #907 and #908 without a requested reviewer and outside the project |
| **L99** — check issue by issue | 028 | #908 was born from checking: T009/T010 described the listing, and the defect was in the detail |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
**Iteration**: *Sprint 025 — Contas e o elo do GitHub* · 2026-09-12 to 2026-09-19

**The 17 issues had existed since 2026-09-13** with labels (`task`, `us`) and **without type, without hierarchy
and outside the project**. Materialized on 2026-09-13 while writing this document — result in
`github.md` in this folder. The three USs stay **without type** (`User Story` does not exist in the organization;
decision of sprint 029). **There is no epic.** Four tasks have no user story because
`tasks.md` did not tie them to any: T009, T010 (FR-016, FR-017), T013 and T014.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Priority | Issue | Tasks | Criteria |
|---|---|---|---|---|---|
| US1 | See, in the list, what the team called each item | P1 | [#904](https://github.com/The-Band-Solution/theband/issues/904) | T001, T002, T003, T005, T006, T007 | AS 1–4, FR-001 to FR-006, FR-010, FR-012, FR-013, SC-001 to SC-003, SC-005 to SC-007 |
| US3 | The label never becomes a concept | P1 | [#906](https://github.com/The-Band-Solution/theband/issues/906) | T004, T008 | AS 1–3, FR-007 to FR-009, SC-004 |
| US2 | See the claim next to the verdict | P2 | [#905](https://github.com/The-Band-Solution/theband/issues/905) | T011, T012 | AS 1–3, FR-014, SC-008 |

**US3 goes into the same phase as US1, not after** — it is the rule US1 can break. `Estimate`
not filled in.

## Tasks {#tarefas}

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T001 | Read the declared list of prefixes | US1 | [#890](https://github.com/The-Band-Solution/theband/issues/890) | done · #907 |
| T002 | Bring the field's labels into the listing | US1 | [#891](https://github.com/The-Band-Solution/theband/issues/891) | done · #907 |
| T003 | Prove that the listing does not grow in queries | US1 | [#892](https://github.com/The-Band-Solution/theband/issues/892) | done · #907 |
| T004 | Prevent the label from becoming a concept | US3 | [#893](https://github.com/The-Band-Solution/theband/issues/893) | done · #907 |
| T005 | Show the labels on the screen, with the origin | US1 | [#894](https://github.com/The-Band-Solution/theband/issues/894) | done · #907 |
| T006 | Derive the label from the title's prefix | US1 | [#895](https://github.com/The-Band-Solution/theband/issues/895) | done · #907 |
| T007 | Show both origins without merging them | US1 | [#896](https://github.com/The-Band-Solution/theband/issues/896) | done · #907 |
| T008 | Refuse to interpret the label's content | US3 | [#897](https://github.com/The-Band-Solution/theband/issues/897) | done · #907 |
| T009 | Bring the repository into the detail's sub-lists | — (FR-016) | [#898](https://github.com/The-Band-Solution/theband/issues/898) | done · #907, scope rewritten in #908 |
| T010 | Say when the part comes from another repository | — (FR-016, FR-017, SC-009) | [#899](https://github.com/The-Band-Solution/theband/issues/899) | done · #907 |
| T011 | Bring the labels into the divergences | US2 | [#900](https://github.com/The-Band-Solution/theband/issues/900) | closed **without code** — see the sprint review |
| T012 | Show both sides and say which one won | US2 | [#901](https://github.com/The-Band-Solution/theband/issues/901) | closed **without code** — see the sprint review |
| T013 | Check the screen against the approved prototype | — (FR-015) | [#902](https://github.com/The-Band-Solution/theband/issues/902) | done — **by reading code, by whoever implemented it** |
| T014 | Close the gates | — | [#903](https://github.com/The-Band-Solution/theband/issues/903) | done · CI run 34779226200 |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

Nothing from `tasks.md` was left out. What was left out is in the **spec**, not in the tasks: FR-011,
FR-015, FR-016, FR-017, FR-018, SC-009 and SC-010 are not tied to any user story, and for
that reason **no deliverable evaluates them** — the acceptance measured them in passing.

## Risks and dependencies {#riscos-e-dependências}

- **The rule that cannot break** (US3) is the reason US3 is P1 together with US1;
- **The prototype is not recorded as the role requires** — there is no `prototipo/PROMPT.md` nor an item
  in `docs/backlog/`; the three links live only in the body of #903;
- **"Rótulo" and "label" are homonyms** inside the platform — the spec speaks of GitHub's label; the
  divergence mechanism (`ConceptLabel`) calls the declared type "label". It was not seen as a
  risk when writing; the acceptance found it (L110).

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] quality gates green — CI run 34779226200 on `0ccf02b`, `mix gates` `success`
- [x] knowledge base valid — part of the gates
- [x] task issues closed — #890–#903, by hand after the merge (the base is not the default branch)
- [ ] user story issues closed or with a destination — **#904–#906 open**, with a proposed verdict and destination written in the acceptance; the confirmation belongs to the role
- [x] `sprint-review.md` written
- [x] `aceitacao.md` written — the role's proposal, 2026-09-13
- [x] `licoes-aprendidas.md` updated — L109, L110
