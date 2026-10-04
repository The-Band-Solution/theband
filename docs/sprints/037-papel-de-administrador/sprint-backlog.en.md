# Sprint 037 — the administrator mark {#sprint-037--a-marca-de-administrador}

**Period**: 2026-10-03 to 2026-10-09, in the Sprint 035 iteration on GitHub (`ee36a246`)
**Feature**: [072](../../../specs/072-papel-de-administrador/spec.md) · **Plan**: [plan.md](../../../specs/072-papel-de-administrador/plan.md)
**Originating issue**: [#568](https://github.com/The-Band-Solution/theband/issues/568), the gap named by the acceptance of sprint 023

## Sprint goal {#objetivo-do-sprint}

The organization can now have more than one administrator, and never none. Whoever loses the mark stops
administering on the next action.

## Lessons applied {#lições-aplicadas}

| lesson | how it is being applied |
|---|---|
| L50 — the test that compares must prove it measured | the SC-001 race asserts that the ten acts ran; the capture of the `FOR UPDATE` asserts that it measured |
| L90 — counting only the winner of the race does not prove the loser | the race asserts the winner **and** the refusal of each loser, by reason |
| L108 — feature without a sprint backlog | this document exists before the code, and the US only close with acceptance |
| the screen exactly as approved | the prototype was approved on 2026-10-03, and T012 checks it item by item |

## User stories {#user-stories}

| # | user story | issue | Priority |
|---|---|---|---|
| US1 | Promote an account to administrator | [#1165](https://github.com/The-Band-Solution/theband/issues/1165) | P1 |
| US2 | Demote an administrator, never the last one | [#1166](https://github.com/The-Band-Solution/theband/issues/1166) | P1 |
| US3 | The controls on the accounts screen | [#1167](https://github.com/The-Band-Solution/theband/issues/1167) | P2 |

## Tasks {#tarefas}

| # | task | serves | type | issue | state |
|---|---|---|---|---|---|
| T001 | Restrict the role to two values | — | Task | [#1168](https://github.com/The-Band-Solution/theband/issues/1168) | to do |
| T002 | Record role changes in the database | — | Task | [#1169](https://github.com/The-Band-Solution/theband/issues/1169) | to do |
| T003 | The database refuses a role without an episode | — | Task | [#1170](https://github.com/The-Band-Solution/theband/issues/1170) | to do |
| T004 | The single guard of the role | — | Task | [#1171](https://github.com/The-Band-Solution/theband/issues/1171) | to do |
| T005 | The role phrases in the knowledge base | — | Task | [#1172](https://github.com/The-Band-Solution/theband/issues/1172) | to do |
| T006 | Promote and demote in one transaction | US1 | Task | [#1173](https://github.com/The-Band-Solution/theband/issues/1173) | to do |
| T007 | Deactivation through the same guard | US2 | Task | [#1174](https://github.com/The-Band-Solution/theband/issues/1174) | to do |
| T008 | Administration acts check the re-read actor | US2 | Task | [#1175](https://github.com/The-Band-Solution/theband/issues/1175) | to do |
| T009 | The demoted person's open screen falls | US2 | Task | [#1176](https://github.com/The-Band-Solution/theband/issues/1176) | to do |
| T010 | Read the record of changes | US3 | Task | [#1177](https://github.com/The-Band-Solution/theband/issues/1177) | to do |
| T011 | The accounts screen from the approved prototype | US3 | Task | [#1178](https://github.com/The-Band-Solution/theband/issues/1178) | to do |
| T012 | Check the screen against the prototype | US3 | Task | [#1179](https://github.com/The-Band-Solution/theband/issues/1179) | to do |
| T013 | Write the risk note and open the PR | — | Task | [#1180](https://github.com/The-Band-Solution/theband/issues/1180) | to do |

## Risks {#riscos}

- **FR-002a changes the behavior of ten acts that already exist.** Each one gets a test with the actor that
  lost the mark.
- **[redigido]**, until 071 (#1131) comes into force.
