# Sprint 036 — the database roles {#sprint-036--os-papéis-do-banco}

**Period**: 2026-10-03 to 2026-10-09, in the same iteration as 070 (Sprint 035 on GitHub)
**Feature**: [071](../../../specs/071-papeis-do-banco/spec.md) · **Plan**: [plan.md](../../../specs/071-papeis-do-banco/plan.md)
**Originating issue**: [#1131](https://github.com/The-Band-Solution/theband/issues/1131), security, finding G1 of 070

## Sprint goal {#objetivo-do-sprint}

The process that serves [redigido], and the check says so
against the environment.

## Lessons applied {#lições-aplicadas}

| lesson | how it is being applied |
|---|---|
| L24 — what only runs in a clean environment is not tested by whoever already has the environment | the non-owner role is born **in the test**, and quickstart §3 runs in the release container, and not only in the suite |
| L50 — the test that compares must prove it measured | every attempt first asserts `current_user` and `rolsuper`; the positive control (A10) is per attempt |
| L105 — the secret reached the text without anyone recording it | no URL or password in log, error or runbook (FR-012); A7 asserts the absence of the password |
| L108 — feature without a sprint backlog | this document exists before the code, and the US only close with acceptance |
| L109 — task closed without code and with the criterion intact | the three 👤 tasks only close with the output pasted in the issue; #1131 only closes with the check in force in production |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: the current one of the The Band project (`8808ca77`), as the issues were created.
**Scope**: the whole feature. The three 👤 tasks belong to the maintainer.

## User stories {#user-stories}

| # | user story | issue | Priority |
|---|---|---|---|
| US1 | The application that serves [redigido] | [#1141](https://github.com/The-Band-Solution/theband/issues/1141) | P1 |
| US2 | Migration still happens on its own at deploy | [#1142](https://github.com/The-Band-Solution/theband/issues/1142) | P1 |
| US3 | Whoever operates knows how to create the roles, and the backup is still restorable | [#1143](https://github.com/The-Band-Solution/theband/issues/1143) | P2 |

## Tasks {#tarefas}

| # | task | serves | type | issue | state |
|---|---|---|---|---|---|
| T001 | Check the starting state | — | Task | [#1144](https://github.com/The-Band-Solution/theband/issues/1144) | to do |
| T002 | Grant the privileges of whoever serves | — | Task | [#1145](https://github.com/The-Band-Solution/theband/issues/1145) | to do |
| T003 | Prove [redigido] | — | Task | [#1146](https://github.com/The-Band-Solution/theband/issues/1146) | to do |
| T004 | Check in the database whether the separation is in force | — | Task | [#1147](https://github.com/The-Band-Solution/theband/issues/1147) | to do |
| T005 | The whole suite as whoever serves | US1 | Task | [#1148](https://github.com/The-Band-Solution/theband/issues/1148) | to do |
| T006 | Migrate and grant with the credential that migrates | US2 | Task | [#1149](https://github.com/The-Band-Solution/theband/issues/1149) | to do |
| T007 | The three states without the credential that migrates | US2 | Task | [#1150](https://github.com/The-Band-Solution/theband/issues/1150) | to do |
| T008 | The entrypoint with the two credentials | US2 | Task | [#1151](https://github.com/The-Band-Solution/theband/issues/1151) | to do |
| T009 | The warning on every startup | US2 | Task | [#1152](https://github.com/The-Band-Solution/theband/issues/1152) | to do |
| T010 | The check over rpc | US2 | Task | [#1153](https://github.com/The-Band-Solution/theband/issues/1153) | to do |
| T011 | Write the roles runbook | US3 | Task | [#1154](https://github.com/The-Band-Solution/theband/issues/1154) | to do |
| T012 | The restore rehearsal with the roles | US3 | Task | [#1155](https://github.com/The-Band-Solution/theband/issues/1155) | to do |
| T013 | 👤 Measure today's role in production | US3 | Task | [#1156](https://github.com/The-Band-Solution/theband/issues/1156) | to do |
| T014 | 👤 Create the roles and transfer ownership | US3 | Task | [#1157](https://github.com/The-Band-Solution/theband/issues/1157) | to do |
| T015 | 👤 Configure the two credentials in Dokploy | US3 | Task | [#1158](https://github.com/The-Band-Solution/theband/issues/1158) | to do |
| T016 | Write the release risk note | — | Task | [#1159](https://github.com/The-Band-Solution/theband/issues/1159) | to do |
| T017 | Run the gates and open the PR | — | Task | [#1160](https://github.com/The-Band-Solution/theband/issues/1160) | to do |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **#1140, [redigido] (S5).** [redigido]
- **[redigido] (S10).** [redigido]

## Risks and dependencies {#riscos-e-dependências}

- **Phase 6 depends on access to production.** Without it, the code goes in and the check says "NOT
  in force", and there is no regression: the first state of FR-008.
- **CI runs PostgreSQL 17 and production 16** (S8).
- **The real guards of 070 are not yet in `development`.** T003 uses guards created in the
  test, and adds the real ones when the 070 stack is merged.
