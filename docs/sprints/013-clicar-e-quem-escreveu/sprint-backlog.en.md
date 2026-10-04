# Sprint 013 — clicking leads to the page, and whoever wrote it comes into existence {#sprint-013--clicar-leva-à-página-e-quem-escreveu-passa-a-existir}

**Period**: 2026-08-13 to 2026-08-19
**Features**: [014](../../../specs/014-clicar-leva-a-pagina/spec.md) · [015](../../../specs/015-quem-escreveu-a-issue-tambem-e-observado/spec.md)
**Origin**: [#281](https://github.com/The-Band-Solution/theband/issues/281) and [#283](https://github.com/The-Band-Solution/theband/issues/283)

## Goal {#objetivo}

By the end of the sprint, clicking a person's name leads to their page — and the people who only
appeared as authors come into existence, with an identity that comes from the source.

## The L44 and L45 check {#a-conferência-da-l44-e-da-l45}

```text
docs/sprints/012-pagina-da-pessoa-mais-rapida/sprint-backlog.md   ✓
docs/sprints/012-pagina-da-pessoa-mais-rapida/sprint-review.md    ✓
specs/013-pagina-da-pessoa-mais-rapida/aceitacao.md               ✓
```

**And where they are** — L45: all three are on `main`, brought in by PR #282. This branch came off
`main` and sees everything.

## Two features in the same sprint, and why it is not a single PR {#duas-features-no-mesmo-sprint-e-por-que-não-é-um-pr-só}

Sprint 005 already had two. What **cannot** happen is the same PR: collection and navigation have
different review criteria, and `AGENTS.md` §17 forbids mixing them. **Two PRs, one sprint.**

## Lessons applied {#lições-aplicadas}

| Lesson | How |
|---|---|
| **L25** | identity by the source's `id`, never by the login — that is what changed the path of 015 |
| **L28** | "the collection creates" and "the screen links" are different claims; each has its own test |
| **L30** | the measure came first: 288 appearances, 15 logins, 135 repositories already clickable |
| **L32** | the screen does not claim what it did not observe — a name without a person stays text |
| **L34** | "member" and "worked" are two words for different things, and 015 separates them |
| **L42** | the query counter excludes Oban — that is what failed sprint 012's CI |
| **L44**, **L45** | the check above |
| **L49** | measure the tail: the person page was measured on eight people, not one |

## Scope {#escopo}

| # | Task | Feature | Phase | State |
|---|---|---|---|---|
| 014-T001 | Link author and assignees when there is a person | 014 | F1 | to do |
| 014-T002 | Link the team members | 014 | F2 | to do |
| 014-T003 | A name without a destination stays text | 014 | F3 | to do |
| 014-T004 | No new query | 014 | F3 | to do |
| 014-T005 | Keyboard, and no reliance on color | 014 | F3 | to do |
| 015-T001 | Ask the source for the identifier | 015 | F1 | to do |
| 015-T002 | Record whoever wrote it | 015 | F2 | to do |
| 015-T003 | Refuse what is not a person | 015 | F2 | to do |
| 015-T004 | Pin down idempotency | 015 | F2 | to do |
| 015-T005 | A member stays a member | 015 | F3 | to do |
| 015-T006 | The organization came from the work | 015 | F3 | to do |
| 015-T007 | Check against the real data | 015 | F4 | **needs the master key** |

**Order**: 014 first — it delivers **8,470** names without depending on collection. 015 then moves
the remaining 288.

## What the analysis found, before the code {#o-que-a-análise-achou-antes-do-código}

| # | Finding | Fix |
|---|---|---|
| **A1** | `ctx.pessoas` is built **once**: the person created in repository #3 would not exist in the map when collecting #4, and their issues would be left without a link — with no error | FR-012 and the test with two repositories in the same run |
| **A2** | `gravar_issue` reads the map in the same pass: recording afterwards leaves `author_person_id` null | T002 declares the order |
| **A3** | `replace_assignees` writes `person_id` from the same map — the defect hits the assignee | FR-013 |
| **A4** | counting queries would include Oban | T004 already excludes it |

## Out of scope {#fora-do-escopo}

| Out | Why |
|---|---|
| organization page | there is no route; creating one is another product decision |
| organizational role | GitHub does not provide it; that is #99/#100 |
| reprocessing old payloads to find the author | they do not have the `id` — declared limitation |
| unifying accounts of the same person | the mapping already declares that this requires an explicit rule, never a heuristic |

## Definition of Done {#definition-of-done}

- [ ] `mix gates` green by exit code
- [ ] **two** PRs, one per feature, with review requested from the team
- [ ] `aceitacao.md` for both, criterion by criterion
- [ ] `sprint-review.md` written in this sprint — L44
- [ ] lessons updated
- [ ] issue closing keyword **in English** — L48
