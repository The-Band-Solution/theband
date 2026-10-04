# Sprint 003 — Acceptance record {#sprint-003--registro-de-aceitação}

**Feature**: [003-editar-remover-ferramentas](../../../specs/003-editar-remover-ferramentas/spec.md)
**Evaluated on**: 2026-08-10
**Role**: Product Owner — Paulo Sergio Santos Junior
**Type**: `sro.product_owner_client` — the one who makes the demand is the one who decides, and the decision is final

Each criterion was walked through against evidence. The classification is derived from that,
never assigned — `sro.rule03`.

## Summary {#resumo}

| | Count |
|---|---:|
| Deliverables evaluated | 3 |
| Accepted | — to be confirmed by the role |
| Not accepted | — |
| Tasks performed successfully | — |
| Criteria evaluated | 21 |
| Criteria without evidence | **0** |

## What the evaluation found before classifying {#o-que-a-avaliação-encontrou-antes-de-classificar}

Walking through the criteria one by one, instead of checking whether the sprint "looked
done", found **three things that were missing** — and all three were done before this
record, not noted as pending:

| Finding | What was missing | Where the illusion was |
|---|---|---|
| **US2, AC4** | history did not appear on any screen | `observation_history/2` existed and passed the tests, with no consumer at all |
| **SC-007** | no test that the collection **unmarks** | there was a test that resuming does not unmark. Half of the promise verified, and the other half looking verified |
| **SC-010** | ending and resuming had no isolation test | people and teams had one; the observation cycle did not |

And before them, the finding that started the work: **resume had no button**.
It was specified, implemented and tested, and there was no way for a person
to execute it.

---

## D01 — The absence mark scoped by organization (L19) {#d01--a-marca-de-ausência-escopada-por-organização-l19}

**Produced by**: the sprint's F0 · a defect fix for feature 001
**Materializes**: no user story — it is a defect fix (`osdef.defect`),
evaluated against the behavior feature 002 already required.

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| Collecting one organization marks only its own team memberships | functional | **yes** | `sources_observation_test.exs` and `commands_test.exs`; removing the scope, **4 tests fail** |
| No team membership of another organization is touched | functional | **yes** | the test spells out the reason: `coletar alfa marcou o vínculo de beta — é a L19 de volta` |
| The shape of the test covers what the suite did not cover | non-functional | **yes** | two organizations and two collections in sequence — a shape absent from the 151 previous tests |

**Derived phase**: `sro.accepted_deliverable`.
**Phase of the task**: `sro.successfully_performed_scrum_development_task`.

**Recorded caveat, and it is not a criterion failure**: the historical data marked
wrongly **remains marked**. It was not unmarked, by decision — it is not known what
the source showed at that instant, and unmarking would assert an observation that did not
occur, which is the very error of L19. The repair happens on the next real collection
of each organization.

---

## D02 — End the observation (US1) {#d02--encerrar-a-observação-us1}

**Produced by**: F3 · T009 to T018
**Materializes**: US1 — End the observation of an organization (atomic, P1)

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — impact shown **before** confirming | functional | **yes** | screen at `localhost:4000/ferramentas`: 1 team, 5 team memberships, 4 people only from here, 1 remains, 0 payloads deleted |
| AC2 — the tool stops being synced | functional | **yes** | `origem encerrada não é coletada`: `{:error, :observation_ended}`, with the HTTP-edge Mox holding no expectation at all — any call to the source brings the test down |
| AC3 — records remain queryable, marked, with date | functional | **yes** | `a equipe da organização encerrada é marcada, não apagada` |
| AC4 — the credential no longer exists | functional | **yes** | `nenhuma linha remanescente, e nenhum texto cifrado` — a direct query on the table, not an assertion in the code |
| AC5 — whoever was in two keeps the other | functional | **yes** | `quem tem vínculo em outra organização NÃO é marcado`; `as organizações vigentes da pessoa passam de três para duas` |
| AC6 — the derived team is marked, not deleted | functional | **yes** | same test as AC3, with a derived team in the scenario |
| SC-001 — nothing is deleted | non-functional | **yes** | real database: 72 people · 12 teams · 82 team memberships · 472 payloads, **identical** before and after |
| SC-002 — 100% of the exclusive data marked, with date | non-functional | **yes** | `pessoa com vínculo apenas na organização encerrada perde vigência` |
| SC-003 — nothing with provenance in force elsewhere is marked | non-functional | **yes** | this is the test that matters: Paulo is **not** marked when ending `ifesserra-lab` |
| SC-004 — no credential, not even encrypted | non-functional | **yes** | direct query; in the real database, remaining credentials: 0 |
| SC-005 — the collection does not query the ended source | non-functional | **yes** | the absence of an expectation on the Mox is the proof |
| SC-008 — the ended team membership remains queryable | non-functional | **yes** | `o histórico mantém a organização encerrada` |
| SC-009 — the numbers on the screen match what gets marked | non-functional | **yes** | `o número mostrado é o número que o encerramento marca` — the impact is stored in the event and read back from the database |
| SC-010 — does not cross tenants | non-functional | **yes** | **written during this evaluation**: three tests, with the counter-proof that the owner still reaches it |

