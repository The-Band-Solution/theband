# Sprint 028 — The team screen, and the team made of teams {#sprint-028--a-tela-da-equipe-e-a-equipe-feita-de-equipes}

**Period**: 2026-09-02 to 2026-09-09 (one-week cadence)
**Feature**: [057](../../../specs/057-tela-da-equipe-complexa/spec.md)
**Plan**: [plan.md](../../../specs/057-tela-da-equipe-complexa/plan.md)
**Approved prototype**: [prototipo/](../../../specs/057-tela-da-equipe-complexa/prototipo)

## Sprint goal {#objetivo-do-sprint}

The team screen starts answering the four management questions, the composite
team shows its sub-teams **without adding them up**, and — before any new
indicator — **the numbers stop counting who has already left and stop rewriting
the past**.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md):

| Lesson | Origin | How it is being applied |
|---|---|---|
| **L95** requesting a reviewer is not obtaining a review | Sprint 027 | before each merge, measure `gh pr view <n> --json reviews`. **Zero is a blocker**, not an observation — it is what was missing in the four PRs of 055 |
| **L96** an issue nobody closes makes the sprint look undelivered | Sprint 027 | `gh issue list --state open` with the `057/` prefix enters the sprint DoD, **before** writing the review |
| **L97** a feature that fixes the team membership does not fix whoever reads the team membership | Sprint 027 | it is US1 of this sprint. The `plan.md` lists the consumers of the team membership and says for each one whether it changes |
| **L91** the cycle step without a gate is the one that disappears | Sprint 025 | the 41 issues are linked in `tasks.md`, one per task, and checked against the source |
| **L86** a moving denominator lies just like an invented one | Sprint 026 | SC-002 requires strict equality between the series before and after a departure is recorded |
| **L11** reconfiguring the iteration field recreates the existing ones | Sprint 002 | **the iteration field was not touched** — see the limitation below |
| **L83/L92** squash diverges and erases the back-merge | Sprint 026 | merge commit on the PRs, never squash |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
43 items added

### Two declared limitations, not worked around {#duas-limitações-declaradas-não-contornadas}

**1. This sprint has no iteration.** The last configured iteration is *Sprint 026
— Herança e a produção*, starting on 2026-09-19 — dates that no longer match
when the sprints actually run. Adding iterations requires `updateProjectV2Field`, and
**L11 measured the cost of that**: the existing iterations were recreated and **97
items were orphaned**, with 87 reassigned by hand afterwards.

No label or milestone was improvised in its place. Sprint 027 also ran without an
iteration, and the gap accumulates — fixing it is work of its own, with a
snapshot of the `item id`s taken first.

**2. The user stories have no type.** The organization has `Task`, `Bug` and
`Feature`; **`User Story` and `Epic` do not exist**. Creating a type changes the
organization's configuration, and the skill requires confirmation — which was not given.

Typing the six as `Feature` would make the routing rule in
`priv/knowledge_base/rules/github_issue_type_routing.yaml` classify them
wrongly. **No type is an absence; the wrong type is a false statement.**

