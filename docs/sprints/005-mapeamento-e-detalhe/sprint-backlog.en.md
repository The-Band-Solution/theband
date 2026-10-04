# Sprint 005 — mapping per organization and issue detail {#sprint-005--mapeamento-por-organização-e-detalhe-da-issue}

**Period**: 2026-08-11 to 2026-08-17 (one-week cadence)
**Features**: [005 — mapping rules](../../../specs/005-regras-de-mapeamento/spec.md) ·
[006 — issue detail](../../../specs/006-detalhe-da-issue/spec.md)
**Plans**: [005/plan.md](../../../specs/005-regras-de-mapeamento/plan.md) ·
[006/plan.md](../../../specs/006-detalhe-da-issue/plan.md)

## Sprint goal {#objetivo-do-sprint}

By the end of this sprint, the product knows **what each issue is** — and whoever reads can see **why**,
issue by issue.

Two halves of the same question: 005 decides the concept of 3406 issues that today have
none; 006 shows, for any issue, what was collected, who decided, with which rule and
with what confidence.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md), 26 lessons. Those that come in as a **constraint**
of this sprint:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L08** | Sprint 002 | API contract written before the first public function in both features — and 006's was **corrected** when the implementation showed two deviations |
| **L11** | Sprint 002 | I will **not** touch the iterations configuration. See "Sprint on GitHub" |
| **L13** | Sprint 002 | `nil` and `""` distinguished on the issue body screen, and in the value — not in the date |
| **L18** | Sprint 003 | a criterion met is not enough: the acceptance assesses each SC with evidence, not the green suite |
| **L20** | Sprint 004 | the promotion in force is the latest by `inserted_at` at microsecond precision, and 005's recomputation keeps that |
| **L21** | Sprint 004 | no public function without a visible consumer: 005 is only delivered with the screen (F5) |
| **L22** | Sprint 004 | gate checked by **exit code**, never by text with `\| tail` |
| **L23** | Sprint 004 | a skipped-verification warning is a failure |
| **L25** | Sprint 004 | linking by `external_id`, never by `number` — applies to 005's preview, which groups by pattern and not by number |
| **L26** | Sprint 004 | match the right envelope of the GraphQL client; 006's collection uses the same path already fixed |

**This sprint's new lesson is already known, and it is about process**: implementing before the plan
cost two decisions examined late in 006. It enters the review as L27 if it is confirmed.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
7-day `Iteration` field

**Iteration**: **does not exist for this sprint**, and it is a declared limitation — not forgetfulness.

The field has one active iteration (`Sprint 002 — Escopo por organização`, 2026-08-10) and one
completed. Sprints 003 and 004 also ran without their own iteration, for the same reason:
**configuring ProjectV2 iterations recreates the existing ones** — it is L11, and it cost reassigning
96 items.

Accepted consequence: `flow.throughput` and `flow.wip.count` cannot separate 003, 004 and 005
by iteration. The alternative — touching the configuration — has a known and larger cost.

**Decision pending**, inherited from sprint 004: fix the window of sprint 002 and create the
missing iterations, accepting the reassignment. It remains in the product backlog.

## Selected user stories {#user-stories-selecionadas}

### Feature 006 — delivered in this session {#feature-006--entregue-nesta-sessão}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | See everything the platform knows about an issue | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#145](https://github.com/The-Band-Solution/theband/issues/145) | P1 | 5 | done |
| US2 | Navigate the decomposition with the two relations separated | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#146](https://github.com/The-Band-Solution/theband/issues/146) | P1 | 5 | done |
| US3 | See what violates the rule, on the issue itself | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#147](https://github.com/The-Band-Solution/theband/issues/147) | P2 | 3 | done |
| US4 | See all issues of a repository | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#148](https://github.com/The-Band-Solution/theband/issues/148) | P1 | 3 | done |