**Derived phase**: `sro.accepted_deliverable`.
**Phase of the task**: `sro.successfully_performed_scrum_development_task`.

---

## D03 — Resume the observation (US2) {#d03--retomar-a-observação-us2}

**Produced by**: F4 · backend in T023 to T025; screen and history during this evaluation
**Materializes**: US2 — Resume an ended observation (atomic, P2)

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — resumes the existing tool, does not create a second one | functional | **yes** | `reusa a ferramenta existente, não cria uma segunda` |
| AC2 — the next collection restores the in-force status of what reappeared | functional | **yes** | **written during this evaluation**: re-observes one of two team memberships and requires the distinction in both directions |
| AC3 — requires a new credential | functional | **yes** | `exige credencial nova, e ela passa a ser a ativa`; `credencial recusada não retoma` |
| AC4 — the history shows ending and resuming | functional | **yes** | **done during this evaluation**: `histórico de observação (2)` on the screen, with both transitions when expanded |
| SC-006 — does not duplicate tool, person or team | non-functional | **yes** | same test as AC1 |
| SC-007 — what came back stays in force, what did not come back stays marked | non-functional | **yes** | **written during this evaluation**; without the second assert, unmarking everything would pass |
| SC-011 — no usable secret on screen | non-functional | **yes** | a test by the violation: it looks for a test token string [redigido] in the HTML and requires not finding it |

**Derived phase**: `sro.accepted_deliverable`.
**Phase of the task**: `sro.successfully_performed_scrum_development_task`.

**A declared limitation, and it is not a criterion failure**: the happy path of
resuming **was not exercised against the real GitHub**. It requires a valid
credential, and the master key that decrypts the credentials in the development database
belongs to the maintainer — it is not in my environment. What was verified in the
running application is the button, the form and the history; a successful resume
is proven in a test, with the HTTP edge simulated.

---

## Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

None. The 27 FRs and the 11 SCs are as they were specified and approved before
implementation.

## Criteria without evidence {#critérios-sem-evidência}

None. The three that lacked evidence when this evaluation began —
US2/AC4, SC-007 and SC-010 — were covered before this record, and the coverage
is committed.

---

## Outside the evaluated scope {#fora-do-escopo-avaliado}

They are not part of this evaluation because **they did not enter the sprint**, with a destination
declared in the [backlog](sprint-backlog.md):

| Item | Destination |
|---|---|
| **US3 — rename and remove credential, clear attention** | product backlog, no iteration |
| **Screens T019 to T022** | product backlog; the ending screen exists and covers the main path |
| **Repair of the L19 historical data** | happens on the next real collection of each organization |
| **Sprint 002 iteration window** | pending decision — fixing it requires touching iterations, the cause of L11 |

## Sprint deliverable {#entregável-do-sprint}

`sro.sprint_deliverable_composed_of_accepted_deliverable` admits only
accepted deliverables. With D01, D02 and D03 derived as accepted, the sprint 003
deliverable is composed of the three — **subject to confirmation by whoever plays the
role**, which is a human act and does not follow from this evaluation.

## Note on the independent review {#nota-sobre-a-revisão-independente}

It remains **blocked by tooling**: with a single identity in the repository, the
author does not approve their own PR. The maintainer reviewed and agreed with the
previous PRs without recording a comment — the missing record does not mean a missing
review, and it is the tool that cannot represent that. It closes with a bot
or a GitHub App.
