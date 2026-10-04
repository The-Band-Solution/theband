# Sprint 039 — the review network, the backend that does not wait {#sprint-039--a-rede-de-revisão-o-backend-que-não-espera}

**Period**: 2026-10-03 to 2026-10-09, in the current GitHub iteration (Sprint 035)
**Feature**: [073](../../../specs/073-rede-de-revisao/spec.md) · **Plan**: [plan.md](../../../specs/073-rede-de-revisao/plan.md) · **Tasks**: [tasks.md](../../../specs/073-rede-de-revisao/tasks.md)
**Epic**: [#1182](https://github.com/The-Band-Solution/theband/issues/1182)

## Sprint goal {#objetivo-do-sprint}

The computation and the scoping of the review network exist and are proven, with each attack scenario seen
failing, so that US1 is one approved knowledge base and one approved screen away from being delivered.

**This sprint delivers nothing visible**, and that is said here so it does not seem to deliver anything. US1 only closes
with the screen (T021); no PR is opened before that (memory *Vertical slice*).

**Updated on 2026-10-03**: the prototype was **approved** (v2, `prototipo/`), and the screen tasks no longer
wait for it. They wait for the facade (T017), which waits for the knowledge base parameters (T013 ← T004 ←
T003, the semantic review). The maintainer's decisions of the same day (sample of 10 reviews and
concentration absent below it; groups and exclusions by the scope; a deleted account as having no linked
person; minimum group of 3) are already in the spec, the contract, the tasks and `proposta-base/`.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), considered in this sprint:

