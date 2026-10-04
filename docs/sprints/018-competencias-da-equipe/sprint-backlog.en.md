# Sprint 018 — Team competences {#sprint-018--competências-da-equipe}

**Period**: 2026-08-16 · **Feature**: [029](../../../specs/029-competencias-da-equipe/spec.md)

## Goal {#objetivo}

When opening a team, the reading that no résumé gives: competence coverage, who
demonstrates what, a computed summary and evolution per generation — all counted from the profiles that already
exist, zero calls to a model.

## Lessons applied {#lições-aplicadas}

| Lesson | How |
|---|---|
| L60/L59 | gates via `> log; ec=$?; exit $ec`; a single query counter in the cost test |
| silent success | no-profile is named, never zero; a month without a generation does not exist in the series |
| #372 | the cost test uses `TheBand.ContadorDeConsultas` |

## Tasks {#tarefas}

| # | Task | State |
|---|---|---|
| T001 | `TeamSkills` contract (coverage/evolution/summary) | done (with the spec) |
| T002 | `Profiles.TeamSkills` — aggregation with a fixed number of queries | done |
| T003 | Evolution per month with a generation — profiles in force on the date | done |
| T004 | Computed summary, with a ceiling and the granularity sentence | done |
| T005 | The section on the team screen — bars, matrix, sparklines, hatching | done |
| T006 | Tests: SC-001 to SC-004 + FR-006a (no ranking) | done |
| T007 | Associate team↔project also from the team screen (requested in session) | done |

**Iteration**: not created (L11). Single issue for the feature: see above.

## DoD {#dod}

- [x] 13 gates green (971 tests, 14 new) · [x] SC-001..004 by test · [x] screen verified in the app with real data (PLATAFORMA, 18 members)
- [ ] PR with `the-band` reviewer checked · [ ] review + lessons

## What the real data taught (goes into the lessons) {#o-que-o-dado-real-ensinou-vai-para-as-lições}

The profile domains are hyper-specific per person: in the real team, EVERY domain came out
1/18, and the single-point sentence listed 40+ names. Two fixes on the same day: a ceiling on the
sentence (3 names + count) and the granularity sentence — "it is a limit of the record, not an
absence of overlap". Aggregation by area is exactly what #363 will provide.
