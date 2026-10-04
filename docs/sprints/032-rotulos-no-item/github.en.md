# Sprint 032 — what was materialized on GitHub {#sprint-032--o-que-foi-materializado-no-github}

**Executed on**: 2026-09-13, **after** the sprint — the 17 issues had existed since the morning with
labels (`task`, `us`) and **without type, without hierarchy, outside the project**. What is here was
**read back** from the API after writing.

| step | issues | result |
|---|---|---|
| type `Task` | #890–#903 (14) | **14 written**, read back as `type=Task` |
| type on the USs | #904–#906 | **not written, on purpose** — `User Story` does not exist in the organization (decision of sprint 029) |
| epic | — | **there is no epic** for 065 |
| sub-issue task → US | T001, T002, T003, T005, T006, T007 → #904 · T004, T008 → #906 · T011, T012 → #905 | **10 linked** |
| item in the project [The Band](https://github.com/orgs/The-Band-Solution/projects/2) | all 17 | **17 added** |
| `Iteration` | all 17 | *Sprint 025 — Contas e o elo do GitHub* (2026-09-12 to 2026-09-19) |
| `Status` — tasks | #890–#903 | **Done** — closed on 2026-09-13 |
| `Status` — user stories | #904–#906 | **In review** — verdict proposed by the role, confirmation pending |

## What was left out, and why {#o-que-ficou-de-fora-e-por-quê}

- **T009, T010, T013, T014 without a parent** — `tasks.md` does not tie them to a user story (T009/T010
  serve FR-016/FR-017, which have no US; T013 and T014 are checks). The gap belongs to the spec;
- **T008 had two parent candidates** — the body of #904 lists it, and so does that of #906. An
  issue has only one parent: it stayed in **US3**, because T008 is FR-009 (*refuse to interpret the
  label's content*), which is US3's rule;
- **`Estimate`** not filled in; the USs' **`Priority`** comes from the spec (US1 P1, US3 P1, US2 P2) and
  can be written at confirmation;
- **the tasks' `Status` as `Done`** states that the task was executed — not that the
  deliverable was accepted. T005, T007, T011 and T012 are `Done` and are
  `non_successfully_performed`; the phase lives in the acceptance, not on the board.

## Read-back (sample) {#leitura-de-volta-amostra}

```
#890  type=Task  parent=904  status=Done       iter=Sprint 025
#897  type=Task  parent=906  status=Done       iter=Sprint 025
#904  type=∅     parent=∅    status=In review  iter=Sprint 025
#906  type=∅     parent=∅    status=In review  iter=Sprint 025
```
