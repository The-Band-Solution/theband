# Sprint 009 — the person detail {#sprint-009--o-detalhe-da-pessoa}

**Period**: 2026-08-12 to 2026-08-18 (one-week cadence)
**Feature**: [010 — person detail](../../../specs/010-detalhe-da-pessoa/spec.md)
**Plan**: [plan.md](../../../specs/010-detalhe-da-pessoa/plan.md)
**Origin**: [#211](https://github.com/The-Band-Solution/theband/issues/211), requested during sprint 007
**Analysis**: run before the code, **six corrections**, the critical one being about a **boundary**

## Sprint goal {#objetivo-do-sprint}

At the end of this sprint, clicking on a person shows what the platform knows about them — **and what it refused
to assert**.

There are **88 pieces of evidence** of person-team membership and **zero** materialized team memberships. The screen exists to
show the three things: what the source declared, that the platform did not promote, and **why**.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md), 37 lessons. The ones that enter as a **constraint**:

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L08** | Sprint 002 | contract before the first public function — and it **refuses** three functions on purpose |
| **L11** | Sprint 002 | without touching the iterations configuration |
| **L18** | Sprint 003 | the acceptance assesses the 13 SC with evidence, never the green suite |
| **L21** | Sprint 004 | F1 and F2 are queries without a consumer; the page is in the same sprint |
| **L22**, **L23** | Sprint 004 | gate by exit code — and since #229 it **really counts** |
| **L25** | Sprint 004 | the route uses an **internal** identifier; the login belongs to the source, changes, and is not unique |
| **L27** | Sprint 005 | full cycle before the code — fifth feature in a row |
| **L28** | Sprint 005 | "the function returns" and "the screen shows" are different claims: the page tests go to the HTML |
| **L30** | Sprint 005 | the numbers come from the database: 75 people, 88 pieces of evidence, 4,232 assignments, 4,241 authorships |
| **L32** | Sprint 006 | the screen **does not assert** what it did not observe: the non-promotion is explained based on the data |
| **L34** | Sprint 007 | **two** options with distinct names — `assigned_to` and `authored_by` —, never one `person_id` |
| **L36** | Sprint 008 | when two measurements seem to contradict each other, the link is a hypothesis — and this feature's analysis isolated six before asserting |

**L34 comes in before it hurts.** It was born from "alive" meaning two things in feature 008; here the
dangerous phrase is *"the person's issues"*, which are **three** sets — assigned, opened, and the
union. The union is the one that corresponds to nothing, and FR-009 forbids it.

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration**: **does not exist for this sprint** — a declared limitation. Configuring
ProjectV2 iterations recreates the existing ones (L11), and it has already cost reassigning 96 items.

