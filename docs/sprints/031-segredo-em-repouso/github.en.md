# Sprint 031 — what was materialized on GitHub {#sprint-031--o-que-foi-materializado-no-github}

**Executed on**: 2026-09-13, while writing the backlog — the issues had existed since #889 with
labels and **without type, without hierarchy, outside the project**. Script and log stayed out of the
repository; what is here was **read back** from the API after writing, not copied from
what the script said it did.

| step | issues | result |
|---|---|---|
| type `Task` (`updateIssueIssueType`) | #866–#884 (19) | **19 written**, read back as `type=Task` |
| type on the USs and the epic | #885–#888 | **not written, on purpose** — `User Story` and `Epic` do not exist in the organization (only `Task`, `Bug`, `Feature`); typing them as `Feature` would make the routing rule classify wrongly. Decision of sprint 029, kept |
| sub-issue task → US (`addSubIssue`) | T002–T005 → #885 · T006–T008 → #887 · T009–T014 → #886 | **13 linked** |
| sub-issue US → epic | #885, #886, #887 → #888 | **3 linked** |
| item in the project [The Band](https://github.com/orgs/The-Band-Solution/projects/2) | all 23 | **23 added** |
| `Iteration` | all 23 | *Sprint 025 — Contas e o elo do GitHub* (2026-09-12 to 2026-09-19) |
| `Status` | all 23 | **Ready** — selected for the sprint, none started |

## What was left out, and why {#o-que-ficou-de-fora-e-por-quê}

- **T001, T015, T016, T017, T018, T019 without a parent.** `tasks.md` does not tie them to a user story:
  T001 is foundation; T015–T016 are what stays written; T017–T019 serve FR-016 to FR-019, which
  #889 added to the spec **without its own user story**. Linking them to the epic would count a task as
  composition — wrong by the routing rule. They stay loose, and the gap belongs to the spec;
- **`Priority`, `Size`, `Estimate`** not filled in — unknown, not zero. The USs' `Priority`
  comes from the spec (P1, P2, P3) and can be written when the role confirms the backlog;
- **the iteration numbering** (*Sprint 025*) lags behind these folders' (031). It is the field that
  exists; fixing the project's numbering is work of its own, with a snapshot beforehand (L11).

## Read-back (sample) {#leitura-de-volta-amostra}

```
#866  type=Task  parent=∅    status=Ready  iter=Sprint 025
#870  type=Task  parent=885  status=Ready  iter=Sprint 025
#885  type=∅     parent=888  status=Ready  iter=Sprint 025
#888  type=∅     parent=∅    status=Ready  iter=Sprint 025
```
