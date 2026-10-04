# Sprint Backlog 001 — Foundation and EO collection {#sprint-backlog-001--fundação-e-coleta-eo}

**GitHub iteration**: Sprint 001 — Fundação e coleta EO · 2026-08-03 to 2026-08-09 · 7 days
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)
**Feature**: [001-github-eo-ingestion](../../../specs/001-github-eo-ingestion/spec.md)
**Epic**: [#1](https://github.com/The-Band-Solution/theband/issues/1)
**Opened on**: 2026-08-09

## Goal {#objetivo}

Deliver the first vertical slice of The Band: an organization declares that it uses
GitHub, provides instance and credential, triggers a sync and **sees on screen**
the people and teams the platform has come to know — each record with
source, identifier in the tool and collection date.

The bootstrap of the Phoenix project is part of this slice. Separating it would produce a
delivery with nothing visible, which principle VI of the constitution forbids.

## Lessons considered {#lições-consideradas}

From the [accumulated record](../licoes-aprendidas.md): **this is the first sprint**, and
the lessons file did not exist when it was opened. Lessons L01 to L07 were written
during and at the end of it, and become a constraint for sprint 002.

Two constraints came from standing instructions predating the sprint, and were
applied from planning onward:

- **vertical slice** — every delivery shows screen and backend in the same change
  proposal; never infrastructure without a visible consumer;
- **proportional ceremony** — one checklist, not three, and requirements only for what the
  feature delivers.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Type | Epic | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|---|
| US1 | Connect a tool with a protected credential | Feature | [#1](https://github.com/The-Band-Solution/theband/issues/1) | [#3](https://github.com/The-Band-Solution/theband/issues/3) | P0 | — | 5 scenarios |
| US2 | Know an organization's people and teams | Feature | [#1](https://github.com/The-Band-Solution/theband/issues/1) | [#4](https://github.com/The-Band-Solution/theband/issues/4) | P1 | — | 6 scenarios |
| US3 | Trace where each piece of information came from | Feature | [#1](https://github.com/The-Band-Solution/theband/issues/1) | [#5](https://github.com/The-Band-Solution/theband/issues/5) | P2 | — | 3 scenarios |

`Priority` is SRO's *importance* — value to the organization. `Estimate` is
*complexity* — difficulty for the team. A blank field means unknown,
not zero.

### Two field divergences, recorded instead of hidden {#duas-divergências-de-campo-registradas-em-vez-de-escondidas}

**Priority scale.** The spec uses P1/P2/P3; the GitHub project offers
P0/P1/P2. The mapping preserves the **order**, not the label: US1→P0, US2→P1,
US3→P2. Read "P0" here as "the most important of the three", never as a
criticality the spec did not declare.

**`Estimate` blank, on purpose.** No complexity estimate was
made with the team. Filling the field with an invented number would produce a flow
metric resting on fiction, and the absence is the honest record that the decision was not
made — absence is null, never zero.

## Tasks {#tarefas}

73 tasks, issues [#6](https://github.com/The-Band-Solution/theband/issues/6) to
[#78](https://github.com/The-Band-Solution/theband/issues/78), derived from
[tasks.md](../../../specs/001-github-eo-ingestion/tasks.md). Numbering: `Tnnn` →
issue `#(nnn + 5)`.

| Phase | Tasks | Issues | Serves |
|---|---|---|---|
| 1 — Setup | T001–T008 | #6–#13 | foundation (epic) |
| 2 — Foundational | T009–T031 | #14–#36 | foundation (epic) |
| 3 — US1 | T032–T040 | #37–#45 | US1 |
| 4 — US2 | T041–T060 | #46–#65 | US2 |
| 5 — US3 | T061–T068 | #66–#73 | US3 |
| 6 — Polish | T069–T073 | #74–#78 | foundation (epic) |

A task does not get a `Priority`: it inherits that of the user story it serves.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started)

## Materialization on GitHub {#materialização-no-github}

| SRO concept | GitHub | State |
|---|---|---|
| `sro.sprint` | ProjectV2 iteration `2849580c`, in `completedIterations` | 7 days, 2026-08-03 to 2026-08-09 |
| `sro.epic` | issue [#1](https://github.com/The-Band-Solution/theband/issues/1), type `Feature`, 3 user story sub-issues | created |
| `sro.atomic_user_story` | issues #3, #4, #5, type `Feature` | created and linked to the epic |
| `sro.intended_scrum_development_task` | issues #6–#78, type `Task` | created and linked to the user stories |
| `sro.sprint_backlog` | 77 project items in the iteration | assigned |

**Recorded limitation — issue types.** The organization has only `Task`, `Bug`
and `Feature`. `Epic` and `User Story` do not exist, and creating them changes the
organization's configuration, which requires a human confirmation that was not requested. The rule
`github.issue_type_routing` accepts `Feature` as a route to
`sro.atomic_user_story`, and its precedence is **structure over label** — an
issue of type `Feature` whose sub-issues are user stories is promoted to `sro.epic`.
That is why the epic works without the dedicated type, and the divergence is recorded in
provenance when the repository itself is ingested.

**Occurrence corrected.** Issue #2 is an orphan duplicate of US1, created by a
run of the materialization script that failed parsing the response **after**
the issue already existed. Closed as `not planned`, with the reason recorded in
the closing itself. The valid US1 is #3.

## Definition of Done for this sprint {#definition-of-done-deste-sprint}

From the constitution, principle VII and the Development flow section:

- [ ] acceptance criteria evaluated one by one, with evidence
- [ ] issues updated
- [ ] YAMLs validated
- [ ] tests passing
- [ ] Credo and Dialyzer approved
- [ ] migrations tested
- [ ] semantic mapping reviewed
- [ ] documentation updated
- [ ] **PR approved by another person or another agent**
- [ ] green pipeline
- [ ] merge done and issues closed

The outcome of each item is in [sprint-review.md](sprint-review.md), separating
what was delivered from what was not.
