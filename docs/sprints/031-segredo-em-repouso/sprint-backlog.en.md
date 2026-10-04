# Sprint 031 — Secret at rest {#sprint-031--segredo-em-repouso}

**Period**: 2026-09-12 to 2026-09-19 (one-week cadence) · **open**
**Feature**: [064 — secret at rest](../../../specs/064-segredo-em-repouso/spec.md)
**Plan**: [plan.md](../../../specs/064-segredo-em-repouso/plan.md) ·
**Research**: [research.md](../../../specs/064-segredo-em-repouso/research.md) ·
**Model**: [data-model.md](../../../specs/064-segredo-em-repouso/data-model.md) ·
**Contracts**: [contracts/](../../../specs/064-segredo-em-repouso/contracts/)

> **Written on 2026-09-13, one day after the work began.** The spec (#864), the plan (#865)
> and the issues (#889) went in between 2026-09-12 and 2026-09-13 without this document. None of the 19
> tasks has been executed yet, so the intention recorded here **is** prior to execution — what
> this delay cost was `TheBand.Segredo` (FR-006) being delivered in the spec's PR,
> before there was a backlog. It is stated in *Where this sprint came from*.

## Sprint goal {#objetivo-do-sprint}

**No cleartext secret reaches a backup**: the repeatable scan, with a positive control,
runs before the first copy to the second host; the session token stops being readable in the
database; and a secret, asked for its textual form, answers with a marker.

## Where this sprint came from {#de-onde-este-sprint-veio}

From **L105**. On 2026-09-12 a GitHub access token showed up in cleartext inside
`oban_jobs.errors`, where it had been since [redigido]. No line of code
logged it: the value reached the text through the error path, which no review looking for
log calls would find. The right answer was not to forbid logging, it was the **type**: a
secret that does not know how to become text.

**What was already done before this backlog**, in the spec's PR (#864, 2026-09-13): the type
`TheBand.Segredo` (refuses `inspect`, interpolation and serialization — FR-006), the redaction of row
#697, a **manual** scan of the development database (259 columns, zero), and the dump
rehearsal — 260 MB scanned inside and restored with 0 errors. **None of that closes a task**: T002
asks for the scan as a repeatable task, T005 asks for the execution recorded by it, T006 asks for the
type closing the model provider's path. What exists is a foundation with no declared
consumer, and the backlog names it.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), read on 2026-09-13:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L105** — the secret reached the text without anyone logging it | 030 (2026-09-12) | it is the origin of the feature; FR-006 and T006 |
| **L104** — a silenced warning becomes a certificate | 030 (2026-09-10) | the scan carries a **positive control** (T003): it must prove it can see before saying zero |
| **L23** — a skipped-check warning is a failure | 002 | T004: a scan that finds something refuses to **print** the value, and fails naming the column |
| **L30** — check against the source, item by item | 003 | the dump rehearsal was against a copy of the real database; T005 records the scan over the real database, not over a fixture |
| **L60** — the verdict is the exit code | 019 | in the DoD and in the PR template |
| **L100** — documentation branch without a PR | 029 | spec, plan and issues came by PR (#864, #865, #889) |
| **L102** — `git add -A` in a shared tree | 030 | #889 records "the audit that found a mistake of mine": explicit paths and `git status` before opening a PR (constitution 1.8.0) |
| **L95** — requesting a reviewer is not getting a review | 027 | **not applied in the three preparation PRs**: #864, #865 and #889 without a requested reviewer (`reviewRequests` 0). From this backlog on, every 064 PR requests the `the-band` team on opening and checks it |
| **L108** — the step without an owner disappears | 032 | this document exists **before** T001 |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
**Iteration**: *Sprint 025 — Contas e o elo do GitHub* · 2026-09-12 to 2026-09-19 · 7 days
(the project's iteration numbering lags behind these folders'; it is the active one in the period)

**Materialized on 2026-09-13**, while writing this backlog — the 23 issues had existed since
#889 with labels (`task`, `us`, `epic`, `security`) and **without type, without hierarchy and outside the
project**. What was done, and what was not:

| step | result |
|---|---|
| type `Task` on the 19 tasks | see `docs/sprints/031-segredo-em-repouso/github.md` |
| type on the 3 USs and the epic | **no** — `User Story` and `Epic` do not exist in the organization; typing them as `Feature` would make the routing rule classify wrongly. No type is absence; the wrong type is a false statement (decision of sprint 029, kept) |
| task → sub-issue of the US | T002–T005 → #885 · T006–T008 → #887 · T009–T014 → #886 |
| US → sub-issue of epic #888 | #885, #886, #887 |
| item in the project + iteration + Status | all 23 |

**Six tasks have no user story**, and that comes from `tasks.md`, not from the materialization: T001
(foundation), T015 and T016 (what stays written) and T017–T019 (the age of the credential, FR-016 to FR-019,
a requirement added by #889 without its own user story). Do they become children of the epic? **No** —
a task is a child of a user story, and linking them to the epic would make the routing rule count a task as
composition. They stay loose, and the gap is stated here.

## Selected user stories {#user-stories-selecionadas}

**All three.** The order of the phases does **not** follow the spec's priority, and `tasks.md` says why:
US3 (P3) is brought forward because the `Segredo` type already exists and closing the provider's path is
small; US2 (P2) is the largest and comes last.

| # | User story | Priority | Epic | Issue | Tasks | Criteria |
|---|---|---|---|---|---|---|
| US1 | No cleartext secret reaches a backup 🎯 | P1 | [#888](https://github.com/The-Band-Solution/theband/issues/888) | [#885](https://github.com/The-Band-Solution/theband/issues/885) | T002–T005 | FR-001 to FR-005 |
| US2 | The session token stops being readable in the database | P2 | #888 | [#886](https://github.com/The-Band-Solution/theband/issues/886) | T009–T014 | FR-010 to FR-015 |
| US3 | A secret never reaches a log, error or diagnostic field | P3 | #888 | [#887](https://github.com/The-Band-Solution/theband/issues/887) | T006–T008 | FR-006 to FR-009 |

`Estimate` (the *complexity*) **was not filled in** — unknown, not zero. `Priority` comes from the
spec.

## Tasks {#tarefas}

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T001 | Declare the secret patterns in a single place | foundation | [#866](https://github.com/The-Band-Solution/theband/issues/866) | done (2026-09-28) |
| T002 | Create the scan task | US1 | [#867](https://github.com/The-Band-Solution/theband/issues/867) | done (2026-09-28) |
| T003 | Embed the positive control in the scan | US1 | [#868](https://github.com/The-Band-Solution/theband/issues/868) | done (2026-09-28) |
| T004 | Refuse to print the value found | US1 | [#869](https://github.com/The-Band-Solution/theband/issues/869) | done (2026-09-28) |
| T005 | Scan the development database and record it | US1 | [#870](https://github.com/The-Band-Solution/theband/issues/870) | done (2026-09-28) |
| T006 | Close the secret in the model provider's path | US3 | [#871](https://github.com/The-Band-Solution/theband/issues/871) | done — the provider's edge receives a `Segredo`, and only the header and the redaction open it |
| T007 | Fill in the missing end dates | US3 | [#872](https://github.com/The-Band-Solution/theband/issues/872) | to do · `bug` |
| T008 | Check for a finished record without a date | US3 | [#873](https://github.com/The-Band-Solution/theband/issues/873) | to do |
| T009 | Create the sessions table | US2 | [#874](https://github.com/The-Band-Solution/theband/issues/874) | to do |
| T010 | Add the password epoch | US2 | [#875](https://github.com/The-Band-Solution/theband/issues/875) | to do |
| T011 | Open, check and end a session | US2 | [#876](https://github.com/The-Band-Solution/theband/issues/876) | to do |
| T012 | Migrate the live sessions without logging anyone out | US2 | [#877](https://github.com/The-Band-Solution/theband/issues/877) | to do |
| T013 | Read the session from the new table | US2 | [#878](https://github.com/The-Band-Solution/theband/issues/878) | to do |
| T014 | Remove the old column | US2 | [#879](https://github.com/The-Band-Solution/theband/issues/879) | to do — **destructive**; last, on purpose |
| T015 | Document the effect of a restore on the sessions | — | [#880](https://github.com/The-Band-Solution/theband/issues/880) | to do · `documentation` |
| T016 | Write the procedure to rotate all sessions | — | [#881](https://github.com/The-Band-Solution/theband/issues/881) | to do · `documentation` |
| T017 | Know the age of each credential | — (FR-016, FR-019) | [#882](https://github.com/The-Band-Solution/theband/issues/882) | done (2026-10-03) — `Credenciais.Idade`, three states, deadline in a single place |
| T018 | Request the change on the screen that administers it | — (FR-017) | [#883](https://github.com/The-Band-Solution/theband/issues/883) | done (2026-10-03) — the request in `/tools` and `/ai` against the approved prototype (v2); the same-key flash with the six conditions of opinion C.1; log finding at `:debug` fixed in `AI.put/3` and opened for tools (#1222). The QA check with a browser is still missing (color, grayscale, 360 px) |
| T019 | Record the date of the change | — (FR-018) | [#884](https://github.com/The-Band-Solution/theband/issues/884) | done (2026-10-03) — `AI.put/3` records the date of the change and the previous one; the same key does not reset it |

A task does not receive a `Priority`: it inherits that of the user story it serves.

## Minimum scope {#escopo-mínimo}

**T001 to T005 — the whole of US1.** On its own it delivers what time makes impossible later: scanning a
dump **before** the first copy to the second host, with proof that the scan can see.
The decision of MinIO as the production destination is in PR #914, open — the scan needs to
exist before it is merged.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

From `tasks.md`, section *What these tasks do not cover*:

- **the rotation of the GitHub token** ([redigido]) — an operational act, postponed by the maintainer
  to [redigido]. [redigido] **Redacting the row did not close it** — only rotation invalidates a value that was readable
  (L105);
- **running the scan in production** — T002 makes it possible; executing it belongs to whoever operates;
- **the path to MinIO** — `pg_dump → varredura → restauração` is covered;
  `→ destino remoto →` was exercised on 2026-09-13 outside this feature
  (`docs/seguranca/2026-09-13-o-caminho-completo-do-backup.md`), and [redigido];
- **where the four records cancelled without a date came from** — an unknown declared in R6.

## Risks and dependencies {#riscos-e-dependências}

- **T014 removes a column** — it is the only destructive task, and that is why it is last. A rollback after
  it loses the sessions the new table holds; T015 documents what a restore does
  to the sessions **before** T014;
- **T012 migrates live sessions** — failing logs out whoever is logged in, including whoever administers.
  Rehearsal against a copy of the real database before production;
- **T018 is a screen** and goes through the Design role before the code;
- **H9** ([redigido]) is a neighbour: secret at rest in the database and [redigido]
  are two problems, and this sprint only handles the first.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] quality gates green — `mix gates` with exit code 0
- [ ] knowledge base valid
- [ ] `gh issue list --state open --search "064/"` empty, or each open one with a written destination
- [ ] every PR with the `the-band` reviewer requested and checked, and in the project (L95, `AGENTS.md`)
- [ ] `sprint-review.md` written
- [ ] `aceitacao.md` written by the role, criterion by criterion
- [ ] `licoes-aprendidas.md` updated
