# Sprint 028 — Review {#sprint-028--review}

**Period**: 2026-09-02 to 2026-09-09 · closed on 2026-09-02
**Feature**: [057 — the team screen, and the team made of teams](../../../specs/057-tela-da-equipe-complexa/spec.md)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 6 | 6 |
| Tasks | 37 | 36 |
| Accepted deliverables | 37 | **36 with a reservation** |

The six user stories are complete in `development`. The task not delivered is
precisely the one that requires independent review, and the reservation is the same as in the
previous sprint.

## What was done {#o-que-foi-feito}

| # | User story | Issue | Delivered by |
|---|---|---|---|
| US1 | The measure counts only while the person belonged | [#715](https://github.com/The-Band-Solution/theband/issues/715) | [#758](https://github.com/The-Band-Solution/theband/pull/758) |
| US2 | The complex team shows its teams, one by one | [#716](https://github.com/The-Band-Solution/theband/issues/716) | [#759](https://github.com/The-Band-Solution/theband/pull/759) |
| US3 | The sub-team detail | [#717](https://github.com/The-Band-Solution/theband/issues/717) | [#761](https://github.com/The-Band-Solution/theband/pull/761) |
| US4 | What each person is doing, and what they have shown | [#718](https://github.com/The-Band-Solution/theband/issues/718) | [#761](https://github.com/The-Band-Solution/theband/pull/761) + [#762](https://github.com/The-Band-Solution/theband/pull/762) |
| US5 | Burn-up and burn-down, with what remains between the curves | [#719](https://github.com/The-Band-Solution/theband/issues/719) | [#761](https://github.com/The-Band-Solution/theband/pull/761) |
| US6 | A forecast that states its confidence | [#720](https://github.com/The-Band-Solution/theband/issues/720) | [#761](https://github.com/The-Band-Solution/theband/pull/761) |

**42 of the 43 issues closed.** Each one with the number of the PR that delivered it in a
comment — this sprint's **L96** exists because that was not done in 027.

### The five PRs {#os-cinco-prs}

| PR | What it delivered |
|---|---|
| [#760](https://github.com/The-Band-Solution/theband/pull/760) | the whole Spec Kit cycle, the closing of 027 and the opening of 028 |
| [#758](https://github.com/The-Band-Solution/theband/pull/758) | `team_members_at/3`, `vigente_em/2`, the `TeamSkills` fix, the two measures in YAML |
| [#759](https://github.com/The-Band-Solution/theband/pull/759) | `TeamWork`, the composite screen without sums, the ordering by stopped work |
| [#761](https://github.com/The-Band-Solution/theband/pull/761) | `burn/2` with a baseline, `Forecast`, the people, the query ceiling |
| [#762](https://github.com/The-Band-Solution/theband/pull/762) | the skills per person — the missing half of US4 |

## What was not done {#o-que-não-foi-feito}

| Task | Issue | Reason | Destination |
|---|---|---|---|
| T033 | [#753](https://github.com/The-Band-Solution/theband/issues/753) | gates green ✅, PRs following the standard ✅, **independent review ✗** | **sprint 029**, as an entry condition — for the second sprint in a row |

## Deliverables accepted with a reservation {#entregáveis-aceitos-com-ressalva}

**The five PRs were merged with 0 reviews each.** The decision was the
maintainer's on 2026-09-02, with CI green — and **green CI is not a review**: the
gates say the code compiles, passes and does not regress, and they do not say anyone read
the design.

The gap is **declared in each PR**, as principle VII requires, and never
marked as fulfilled.

**It is the second time in a row.** L95 was born from this in sprint 027, and recurred in the
very sprint that recorded it. It is noted in the lessons.

## Evidence {#evidências}

| What | Measure |
|---|---|
| `mix gates` on `development` after all merges | **exit code 0** · 14 gates |
| code and tests added | 2,493 lines in 15 files |
| documentation | 3,473 lines in 19 files |
| new test files | 5 |
| new modules | `TheBand.Forecast`, `TheBand.WorkItems.TeamWork` |
| measures declared in YAML | 5 → **7** |
| merge type | **all five are merge commits** — checked with `git rev-list --parents` |

## Debt generated {#dívida-gerada}

**The burn on the person page starts from zero.** The equivalent fix was made
for the team in this sprint. Recorded in
[`docs/backlog/burn-da-pessoa-sem-linha-de-base.md`](../../backlog/burn-da-pessoa-sem-linha-de-base.md)
with the three reasons, and the third is the one that matters: for the person, perhaps the window
cut **is** what is wanted. It needs to be decided, not deduced.

**The sprint ran without an iteration in Projects v2** — the second in a row. Adding it
recreates the existing ones, and L11 measured the cost at 97 orphaned items. The gap
accumulates, and fixing it is work of its own.

**The user stories were left without a type.** `User Story` does not exist in the organization, and
typing them as `Feature` would make the routing rule classify them wrongly.
Creating the type changes the organization's configuration and was not authorized.

## Lessons from this sprint {#lições-deste-sprint}

### L98 — The lesson that does not become a rule recurs in the next sprint {#l98--a-lição-que-não-vira-regra-reincide-no-sprint-seguinte}

**L95** — requesting a reviewer is not obtaining a review — was born in sprint 027 and
**recurred in 028**, with five PRs merged without review. Writing the lesson
did not change behavior; it stayed in the cumulative document, and the document is read
when **opening** the sprint, not at the moment of clicking the button.

The same happened with squash: **L75, L83 and L92**, and the third occurred after
the first two had already been written.

**What to do differently**: a lesson that describes a repeatable act becomes a **rule in
`AGENTS.md` and a mandatory field in the artifact** where the act happens. That is what was
done with the merge type in the PR ([#763](https://github.com/The-Band-Solution/theband/pull/763)).
The cumulative record keeps the **why**; the artifact carries the **obligation**.

### L99 — Checking issue by issue found what planning did not {#l99--conferir-issue-por-issue-achou-o-que-planejar-não-achou}

When closing the sprint, checking `gh issue list --state open` showed that
**T020 and T021 were never implemented**: the people section had the tasks and
did not have the skills. US4 was half done, with the PR already merged and the
gates green.

No gate catches this. Tests prove what exists, not what was promised —
an absent section has no test that fails.

**What to do differently**: checking issue by issue **before** writing the
review is not a formality — it is the only reading that compares what was promised with what was
delivered. It is already in the sprint DoD because of L96, and in this sprint it worked
in the very sprint that created it.

### L100 — A documentation branch without a PR makes the code arrive without the spec {#l100--branch-de-documentação-sem-pr-faz-o-código-chegar-sem-a-spec}

The code PRs were branched from `development`, and the branch with the spec, the
plan, the tasks and the sprint **never had a PR**. The first three PRs went out without
the documents they implemented, and the defect only showed up when a backlog file
disappeared from the working tree.

**What to do differently**: when branching to implement, check that the source
branch **is already in `development`** — `git log development..<branch>` empty — or
open its PR first. A one-line `git log` answers it.
