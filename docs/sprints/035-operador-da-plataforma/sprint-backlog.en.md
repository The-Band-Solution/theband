# Sprint 035 — The platform operator {#sprint-035--o-operador-da-plataforma}

**Period**: starting 2026-10-03, when Sprint 034 ends. The duration is for the maintainer to decide together with the iteration.
**Feature**: [070 — the platform operator](../../../specs/070-operador-da-plataforma/spec.md)
**Plan**: [plan.md](../../../specs/070-operador-da-plataforma/plan.md) · **Tasks**: [tasks.md](../../../specs/070-operador-da-plataforma/tasks.md)

## Sprint goal {#objetivo-do-sprint}

Whoever operates the platform suspends an organization through the screen, with the reason and the second factor. Every
session and every token of the organization fall in the same transaction, and reactivating gives none of them back. This
closes #1009.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md). The open lessons that apply here come in as a
**constraint**:

| Lesson | How it is being applied |
|---|---|
| L42 — a late telemetry message enters the next count | the telemetry guards (R10, SC-003; T041) drain the mailbox and detach before asserting |
| L50 — a test that compares two measures must prove it measured | every capture has the control "the capture measured something" (T041, T049, T056) |
| L56 — filtering telemetry by `source` does not reach raw SQL | R10 and T041 also assert on the SQL text (`"users"`), and not only on the `source` |
| L90 — counting only the winner of the race does not prove the loser | the concurrency tests (A1, A5, O9, FR-014) assert the winner **and** the loser's refusal |
| L105 — the secret reached the text without anyone recording it | the setup, safekeeping and recovery codes and the TOTP secret never go to log, flash or redirect (T5); the parameter filter covers the field names (A10) |
| L108 — features without a sprint backlog, and acceptance without a place | this document exists **before** any code, and the US only closes with acceptance |
| L109 — task closed "without code" with the criterion intact | T002, T003 and T003a stay open until the evidence is pasted in the issue, even with the PRs already merged |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: **pending**. The 74 issues were created in Sprint 034 (`8808ca77`), which ends on
2026-10-03. Creating the "Sprint 035" iteration changes the project's configuration and is the
maintainer's decision. Once it is created, the 74 issues move there.
**Project**: The Band (`PVT_kwDODHSRm84BAAnT`)

## Selected user stories {#user-stories-selecionadas}