**Types**: the organization has `Task`, `Bug` and `Feature`. Epic and user stories are typed `Feature`.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Epic | Issue | Priority | Estimate | State |
|---|---|---|---|---|---|---|
| US1 | See what the platform knows about a person | [#233](https://github.com/The-Band-Solution/theband/issues/233) | [#234](https://github.com/The-Band-Solution/theband/issues/234) | P1 | 8 | to do |
| US2 | See the teams, and what the platform refused to promote | [#233](https://github.com/The-Band-Solution/theband/issues/233) | [#235](https://github.com/The-Band-Solution/theband/issues/235) | P1 | 8 | to do |
| US3 | See the work: issues and repositories | [#233](https://github.com/The-Band-Solution/theband/issues/233) | [#236](https://github.com/The-Band-Solution/theband/issues/236) | P1 | 8 | to do |

**All three are P1, and none is P0.** Unlike sprint 008: there the tool became unusable and the
way out was SQL. Here the platform works — what is missing is **seeing** what it already knows.

## Tasks {#tarefas}

Detailed in [010/tasks.md](../../../specs/010-detalhe-da-pessoa/tasks.md). Each task is a child of the
**user story it serves** — never of the epic.

| # | Task | Serves | Issue | Estimate | Phase | State |
|---|---|---|---|---|---|---|
| T001 | List the teams the source declares | US2 | [#237](https://github.com/The-Band-Solution/theband/issues/237) | 3 | F1 | to do |
| T002 | Count the registered roles | US2 | [#238](https://github.com/The-Band-Solution/theband/issues/238) | 2 | F1 | to do |
| T003 | Count assignments and authorships separately | US3 | [#239](https://github.com/The-Band-Solution/theband/issues/239) | 3 | F2 | to do |
| T004 | Filter issues by person, with two names | US3 | [#240](https://github.com/The-Band-Solution/theband/issues/240) | 3 | F2 | to do |
| T005 | Group the person's repositories | US3 | [#241](https://github.com/The-Band-Solution/theband/issues/241) | 3 | F2 | to do |
| T006 | Open the person's page | US1 | [#242](https://github.com/The-Band-Solution/theband/issues/242) | 5 | F3 | to do |
| T007 | Link the name to the page | US1 | [#243](https://github.com/The-Band-Solution/theband/issues/243) | 2 | F3 | to do |
| T008 | Say what the platform did not promote | US2 | [#244](https://github.com/The-Band-Solution/theband/issues/244) | 5 | F3 | to do |
| T009 | Show the work without summing | US3 | [#245](https://github.com/The-Band-Solution/theband/issues/245) | 5 | F3 | to do |

**Total: 31 of complexity, nine tasks.** It is the largest since sprint 005, and the reason is the screen: three
sections, each with a distinction that cannot be flattened.

## What the analysis changed, before the code {#o-que-a-análise-mudou-antes-do-código}

| # | Finding | Correction |
|---|---|---|
| **A1** | `repositories_of_person/2` returns an identifier and counts, and **nothing** gives the repository's name. The name belongs to **CMPO**, a **third** boundary the plan did not declare. The implementation would resolve it per row, violating FR-016 | CMPO in the plan and in T005/T009; the name comes from **one** query turned into a map |
| A2 | two `no_longer_observed_at` — issue and assignment — with no rule for the crossing | FR-008a: **the issue rules** |
| A3 | the plan said **four** queries; there are **eight**, and V8 measured "a number that does not grow" | eight, **asserted**, with the table of what each one is |
| A4 | the third case of the explanation was plausible and without content | verifiable: nobody allocated a role to this person in this team |
| A5 | the 288 issues without an author were a claim without verification | SC-009a and V10: the sum of authorships comes to 4,241 |
| A6 | the component was justified by three uses | there are **two**, and it is on the threshold — declared |

**A1 is not about logic, it is about record.** `repository_live/show.ex` already composes three boundaries,
so there was no violation — but a plan that asserts two authorizes the next person to cross one without
thinking.

## Confirmed scope {#escopo-confirmado}

**Feature 010 complete — F1 to F3, T001 to T009.**

The three phases are the MVP: F1 and F2 are queries without a consumer, and **L21** says that is not
delivered functionality.

**The possible cut is by user story**, in the spec's order. US1 alone already delivers the click that today does not
exist.

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| Out | Why |
|---|---|
| register a role, or allocate a person to a role | it is #99 and #100; this feature **displays** the absence |
| promote the evidence to a team membership | depends on the role existing |
| a module that assembles the page | it would dissolve the boundary between EO, WorkItems and CMPO — principle IX |
| a place for the 288 issues without an author | they have no person |
| contribution by commit, or PR review | it is not collected today |
| edit the person's data | it would create a second truth about what the source declares |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Mitigation |
|---|---|
| **displaying the sum of assignment and authorship** | FR-009; the test looks for the forbidden number — `refute html =~ ">19<"` |
| reading access level as a role | FR-004; the test does a `refute` on the word in the teams section |
| resolving the repository name per row | one query turned into a map; the test **counts** the queries and requires eight |
| the explanation of the non-promotion aging | the reason comes from the data, with the third case anticipated before it exists |
| an absent team membership disappearing from the screen | FR-006; the test marks the evidence and requires it to appear with the date |
| an absent issue counting because of the assignment | FR-008a; the test builds the crossing |

**No dependency on another branch.** `014-detalhe-da-pessoa` comes out of `main`, and there is no migration.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] `mix gates` green by **exit code** — ten gates
- [ ] V1 to V10 of the [quickstart](../../../specs/010-detalhe-da-pessoa/quickstart.md) verified
- [ ] **on the real data**: the page of one of the 75 people opens and shows the three sections, with the explanation
      of the non-promotion
- [ ] the authorships invariant checked: the sum comes to **4,241**
- [ ] the nine issues closed or reprioritized with justification
- [ ] PR with reviewer requested and **checked** via `requested_reviewers` (L14), linked to the project
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `licoes-aprendidas.md` updated
- [ ] `aceitacao.md` with the 13 SC assessed one by one
- [ ] **the screen looked at at 360 px** — and not only asserted in HTML, which is the debt that has crossed three
      sprints
