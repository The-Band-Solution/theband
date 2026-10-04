# Sprint 007 — unblocking the stuck sync {#sprint-007--destravar-a-sincronização-presa}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [008 — unblock stuck sync](../../../specs/008-destravar-sync-presa/spec.md)
**Plan**: [plan.md](../../../specs/008-destravar-sync-presa/plan.md) ·
**Origin**: [#175](https://github.com/The-Band-Solution/theband/issues/175), product backlog
**Analysis**: run before the code, and it **changed the central decision**

## Sprint goal {#objetivo-do-sprint}

At the end of this sprint, a collection that died **no longer blocks the tool** — without SQL, and without
anyone needing to open the screen.

Today the unique index that prevents two simultaneous collections becomes a permanent block when the job
dies. **Two runs have already been unblocked by hand**, and the procedure is recorded in
[RETOMAR.md](../RETOMAR.md). Needing SQL twice is the argument of the sprint.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), 33 lessons. The ones that enter as a **constraint**:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L02** | Sprint 001 | it is the lesson that **took down the automatic rescue**: a duplicated collection produces a plausible and wrong number. See the section below |
| **L08** | Sprint 002 | contract written before the first public function, and **corrected** when the implementation showed a third function was missing |
| **L11** | Sprint 002 | I will **not** touch the iterations configuration |
| **L18** | Sprint 003 | a met criterion is not enough: the acceptance assesses the 13 SC with evidence |
| **L21** | Sprint 004 | F1 alone delivers nothing visible — a decision without a trigger unblocks nothing, and that is why F2 is in the same sprint |
| **L22**, **L23** | Sprint 004 | gate by **exit code**, `mix gates`, without `\| tail` |
| **L26** | Sprint 004 | match the right envelope: here the analogue is to check the **result** of `Oban.insert`, which today goes into the void |
| **L27** | Sprint 005 | full cycle before the code — and it is the third feature in a row in order |
| **L29** | Sprint 005 | the reason distinguishes a transient failure from a permanent one; a generic reason is the defect that cost 899 issues |
| **L30** | Sprint 005 | the sprint's numbers come from the database, not from estimates: 32 runs, 5 discarded, 1 orphan three days old |
| **L33** | Sprint 006 | the question "what does the screen say the next day" was asked, and became the 1-minute grace period |

**L02 is the one that decided the design, and it is worth saying how.** The plan had accepted configuring the
automatic rescue of orphan jobs with a `rescue_after` of 60 minutes — 3.7× the longest collection measured.
The analysis asked whether there was protection **beyond** time, and reading the source answered no:

```elixir
# deps/oban/lib/oban/engines/basic.ex:189
where([j], j.state == "executing" and j.attempted_at < ^cut)
```

No live-node check. The collection grows with the number of repositories, and on the day it goes
beyond 60 minutes there are **two runs of the same collection**, each one working. It is exactly L02 —
32 records instead of 16, and the number passed as correct.

**The rescue left the design.** An orphan is ended, and the new collection re-collects without duplicating rows, because
storage is by natural key.

## The third locking path, which nobody had seen {#o-terceiro-caminho-de-travamento-que-ninguém-tinha-visto}

The same analysis read the opening of the run and found this: `Repo.insert()` and `Oban.insert()` are
separate operations, and **the result of the second is discarded**. If creating the job fails, the
record stays `running` with nothing to execute it.

**It is not among the 5 discarded nor in the measured orphan** — because nobody would know whether it has already happened. It is
T006, and it is the kind of defect that only shows up reading the code with the right question.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration**: **does not exist for this sprint**, and it is a declared limitation — not forgetfulness.
Configuring ProjectV2 iterations recreates the existing ones (L11), and it has already cost reassigning 96 items. Sprints
003 to 007 run without their own iteration for the same reason.

