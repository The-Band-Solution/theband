# Sprint 004 — Issues and projects of the observed organizations {#sprint-004--issues-e-projetos-das-organizações-observadas}

**Period**: 2026-08-11 to 2026-08-17 (7 days — weekly cadence)
**Feature**: [004-issues-e-projetos](../../../specs/004-issues-e-projetos/spec.md)
**Plan**: [plan.md](../../../specs/004-issues-e-projetos/plan.md)
**Tasks**: [tasks.md](../../../specs/004-issues-e-projetos/tasks.md) — 42, of which 29 in this sprint

## Sprint goal {#objetivo-do-sprint}

The platform comes to know **what work exists** in the observed organizations — and to
show, alongside it, what it could not classify and why.

## What this sprint does differently because of the lessons {#o-que-este-sprint-faz-diferente-por-causa-das-lições}

Twenty-four lessons in the [cumulative record](../licoes-aprendidas.md). These come in
as constraints:

| Lesson | What changes here |
|---|---|
| **L19** — an absence mark by tenant marks what belongs to another organization | `mark_issues_no_longer_observed/3` **requires** `repository_id` in the signature, and the arity-2 version does not exist. L19 prevented in the type, at a volume four times larger: 14 repositories instead of 3 organizations |
| **L21** — a tested function without a consumer is not delivered | no phase ends in an API without a screen. T028 closes US1; the five query functions (T021) exist because the screen uses them, not before |
| **L22** — differential gate without a success gate | `mix gates` checks the **exit code** of each derivation, not just the diff. That is what left the gate red for weeks |
| **L23** — a skipped-verification warning is a failure | `mix gates` provisions the venv, and the Python validator validates **form**. No gate runs with `\| tail` |
| **L24** — the clean-environment path is not tested by whoever has the environment | T001 is exercised with the `.venv` removed, and the migrations with rollback |
| **L18** — one criterion met is not enough | 7 of the 15 SC are about the violation. T023 checks that `#3` is **not** an epic; T022 checks that **0** issues of another repository were marked |
| **L11** — configuring iterations recreates the existing ones | **no iteration change.** See the limitation below |
| **L12** — a PR not opened right away carries another feature | PR #105 has been open since planning, and receives the sprint's commits |
| **L03** — invalid data finds what the happy path hides | the tests use the real data, which already contains a violation of `sro.rule07` — a task without a parent |

## Inheritance — everything with a destination before new scope {#herança--tudo-com-destino-antes-de-escopo-novo}

Rule of the `product-owner` skill. An open item without a destination is not work, not a decision
and not a discard.

| What was left over | From where | Destination |
|---|---|---|
| **#81, #82** — US2 and US3 of feature 002 | sprint 002 | product backlog, no iteration — decision made |
| **#98, #99, #100** — Scrum roles | manual-registration decision | product backlog, no iteration |
| **#104** — US3 of feature 003, screens T019 to T022 | sprint 003 | product backlog, no iteration |
| **Repair of the historical data of L19** | feature 001 | happens on the next real collection of each organization — one does not unmark what one does not know whether the source showed |
| **Iteration window of sprint 002** | sprint 002 | **decision pending**: fixing it requires touching iterations, the cause of L11, which cost reassigning 96 items |
| **Iteration of sprints 003 and 004** | — | **do not exist**, for the same reason. Limitation declared below |
| **Elixir/Python parity** | sprints 001 and 002 | declared debt: 4 checks against 12. The Python gate is the one that decides, and it runs in `mix gates` |
| **`connected_tools.status` materializes a situation** | feature 001 | declared debt, against ADR 0004 D7. **Not expanded**: this feature does not materialize `sro_user_stories.status` |
| **RSRO and SYS_SWO without a stereotype** | knowledge base | there were 16 concepts; the boundary rule reduced this feature's requirement to **one** — T001. The other 15 remain as declared debt |
| **Recorded review approval** | sprints 001 to 003 | **blocked by tooling**: with one identity, the author does not approve their own PR. Closes with a bot or a GitHub App |
| **F4 and F5 of feature 004** | this feature | **outside this sprint**, with the cost declared below |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration: does not exist for this sprint** — and it is a declared limitation, not forgetfulness.

The project's iteration field has two iterations configured: `Sprint 001` and
`Sprint 002`. Adding `Sprint 003` and `Sprint 004` requires changing the field's
configuration, which is exactly what caused [L11](../licoes-aprendidas.md) — the change
recreated the existing iterations with new identifiers, and 96 items lost their
assignment.