| Lesson | How it is being applied |
|---|---|
| L19 — marking by tenant marks what belongs to another organization | the network is per **observed organization**, fetched by id and tenant together (T006); A3 has two organizations in the same tenant |
| L38 — screen cost by the difference and by the constancy | `read/5` with a query ceiling, measured with 5 and with 50 people (T016) |
| L50 — a test that compares must prove it measured | every isolation `refute` comes after an `assert` that the read has edges (A1, A2, A3) |
| L54 — atom created on demand | the window never becomes an atom; the closed list compares integers (A8) |
| L62 — summing counters by a hand-written list erases the new key | the invariant *pairs = network + three exclusions* is a test, and a wrong classification shows up as a difference (T014) |
| L67 — two measures with the same name | a single unit, the (reviewer, request) pair, for the total, the weight and the concentration (research.md R2) |
| L69 — a defect inside `Logger.info` is invisible to tests | the log proof (A16) really raises the Logger level; it is left for T019, which waits for the knowledge base |
| L102 — `git add -A` in a shared tree | two agents write in `proposta-base/` and `prototipo/`; every commit is `git commit -- <my paths>` |
| L108 — feature without a sprint backlog | this document exists before the code |
| L109 — task closed without code | only the issue whose evidence (command, exit code, injected defect) is in it gets closed |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 035 — O operador da plataforma (`ee36a246`) · 2026-10-03 · 7 days, in the
[The Band](https://github.com/orgs/The-Band-Solution/projects/2) project. The user stories and the tasks in
scope are in the iteration with a `Status`.

**Limitation**: the organization has no `User Story` type (only `Task`, `Bug`, `Feature`). The US carry the
`us` label, with no type, like those of specs 070–072. `Estimate` was not filled in: absence, not zero.

## User stories {#user-stories}

| # | User story | Issue | Priority | Criteria |
|---|---|---|---|---|
| US1 | See whether review is concentrated | [#1186](https://github.com/The-Band-Solution/theband/issues/1186) | P1 | 3 scenarios; SC-001, SC-002, SC-004, SC-005 |
| US2 | See who reviews whom | [#1187](https://github.com/The-Band-Solution/theband/issues/1187) | P2 | 3 scenarios |
| US3 | See the shape of the network | [#1188](https://github.com/The-Band-Solution/theband/issues/1188) | — (P3 does not exist in the field) | 2 scenarios |

None closes in this sprint: all depend on the screen.

## Tasks in scope {#tarefas-do-escopo}

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T001 | Integrate `development`, with #1181 | US1 | [#1189](https://github.com/The-Band-Solution/theband/issues/1189) | done |
| T005 | Create the table of the read in force | US1 | [#1193](https://github.com/The-Band-Solution/theband/issues/1193) | done |
| T006 | Give EO the three reads the network asks for | US1 | [#1194](https://github.com/The-Band-Solution/theband/issues/1194) | done |
| T007 | Filter the observed repositories by organization | US1 | [#1195](https://github.com/The-Band-Solution/theband/issues/1195) | done |
| T008 | Read the reviewer–request pairs, with the tenant on both ends | US1 | [#1196](https://github.com/The-Band-Solution/theband/issues/1196) | done |
| T009 | Read who opened a request in the window | US1 | [#1197](https://github.com/The-Band-Solution/theband/issues/1197) | done |
| T010 | Remove the reviewer ranking without reach | US1 | [#1198](https://github.com/The-Band-Solution/theband/issues/1198) | done |
| T011 | Classify each pair into a single destination | US1 | [#1199](https://github.com/The-Band-Solution/theband/issues/1199) | done |
| T012 | Compute edges, totals, groups and concentration in pure Elixir | US1 | [#1200](https://github.com/The-Band-Solution/theband/issues/1200) | done |
| T014 | Replace the organization's three reads in one transaction | US1 | [#1202](https://github.com/The-Band-Solution/theband/issues/1202) | done |
| T015 | Scope the concentration and the exclusions by reach | US1 | [#1203](https://github.com/The-Band-Solution/theband/issues/1203) | done |
| T016 | Read the network with the reach recomputed on every read | US1 | [#1204](https://github.com/The-Band-Solution/theband/issues/1204) | done |
| T018 | Check tenant and organization before computing, and cancel without writing | US1 | [#1206](https://github.com/The-Band-Solution/theband/issues/1206) | done |
| T023 | Build the per-person list, sorted by name | US2 | [#1211](https://github.com/The-Band-Solution/theband/issues/1211) | done |
| T025 | Count the groups, hiding the size of the small ones | US3 | [#1213](https://github.com/The-Band-Solution/theband/issues/1213) | done |
| T027 | Prove that the network does not leave through the API or through MCP | US1 | [#1215](https://github.com/The-Band-Solution/theband/issues/1215) | done |
| T028 | Open the issue for the scope notice [redigido] | US1 | [#1216](https://github.com/The-Band-Solution/theband/issues/1216) | done |
| T030 | Count a deleted account as having no linked person, and not as a bot, in the collection | US1 | [#1219](https://github.com/The-Band-Solution/theband/issues/1219) | done |

A task does not get a `Priority`: it inherits the user story's.

## Addition of 2026-10-03, after the semantic review and the approved prototype {#acréscimo-de-2026-10-03-depois-da-revisão-semântica-e-do-protótipo-aprovado}

With the knowledge base accepted (T003, T004) and the prototype approved, the sprint scope became the whole
feature up to the PR. These came in and were done: T003, T004, T013, T017, T019, T020, T021, T024, T026 and
T029. Still open are T002 and T022, the maintainer's, and the US #1186–#1188, which only close with
acceptance.

## Out of scope for this sprint (the list from before the addition) {#fora-do-escopo-deste-sprint-a-lista-de-antes-do-acréscimo}

| Task | Issue | Why |
|---|---|---|
| T002 measure production 👤 | [#1190](https://github.com/The-Band-Solution/theband/issues/1190) | access to production; before the US1 merge |
| T003 semantic review | [#1191](https://github.com/The-Band-Solution/theband/issues/1191) | it belongs to the ontology and semantic integration agent, and not to whoever wrote the proposal; the states that count are in free text in the proposal and need to become a readable list |
| T004 YAMLs in the knowledge base | [#1192](https://github.com/The-Band-Solution/theband/issues/1192) | waits for T003 |
| T013 knowledge base parameters | [#1201](https://github.com/The-Band-Solution/theband/issues/1201) | waits for T004; **no value written in the code so as not to wait** |
| T017 the facade with the parameters | [#1205](https://github.com/The-Band-Solution/theband/issues/1205) | waits for T013 |
| T019 the job's happy path, log and notice | [#1207](https://github.com/The-Band-Solution/theband/issues/1207) | waits for T017 |
| T020 the trigger in the synchronization | [#1208](https://github.com/The-Band-Solution/theband/issues/1208) | waits for T019: triggering earlier would enqueue a job that only raises |
| T021, T024, T026 the screens | [#1209](https://github.com/The-Band-Solution/theband/issues/1209), [#1212](https://github.com/The-Band-Solution/theband/issues/1212), [#1214](https://github.com/The-Band-Solution/theband/issues/1214) | the prototype was approved; they wait for T017, T019 and T020 |
| T022 acceptance 👤 | [#1210](https://github.com/The-Band-Solution/theband/issues/1210) | waits for the screen and the release |
| T029 gates, PR | [#1217](https://github.com/The-Band-Solution/theband/issues/1217) | closes the feature; the PR waits for T021 |

## Risks and dependencies {#riscos-e-dependências}

- **The knowledge base may change the key names**: the code receives the parameters as an argument
  (`contracts/review-network.md`, *Os parâmetros entram pela fachada*), and only `Parameters` changes;
- **the semantic review may change the unit** (R2): it changes `Graph.concentration/2` and its test, and
  not the table;
- **tree shared with two agents**: commits only of my paths.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] each task in scope with the evidence in the issue: command, exit code, injected defect and the
      exit code with it
- [ ] `mix gates` with `MIX_TEST_PARTITION=73`, exit code read without a pipe
- [ ] `sprint-review.md` separating done from not done
- [ ] `licoes-aprendidas.md` updated