| # | User story | Type | Epic | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|---|
| US2 | The operator role exists, and does not leak organization data | User Story | [#1056](https://github.com/The-Band-Solution/theband/issues/1056) | [#1058](https://github.com/The-Band-Solution/theband/issues/1058) | P1 | | 4 scenarios |
| US1 | Suspend an organization, and the sessions really fall | User Story | [#1056](https://github.com/The-Band-Solution/theband/issues/1056) | [#1057](https://github.com/The-Band-Solution/theband/issues/1057) | P1 (MVP) | | 3 scenarios |

US2 comes first because it is a prerequisite of US1. The release only ships with both. A blank `Estimate`
means **unknown**, not zero: it was not estimated.

## Tasks {#tarefas}

The 71, with the issue for each one. A task inherits the priority of its US.

| # | Task | Serves | Phase | Issue | State |
|---|---|---|---|---|---|
| T001 | Check the prerequisites already merged | epic | Phase 1 | [#1059](https://github.com/The-Band-Solution/theband/issues/1059) | to do |
| T002 | Wait for the merge of the parallel wait fix | epic | Phase 1 | [#1060](https://github.com/The-Band-Solution/theband/issues/1060) | to do |
| T003 | Wait for the merge of the fix for the cost of the wait | epic | Phase 1 | [#1061](https://github.com/The-Band-Solution/theband/issues/1061) | to do |
| T003a | Wait for the merge of the rotation that re-encrypts all encrypted fields | epic | Phase 1 | [#1062](https://github.com/The-Band-Solution/theband/issues/1062) | to do |
| T004 | Measure the IP header at the production proxy | epic | Phase 1 | [#1063](https://github.com/The-Band-Solution/theband/issues/1063) | to do |
| T005 | Decide the shape of the operator area | epic | Phase 1 | [#1064](https://github.com/The-Band-Solution/theband/issues/1064) | done |
| T006 | Open the sprint backlog and the issues | epic | Phase 1 | [#1065](https://github.com/The-Band-Solution/theband/issues/1065) | to do |
| T007 | Rebase the work onto the integration branch | epic | Phase 1 | [#1066](https://github.com/The-Band-Solution/theband/issues/1066) | to do |
| T008 | Check the security amendments in the contracts — done on 2026-10-01 by the `security` agent; section "Conferência das emendas" in seguranca-autenticacao.md, the six blockers covered | epic | Phase 2 | [#1067](https://github.com/The-Band-Solution/theband/issues/1067) | done |
| T009 | Research the TOTP implementation — done on 2026-10-01: NimbleTOTP == 1.0.0, hex.audit and deps.audit with exit code 0; no QR (recommendation, decision in the T012 prototype) | epic | Phase 2 | [#1068](https://github.com/The-Band-Solution/theband/issues/1068) | done |
| T010 | Evaluate TOTP security before the code — done on 2026-10-01 by the `security` agent, which did not write the design; seguranca-totp.md: T1 high and T2 medium amended in the contracts, T1 became T028a (blocking), T3 went into T021; the rest is left for T011 | epic | Phase 2 | [#1069](https://github.com/The-Band-Solution/theband/issues/1069) | done |
| T011 | Amend the contracts with the TOTP result — done on 2026-10-01 by the `security` agent; seguranca-totp.md §3, "Emendas de T011", points to the passage of each one (T4, T5, T6, T8; T9–T11 in plan.md "Riscos"; T12 new, step 2 counting only in `failed_attempts`, kept with the reason); scenarios C14–C21 of the safekeeping code in §4. Limit: the T011 amendments were written and checked by the same agent — the independent check is left for the PR review | epic | Phase 2 | [#1070](https://github.com/The-Band-Solution/theband/issues/1070) | done |
| T012 | Prototype the operator screens | epic | Phase 2 | [#1071](https://github.com/The-Band-Solution/theband/issues/1071) | done |
| T013 | Restrict the organization state | epic | Phase 2 | [#1072](https://github.com/The-Band-Solution/theband/issues/1072) | to do |
| T014 | Declare the suspension reasons in the knowledge base — list approved by the maintainer on 2026-10-01, as in data-model §5 | epic | Phase 2 | [#1073](https://github.com/The-Band-Solution/theband/issues/1073) | to do |
| T015 | Declare the record-only revocation clause | epic | Phase 2 | [#1074](https://github.com/The-Band-Solution/theband/issues/1074) | to do |
| T016 | Teach the log to name the operator and to keep the secret quiet | epic | Phase 2 | [#1075](https://github.com/The-Band-Solution/theband/issues/1075) | to do |
| T017 | Share the CSP between the two pipelines | epic | Phase 2 | [#1076](https://github.com/The-Band-Solution/theband/issues/1076) | to do |
| T018 | Create the operator tables | US2 | Phase 3 | [#1077](https://github.com/The-Band-Solution/theband/issues/1077) | to do |
| T019 | Prove that the grant is neither deleted nor rewritten | US2 | Phase 3 | [#1078](https://github.com/The-Band-Solution/theband/issues/1078) | to do |
| T020 | Create the second-factor columns and table | US2 | Phase 3 | [#1079](https://github.com/The-Band-Solution/theband/issues/1079) | to do |
| T021 | Write the schemas of the platform context | US2 | Phase 3 | [#1080](https://github.com/The-Band-Solution/theband/issues/1080) | to do |
| T022 | Check the second-factor code | US2 | Phase 3 | [#1081](https://github.com/The-Band-Solution/theband/issues/1081) | to do |
| T033 | Record the operator's access events | US2 | Phase 3 | [#1082](https://github.com/The-Band-Solution/theband/issues/1082) | to do |
| T023 | Check the operator's sign-in | US2 | Phase 3 | [#1083](https://github.com/The-Band-Solution/theband/issues/1083) | to do |
| T023a | Prove that key rotation reaches the TOTP secret | US2 | Phase 3 | [#1084](https://github.com/The-Band-Solution/theband/issues/1084) | to do |
| T024 | Prove the wait under a parallel burst | US2 | Phase 3 | [#1085](https://github.com/The-Band-Solution/theband/issues/1085) | to do |
| T025 | Prove that the wait pays the cost of the hash | US2 | Phase 3 | [#1086](https://github.com/The-Band-Solution/theband/issues/1086) | to do |
| T026 | Set the password and enroll the second factor | US2 | Phase 3 | [#1087](https://github.com/The-Band-Solution/theband/issues/1087) | to do |
| T027 | Prove the single-use code under concurrency | US2 | Phase 3 | [#1088](https://github.com/The-Band-Solution/theband/issues/1088) | to do |
| T028 | Prove the second factor at sign-in | US2 | Phase 3 | [#1089](https://github.com/The-Band-Solution/theband/issues/1089) | to do |
| T029 | Open and check the operator session | US2 | Phase 3 | [#1090](https://github.com/The-Band-Solution/theband/issues/1090) | to do |
| T030 | Grant, reset and revoke the role | US2 | Phase 3 | [#1091](https://github.com/The-Band-Solution/theband/issues/1091) | to do |
| T030a | Prove revocation and reset in the middle of enrollment | US2 | Phase 3 | [#1092](https://github.com/The-Band-Solution/theband/issues/1092) | to do |
| T028a | Prove the second factor's own limit | US2 | Phase 3 | [#1093](https://github.com/The-Band-Solution/theband/issues/1093) | to do |
| T031 | Prove that granting again does not give a credential back | US2 | Phase 3 | [#1094](https://github.com/The-Band-Solution/theband/issues/1094) | to do |
| T032 | Operations commands for the role | US2 | Phase 3 | [#1095](https://github.com/The-Band-Solution/theband/issues/1095) | to do |
| T034 | Prove the parity of the two authentications | US2 | Phase 3 | [#1096](https://github.com/The-Band-Solution/theband/issues/1096) | to do |
| T035 | Keep the operator session in its own cookie | US2 | Phase 3 | [#1097](https://github.com/The-Band-Solution/theband/issues/1097) | to do |
| T036 | Mount the operator area in the router | US2 | Phase 3 | [#1098](https://github.com/The-Band-Solution/theband/issues/1098) | to do |
| T037 | Prove that the operator's 404 is the same as any path's | US2 | Phase 3 | [#1099](https://github.com/The-Band-Solution/theband/issues/1099) | to do |
| T038 | Prove the headers of the operator area | US2 | Phase 3 | [#1100](https://github.com/The-Band-Solution/theband/issues/1100) | to do |
| T038a | Read the organizations for the operator area, on the `Tenants` side | US2 | Phase 3 | [#1101](https://github.com/The-Band-Solution/theband/issues/1101) | to do |
| T039 | Sign-in, setup and enrollment screens | US2 | Phase 3 | [#1102](https://github.com/The-Band-Solution/theband/issues/1102) | to do |
| T040 | Organization list screen | US2 | Phase 3 | [#1103](https://github.com/The-Band-Solution/theband/issues/1103) | to do |
| T041 | Prove that the operator does not read domain data | US2 | Phase 3 | [#1104](https://github.com/The-Band-Solution/theband/issues/1104) | to do |
| T042 | Prove that the operator cookie does not open the domain | US2 | Phase 3 | [#1105](https://github.com/The-Band-Solution/theband/issues/1105) | to do |
| T043 | [redigido] | US2 | Phase 3 | [#1106](https://github.com/The-Band-Solution/theband/issues/1106) | to do |
| T044 | Create the suspension episode | US1 | Phase 4 | [#1107](https://github.com/The-Band-Solution/theband/issues/1107) | to do |
| T044a | The database refuses a state without an episode — deferred constraint trigger (D1-a) | US1 | Phase 4 | [#1108](https://github.com/The-Band-Solution/theband/issues/1108) | to do |
| T045 | Prove that the episode is a single one and is not rewritten | US1 | Phase 4 | [#1109](https://github.com/The-Band-Solution/theband/issues/1109) | to do |
| T046 | End the sessions of an organization | US1 | Phase 4 | [#1110](https://github.com/The-Band-Solution/theband/issues/1110) | to do |
| T046a | Change the organization state inside a `Multi`, on the `Tenants` side | US1 | Phase 4 | [#1111](https://github.com/The-Band-Solution/theband/issues/1111) | to do |
| T047 | Revoke the tokens of a suspended organization | US1 | Phase 4 | [#1112](https://github.com/The-Band-Solution/theband/issues/1112) | to do |
| T048 | Read the suspension reasons from the knowledge base | US1 | Phase 4 | [#1113](https://github.com/The-Band-Solution/theband/issues/1113) | to do |
| T049 | Suspend an organization in one transaction | US1 | Phase 4 | [#1114](https://github.com/The-Band-Solution/theband/issues/1114) | to do |
| T050 | Reactivate an organization without giving anything back | US1 | Phase 4 | [#1115](https://github.com/The-Band-Solution/theband/issues/1115) | to do |
| T056 | History and act screen | US1 | Phase 4 | [#1116](https://github.com/The-Band-Solution/theband/issues/1116) | to do |
| T051 | Prove that suspending brings down sessions and tokens | US1 | Phase 4 | [#1117](https://github.com/The-Band-Solution/theband/issues/1117) | to do |
| T052 | Prove the race between signing in and suspending | US1 | Phase 4 | [#1118](https://github.com/The-Band-Solution/theband/issues/1118) | to do |
| T053 | Prove that the open tab falls too | US1 | Phase 4 | [#1119](https://github.com/The-Band-Solution/theband/issues/1119) | to do |
| T054 | Prove revocation with the form open | US1 | Phase 4 | [#1120](https://github.com/The-Band-Solution/theband/issues/1120) | to do |
| T055 | Record the platform acts in the log | US1 | Phase 4 | [#1121](https://github.com/The-Band-Solution/theband/issues/1121) | to do |
| T057 | Measure the time of the act and the batch refusal | US1 | Phase 4 | [#1122](https://github.com/The-Band-Solution/theband/issues/1122) | to do |
| T058 | Delete the operator's expired sessions | epic | Phase 5 | [#1123](https://github.com/The-Band-Solution/theband/issues/1123) | to do |
| T059 | Write the operator's operations runbook | epic | Phase 5 | [#1124](https://github.com/The-Band-Solution/theband/issues/1124) | to do |
| T060 | Check the screen against the prototype | epic | Phase 5 | [#1125](https://github.com/The-Band-Solution/theband/issues/1125) | to do |
| T061 | Run the validation script and the gates | epic | Phase 5 | [#1126](https://github.com/The-Band-Solution/theband/issues/1126) | to do |
| T062 | Write the release risk note | epic | Phase 5 | [#1127](https://github.com/The-Band-Solution/theband/issues/1127) | to do |
| T063 | Derive the feature's models | epic | Phase 5 | [#1128](https://github.com/The-Band-Solution/theband/issues/1128) | to do |
| T064 | Open the PR from the template | epic | Phase 5 | [#1129](https://github.com/The-Band-Solution/theband/issues/1129) | to do |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

Nothing from `tasks.md` was left out. Left out **of the feature** is what the spec already declares: managing
`admin` inside the organization (#568, spec 071), creating, deleting or renaming an organization, and any
reading of domain data by the operator.

## Risks and dependencies {#riscos-e-dependências}

- **T004 depends on the maintainer**: [redigido]. Without the measurement, [redigido] (T043) does not go in, and A4 goes to the release note.
- **Declared residual risks**, which go to T062:
  - A8: [redigido];
  - A17;
  - T9–T11: [redigido];
  - G1: [redigido];
  - G2: [redigido].
- **New dependency**: `nimble_totp == 1.0.0`, audited (`hex.audit` and `deps.audit` with exit code 0).
- **Unstable network with GitHub on 2026-10-02**: the issue scripts are idempotent and retry.

## Sprint Definition of Done {#definition-of-done-do-sprint}

Beyond the per-task DoD:

- [ ] quality gates green (`mix gates`, exit code 0)
- [ ] knowledge base valid (`platform.tenant_suspension`)
- [ ] each security guard seen failing with the injected defect, with the evidence pasted in the issue
- [ ] the implemented screen is the one from the approved prototype, checked item by item against `prototipo/PROMPT.md` §3
- [ ] issues closed, or reprioritized with justification; the US only with acceptance
- [ ] `sprint-review.md` written
- [ ] `licoes-aprendidas.md` updated