The sprint's scope is tracked by this document and by the issues, which are in the
project. The backlog order uses `Priority`.

### Issue types of this organization {#tipos-de-issue-desta-organização}

`Epic` and `User Story` **do not exist** in the organization, and **were not created**. The
organization uses `Feature`, `Task` and `Bug`, and the routing rule already accepts `Feature`
as an atomic user story.

Creating the types would change the organization's configuration to match a document —
and would invert the precedence that the rule itself declares: structure beats the label.
The mapping is in
[`rules/tenants/the_band_solution.yaml`](../../../priv/knowledge_base/rules/tenants/the_band_solution.yaml),
and US3 of this feature delivers the screen that makes it adjustable without editing YAML.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Type | Issue | Priority | Estimate | Scenarios | In this sprint |
|---|---|---|---|---:|---:|---:|---|
| US1 | Know which issues exist, and what they are | Feature | [#106](https://github.com/The-Band-Solution/theband/issues/106) | P0 | — | 8 | **yes** |
| US2 | See the boards and what each item carries | Feature | [#107](https://github.com/The-Band-Solution/theband/issues/107) | P1 | — | 9 | no |
| US3 | See and adjust the type mapping | Feature | — | P1 | — | 8 | no |
| US4 | Restrict which repositories are observed | Feature | [#108](https://github.com/The-Band-Solution/theband/issues/108) | P2 | — | 4 | **partial** |

`Priority` carries the *importance* — value to the organization. `Estimate` carries the
*complexity*. **A blank `Estimate` means unknown, not zero**: no
estimate was made, and filling it with zero would measure as if the decision had been
made.

**US3 has no issue yet** — it was specified after the issues were created, and it is an
explicit pending item instead of an invented link.

**US4 enters partially**: repository exclusion and the inaccessible repository
(T011, T012) are the base of US1, because they define the scope of the absence mark. The
repository management screen stays out.

## Tasks {#tarefas}

| # | Task | Phase | Serves | Issue | [P] | State |
|---|---|---|---|---|---|---|
| T001 | Annotate the referenced kind | F0 | US1 | [#109](https://github.com/The-Band-Solution/theband/issues/109) | — | to do |
| T002 | Prove the reference is a single table | F0 | US1 | [#110](https://github.com/The-Band-Solution/theband/issues/110) | — | to do |
| T003 | Declare the tenant rule | F1 | US1 | [#111](https://github.com/The-Band-Solution/theband/issues/111) | yes | to do |
| T004 | Write the repositories query | F1 | US1 | [#112](https://github.com/The-Band-Solution/theband/issues/112) | yes | to do |
| T005 | Write the issues queries | F1 | US1 | [#113](https://github.com/The-Band-Solution/theband/issues/113) | yes | to do |
| T006 | Declare the issues connector | F1 | US1 | [#114](https://github.com/The-Band-Solution/theband/issues/114) | — | to do |
| T007 | Migrate the referenced kind's table | F2 | US1 | [#115](https://github.com/The-Band-Solution/theband/issues/115) | — | to do |
| T008 | Migrate the repository extension | F2 | US1 | [#116](https://github.com/The-Band-Solution/theband/issues/116) | — | to do |
| T009 | Migrate the observed repository | F2 | US1 | [#117](https://github.com/The-Band-Solution/theband/issues/117) | — | to do |
| T010 | Discover the organization's repositories | F2 | US1 | [#118](https://github.com/The-Band-Solution/theband/issues/118) | — | to do |
| T011 | Exclude a repository from observation | F2 | US4 | [#119](https://github.com/The-Band-Solution/theband/issues/119) | — | to do |
| T012 | Mark a repository inaccessible | F2 | US4 | [#120](https://github.com/The-Band-Solution/theband/issues/120) | — | to do |
| T013 | Migrate the collected issue | F3 | US1 | [#121](https://github.com/The-Band-Solution/theband/issues/121) | — | to do |
| T014 | Migrate the issue promotion | F3 | US1 | [#122](https://github.com/The-Band-Solution/theband/issues/122) | — | to do |
| T015 | Migrate links and refusals | F3 | US1 | [#123](https://github.com/The-Band-Solution/theband/issues/123) | — | to do |
| T016 | Record the collected issue | F3 | US1 | [#124](https://github.com/The-Band-Solution/theband/issues/124) | — | to do |
| T017 | Promote by the versioned rule | F3 | US1 | [#125](https://github.com/The-Band-Solution/theband/issues/125) | — | to do |
| T018 | Record the divergence between declared and derived | F3 | US1 | [#126](https://github.com/The-Band-Solution/theband/issues/126) | — | to do |
| T019 | Report per repository what was promoted | F3 | US1 | [#127](https://github.com/The-Band-Solution/theband/issues/127) | — | to do |
| T020 | Record classification change between collections | F3 | US1 | [#128](https://github.com/The-Band-Solution/theband/issues/128) | — | to do |
| T021 | Queries for issues, promotions and gaps | F3 | US1 | [#129](https://github.com/The-Band-Solution/theband/issues/129) | — | to do |
| T022 | Record the gap with the type name | F3 | US1 | [#130](https://github.com/The-Band-Solution/theband/issues/130) | — | to do |
| T023 | Derive epic from atomic | F3 | US1 | [#131](https://github.com/The-Band-Solution/theband/issues/131) | — | to do |
| T024 | Refuse a cycle in the command | F3 | US1 | [#132](https://github.com/The-Band-Solution/theband/issues/132) | — | to do |
| T025 | Record an out-of-scope reference | F3 | US1 | [#133](https://github.com/The-Band-Solution/theband/issues/133) | — | to do |
| T026 | Mark absence per repository | F3 | US1 | [#134](https://github.com/The-Band-Solution/theband/issues/134) | — | to do |
| T027 | Interrupt the collection by the consumption limit | F3 | US1 | [#135](https://github.com/The-Band-Solution/theband/issues/135) | — | to do |
| T028 | Issues screen with gaps | F3 | US1 | [#136](https://github.com/The-Band-Solution/theband/issues/136) | — | to do |
| T029 | Prove isolation between tenants | F3 | US1 | [#137](https://github.com/The-Band-Solution/theband/issues/137) | — | to do |

A task does not get a `Priority`: it inherits the one of the user story it serves.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started)

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Item | Tasks | Declared cost |
|---|---|---|
| **F4 — boards, fields and iterations** | T030 to T039 | without them there is no sprint, backlog or field value. **The dependency runs in this direction**: a board item points to an issue, and delivering boards first would produce empty backlogs |
| **F5 — boards screen** | T040 | same |
| **US3 — mapping screen** | no tasks yet | the tenant rule stays declared in YAML (T003), and adjusting it requires editing the repository. **The gap is visible through US1 and unaddressable through the interface** until this screen exists |
| **Closing** | T041, T042 | depend on the MVP |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **Mistaking service for composition** — a task as part of a user story | it is the feature's defect. T023 uses the six real cases, and the assertion that matters is that `#3` with nine sub-issues is **not** an epic. If it fails, 78 tasks link to epics |
| **Repeating L19 in 14 repositories** | `repository_id` mandatory in the signature, and T022 tests with two repositories and two collections in sequence |
| **Issue volume blowing the consumption limit** | checkpoint **per repository**; resuming does not restart the whole repository (T027) |
| **Sub-issues unavailable on the instance** | detect and **declare** that the epic/atomic distinction is not made. Never fall back to a markdown-list heuristic |
| **The routing rule being wrong** | it has `status: proposed`. The feature **measures** it: the gap by reason is the metric that says where it errs. Fixing it is a consequence, not a prerequisite |
| **`refused_links` being born and staying empty** | declared in the plan as a **forecast**, with a reversal criterion: empty after two real collections in all tenants, it becomes a count in the report. T041 records the count |

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] `mix gates` green — all nine, checked by exit code
- [ ] the six real structural cases classify correctly, and `#3` is **not** an epic
- [ ] the absence mark does not cross repositories, proven with two repositories and two collections
- [ ] the sum of promoted and non-promoted equals the total collected, under any filter
- [ ] an issue of unknown type is not promoted, and is counted **with the type name**
- [ ] the divergence between declared type and derived concept is **recorded**, not just derived
- [ ] V1 to V8 of the quickstart executed against the real data, with the numbers recorded
- [ ] the issues screen live, showing promotions, gaps and divergences
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `aceitacao.md` walking through the criteria, one by one, with evidence
- [ ] `licoes-aprendidas.md` updated
- [ ] **independent review** — declared, never marked as fulfilled by whoever implements
