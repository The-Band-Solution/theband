# Sprint 022 — Review {#sprint-022--review}

**Period**: 2026-08-28 (opened and closed on the same day)
**Feature**: [046-menu-por-entidades](../../../specs/046-menu-por-entidades/spec.md)
**PR**: [#543](https://github.com/The-Band-Solution/theband/pull/543), merge `380d90f`

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 11 | 11 |
| Accepted deliverables | 3 | 3 |

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001 | [#532](https://github.com/The-Band-Solution/theband/issues/532) | Branch and gates baseline (with the caveat of the contaminated baseline — see lessons) | yes |
| T002 | [#533](https://github.com/The-Band-Solution/theband/issues/533) | Pure `nav_area/1`, 18 paths tested by table | yes |
| T003 | [#534](https://github.com/The-Band-Solution/theband/issues/534) | Bar with the 4 entities, `aria-current="true"` on the active section | yes |
| T004 | [#535](https://github.com/The-Band-Solution/theband/issues/535) | Settings in three sections; Operation admin-only (FR-003) | yes |
| T005 | [#536](https://github.com/The-Band-Solution/theband/issues/536) | Nine moved routes unchanged; /tools gating untouched | yes |
| T006 | [#537](https://github.com/The-Band-Solution/theband/issues/537) | `work_tabs/1` with the exact six destinations | yes |
| T007 | [#538](https://github.com/The-Band-Solution/theband/issues/538) | Sub-tabs on the six work screens (SC-004: 1 click) | yes |
| T008 | [#539](https://github.com/The-Band-Solution/theband/issues/539) | `EO.organization_overview/1` per the corrected contract | yes |
| T009 | [#540](https://github.com/The-Band-Solution/theband/issues/540) | `/organizations` with named absences and an orphans group | yes |
| T010 | [#541](https://github.com/The-Band-Solution/theband/issues/541) | Screen × SQL: orgs 3/3, teams 2/9/0, projects 2/15/9, 0 orphans | yes |
| T011 | [#542](https://github.com/The-Band-Solution/theband/issues/542) | 13 green gates + 1280px captures with no horizontal scroll | yes |

**Acceptance**: evaluated criterion by criterion by the product-owner agent on 2026-08-28,
re-running the feature's 5 test files (28 passed, EXIT=0), direct SQL against the
dev database and inspection of the merged markup. Verdict: **3/3 user stories accepted** —
recorded in issues [#529](https://github.com/The-Band-Solution/theband/issues/529),
[#530](https://github.com/The-Band-Solution/theband/issues/530) and
[#531](https://github.com/The-Band-Solution/theband/issues/531). Confirmed by the
maintainer when authorizing the merge in this session.

## What was not done {#o-que-não-foi-feito}

Nothing — the 11 backlog tasks were executed and accepted.

## Deliverables not accepted {#entregáveis-não-aceitos}

None.

## Evidence {#evidências}

- 13 green gates (`mix gates`, output in a log with the verdict from the exit code).
- Check against the source (T010) reproduced by the product-owner at acceptance.
- 1280px captures: /organizations, /people, /work — no horizontal scroll (SC-005).
- Independent review by another agent, no findings — comment on PR #543.
- Two contract corrections in the implementation commit, with reasons (constitution VI):
  projects outside EO (module boundary) and the project→organization link through the chain
  `connected_tool_id → organization_login` — matching by `source_instance` would have been
  100% orphan, contradicted by the collection code before touching the database.

## Debt generated {#dívida-gerada}

- **Tests to harden** (pointed out at acceptance): the Settings test does not pin the
  titles "Trabalho" and "Vocabulário" (only "Operação"); the narrow viewport scenario
  (FR-008) has no automated test — evidence through markup and capture.
- **Gap in proof of review**: the independent review is attested in a comment,
  but there is no formal approval in `pulls/543/reviews` — the merge was authorized by the
  maintainer in session, with the request to the `the-band` team still open.
- **Visual duplication in /work**: the page keeps old internal links
  ("Change requests · Continuous verification · Files") redundant with the new
  sub-tabs — the cleanup belongs to a task of its own, it did not go into this feature.
- Issue types `Epic`/`User Story` remain nonexistent in the organization (inherited
  limitation; creating them requires the maintainer's approval).

## Lessons from this sprint {#lições-deste-sprint}

See the [cumulative record](../licoes-aprendidas.md) — L60 gained a new occurrence
(EXIT echoed outside the log) and L71 was born (tests that document the old requirement
fall in bulk when the requirement moves elsewhere).