**Types**: the organization has `Task`, `Bug` and `Feature`, and does **not** have `Epic` or `User Story`. Epic
and user stories are typed `Feature`, as in the previous sprints. The hierarchy carries what the type
does not.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | Collect again after a failure | [#198](https://github.com/The-Band-Solution/theband/issues/198) | [#199](https://github.com/The-Band-Solution/theband/issues/199) | **P0** | 13 | to do |
| US2 | Understand why the run died | [#198](https://github.com/The-Band-Solution/theband/issues/198) | [#200](https://github.com/The-Band-Solution/theband/issues/200) | **P0** | 3 | to do |
| US3 | End by hand what the platform cannot prove | [#198](https://github.com/The-Band-Solution/theband/issues/198) | [#201](https://github.com/The-Band-Solution/theband/issues/201) | P1 | 5 | to do |

**US1 and US2 are P0, and it is the first time in this project.** The *importance* here is not preference: without
them the tool becomes unusable and the only way out is SQL on the production database. US3 is P1 because
it covers the case the platform cannot prove — real, and less frequent.

`Priority` is the SRO's *importance*; `Estimate` is the *complexity*. A blank field means
**unknown**, never zero.

## Tasks {#tarefas}

Detailed in [008/tasks.md](../../../specs/008-destravar-sync-presa/tasks.md). Each task is a child of the
**user story it serves** — never of the epic: a task under an epic violates `sro.rule07`.

| # | Task | Serves | Issue | Estimate | Phase | State |
|---|---|---|---|---|---|---|
| T001 | Record who ended the run | US1 | [#202](https://github.com/The-Band-Solution/theband/issues/202) | 2 | F1 | to do |
| T002 | Find a run's job | US1 | [#203](https://github.com/The-Band-Solution/theband/issues/203) | 3 | F1 | to do |
| T003 | Decide whether the run is stuck | US1 | [#204](https://github.com/The-Band-Solution/theband/issues/204) | 5 | F1 | to do |
| T004 | Say why the run died | US2 | [#205](https://github.com/The-Band-Solution/theband/issues/205) | 3 | F1 | to do |
| T005 | Do not change an ending already made | US1 | [#206](https://github.com/The-Band-Solution/theband/issues/206) | 2 | F1 | to do |
| T006 | End when the job is never born | US1 | [#207](https://github.com/The-Band-Solution/theband/issues/207) | 3 | F2 | to do |
| T007 | Reconcile every five minutes | US1 | [#208](https://github.com/The-Band-Solution/theband/issues/208) | 3 | F2 | to do |
| T008 | End the stuck run from the screen | US3 | [#209](https://github.com/The-Band-Solution/theband/issues/209) | 5 | F3 | to do |
| T009 | Say who ended the run | US3 | [#210](https://github.com/The-Band-Solution/theband/issues/210) | 2 | F3 | to do |

A task does not get `Priority`: it inherits that of the user story it serves.

**Total: 28 of complexity, nine tasks.**

## Confirmed scope {#escopo-confirmado}

**Feature 008 complete — F1 to F3, T001 to T009.**

**The MVP is F1+F2**, and it solves issue #175 entirely: the block clears by itself, without SQL and without anyone
opening the screen. F3 adds the case the platform cannot prove — the job shows as
executing and whoever administers knows the process died.

**F1 alone delivers nothing visible**, and that is declared: a decision without a trigger unblocks nothing. It is
L21, and that is why F2 is not optional.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| **automatic rescue of orphan jobs** | decides by time without knowing whether the process is alive; the constant ages with the collection — R1, and it is L02 |
| cancel a collection **in progress** | it is another question: stopping what is alive, and nobody asked |
| panel of queue jobs | the screen shows collection, not infrastructure |
| repeat the collection automatically | whoever decides to try again is whoever administers; automating would hide a permanent failure |
| a dedicated queue for the reconciliation | it competes for a slot in `ingestion` and, with 5 collections, waits — it delays, it does not prevent |
| `stuck` state | `interrupted` serves; the distinction lives in the reason and the author |
| **person detail page** | requested during this sprint and recorded in [#211](https://github.com/The-Band-Solution/theband/issues/211) — it goes into the next one, with its own cycle |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **ending a live collection** — the opposite defect, and worse than the problem | the decision requires the absence of an active job, never age; the test inserts a **real** `executing` job |
| list of active states written from memory | there are **five**, derived from `Oban.Job.states/0`; the test fails if Oban adds a state |
| ending a run that just started | 1-minute grace period, three orders of magnitude above the real race |
| the reason erasing the difference between a momentary and a permanent failure | reason by cause, and the test requires **different** texts — L29 |
| automatic trigger erasing a human decision | it acts only on `running`; the test ends by a person and reconciles afterwards |
| the reconciliation waiting for a slot in the queue | accepted and declared: it delays the unblocking, it does not prevent it |

**No dependency on another branch.** `009-destravar-sync-presa` comes out of `main`, with the
artifacts already committed. [PR #197](https://github.com/The-Band-Solution/theband/pull/197) — the
tagline — is open and does not block: no file in common.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] `mix gates` green by **exit code** — ten gates
- [ ] V1 to V9 of the [quickstart](../../../specs/008-destravar-sync-presa/quickstart.md) verified
- [ ] the orphan job of 2026-08-09 **ended by the platform**, not by SQL — it is the proof on the real data
- [ ] the nine issues closed or reprioritized with justification
- [ ] PR with reviewer requested and **checked** via `requested_reviewers` (L14), linked to the project
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `licoes-aprendidas.md` updated
- [ ] `aceitacao.md` with the 13 SC assessed one by one
