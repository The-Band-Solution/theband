# Sprint 020 — Collecting changes, and the trace {#sprint-020--a-coleta-das-mudanças-e-o-rastreio}

**Period**: 2026-08-18 to 2026-09-01
**Feature**: [032](../../../specs/032-coleta-de-mudancas/spec.md)
**Plan**: [plan.md](../../../specs/032-coleta-de-mudancas/plan.md)

## Sprint goal {#objetivo-do-sprint}

The `issue → solicitação → commit → pessoa` trace stops being a model and becomes data and a
screen: who requested the change, who integrated it, who performed each commit.

## What came before, and unblocks this sprint {#o-que-veio-antes-e-destrava-este-sprint}

The relations were **declared** (PR #427, issue #426) and there was no data. The order was
like that on purpose: the contract first, and it was the contract that exposed the gap in the relations before
any line of collection.

## Lessons applied {#lições-aplicadas}

| Lesson | How it is being applied |
|---|---|
| L25 | commit identity by `[tenant, external_id]`; a PR number does not identify across repositories |
| L26 | narrow matching on the envelope (`{:ok, %{data: data}}`) — an empty list with `totalCount > 0` would be an error |
| L29 | a per-repository failure becomes `unreachable`, with no checkpoint recorded: the next collection tries again |
| L30/L35 | SC-001 checked against the live API, not by the suite |
| L46 | **and it recurred**: marking a vanished link by `last_observed_at < now` fails when both writes fall in the same second. Fixed to mark by observed set |
| L47 | the phase reads issues from the DATABASE, not from the previous phase's memory |
| L48 | closing keyword in English, **one per issue** — the second occurrence of the lesson, now in the syntax |

## Tasks {#tarefas}

See [tasks.md](../../../specs/032-coleta-de-mudancas/tasks.md). Phases 1 to 3 done; Phase 4
(list, search and timeline) approved as a proposal and pending.

## The criteria, with the evidence {#os-critérios-com-a-evidência}

| # | criterion | evidence |
|---|---|---|
| SC-001 | collection finishes and matches the source | **5,032 change requests, 16,416 distinct commits, 17,928 authorships, 1,078 links, 66 people** in 1,396s (23min). 3 unreachable repositories, recorded. |
| SC-002 | complete trace on the screen | Issue #395 → PR #396 → 9 commits, each with two authors (Paulo + claude). Verified live. |
| SC-003 | fixed number of queries | `commits_of/2` costs 2 with one commit or with twenty. Ceilings updated with a named increase: issue 40→42, person 19→22. |
| SC-004 | co-authorship is not flattened | 477 commits with more than one author in the first measurement; the screen shows the `co-author` badge, and the person shows up in their own list even without having opened a change request. |

## What the collection exposed, and became a fix {#o-que-a-coleta-expôs-e-virou-correção}

**509 truncated change requests** on the first pass — PRs with more than 50 commits. The way out
was not to declare a limitation: the API paginates, so **the limitation was ours**. The
`pull_request_commits.graphql` query came in, called only for the truncated ones. The fields
`commits_total` and `commits_collected` stay as a safety net: if pagination fails midway, the
screen says what is missing instead of showing a partial as a total.

## Out of scope {#fora-do-escopo}

Commits outside a change request (direct push), PR reviews, conflicts, `cmpo.artifact_copy`
and CI (#401) — all declared in the spec and in the mappings.

## Definition of Done {#definition-of-done}

- [x] quality gates green
- [x] knowledge base valid
- [x] SC-001 to SC-004 verified on the real tenant
- [ ] issues closed
- [ ] `sprint-review.md`
- [ ] `licoes-aprendidas.md` updated (L46 recurred; the new occurrence of L48)
