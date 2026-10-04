# Sprint 016 — the monthly generation of profiles {#sprint-016--a-geração-mensal-dos-perfis}

**Period**: from 2026-08-16 · end not declared — see *Limitations* below
**Feature**: [027 monthly generation of profiles](../../../specs/027-geracao-mensal-de-perfis/spec.md)
**Plan**: [plan.md](../../../specs/027-geracao-mensal-de-perfis/plan.md) · **Tasks**: [tasks.md](../../../specs/027-geracao-mensal-de-perfis/tasks.md)
**Branch**: `027-geracao-mensal-de-perfis`

## Sprint goal {#objetivo-do-sprint}

The competence profile stops depending on someone remembering to click: the platform writes it by itself, once a month, for whoever had new work — and shows on a screen what the round did and how much it cost.

## Phase 0 — what was left from the previous sprint, with a destination {#fase-0--o-que-sobrou-do-sprint-anterior-com-destino}

The **L12** rule is that no new scope is selected while the previous item has no destination. The destination does not need to be "done": it can be returned, discarded with a reason, or blocked with a named blocker.

| Item | Real state | Destination |
|---|---|---|
| **Feature 026** — competence profile, PR [#330](https://github.com/The-Band-Solution/theband/pull/330) | **merged** on 2026-08-16 at 13:06 UTC, commit `16c7388` | done |
| Independent review of #330 | **did not happen**: `reviews` empty at the time of the merge, with a pending request to `Adylla027` and `EduardoNFraiz` | **gap recorded**, not marked as fulfilled — principle VII |
| `sprint-review.md` for sprint 014 | **does not exist** | pending item declared below |
| Sprint 015 and features 018 to 026 | no directory in `docs/sprints/` | pending item declared below |

### The process gap, stated in full {#a-pendência-de-processo-dita-por-inteiro}

The check that **L44** requires when opening a sprint found the following: `docs/sprints/` goes up to **014**, and the lessons record cites **Sprint 015**. Features 018 to 026 were delivered **without** `sprint-backlog.md` and without `sprint-review.md`, even though lessons kept being written — the accumulated file reached L59.

In other words: the mechanism that produces learning kept working, and the one that produces **a trail of what was planned against what was delivered** stopped. It is exactly the half that L44 describes as the one that disappears without anything failing.

This sprint does not fix the past — rebuilding nine reviews from memory would produce a document worse than the absence. What it does is **start producing again**, and record the gap so that nobody reads it as "there was no sprint".

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), considered in this sprint:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L12** | Sprint 001 | Phase 0 above: 026 got a destination before any new scope was selected, and the review that did not happen is declared, not made up |
| **L44** | Sprint 009 | the mechanical check was done at opening, and found the gap of nine sprints without a document |
| **L58** | Sprint 015 | #330 was merged by *squash* during this session; the 027 branch was **rebased** onto `main` so that this feature's PR would not show 026 again. Checked with `git log origin/main..HEAD`: two commits, mine |
| **L11** | Sprint 001 | **that is why the sprint does not become an iteration on GitHub**: reconfiguring the field recreates the existing iterations, and Sprint 001 and 002 would lose identity |
| **L26** | Sprint 006 | `FR-016` separates credential failure from transient failure, and `200` with an empty list of models is an **error** in `verify/2`, never success |
| **L28** | Sprint 007 | input tokens are **recorded** per person, and not only computed for display — `FR-020`, T014 |
| **L30** and **L35** | Sprints 008 and 009 | the cost of the round is measured against the real provider, not estimated — T024, and it is the only item that no test replaces |
| **L59** | Sprint 015 | CI green is checked on the commit, not on the PR: the Credo gate that `57c509f` broke did not show up on #330 because the green checks were from the previous commit |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) · `PVT_kwDODHSRm84BAAnT`

**Declared limitations, not worked around:**

- **the `Iteration` field stopped at Sprint 002**, started on 2026-08-10 with seven days. There is no iteration for sprints 003 to 016. Creating this sprint's requires `updateProjectV2Field` on the field's configuration, and **L11** records that this mutation recreates the existing iterations — Sprint 001 and 002 would lose identity, and with it the series the product intends to ingest. **Decision of 2026-08-16: do not touch it, and record it here**;
- **the `Epic` and `User Story` types do not exist in the organization.** Only `Task`, `Bug` and `Feature`. Creating them changes the configuration of the whole organization. The 28 issues were created without a type of their own, with the `enhancement` label, and the link to the feature lives **in the body of each issue** — the path `specs/027-geracao-mensal-de-perfis/tasks.md`, which is what allows finding them again;
- consequence: the `Epic → User Story → Task` hierarchy that the routing rule expects **does not exist** for this sprint. Whoever ingests the repository will read these 28 issues as loose tasks.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Priority | Tasks | Acceptance criteria |
|---|---|---|---|---|
| **US1** | The profile is there when I open it | P1 | 11 | 4 scenarios |
| **US2** | See what the round did, and what it cost | P1 | 5 | 4 scenarios |

Both are P1 and **go in together**: US1 alone is infrastructure without a visible consumer, which principle VI forbids. `Priority` and `Estimate` were not recorded in the project — see *Limitations*. A blank field means unknown, never zero.

## Tasks {#tarefas}

### Setup {#setup}

