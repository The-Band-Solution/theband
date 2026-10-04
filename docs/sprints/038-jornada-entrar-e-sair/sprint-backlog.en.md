# Sprint 038 — the sign-in and sign-out journey, as seen by whoever operates {#sprint-038--a-jornada-de-entrar-e-sair-vista-por-quem-opera}

**Period**: opened on 2026-10-03, in the *Sprint 035* iteration on GitHub (`ee36a246`)
**Feature**: [074](../../../specs/074-jornada-entrar-e-sair/spec.md) · **Plan**: [plan.md](../../../specs/074-jornada-entrar-e-sair/plan.md) · **Security**: [seguranca.md](../../../specs/074-jornada-entrar-e-sair/seguranca.md)
**Epic**: [#802](https://github.com/The-Band-Solution/theband/issues/802) · **ADR**: [0005](../../adr/0005-telemetria-da-jornada.md), accepted on 2026-10-03
**Documents branch**: `feature/802-tracing-signoz`

*The number 038 is the next free one also looking at the open branches: `development` goes up to 037
(administrator role), and `feature/1182-rede-de-revisao` has another 037 (review network), which
will need renumbering when it comes in.*

## Sprint goal {#objetivo-do-sprint}

Whoever operates the platform gets to know, in SigNoz, **who could not sign in and why**, when
signing out failed, and when setting or changing the password failed — without any secret leaving the process.

## The code waits — read before starting {#o-código-espera--leia-antes-de-começar}

**The code waits for #1227 to be merged; #887 has its tasks delivered and is waiting for acceptance.**

| prerequisite | state on 2026-10-03 | blocks |
|---|---|---|
| PR [#1227](https://github.com/The-Band-Solution/theband/issues/1227) ([#1222](https://github.com/The-Band-Solution/theband/issues/1222), the query log redacted) | merged on 2026-10-03 (T003) | **every task that touches `lib/` or `mix.exs`** (T003 onwards, except T006 and T007) — decision D6, §14.0 item 2 |
| [#887](https://github.com/The-Band-Solution/theband/issues/887) (064/US3) | open only waiting for acceptance; the tasks [#871](https://github.com/The-Band-Solution/theband/issues/871), [#872](https://github.com/The-Band-Solution/theband/issues/872) and [#873](https://github.com/The-Band-Solution/theband/issues/873) are **closed** | **does not block** |
| [#1162](https://github.com/The-Band-Solution/theband/issues/1162) (Erlang distribution, [redigido]) | open | the SigNoz deployment on the same VPS (T026) |
| the six S6 items of the evaluation | not verified | the SigNoz deployment (T026) |

T006 (local SigNoz in a profile) and T007 (the taxonomy in YAML) do **not** touch `lib/` or `mix.exs`
and can start before #1227.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), read on 2026-10-03:

| lesson | how it is being applied |
|---|---|
| L108 — feature without a sprint backlog | this document exists before the code; the issues were created with type, hierarchy and iteration in the same step |
| L100 — documentation branch without a PR | the spec, the plan and the tasks are on `feature/802-tracing-signoz`, **without a PR**. Before the first code branch: `git log origin/development..origin/feature/802-tracing-signoz` empty, or the documents PR opened first |
| L69 — a defect inside `Logger.info` is invisible to tests | the step is a **relator**: the test asserts on the span that reaches the exporter, and on the return of `Auth`, never on the log |
| L42 — a late telemetry message enters the next count | the span tests empty the mailbox before attaching the test exporter, and the count has to repeat across runs |
| L50 — the test that compares must prove it measured | the sentinels test (T018) asserts that spans from the four steps arrived **before** any `refute` |
| L77 — a new checker is born with a test that does not pass through it | the test swaps only the destination, and not the filter (S15); the support function refuses to attach without the filter (T008) |
| L56 — filtering telemetry by `source` does not reach raw SQL | it is the reason for FR-012: the #1227 rule is necessary and not sufficient for a query span; in this slice there is none |
| L38 and L53 — cost is measured by the difference, and the ceiling comes from measuring both sides | SC-006 (T030) compares with and without telemetry in the same scenario; the T015 threshold is a difference of medians |
| L21 — a function with no consumer is not delivered functionality | US5 (versioned dashboard) is the visible consumer; without it the spans are infrastructure on their own |
| L84 and L93 — the board saying `Done` is not the application live | production acceptance is T027: the sign-in itself showing up in SigNoz, through the tunnel |

## User stories {#user-stories}

| # | user story | issue | Priority | Estimate |
|---|---|---|---|---|
| US1 | I know who could not sign in, and why | [#1230](https://github.com/The-Band-Solution/theband/issues/1230) | P1 | — |
| US2 | I know when signing out failed | [#1231](https://github.com/The-Band-Solution/theband/issues/1231) | P1 | — |
| US3 | None of this leaks | [#1232](https://github.com/The-Band-Solution/theband/issues/1232) | P1 | — |
| US4 | I know when setting or changing the password failed | [#1233](https://github.com/The-Band-Solution/theband/issues/1233) | P2 | — |
| US5 | Whoever operates finds the answers without building a query | [#1234](https://github.com/The-Band-Solution/theband/issues/1234) | P2 | — |

`Priority` is the spec's; it was not written to the project field at this opening. A blank `Estimate` is
**unknown**, not zero: nobody has estimated yet.

## Tasks {#tarefas}

| # | task | serves | type | issue | state |
|---|---|---|---|---|---|
| T001 | 👤 Accept or reject ADR 0005 | — | Task | [#1235](https://github.com/The-Band-Solution/theband/issues/1235) | done — decision of 2026-10-03 |
| T002 | 👤 Decide D1 to D7 of the security evaluation | — | Task | [#1236](https://github.com/The-Band-Solution/theband/issues/1236) | done — decision of 2026-10-03 |
| T003 | Check that the security prerequisites have arrived | — | Task | [#1237](https://github.com/The-Band-Solution/theband/issues/1237) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T004 | Pin the OpenTelemetry dependencies | — | Task | [#1238](https://github.com/The-Band-Solution/theband/issues/1238) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T005 | Configure the SDK explicitly, and off by default | — | Task | [#1239](https://github.com/The-Band-Solution/theband/issues/1239) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T006 | Bring up local SigNoz in its own profile | — | Task | [#1240](https://github.com/The-Band-Solution/theband/issues/1240) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T007 | Declare the journey taxonomy | — | Task | [#1241](https://github.com/The-Band-Solution/theband/issues/1241) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T008 | Test support for reading spans | — | Task | [#1242](https://github.com/The-Band-Solution/theband/issues/1242) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T009 | The exporter that only lets out what is allowed | — | Task | [#1243](https://github.com/The-Band-Solution/theband/issues/1243) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T010 | The handler that translates without vanishing | — | Task | [#1244](https://github.com/The-Band-Solution/theband/issues/1244) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T011 | The single function that emits the step | — | Task | [#1245](https://github.com/The-Band-Solution/theband/issues/1245) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T012 | Sign-in emits the step after the transaction | US1 | Task | [#1246](https://github.com/The-Band-Solution/theband/issues/1246) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T013 | The correlator is born on the server and dies with the attempt | US1 | Task | [#1247](https://github.com/The-Band-Solution/theband/issues/1247) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T014 | Opening the sign-in counts once | US1 | Task | [#1248](https://github.com/The-Band-Solution/theband/issues/1248) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T015 | Time and session do not distinguish the reasons | US1 | Task | [#1249](https://github.com/The-Band-Solution/theband/issues/1249) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T016 | Signing out says whether it ended anything | US2 | Task | [#1250](https://github.com/The-Band-Solution/theband/issues/1250) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T017 | A session drop says the reason | US2 | Task | [#1251](https://github.com/The-Band-Solution/theband/issues/1251) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T018 | The sentinels do not leave, in any of the four steps | US3 | Task | [#1252](https://github.com/The-Band-Solution/theband/issues/1252) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T019 | The taxonomy gate | US3 | Task | [#1253](https://github.com/The-Band-Solution/theband/issues/1253) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T020 | Without a backend, signing in and out stay the same | US3 | Task | [#1254](https://github.com/The-Band-Solution/theband/issues/1254) | done — 2026-10-03, branch `feature/1230-jornada-entrar-e-sair`; evidence in `tasks.md` |
| T021 | Setting and changing the password emit the outcome | US4 | Task | [#1255](https://github.com/The-Band-Solution/theband/issues/1255) | to do — the block (T003) fell on 2026-10-03 |
| T022 | The dashboard of the three questions | US5 | Task | [#1256](https://github.com/The-Band-Solution/theband/issues/1256) | to do — the block (T003) fell on 2026-10-03 |
| T023 | The account enumeration alert | US5 | Task | [#1257](https://github.com/The-Band-Solution/theband/issues/1257) | to do — the block (T003) fell on 2026-10-03 |
| T024 | 👤 Measure the VPS before bringing it up | — | Task | [#1258](https://github.com/The-Band-Solution/theband/issues/1258) | to do 👤 |
| T025 | 👤 Fix the Erlang distribution [redigido] | — | Task | [#1259](https://github.com/The-Band-Solution/theband/issues/1259) | to do 👤 |
| T026 | 👤 Bring up SigNoz on Dokploy, closed | — | Task | [#1260](https://github.com/The-Band-Solution/theband/issues/1260) | to do 👤 |
| T027 | 👤 Connect the application to the collector | — | Task | [#1261](https://github.com/The-Band-Solution/theband/issues/1261) | to do 👤 |
| T028 | 👤 Measure afterwards, and check the output and the retention | — | Task | [#1262](https://github.com/The-Band-Solution/theband/issues/1262) | to do 👤 |
| T029 | Update the runbook | — | Task | [#1263](https://github.com/The-Band-Solution/theband/issues/1263) | to do — the block (T003) fell on 2026-10-03 |
| T030 | Measure the cost of telemetry at sign-in | — | Task | [#1264](https://github.com/The-Band-Solution/theband/issues/1264) | to do — the block (T003) fell on 2026-10-03 |
| T031 | Run the gates and open the PR | — | Task | [#1265](https://github.com/The-Band-Solution/theband/issues/1265) | to do — the block (T003) fell on 2026-10-03 |

Phase tasks (with no US) are children of the epic [#802](https://github.com/The-Band-Solution/theband/issues/802); US tasks are children of the US. A task does not
get a `Priority`.

## Scope — **to be confirmed by the maintainer** {#escopo--a-confirmar-pela-pessoa-mantenedora}

The 31 tasks are in the iteration, because the opening was requested for the whole of 074. The proposal,
following the `tasks.md` strategy:

- **in this sprint**: Phases 0 to 5 (T001–T020), the **MVP** — US1, US2 and US3 together, because US3 is the
  condition for US1 to go to production;
- **if it fits**: US4 (T021) and US5 (T022, T023), T029–T031;
- **out, if #1162 does not close**: T024–T028, the deployment. The code can go to `development`
  with telemetry **off** (FR-015), changing nothing for whoever signs in.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- the platform operator's sign-in (`/platform/sign-in`, with a second factor) — the next slice
  of #802, with its own evaluation;
- J2 to J6, the epic's US3 (noticing that Oban has stopped) and any automatic instrumenter;
- [redigido] — [#1229](https://github.com/The-Band-Solution/theband/issues/1229) (D7).

## Risks and dependencies {#riscos-e-dependências}

- **PR #1227** depends on review by the `the-band` team; until it merges, only T006 and T007
  move;
- **the SDK's batch processor** may not expose drops due to a full queue (research R13); T020
  decides, and the gap, if there is one, is declared;
- **Foundry** (`foundryctl forge`) is the supported SigNoz installation and was not tested in this
  session; the measurement used the v0.125.0 compose. T006 is the first to use it;
- **the VPS** was not measured; T024 may rule out hosting on the same VPS (D3).

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] quality gates green, with the exit code of `mix gates` read
- [ ] `mix knowledge.validate` and `taxonomia_test.exs` green
- [ ] each security guard seen **failing** with the injected defect, with the evidence in the issue
- [ ] issues closed or reprioritized with justification; US only close with acceptance
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `licoes-aprendidas.md` updated