The 37 tasks **are** typed as `Task`, and the 28 that serve a user story are
linked as sub-issues of it.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Issue | Priority | Estimate | Tasks | Criteria |
|---|---|---|---|---|---|---|
| US1 | The measure counts only while the person belonged | [#715](https://github.com/The-Band-Solution/theband/issues/715) | P0 | 5 | T005–T008 | SC-001, SC-002 |
| US2 | The complex team shows its teams, one by one | [#716](https://github.com/The-Band-Solution/theband/issues/716) | P0 | 5 | T009–T013, T037 | SC-003, SC-005 |
| US3 | The sub-team detail: doing, done, and what is coming | [#717](https://github.com/The-Band-Solution/theband/issues/717) | P1 | 3 | T014–T017 | — |
| US4 | What each person is doing, and what they have shown | [#718](https://github.com/The-Band-Solution/theband/issues/718) | P1 | 5 | T018–T022, T035, T036 | SC-006, SC-007, SC-012 |
| US5 | Burn-up and burn-down, with what remains between the curves | [#719](https://github.com/The-Band-Solution/theband/issues/719) | P1 | 3 | T023–T026 | SC-004 |
| US6 | A forecast that states its confidence | [#720](https://github.com/The-Band-Solution/theband/issues/720) | P2 | 5 | T027–T029 | SC-008, SC-009, SC-010 |

`Priority` is the SRO *importance* — value to the organization. `Estimate` is the
*complexity* — difficulty for the team. **Tasks do not get a `Priority`**:
they inherit the one of the user story they serve.

## Tasks {#tarefas}

All in [`tasks.md`](../../../specs/057-tela-da-equipe-complexa/tasks.md), with the
four fields and the issue link. Range: [#721](https://github.com/The-Band-Solution/theband/issues/721)
to [#757](https://github.com/The-Band-Solution/theband/issues/757).

| Phase | Tasks | Issues | Serves |
|---|---|---|---|
| Setup | T001 | #721 | — |
| Foundational | T002–T004, **T034** | #722–#724, #754 | blocks everything |
| US1 | T005–T008 | #725–#728 | #715 |
| US2 | T009–T013, T037 | #729–#733, #757 | #716 |
| US3 | T014–T017 | #734–#737 | #717 |
| US4 | T018–T022, T035, T036 | #738–#742, #755, #756 | #718 |
| US5 | T023–T026 | #743–#746 | #719 |
| US6 | T027–T029 | #747–#749 | #720 |
| Polish | T030–T033 | #750–#753 | — |

**T034–T037 are out of numerical order on purpose**: they were born from
`/speckit-analyze` after the first 33 issues, and renumbering would invalidate them.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started) —
all in **a fazer**.

## Inherited from sprint 027 {#herdado-do-sprint-027}

| Item | Issue | Why it came | Where it goes |
|---|---|---|---|
| T014 of 055 — the two statements when collection and declaration disagree | [#700](https://github.com/The-Band-Solution/theband/issues/700) | never implemented | **inside US3 of this feature**: the screen is rewritten there, and doing it before would be wasted work |
| T015 of 055 — CHECKED review | [#701](https://github.com/The-Band-Solution/theband/issues/701) | the four PRs had 2 reviewers requested and **0 reviews** | **entry condition** for every PR in this sprint |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| What | Why |
|---|---|
| the same baseline fix on the **person page** | its own query ceiling and review criterion — T032 records it in the backlog instead of hiding it |
| period selector for the series | choosing the period is separate work, and a selector without a closed period reopens the moving-denominator question |
| export, active alert, comparison between organizations | outside what the feature answers |
| **any consolidated sum** | by decision, not by deadline — FR-008 |
| creating the `User Story` and `Epic` types | changes the organization's configuration; requires confirmation |
| fixing the Projects v2 iterations | L11 measured the cost: 97 orphaned items |
| [MCP server](../../backlog/servidor-mcp.md) | recorded on 2026-09-02; blocked until authentication and tenant are decided |

## Risks and dependencies {#riscos-e-dependências}

| Risk | Effect | Mitigation |
|---|---|---|
| **independent review not happening again** | principle VII violated once more, and L95 becomes a recurrence | measure `reviews` before each merge; zero is a blocker |
| the US1 fix changes numbers someone has already noted down | distrust in the platform | the PR declares the before and after, measured on real data |
| `show.ex` growing past ~1200 lines | two reasons to change in the same file | limit and split criterion already written in the plan |
| query ceiling blowing up | slow screen, red gate | T031 turns the ceiling into a test |
| the forecast being read as a promise | commitment made on noise | FR-033, the R7 floor, and the text on the screen |

## Sprint Definition of Done {#definition-of-done-do-sprint}

Besides the per-task DoD:

- [ ] `mix gates` with **exit code 0** — the verdict is the code, and no
      command after it
- [ ] valid knowledge base, with the new measures declared (T004)
- [ ] **`gh pr view <n> --json reviews` > 0 on every merged PR** — L95
- [ ] **`gh issue list --state open --search "057/ in:title"` checked before the
      review**, and every divergence from `tasks.md` resolved — L96
- [ ] issues closed or reprioritized with justification
- [ ] `sprint-review.md` written
- [ ] `licoes-aprendidas.md` updated

## Gate baseline {#baseline-dos-gates}

Measured on 2026-09-02, before any line of this feature:

```text
14 gates verdes.
CODIGO_DE_SAIDA=0
```

120 YAML files · 14 ontologies · 238 concepts · 175 relations · 5 measures ·
32 modules · reproducible derivation in `eo`, `sro`, `cmpo` and `spo`.
