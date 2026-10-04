# Sprint 019 — Issue comments, and participation in discussions {#sprint-019--os-comentários-das-issues-e-a-participação-nas-discussões}

**Period**: 2026-08-17 to 2026-08-31
**Feature**: [030](../../../specs/030-comentarios-das-issues/spec.md)
**Plan**: [plan.md](../../../specs/030-comentarios-das-issues/plan.md)

## Sprint goal {#objetivo-do-sprint}

The issues' conversation becomes platform data: collected as a note (cmo.comment),
read as discussion and participation (derived), and visible in three places — the issue
detail, the stopped-work anti-pattern (which gains a threefold resolution) and the person page.

## The decision that opened the sprint {#a-decisão-que-abriu-o-sprint}

**CMO exists.** The network had no concept for a comment (#318); the maintainer
decided to extend continuum (2026-08-17) instead of flattening comment into
`spo.information_item`. Ontology, module, competency questions and the mapping
`github.issue_comment.to.cmo.comment` are already written and validated by the knowledge base — the
sprint starts with Phase 0 done.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md):

| Lesson | Origin | How it is being applied |
|---|---|---|
| L25 | Sprint ~010 | comment identity by external_id, natural_key with repository and issue — the number alone does not identify |
| L26 | Sprint ~010 | narrow matching on the ingestion envelopes; an empty list with totalCount > 0 is an error, never success |
| L29 | Sprint ~012 | a transient failure in the comments phase does not mark permanent state — the next collection tries again |
| L30/L35 | Sprint ~012 | SC-001 is a check against the API by sample, not a green suite |
| L47 | Sprint 017 | the comments phase reads issues from the DATABASE, not from the previous phase's memory — a new issue with a comment goes in on the same pass |
| L48 | Sprint 017 | closing keywords in English in the commits; post-merge check |

And the eighth silent success (silent round, 2026-08-17, still without a lesson number):
`totalCount` in the query and coverage recorded in the phase exist precisely so that
truncation is never silence.

## Sprint on GitHub {#sprint-no-github}

**Recorded limitation**: no iteration created for this sprint in Projects v2 — the
issues are created and typeable, and the assignment to the iteration remains pending for the
maintainer (creating iterations is a change to the organization's configuration).

## Selected user stories {#user-stories-selecionadas}

| # | User story | Issue | Criteria |
|---|---|---|---|
| US1 | see the issue's discussion on the platform | [#411](https://github.com/The-Band-Solution/theband/issues/411) | FR-001/002/003/007/008, SC-001 |
| US2 | stopped in silence ≠ stopped with discussion | [#412](https://github.com/The-Band-Solution/theband/issues/412) | FR-004, SC-002 |
| US3 | participation as evidence on the person | [#413](https://github.com/The-Band-Solution/theband/issues/413) | FR-005/006, SC-003/004 |

## Tasks {#tarefas}

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T000 | CMO + mapping, validated | decision | — (done at opening) | done |
| T001 | migration | US1 | [#417](https://github.com/The-Band-Solution/theband/issues/417) | done |
| T002 | Ecto schema + upsert | US1 | [#418](https://github.com/The-Band-Solution/theband/issues/418) | done |
| T003 | GraphQL query | US1 | [#424](https://github.com/The-Band-Solution/theband/issues/424) | done |
| T004 | incremental ingestion | US1 | [#419](https://github.com/The-Band-Solution/theband/issues/419) | done |
| T005 | sync phase | US1 | [#420](https://github.com/The-Band-Solution/theband/issues/420) | done |
| T006 | real collection, totals against the API | US1 | [#414](https://github.com/The-Band-Solution/theband/issues/414) | done |
| T007 | Discussions (reading) | all | [#421](https://github.com/The-Band-Solution/theband/issues/421) | done |
| T008 | discussion in the issue detail | US1 | [#415](https://github.com/The-Band-Solution/theband/issues/415) | done |
| T009 | anti-pattern with threefold resolution | US2 | [#416](https://github.com/The-Band-Solution/theband/issues/416) | done |
| T010 | participation on the person page | US3 | [#422](https://github.com/The-Band-Solution/theband/issues/422) | done |
| T011 | live verification | US2/US3 | [#423](https://github.com/The-Band-Solution/theband/issues/423) | done |

## The success criteria, with the evidence {#os-critérios-de-sucesso-com-a-evidência}

| # | criterion | evidence |
|---|---|---|
| SC-001 | collection finishes and matches the source | **2,013 comments**, 5,116 issues visited, 160 repositories, 0 truncated, 0 unreachable, 259s. Issue 645 checked against the live API: 3 comments there, 3 here, same authors and instants. The difference with `comment_count` (2,008) is that the field is from the moment the issues were collected — what was collected matches the source as of **now**. |
| SC-002 | real stopped issue labeled | AndréCoelho: two stopped for 419d as `silent` ("nobody has commented on it — decide whether it dies or comes back") and one for 104d as `stale discussion` ("1 comment(s), none since 2026-05-18 — discussed, then left"). Before, three identical rows. |
| SC-003 | no_assignment with participation | **7 of the 24** people with no assignment at all work in the conversation: `lucasbruno-devdog` with **72 acts in 50 discussions**, `dnribeiro` with 17 in 13, plus `0xdeadbad`, `oliverids`, `sofiasilv4`, `ogianpaneto`, `JoelHanerth`. They were invisible on the platform. |
| SC-004 | fixed number of queries | `last_act_for_issues/2`: 1 query for 8 issues. `for_issue/2`: 1 query with 1 or with 20 comments. The issue detail went from 39 to **40** queries per render — a fixed one, and the guard test's ceiling was updated with the reason written down. |

## Out of this sprint's scope {#fora-do-escopo-deste-sprint}

PR review threads, reactions, mentions as a relation, and using participation in the
profile material (a separate decision by the maintainer) — all declared in the spec
and in the mapping.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [ ] quality gates green (`mix gates`)
- [ ] knowledge base valid (CMO already passes)
- [ ] SC-001 to SC-004 verified on the real tenant, with evidence
- [ ] issues closed or reprioritized with justification
- [ ] `sprint-review.md` written
- [ ] `licoes-aprendidas.md` updated
