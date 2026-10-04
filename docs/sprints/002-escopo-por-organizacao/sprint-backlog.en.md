# Sprint 002 — Scope by organization {#sprint-002--escopo-por-organização}

**Period**: 2026-08-10 to 2026-08-16 (7 days — weekly cadence)
**Feature**: [002-escopo-por-organizacao](../../../specs/002-escopo-por-organizacao/spec.md)
**Plan**: [plan.md](../../../specs/002-escopo-por-organizacao/plan.md)
**Ontological analysis**: [ontology-analysis.md](../../../specs/002-escopo-por-organizacao/ontology-analysis.md)

## Sprint goal {#objetivo-do-sprint}

Each person and each team come to say which organization they came from, and the schema
once again matches the model derived from the ontology.

## Carry-over from sprint 001 {#herança-do-sprint-001}

**No task in this sprint starts before what was left over from the previous one has a
destination.** It is the rule the `product-owner` skill started to require in planning,
and it exists because open scope without a destination is not work, is not a decision and is not
a discard — it is a pending item that shows up forever.

State of sprint 001, assessed on 2026-08-10 in the
[acceptance record](../001-fundacao-e-coleta-eo/aceitacao.md): **all three
deliverables were accepted**, D01 after the fix of
[#88](https://github.com/The-Band-Solution/theband/issues/88). Acceptance is not
a merge, and it is not a code review — what was left over is below, item by item.

| What was left over | Type | Destination |
|---|---|---|
| **T073 — open the pull request** · [#78](https://github.com/The-Band-Solution/theband/issues/78) | not performed | **completed in Phase 0**: [PR #89](https://github.com/The-Band-Solution/theband/pull/89), with the table of semantic mappings. Merged at `45d21a0` |
| **Independent code review** — principle VII | was a structural block; **unblocked on 2026-08-10** | The cause was permission: the repository had a single collaborator, the author. Once `pull` was granted to the `the-band` team, the review request started working — done in [PR #91](https://github.com/The-Band-Solution/theband/pull/91), and the reviewer is `Adylla027` or `EduardoNFraiz`. **Unrecoverable residue**: #89 was merged without review and there is no way to request a review of a merged PR. Lesson L15 |
| **T072 — quickstart evidence** · [#77](https://github.com/The-Band-Solution/theband/issues/77) | partially performed | closed **with the declared limitation**: V3, V4 and V8 are proven by test and not by real occurrence. Already accepted this way in `aceitacao.md`, with the caveat written |
| **SC-009 volume** — 100 people and 20 teams | not executable | **discarded, with reason**: it would require a source organization that does not exist. The behavior under the usage limit is covered by a test |
| **`Estimate` of the issues** | not performed | **returned**: depends on estimation done with the team. An invented number would produce a flow metric resting on fiction |
| **`mix knowledge.test`, `knowledge.docs`, `knowledge.information_model`** | deferred by recorded decision | **not included here.** The 001 `plan.md` declares: porting the three is work comparable to the whole feature, and they become a feature of their own tied to extracting the library. CI keeps running the Python scripts, so the gate exists — the executor changes, not the requirement |

### The exception, owned — and what the merge changed about it {#a-exceção-assumida--e-o-que-o-merge-mudou-nela}

This sprint starts from the 001 code **without the independent review**, and the rule
the paragraph above instituted allows that in only one case: when the new work
**fixes a defect of the old one**. That is exactly this case — F3 fixes columns
written by hand in 001.

**2026-08-10**: [PR #89](https://github.com/The-Band-Solution/theband/pull/89)
was merged into `main` at `45d21a0`, by decision of the maintainer, with CI
green and **no recorded approval** — `pulls/89/reviews` returns an empty
list.

This did not reduce the risk; **it changed where it lives.** Before, it was unreviewed code
outside the main line, visible as a pending branch. Now it is unreviewed code
**inside** the main line, indistinguishable from the rest. It is the hardest form in which to
remember that the debt exists, and it is the reason this paragraph exists.

**The cause of the review never having happened was found, and it was a different one.** It was not
the schedule: the repository had **a single collaborator**, `paulossjunior`, and no team
with access. A review can only be requested from a collaborator, and the author cannot be a reviewer —
so there were **zero possible reviewers**. The requirement went through the whole of sprint 001
as "review pending", indistinguishable from an item that only needed time. Recorded
in [L14](../licoes-aprendidas.md) and [L15](../licoes-aprendidas.md).

**Unblocked on 2026-08-10, with two API calls**: `pull` granted to the
`the-band` team — the minimum a review requires — and the review request made to the team instead
of to a person. Requesting from the team is what **produces** the independence: the request stays
open to any member, and the author, being a member, cannot fulfill it. The reviewer is
`Adylla027` or `EduardoNFraiz`.

**Correction of the record itself.** This document stated that the review of 001 had
not happened. The maintainer corrected it: *"I looked and agreed, that's why I didn't
leave a comment."* *(original: "eu olhei e concordei, por isso não coloquei comentário.")*
The reading took place; **what is missing is the proof, not the review.**

The wrong conclusion came from reading GitHub's `author` field as if it named who
implemented. It does not: the one who implemented is the agent, whose commits carry
`Co-Authored-By: Claude Opus 5` and who has no account. The `422` is a tooling artifact,
not a conflict of interest. Recorded as [L16](../licoes-aprendidas.md).

**What closes the gap for good** is opening the PRs with an agent identity — bot or GitHub
App. Then the implementer is the actual author, and `paulossjunior` can formally approve what
they did not write. In the meantime, #89, #90 and #91 keep the dated attestation in
`aceitacao.md`, because a merged PR does not receive a review.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md) — eighteen lessons, L01 to L18.
Twelve apply directly:

| Lesson | What changes in this sprint |
|---|---|
| **L03** — a test with invalid data finds what the happy path hides | Three tasks have their test written as a **violation**: T016 (one tenant asks for the other's organization), T007 (organizational team without an organization) and T022 (derived team recorded as observed). It is what L03 said to do |
| **L08** — a contract written together with the code describes, it does not decide | The **four contracts were written before** any code, and every task that creates a public API has "the contract exists" in its `Pronta quando` |
| **L09** — a contract can contradict itself | The 001 reprocessing contract contradicted itself and only the implementation revealed it. Here, a clause unreachable during implementation will be treated as a **symptom of a wrong contract**, not as code to delete |
| **L02** — a running server duplicates the effect of a job triggered by a script | The retrofit (T011) runs through Oban. No verification will call `perform/1` by hand with the server running |
| **L11** — configuring ProjectV2 iterations recreates the existing ones | Applied **in practice**, when changing the cadence to 7 days: snapshot of all 97 items **before**, reassignment by `item id` and not by issue number, and a check against the snapshot afterwards. All 97 were orphaned, as the lesson predicted, and the 87 went back into place |
| **L12** — a PR not opened right away ends up carrying another feature | It is why Phase 0 exists, and it is the lesson that created the rule of not pulling new work. The 002 PR is opened **when the task calls for it**, not at the end |
| **L13** — a secret that is referenced and not registered arrives as an empty string | Where absence has handling, empty gets the same. Applies to every environment read this feature adds |
| **L14** — `gh` swallows the refused review request | When opening this feature's PR, check `gh pr view <n> --json reviewRequests`. An empty list means nobody was requested, no matter what the command said |
| **L16** — the PR author is not who implemented | When recording the review, distinguish "did not happen" from "no proof". Applied in this sprint's `aceitacao.md` |
| **L17** — the schema derivation was not a function of the ontology | Discovered **in this** sprint, while running the T004 regression. Fixed, with a reproducibility gate in CI |
| **L18** — a criterion met is not a sufficient criterion | Discovered **in this** sprint: V9 passed with the derived team taking in the whole tenant. The acceptance walks through all criteria, and it was SC-009 that exposed it |
| **L15** — there is no possible reviewer in a single-collaborator repository | The independent review was pending on **permission**, not on schedule. Unblocked in this sprint: `pull` to the `the-band` team, and the review request to the team. Every PR of this feature is born with `team_reviewers[]=the-band` |

The others were considered and do not apply: L01 (there is no generator in this
feature), L04 (no new query to GitHub), L05 and L07 (fixes already
incorporated), L06 (absolute-path discipline, already in use), L10 (there is no
key rotation here).

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 002 — Scope by organization · 2026-08-10 to 2026-08-16 · 7 days
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**First occurrence.** When the sprint 002 iteration was created, the
ProjectV2 API recreated the sprint 001 one with a new identifier, and its 77 items
were orphaned — `updateProjectV2Field` replaces the set of iterations and does not
accept `id` on existing ones. The items were reassigned, and along the way 10 items from
**other repositories** (`eo_lib`, `theband-frontend`, `theband-backend` and a
pull request) were mistakenly assigned to sprint 001 and later cleaned up. It became
[L11](../licoes-aprendidas.md).

**Second occurrence, this one deliberate.** Changing the cadence to 7 days requires touching
the same configuration, so L11 was applied as a procedure:

| Step | Outcome |
|---|---|
| snapshot before — item, repository, number and iteration of each one | 97 items: 76 in sprint 001, 11 in sprint 002, 10 without iteration |
| `updateProjectV2Field` with `duration: 7` | both iterations recreated, **97 orphaned items** |
| reassignment by the snapshot's `item id` | 87 reassigned, 0 failures |
| check against the snapshot | 76 · 11 · 10 without iteration, and the 10 without are from **other repositories** |

Two things made a difference. Reassigning by **`item id`**, which does not change when the
iteration is recreated, instead of matching by issue number — the number is not unique in a
project that aggregates several repositories, and that was the second mistake the first time. And having
the snapshot **before**: without it, the information about which item belonged to which sprint
would simply not exist anywhere.

**New discovery.** The sprint 001 iteration, dated in the past, left
`iterations` and showed up in **`completedIterations`** — with its own identifier,
`2849580c`. A script that reads only `iterations` does not find it and concludes it
ceased to exist. It is in [L11](../licoes-aprendidas.md).

## Duration — how it was sized {#duração--como-foi-dimensionada}

**Scope**: 27 tasks in 8 phases · **5 levels** of dependency
**Critical path**:

```text
nível 1  Ontologia (T001–T003)
nível 2  Transformação (T004)          ── só depois de a relação existir
nível 3  Esquema (T005–T008)           ── só depois de a derivação produzir a coluna
nível 4  US1 (T009–T012) ‖ Equipe derivada (T020–T024)
nível 5  US2 (T013–T017) ‖ US3 (T018–T019) ‖ Polish (T025–T027)
```

Five levels, not eight phases: US1 and the derived team both depend on the schema and
not on each other, so they take up **one** level. The same holds for US2, US3 and Polish.

**Throughput used**: **none.** It is neither a declared premise nor data — it is an absence, and the
reason is below.

**Vertical slice floor**: **level 4.** The first three levels are ontology,
transformation and schema — infrastructure with no visible consumer. The first
deliverable that materializes a user story is US1, at level 4. A three-level sprint
closes arithmetically and **does not produce a `sro.sprint_deliverable`**.

**Proposed duration**: **4 days** for the MVP (levels 1 to 4), **5 days** for the whole
feature.

**Confidence**: **low.** One day per level is a premise, not an observation.

**Decided duration**: **7 days — one week**, by decision of the maintainer on
2026-08-10, as the project's default cadence.

The decision is about cadence, not about this sprint: a fixed-length sprint is what makes
throughput comparable across sprints, and comparability is a declared condition of
`flow.throughput.rate`. A cadence that varies per sprint would make the series unreadable — that is
why the proposal of 2 to 3 days on demand was discarded in favor of a
fixed week.

Seven days **accommodate the whole feature** with slack over the 5 days of the critical
path. The slack is not available scope: it is where level 3 will fit, which removes
columns with a migration and a recheck and is the most likely to overrun.

### Why 2 or 3 days do not fit this feature {#por-que-2-ou-3-dias-não-cabem-nesta-feature}

It is not conservatism: it is the chain. The first three levels are rigid — a column
before a relation was exactly the mistake that created this work —, and the first
visible consumer is at the fourth. **Three days would buy the three levels of
infrastructure and no screen.**

Shortening would have to come from cutting scope, and the scope left over is not a deliverable.
Duration is the largest of volume, critical path and vertical floor — here the vertical
floor is what rules.

**From 003 onward, sprints of 2 to 3 days are viable.** What prevents them here is this
feature starting with three levels of structural correction. A feature whose first
level already touches a screen fits in two days.

### Why throughput did not enter the calculation {#por-que-a-vazão-não-entrou-na-conta}

Three reasons, and all three are declared in `flow.throughput.rate` itself:

| Reason | What the measure says |
|---|---|
| **a one-sprint history** | "an isolated sprint does not describe the flow" — there is one observation, not a throughput |
| **the sprint 001 window did not contain its tasks** | fixed in this planning: the iteration became 2026-08-03 → 08-09, which contains 08/09. Before, its throughput was **zero**; now it is **76 tasks in 7 days**. One value, not a series |
| **the duration was uneven** | "comparing sprints requires constant duration". With 14 days in 001 and 7 in 002 the comparison would not exist. The weekly cadence solves this **from here on** — and 001 is only comparable because its window was rewritten to 7 days, which is an adjustment of the record, not of the work done |

There is also the trap the measure names: **"using throughput as a goal to hit turns it
into a target, and a target ceases to be a measure"**. Sizing duration by throughput is legitimate;
choosing the duration to reach a throughput produces tasks closed on the board before the
work is finished.

**Practical consequence: fixing the iteration dates is no longer cosmetic.**
As long as sprint 001 has a window that does not contain its own tasks, its throughput
is zero, and no following sprint can be sized by a series. Planning decision 1
became a prerequisite of all future sizing.

### What invalidates this calculation {#o-que-invalida-esta-conta}

- **granularity changing**: 27 tasks here and 76 in sprint 001 are not the same
  unit. Decomposing more finely raises throughput without more work done;
- **a level taking more than one day**: level 3 removes columns with a migration and
  a recheck, and is the most likely to overrun;
- **the first three phases not actually being rigid**: if the derivation already emitted
  the key, level 2 would go away and the chain would shorten by one day;
- **work that did not become a task**: review, support, waiting on a third party. The measure
  declares that this consumes capacity and does not show up in the count.

## Planning — `sro.planning_meeting` {#planejamento--sroplanning_meeting}

**Held on 2026-08-10.** The order followed is the one the `product-owner` skill started
to require: carry-over before new scope, and importance only afterwards.

| Step | Outcome |
|---|---|
| 1. list what is open from the previous sprint | 6 items, in the carry-over table above |
| 2. give each one a destination | 6 destinations: 2 completed, 1 closed with a limitation, 1 discarded with reason, 1 returned, 1 blocked with a named blocker |
| 3. carry-over first | Phase 0, before F1 |
| 4. select new scope by importance | the 9 issues below, with the declared MVP |

**Conclusion: F1 is released.** No item from sprint 001 remains without a destination,
which is the rule's condition — and it is not the same as saying everything from 001 was
done. The independent review remains pending, with a named blocker.

### Two decisions the planning took to the role, and that were made {#duas-decisões-que-o-planejamento-levou-ao-papel-e-que-foram-tomadas}

**1. Weekly cadence, and the dates fixed.** The iteration dates contradicted
what happened, and the contradiction zeroed out the flow measures:

| | Before | Now |
|---|---|---|
| Sprint 001 | start 2026-08-10, 14 days → would end 2026-08-23 | **2026-08-03 to 2026-08-09**, 7 days |
| Sprint 002 | start 2026-08-24, 14 days | **2026-08-10 to 2026-08-16**, 7 days |

The defect was that **the sprint 001 tasks were performed before the date on which the
iteration said it started** — 2026-08-09, outside the window. `flow.throughput.rate`
and `flow.wip.count` assign tasks to sprints by date window, so both
returned **zero** for sprint 001: a sprint that produced 76 tasks appeared with no
work at all. Residue of [L11](../licoes-aprendidas.md), where the items were
fixed and the date was not.

Now the 08/03→08/09 window contains 08/09, and sprint 002 starts **today**, without the two
empty weeks the previous configuration left.

**The fix cost what L11 predicted**, and the mitigation worked. Changing `duration`
from 14 to 7 recreated both iterations and left **all 97 items orphaned**. The
snapshot taken before — item, repository, number and iteration of each one — made it possible
to reassign the 87 that had an iteration: 76 in sprint 001, 11 in sprint 002, and the 10
without iteration stayed without, because they are from **other repositories**. Reassigning by the snapshot's
`item id`, and not by the issue number, is what avoided repeating L11's second
mistake.

**2. Epic #79 received importance P0** — that of its most important part, among US1 (P0),
US2 (P1) and US3 (P2). It is a decision of the role, not a derivation, and that is why it was made by
whoever plays the role instead of recorded for convenience. Tasks #83 to #87
remain **without** `Priority`, which is correct: a task inherits that of the user story it
serves.

## Scope — 9 issues instead of 27 {#escopo--9-issues-em-vez-de-27}

Decision of the maintainer: be more economical than in feature 001, where there were
77 issues. The 27 tasks in `tasks.md` live as a **checklist in the body** of each
issue, so the granularity is not lost and progress remains visible.

### Epic {#épico}

| Issue | Title |
|---|---|
| [#79](https://github.com/The-Band-Solution/theband/issues/79) | People and teams separated by observed organization |

### User stories {#user-stories}

| # | User story | Type | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|
| US1 | Know which organization each record came from | Feature | [#80](https://github.com/The-Band-Solution/theband/issues/80) | P0 | — | 5 scenarios |
| US2 | Query one organization at a time | Feature | [#81](https://github.com/The-Band-Solution/theband/issues/81) | P1 | — | 5 scenarios |
| US3 | See who crosses organizations | Feature | [#82](https://github.com/The-Band-Solution/theband/issues/82) | P2 | — | 3 scenarios |

`Priority` is SRO's *importance* — value to the organization. `Estimate` is the
*complexity*, and it is **blank on purpose**: no estimate was made with
the team, and filling it with an invented number would produce a flow metric resting on
fiction. A blank field means unknown, not zero.

The project's scale is P0/P1/P2 and the spec's is P1/P2/P3 — the mapping preserves the
**order**, not the label. Read "P0" as "the most important of the three".

### Tasks {#tarefas}

| # | Task | Serves | Type | Issue | Tasks from `tasks.md` | State |
|---|---|---|---|---|---|---|
| **F0** | **Open the 001 pull request** | carry-over | Task | [#78](https://github.com/The-Band-Solution/theband/issues/78) | T073 of 001 | **done** |
| **F0** | **Close the quickstart evidence** | carry-over | Task | [#77](https://github.com/The-Band-Solution/theband/issues/77) | T072 of 001 | **done**, with declared limitation |
| F1 | Declare the link in the ontology | epic | Task | [#83](https://github.com/The-Band-Solution/theband/issues/83) | T001–T003 | **done** |
| F2 | Generate a foreign key from an association | epic | Task | [#84](https://github.com/The-Band-Solution/theband/issues/84) | T004 | **done** |
| F3 | Fix the hand-written schema | epic | Task | [#85](https://github.com/The-Band-Solution/theband/issues/85) | T005–T008 | **done** |
| — | US1 tasks | US1 | checklist in #80 | — | T009–T012 | **done** |
| — | US2 tasks | US2 | checklist in #81 | — | T013–T017 | **not done** — returns to the backlog |
| — | US3 tasks | US3 | checklist in #82 | — | T018–T019 | **not done** — returns to the backlog |
| F7 | Create the derived team | epic | Task | [#86](https://github.com/The-Band-Solution/theband/issues/86) | T020–T024 | **done** |
| F8 | Close the feature | epic | Task | [#87](https://github.com/The-Band-Solution/theband/issues/87) | T025–T027 | **done** |

A task does not get a `Priority`: it inherits that of the user story it serves.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started)

## The order is not negotiable {#a-ordem-não-é-negociável}

```text
F0 Herança → F1 Ontologia → F2 Transformação → F3 Esquema → US1 → US2 → US3
                                                     └────→ F7 Equipe derivada → F8
```

**F0 comes first by rule, not by convenience.** Carry-over placed at the end of the
list is carry-over that does not get in: when the sprint gets tight, what gets left for later is
what is at the end. That is why what was left over from the previous sprint is the first thing to
receive a destination, and only afterwards is new scope selected by importance.

The chain of the next three is rigid, and it is the lesson of finding F1 of the analysis:
**a column written before the relation exists** was exactly the mistake that created
this work. No task that depends on `eo_teams.organization_id` starts
before the derivation produces it.

## MVP {#mvp}

**F1, F2, F3, US1 and F7.** The derived team is not optional in the MVP, and the first
version of `tasks.md` was wrong to say it could be left for later.

The reason is criterion SC-003a: no known person can be left without an
organization. Without the derived team, the 18 people who are not in any team
remain without one — including the 5 from `ifesserra-lab`, which has no team at all.
Delivering without it would fix the defect for 54 of the 72 people and keep it for the
other 18, without the screen saying why.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| What | Why |
|---|---|
| Organizational roles | the link remains evidence; promoting it to an allocation is a feature of its own |
| Identity reconciliation | two accounts of the same person remain two records |
| Measures per organization | the link comes into existence; the measures come later |
| Hierarchy between observed organizations | `parent_organization_id` exists and nothing fills it |
| Link from `eo.project_team` to a project | finding F8 of the analysis; the destination is SPO and the dependency direction needs to be checked first |
| Password authentication | remains a feature of its own, as in sprint 001 |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **The independent review of 001 never happening** | stopped being a delay risk and became a **structural impediment**: a single account cannot review its own PR. Closing it requires two identities — an infrastructure decision, outside this sprint. Until then, every deliverable carries the declared gap |
| **The unreviewed code being on `main`** | merged at `45d21a0` without a recorded approval. The risk did not decrease with the merge: it became indistinguishable from the rest of the code, which is why it is written in the carry-over and here |
| **The flow measures returning zero for sprint 001** | the iteration dates do not match what happened, and the fix was not made because touching iterations caused L11. Decision pending, recorded in the planning |
| **`mix knowledge.validate` passing where the Python validator fails** | happened in sprint 001: after the rename of `eo.sector`, the Elixir validator passed and the Python one failed on concept provenance without `source_type`. The Elixir one has 4 checks, the Python one has 11 — the two gates are **not** equivalent. In this sprint T003 closes one of them (a mapping declaring a nonexistent relation). Until the others are ported, **the Python gate is the one that decides**, and it runs in CI |
| **The deriver's new rule changing another ontology's derivation** | T004 requires the output of all the others to come out **identical**; it is a mandatory regression, not an optional check |
| **Removing a column with data in it** | T005 rechecks before T006 migrates; if the count does not come out zero, the task stops and becomes a decision |
| **The derived team being read as observed** | three tasks protect it — T022 is the violation test |
| **`updateProjectV2Field` recreating iterations again** | do not touch the iterations configuration while a sprint is open; this sprint's fix already cost a reassignment of 96 items |

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] **every open item from sprint 001 has a recorded destination** — completed,
      returned, discarded with reason, or blocked with a named blocker
- [ ] quality gates green: `mix format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `dialyzer`, `test`
- [ ] `mix knowledge.validate` and `mix knowledge.graph` green, plus the Python validator
- [ ] the derivation of the other ontologies comes out identical to before
- [ ] V1 to V10 of the [quickstart](../../../specs/002-escopo-por-organizacao/quickstart.md) executed, with evidence for each one
- [ ] V9 returns **zero** people without a team
- [ ] issues closed or reprioritized with justification
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `licoes-aprendidas.md` updated
- [ ] **independent review** — the same gap as sprint 001; declared, never marked as fulfilled by whoever implements