| # | Task | Issue | State |
|---|---|---|---|
| T003 | Dedicated queue for the rounds | [#331](https://github.com/The-Band-Solution/theband/issues/331) | to do |
| T004 | Regeneration thresholds in the knowledge base | [#332](https://github.com/The-Band-Solution/theband/issues/332) | to do |
| T005 | Validation refuses a missing or invalid threshold | [#333](https://github.com/The-Band-Solution/theband/issues/333) | to do |

### Foundation {#fundação}

| # | Task | Issue | State |
|---|---|---|---|
| T006 | Migration of the automation events | [#334](https://github.com/The-Band-Solution/theband/issues/334) | to do |
| T007 | Migration of the rounds | [#335](https://github.com/The-Band-Solution/theband/issues/335) | to do |
| T008 | Migration of the round entries | [#336](https://github.com/The-Band-Solution/theband/issues/336) | to do |
| T009 | Schemas of the three tables | [#337](https://github.com/The-Band-Solution/theband/issues/337) | to do |

### US1 — the profile is there when I open it {#us1--o-perfil-está-lá-quando-eu-abro}

| # | Task | Issue | State |
|---|---|---|---|
| T010 | Read the thresholds without a built-in default | [#338](https://github.com/The-Band-Solution/theband/issues/338) | to do |
| T011 | Decide who goes into the round, and for what reason not | [#339](https://github.com/The-Band-Solution/theband/issues/339) | to do |
| T012 | Turn on and off with an author | [#340](https://github.com/The-Band-Solution/theband/issues/340) | to do |
| T013 | Open, record and close the round | [#341](https://github.com/The-Band-Solution/theband/issues/341) | to do |
| T014 | The generation returns the consumption | [#342](https://github.com/The-Band-Solution/theband/issues/342) | to do |
| T014a | The material is still the whole history | [#343](https://github.com/The-Band-Solution/theband/issues/343) | to do |
| T015 | The round runs sequentially, with a checkpoint | [#344](https://github.com/The-Band-Solution/theband/issues/344) | to do |
| T016 | Credential failure ends the round | [#345](https://github.com/The-Band-Solution/theband/issues/345) | to do |
| T016a | Whoever failed comes back in the next round | [#346](https://github.com/The-Band-Solution/theband/issues/346) | to do |
| T017 | The monthly cron enqueues one round per organization | [#347](https://github.com/The-Band-Solution/theband/issues/347) | to do |
| T017a | Bumping the version generates nothing | [#348](https://github.com/The-Band-Solution/theband/issues/348) | to do |

### US2 — see what the round did {#us2--ver-o-que-a-rodada-fez}

| # | Task | Issue | State |
|---|---|---|---|
| T018 | Automatic generation screen | [#349](https://github.com/The-Band-Solution/theband/issues/349) | to do |
| T019 | The nine numbers of each round | [#350](https://github.com/The-Band-Solution/theband/issues/350) | to do |
| T020 | Turning on triggers the first round | [#351](https://github.com/The-Band-Solution/theband/issues/351) | to do |
| T020a | Request a round by hand | [#352](https://github.com/The-Band-Solution/theband/issues/352) | to do |
| T021 | One organization does not see the other's round | [#353](https://github.com/The-Band-Solution/theband/issues/353) | to do |

**Already delivered on this branch**, and therefore out of the count: the per-organization credential — `lib/the_band/ai.ex`, the `/ai` screen and `verify/2` at the edge —, commit `46b433d`, with 31 tests.

## Out of this sprint's scope {#fora-do-escopo-deste-sprint}

| # | Task | Issue | Why it stays out |
|---|---|---|---|
| T022 | The new threshold applies in the next round | [#354](https://github.com/The-Band-Solution/theband/issues/354) | US3, P2. Depends on US1 existing, and the value shows up when someone wants to adjust — not in the first round |
| T023 | Operational log without the key and without the material | [#355](https://github.com/The-Band-Solution/theband/issues/355) | polish |
| T024 | **Measure the real cost of a round** | [#356](https://github.com/The-Band-Solution/theband/issues/356) | requires a real key and 15 to 35 minutes of round against the provider. **It stays out of the sprint, not out of the path**: `FR-021` requires this measurement before N and M are fixed — see *Risks* |
| T025 | Quality gates green | [#357](https://github.com/The-Band-Solution/theband/issues/357) | runs at closing |
| T026 | Walk through the quickstart by hand | [#358](https://github.com/The-Band-Solution/theband/issues/358) | runs at closing |

Silencing this would make the sprint look like the whole feature. It is not: it is 23 of the 28 issues.

## Risks and dependencies {#riscos-e-dependências}

| Risk | Why | What to do |
|---|---|---|
| **N and M get fixed without the measurement** | T024 is out of the sprint, and `FR-021` requires it before the thresholds take effect | the values go into the YAML as **initial**, and `SC-002` says it changes along with the recount. If the measurement does not happen, the sprint closes with the debt recorded, never with the number declared by estimate |
| **35-minute Oban job** | it is out of the ordinary in this repository | dedicated queue (T003) and checkpoint (T015). A node restart midway puts the job back in the queue, and the checkpoint is what keeps that from costing money |
| **Independent review** | #330 was merged without it; nothing guarantees that this feature's PR will have one | request it from the `the-band` team **when opening** the PR, and check with `gh pr view --json reviewRequests` — L14 records that `gh` exits with code zero even when the request is refused |
| **External provider** | 34 generations in a row may hit a rate limit | `FR-016` already separates this from credential failure; if it happens, it becomes a measurement for T024 |

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] the 23 issues closed, or reprioritized with a written justification
- [ ] `mix gates` with exit code 0 — never with `| tail` or `| grep`
- [ ] `mix knowledge.validate` passing with the new `regeneration` rule
- [ ] PR opened with a reviewer requested from the `the-band` team, and the request **checked**
- [ ] `sprint-review.md` written, separating delivered from not delivered
- [ ] `licoes-aprendidas.md` updated
- [ ] the independent review gap **declared**, if it persists — never marked as fulfilled