**PR**: [#149](https://github.com/The-Band-Solution/theband/pull/149), with the `the-band` team
as reviewer — **checked** with `gh api .../requested_reviewers`, because `gh` swallows the refusal
silently (L14). Status `In review` in the project, not `Done`: the code is implemented and
tested, and was **not** merged or accepted. Marking `Done` before the merge would be declaring
success without evidence — and I did mark it, and corrected it.

### Feature 005 — to do {#feature-005--a-fazer}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | Start with a ready catalog, and edit it | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#140](https://github.com/The-Band-Solution/theband/issues/140) | P1 | 8 | to do |
| US2 | Map a type the platform does not recognize | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#141](https://github.com/The-Band-Solution/theband/issues/141) | P1 | 5 | to do |
| US3 | Rescue issues without a type by title pattern | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#142](https://github.com/The-Band-Solution/theband/issues/142) | P1 | 8 | to do |
| US4 | Do not map what is not a type | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#143](https://github.com/The-Band-Solution/theband/issues/143) | P2 | 3 | to do |

`Priority` is SRO's *importance* — value to the organization. `Estimate` is the *complexity* —
difficulty for the team. A blank field means **unknown**, never zero.

## Tasks {#tarefas}

### Feature 006 — T001 to T020, all done {#feature-006--t001-a-t020-todas-feitas}

Detailed in [006/tasks.md](../../../specs/006-detalhe-da-issue/tasks.md). Four phases: fields
at the source and in the database; reads with the separation in the API; the axiom as a pure function; the two screens.

**No individual issue per task**, and that is a difference from sprint 004 — which created 29.
The reason: the implementation was already done when the backlog opened, and creating 20 issues to
close them in the same minute would produce a false flow trail. User stories #145 to #148
carry the trail, and `tasks.md` carries the detail. **This is declared, not omitted.**

### Feature 005 — T001 to T025, to do {#feature-005--t001-a-t025-a-fazer}

Detailed in [005/tasks.md](../../../specs/005-regras-de-mapeamento/tasks.md).

| Phase | Tasks | Serves | What it delivers |
|---|---|---|---|
| F1 | T001–T008 | US1, US2 | rules table, validation of the three refusals, commands with a mandatory author |
| F2 | T009–T014 | US2, US3, US4 | second stage in `Routing`, confidence, "not a type" decision |
| F3 | T015–T020 | US2, US3 | preview, asynchronous recomputation, idempotence |
| F4 | T021–T023 | US1 | catalog composed per organization, with counts |
| F5 | T024–T025 | US1–US4 | the screen, in the sync, reached through the organization |

The 25 tasks exist as issues typed `Task`, each one a **child of the user story it
serves** — never of the epic: a task under an epic violates `sro.rule07`, and that is exactly what feature
006 began to warn about. The table with the numbers is in [the following section](#issues-das-tarefas).

## Confirmed scope {#escopo-confirmado}

**Feature 005 complete — F1 to F5, T001 to T025.** Decision of the maintainer on 2026-08-11.

The reason is L21: a tested public function without a visible consumer is not delivered
functionality. A mapping feature without the mapping screen is the exact case the lesson
describes, and the vertical slice requires screen and backend together.

**What was refused, and remains recorded as a way out if the week does not fit**: cutting by
**user story**, not by layer — delivering US2 and US3 complete, which together cover the 3443 issues
without a concept, and leaving US1 (catalog) and US4 ("not a type") for the following sprint. Cutting F5
would leave the feature without a consumer, and that is what L21 forbids.

## Task issues {#issues-das-tarefas}

Each task is a child of the **user story it serves** — never of the epic. A task under an epic
violates `sro.rule07`, and it is exactly the warning feature 006 began to show: the product
ingesting its own repository would find the violation this process had created.

| # | Task | Serves | Issue | Estimate | Phase |
|---|---|---|---|---|---|
| T001 | Create the rules table | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#150](https://github.com/The-Band-Solution/theband/issues/150) | 3 | F1 |
| T002 | Create the "not a type" decision table | [#143](https://github.com/The-Band-Solution/theband/issues/143) | [#151](https://github.com/The-Band-Solution/theband/issues/151) | 2 | F1 |
| T003 | Add provenance to the promotion | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#152](https://github.com/The-Band-Solution/theband/issues/152) | 2 | F1 |
| T004 | Validate the pattern before any write | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#153](https://github.com/The-Band-Solution/theband/issues/153) | 5 | F1 |
| T005 | Create a rule with a mandatory author | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#154](https://github.com/The-Band-Solution/theband/issues/154) | 3 | F1 |
| T006 | Change a rule by creating a version | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#155](https://github.com/The-Band-Solution/theband/issues/155) | 2 | F1 |
| T007 | Deactivate without deleting | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#156](https://github.com/The-Band-Solution/theband/issues/156) | 2 | F1 |
| T008 | List the rules in application order | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#157](https://github.com/The-Band-Solution/theband/issues/157) | 2 | F1 |
| T009 | Read the organization's rule in the decision by type | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#158](https://github.com/The-Band-Solution/theband/issues/158) | 3 | F2 |
| T010 | Add the title stage, and only after | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#159](https://github.com/The-Band-Solution/theband/issues/159) | 5 | F2 |
| T011 | Apply the four forms of comparison | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#160](https://github.com/The-Band-Solution/theband/issues/160) | 3 | F2 |
| T012 | Record the evidence source and confidence | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#161](https://github.com/The-Band-Solution/theband/issues/161) | 3 | F2 |
| T013 | Link the promotion to the rule that decided | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#162](https://github.com/The-Band-Solution/theband/issues/162) | 2 | F2 |
| T014 | Declare and revert "not a type" | [#143](https://github.com/The-Band-Solution/theband/issues/143) | [#163](https://github.com/The-Band-Solution/theband/issues/163) | 3 | F2 |
| T015 | Compute the preview without querying the source | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#164](https://github.com/The-Band-Solution/theband/issues/164) | 5 | F3 |
| T016 | Prove that preview and effect coincide | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#165](https://github.com/The-Band-Solution/theband/issues/165) | 3 | F3 |
| T017 | Recompute on the queue that already exists | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#166](https://github.com/The-Band-Solution/theband/issues/166) | 5 | F3 |
| T018 | Record a new promotion, preserving the previous one | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#167](https://github.com/The-Band-Solution/theband/issues/167) | 2 | F3 |
| T019 | Make the recomputation idempotent | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#168](https://github.com/The-Band-Solution/theband/issues/168) | 3 | F3 |
| T020 | Preserve the promotion on re-observation | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#169](https://github.com/The-Band-Solution/theband/issues/169) | 3 | F3 |
| T021 | Read the catalog and compose it with the organization's rules | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#170](https://github.com/The-Band-Solution/theband/issues/170) | 5 | F4 |
| T022 | Count how many issues each proposal would match | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#171](https://github.com/The-Band-Solution/theband/issues/171) | 3 | F4 |
| T023 | Activate a proposal and activate all, with authorship | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#172](https://github.com/The-Band-Solution/theband/issues/172) | 3 | F4 |
| T024 | Rules component on the sync screen | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#173](https://github.com/The-Band-Solution/theband/issues/173) | 8 | F5 |
| T025 | Reach the rules through the organization | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#174](https://github.com/The-Band-Solution/theband/issues/174) | 3 | F5 |

A task does **not** get a `Priority`: priority belongs to the user story, and the task inherits it.
Two sources would diverge, and the divergence would have no way of being resolved.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Item | Why |
|---|---|
| mapping board field → attribute | FR-037 of 005 explicitly excludes it; a field is not a type |
| collection of boards and iterations (004 F4) | unimplemented phase of feature 004; remains in the product backlog |
| issue comments and timeline | would multiply consumption of the source per issue |
| fix the window of sprint 002 and create iterations | cost of L11; decision pending |
| Scrum roles and association with people (#98–#100) | product backlog, no iteration |
| rename and remove a credential (#104) | product backlog, no iteration |
| Elixir/Python parity in the validator | declared debt: 4 checks against 12 |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Effect | Mitigation |
|---|---|---|
| pathological regular expression | hangs the screen's process | evaluation in a `Task` with a limit, over real titles |
| preview diverging from the effect | someone approves seeing 3 and reclassifies 900 | a single decision function; T016 compares the two |
| recomputation of 3440 issues | sync stuck, or timeout | `transformation` queue, which **already exists**; progress on screen |
| job on an unconfigured queue | stays `available` forever | use `transformation`; check the `completed` state in the test |
| catalog reordered | turns off decisions already made | key `(where, how, pattern)`, never the index |
| sync in `running` forever | blocks every collection of the tool | **defect declared and not fixed** — see below |

**Known and unfixed defect**: an Oban job `discarded` leaves the `sync` in `running`, and the
index `syncs_one_running_per_tool_index` starts blocking any new collection of that
tool, with no path through the interface. The way out today is SQL, recorded in
[RETOMAR.md](../RETOMAR.md). **Candidate to enter this sprint** if the asynchronous recomputation
increases the exposure.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] nine gates green by `mix gates`, checked by **exit code**
- [ ] knowledge base valid, including the Python validator
- [ ] each SC of the two features assessed **one by one, with evidence** — never "the suite passed"
- [ ] `aceitacao.md` with no criterion without evidence
- [ ] issues closed or reprioritized with justification
- [ ] PR with reviewer **checked** with `gh pr view --json reviewRequests`
- [ ] `sprint-review.md` with done and **not done** separated
- [ ] `licoes-aprendidas.md` updated

## Declared process gap {#lacuna-de-processo-declarada}

The constitution requires independent review by another agent before merging. This session
**does not invoke an agent without an explicit request** — the condition cannot be satisfied, and the gap is
declared, never marked as fulfilled.
