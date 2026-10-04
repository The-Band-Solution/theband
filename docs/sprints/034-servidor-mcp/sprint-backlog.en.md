# Sprint 034 — the MCP server {#sprint-034--o-servidor-mcp}

**Period**: 2026-09-24 to 2026-10-07 (proposed)
**Feature**: [062 — the MCP server](../../../specs/062-servidor-mcp/spec.md)
**Plan**: [plan.md](../../../specs/062-servidor-mcp/plan.md) · **Tasks**: [tasks.md](../../../specs/062-servidor-mcp/tasks.md) · **Security**: [self-assessment](../../../specs/062-servidor-mcp/seguranca.md), [independent review](../../../specs/062-servidor-mcp/seguranca-revisao-independente.md), [R3](../../../specs/062-servidor-mcp/r3-cowlib-alcance.md)

## Sprint goal {#objetivo-do-sprint}

An agent connected over MCP asks about a team and receives the answer **with the caveat in the
same object**. A refusal comes out as a response, and every granted read is recorded, with the
tool and the team.

## What came before, and why this sprint starts now {#o-que-veio-antes-e-por-que-este-sprint-começa-agora}

On 2026-09-24, the maintainer asked *"make sure everything is secure before doing the
MCP"* *(original: "garanta que tudo está seguro antes de fazer o MCP")*. Before opening this sprint:

