# Sprint 003 — Fix the absence mark, and end observation {#sprint-003--corrigir-a-marca-de-ausência-e-encerrar-observação}

**Period**: 2026-08-11 to 2026-08-17 (7 days — weekly cadence)
**Feature**: [003-editar-remover-ferramentas](../../../specs/003-editar-remover-ferramentas/spec.md)
**Plan**: [plan.md](../../../specs/003-editar-remover-ferramentas/plan.md)

## Sprint goal {#objetivo-do-sprint}

The "no longer observed" mark goes back to meaning what it says, and the platform learns
how to end the observation of an organization.

## Two things wrong before starting {#duas-coisas-erradas-antes-de-começar}

Recorded instead of omitted, because both are mine.

**I implemented 003 without opening a sprint.** The `sprint-backlog` skill says, in its first
line, that it is mandatory before implementing — and I went from `tasks.md` straight to the
code. The work is traceable through the 30 tasks, but it stayed outside the sprint while it
was happening. This document brings it inside, declaring what was already done.

**The sprint 002 window has not closed yet.** The iteration says 2026-08-10 to 2026-08-16, and
the sprint was closed and accepted **on the first day**. It is the second time the declared
duration does not match the actual one — the first became part of [L17](../licoes-aprendidas.md).

This sprint starts on 08/11 and the 002 iteration still says 08/16. Fixing it requires
touching the iterations configuration, which is what caused [L11](../licoes-aprendidas.md)
and cost reassigning 96 items. **It stays as a pending decision**, not as a silent
fix.

## Inheritance — everything with a destination, before new scope {#herança--tudo-com-destino-antes-de-escopo-novo}

It is the rule the `product-owner` skill now requires. An open item without a destination is not
work, is not a decision and is not a discard.

| What was left over | From where | Destination |
|---|---|---|
| **L19 — absence mark without organization scope** | feature 001 | **first phase of this sprint.** It is active and wrong right now |
| **003: F1, F2 and F3 implemented** | this feature, outside a sprint | **recorded as done**, with the reason. What is ready and verified is not redone |
| **003: US2 — resume** | this feature | **enters this sprint**, after L19 |
| **003: US3 and remaining screens** | this feature | **outside this sprint**, with the cost declared below |
| **US2 and US3 of feature 002** | sprint 002 | **in the product backlog**, no iteration — decision already made |
| **Elixir/Python parity** | sprints 001 and 002 | **declared debt**: 4 checks against 12. The Python gate is the one that decides, and it runs in CI |
| **10 team memberships without backing** | feature 002 | **closed by declared limitation**, with the concept named in each mapping |
| **`connected_tools.status` materializes situation** | feature 001 | **declared debt**, against ADR 0004 D7. Not widened by 003 |
| **Recorded review approval** | sprints 001 and 002 | **blocked by tooling**: with a single identity, the author does not approve. It closes with a bot or a GitHub App |
| **Feature 004 — scheduling** | the maintainer's queue | **does not enter**, and the reason is below |

## Why L19 comes before everything {#por-que-a-l19-vem-antes-de-tudo}

It is not priority by severity alone. It is **dependency**.

The promise of resume is *"the next collection restores the in-force status of what the source still
shows"*. With L19, the collection marks and unmarks wrongly — there would be no way to **demonstrate**
resume working, only to claim it. Delivering US2 on top of L19 would produce a check
that passes without proving anything.

And the defect is active: `EduardoNFraiz` shows up with zero organizations in force while being in
two observed ones. Every query that asks only for what is in force returns less than the platform
observes.

## Why 004 does not enter {#por-que-a-004-não-entra}

**Scheduling amplifies L19.** Today the damage requires someone to trigger a collection; with
periodic sync, each run re-marks the team memberships of the other organizations
on its own, with nobody watching.

Specifying 004 now would also make it assume an observation API that 003 may still
change.

## Lessons applied {#lições-aplicadas}

From the [accumulated record](../licoes-aprendidas.md) — nineteen lessons, L01 to L19.

| Lesson | What changes in this sprint |
|---|---|
| **L19** | it is the scope of the first phase, and the fix needs a test with **two** organizations and two collections in sequence — the shape the 151 tests did not have |
| **L18** — one criterion met is not enough | the L19 check does not stop at "the right team membership was marked": it also checks that **no other** one was |
| **L17** — execution reveals what implementation hides | L19 only appeared when demonstrating on the real database. This sprint demonstrates again, after the fix |
| **L03** — a test with invalid data finds what the happy path hides | the L19 test is the violation: collect A and check that B was not marked |
| **L11** — configuring iterations recreates the existing ones | no iteration change without a snapshot first |
| **L12** — a PR not opened right away carries another feature | the 003 PR is opened when the phase calls for it |
| **L14, L15** — review | every PR is born with a reviewer requested, and the approval gap is declared |

## Scope {#escopo}

| # | Phase | State |
|---|---|---|
| **F0** | Inheritance: fix L19 | **to do** — first |
| F1 | Knowledge base: two causes | **done**, outside a sprint |
| F2 | Append-only events and derived state | **done**, outside a sprint |
| F3 | End: mark per team membership, destroy credential | **done**, outside a sprint |
| F4 | US2 — resume | to do |
| F5 | US3 and remaining screens | **out of scope** |

## MVP {#mvp}

**F0 and F4.** The L19 fix and resume.

**The cost of leaving F5 out, declared**: without the screens of T019 to T022, ending exists
in the API and the tools list does not distinguish the three states. Whoever ends via the API will not
see the result reflected. **The ending screen exists** — it was delivered with F3 —,
so the main path is covered.

## Risks {#riscos}

| Risk | Mitigation |
|---|---|
| **Fixing L19 marks too little** | the opposite of the current defect, and equally wrong. The test checks both sides: what should be marked is, and what should not is not |
| **The current data is already marked wrongly** | the fix changes future behavior; the past requires a separate decision — do not unmark on our own, because it is not known what the source showed |
| **Touching iterations** | no change without a snapshot; the discrepancy in the 002 window stays declared |

## Definition of Done {#definition-of-done}

- [ ] nine green quality gates
- [ ] L19 has a test with two organizations and two collections in sequence
- [ ] the fix is demonstrated on the real database, and `EduardoNFraiz` again shows two
      organizations in force
- [ ] `sprint-review.md` written, separating done from not done
- [ ] `aceitacao.md` walking through the criteria
- [ ] `licoes-aprendidas.md` updated
- [ ] **independent review** — declared, never marked as fulfilled by whoever implements