| PR | What |
|---|---|
| [#944](https://github.com/The-Band-Solution/theband/pull/944) | the plan reconciled with the code, the security inventory, the independent review (T009) and the rewritten tasks |
| [#945](https://github.com/The-Band-Solution/theband/pull/945) | N5: the token of a suspended organization was no longer refused. **It was in production** |
| [#946](https://github.com/The-Band-Solution/theband/pull/946) | H2-R: the profile written by the model was outside the verdict. **It was in production** |

Also before: the production token exposed to the TLS proxy was revoked, and read nothing after
the measurements.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), the ones that apply to this sprint:

| Lesson | How it is being applied |
|---|---|
| **L79** — an agent with a shared tree does not switch branches | recurred on 2026-09-24, while preparing this sprint. Work on another branch, with a background agent active, goes to a `git worktree` |
| **L21** — a public function with no consumer is not functionality | each tool only counts as done with the real MCP client calling it (T030) |
| **L77** — a new checker is born with a test that does not pass through it | every new guard (T008, T016, the three from R3 in T001) is proven with an injected defect |
| **L81** — closing the counterexample does not close the class | R6 is treated as a class: the single path of T006, and not a per-tool check |
| **L91 / L96 / L99** — the step without a gate disappears; check issue by issue | the 26 issues are closed one by one, with the evidence in the issue (constitution, principle VII) |
| **L95** — requesting a reviewer is not getting a review | the review gap is declared in each PR, and never marked as fulfilled |
| **L108** — feature without a sprint backlog | this document exists before the first line of code |

**A new lesson, to be recorded when this sprint closes**: in zsh, an unquoted `$VAR` is not split
into words. A list of files passed that way to `mix test` becomes **one** path, which `mix`
ignores without warning when there are other valid paths. A "149 passed" was reported without 17
files running. Use `${=VAR}`, or `"$@"` after `set --`.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2). The 30 issues
are in the project.

**Iteration: not assigned, and that is a declared limitation.** The field has a single active iteration,
*Sprint 026 — Herança e a produção*, from 2026-09-19, 7 days long. The project's numbering (026)
already diverged from this directory's (034). And creating an iteration through the API **recreates the existing ones**
(L11, L72), which would take the iteration away from the items already assigned. The way out is to create the iteration
*Sprint 034* through the GitHub interface, which adds without recreating, and only then assign.

**Types**: the organization only has `Task`, `Bug` and `Feature`. Epic and user story follow the house
pattern, **by label** (`epic`, `us`) and by sub-issue hierarchy. Creating the `Epic` and
`User Story` types changes the organization's configuration, and is left as a separate decision.

## Epic and user stories {#épico-e-user-stories}

| # | User story | Label | Epic | Issue | Priority | Estimate | Tasks |
|---|---|---|---|---|---|---|---|
| — | 062: the MCP server | epic | — | [#947](https://github.com/The-Band-Solution/theband/issues/947) | P1 | — | 14 direct, and the 3 US |
| US1 | The agent answers about the team without losing the caveat | us | [#947](https://github.com/The-Band-Solution/theband/issues/947) | [#948](https://github.com/The-Band-Solution/theband/issues/948) | P1 | — | 6 |
| US2 | The refusal is a response, and agrees with the other doors | us | [#947](https://github.com/The-Band-Solution/theband/issues/947) | [#949](https://github.com/The-Band-Solution/theband/issues/949) | P1 | — | 3 |
| US3 | The read is recorded, and abuse is detectable | us | [#947](https://github.com/The-Band-Solution/theband/issues/947) | [#950](https://github.com/The-Band-Solution/theband/issues/950) | P1 | — | 3 |

`Priority` P1 comes from `tasks.md`, where the three user stories are P1. **`Estimate` is
blank, and that means unknown, not zero.** The complexity was not estimated, and
inventing a number would measure as if the estimate had been made.

## Tasks {#tarefas}

| # | Task | Serves | Type | Issue | Estimate | State |
|---|---|---|---|---|---|---|
| T001 | Pin the protocol dependency | epic | Task | [#951](https://github.com/The-Band-Solution/theband/issues/951) | — | done |
| T002 | Create the skeleton of the MCP context | epic | Task | [#952](https://github.com/The-Band-Solution/theband/issues/952) | — | done |
| T003 | Expose the measure from the knowledge base | epic | Task | [#953](https://github.com/The-Band-Solution/theband/issues/953) | — | done |
| T004 | Build the provenance envelope | epic | Task | [#954](https://github.com/The-Band-Solution/theband/issues/954) | — | done |
| T005 | Name the three states of absence | epic | Task | [#955](https://github.com/The-Band-Solution/theband/issues/955) | — | done |
| T006 | Open the tool registry — and make it the single path | epic | Task · security | [#956](https://github.com/The-Band-Solution/theband/issues/956) | — | done |
| T016 | Close the list of protocol methods, ahead of the library | epic | Task · security | [#957](https://github.com/The-Band-Solution/theband/issues/957) | — | done |
| T007 | Serve MCP authenticated | epic | Task · security | [#958](https://github.com/The-Band-Solution/theband/issues/958) | — | done |
| T008 | Guard the database boundary | epic | Task | [#959](https://github.com/The-Band-Solution/theband/issues/959) | — | done |
| T010 | Answer who is on the team | US1 | Task | [#960](https://github.com/The-Band-Solution/theband/issues/960) | — | done |
| T011 | Answer what each person has open | US1 | Task | [#961](https://github.com/The-Band-Solution/theband/issues/961) | — | done |
| T012 | Answer the wait for review | US1 | Task | [#962](https://github.com/The-Band-Solution/theband/issues/962) | — | done |
| T013 | Answer what is stopped | US1 | Task | [#963](https://github.com/The-Band-Solution/theband/issues/963) | — | done |
| T014 | Mark third-party text in the schema | US1 | Task · security | [#964](https://github.com/The-Band-Solution/theband/issues/964) | — | done |
| T015 | Declare what each tool does not answer | US1 | Task | [#965](https://github.com/The-Band-Solution/theband/issues/965) | — | done |
| T017 | Refuse as a response, never as an error | US2 | Task | [#966](https://github.com/The-Band-Solution/theband/issues/966) | — | done |
| T018 | Prove the parity of the three doors | US2 | Task | [#967](https://github.com/The-Band-Solution/theband/issues/967) | — | done |
| T019 | Refuse a revoked token on the next call | US2 | Task | [#968](https://github.com/The-Band-Solution/theband/issues/968) | — | done |
| T021 | Record the read at the point of the verdict | US3 | Task · security | [#969](https://github.com/The-Band-Solution/theband/issues/969) | — | done |
| T022 | A team refusal is recorded, and does not become a read — in MCP and in the API | US3 | Task · security | [#970](https://github.com/The-Band-Solution/theband/issues/970) | — | done |
| T024 | Prove that the limit is a single one per token | US3 | Task · security | [#971](https://github.com/The-Band-Solution/theband/issues/971) | — | done |
| T027 | Sweep the whole object for secrets | epic | Task · security | [#972](https://github.com/The-Band-Solution/theband/issues/972) | — | done |
| T028 | Measure the cost against the HTTP route | epic | Task | [#973](https://github.com/The-Band-Solution/theband/issues/973) | — | done |
| T029 | Write what the client needs to know | epic | Task | [#974](https://github.com/The-Band-Solution/theband/issues/974) | — | done |
| T030 | Prove end to end with a client | epic | Task | [#975](https://github.com/The-Band-Solution/theband/issues/975) | — | done |
| T031 | Close the gates | epic | Task | [#976](https://github.com/The-Band-Solution/theband/issues/976) | — | done |

T009 (the independent review) is **done**, and has no issue: it was delivered in #944. Tasks
**T023 and T025 were removed** on 2026-09-24, and their numbers stay reserved.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

Everything that `tasks.md` declares under *Fora desta fatia* (out of this slice):
- the other 73 competency questions;
- OAuth;
- writing over MCP;
- cache;
- the server as a separate process;
- the legacy era of the protocol;
- [redigido] (R9).

## Risks and dependencies {#riscos-e-dependências}

- **`ex_mcp` 1.5.0 is young, and a new version comes out every week.** The version stays pinned, and the thin
  layer is what makes swapping it an adapter job.
- **The `cowlib` exception in the gate** holds only while the adapter is Bandit. The three guards
  of T001 are what make it safe.
- **T021 and T022 touch 061 code in production** (`ApiReadLog`, `TeamController`).
  `api_read_log_test.exs` has to stay green without changes.
- **No real MCP client was checked against the 2026-07-28 revision of the protocol.** The
  `:modern_only` depends on that, and T030 is where it is found out.
- **The whole suite does not run with the dev server up.** The gates run with it stopped, or in
  CI.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] `mix gates` exits with 0, read from the exit code
- [ ] knowledge base valid
- [ ] the 26 issues closed with evidence, or reprioritized with justification
- [ ] the real MCP client calling the four tools (T030)
- [ ] `sprint-review.md` written
- [ ] `licoes-aprendidas.md` updated, with the zsh lesson
