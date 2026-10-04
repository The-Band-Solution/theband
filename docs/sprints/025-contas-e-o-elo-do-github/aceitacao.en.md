# Sprint 025 — Acceptance record {#sprint-025--registro-de-aceitação}

**Evaluated on**: 2026-08-29, on `development` (PRs #611 and #612 merged), by the
product-owner role with executed evidence. **Confirmed by the maintainer on
2026-08-29** in the four reserved decisions: the four verdicts as proposed; the
status labels classified as the HEEx-leftover class (keeps #574 accepted);
complete rework for #598.

## Verdict per user story {#veredito-por-user-story}

| US | Issue | Verdict | Decisive criterion |
|---|---|---|---|
| 047/US1 — errors in the catalog | #573 | **NOT ACCEPTED (second time)** | The rework closed 024's counterexample and left its sibling: 5 refusals as literals reaching the screen BEHIND a function call (`PatternValidator.explicar/1` — the domain fabricating a screen sentence, against the contract's own rule — and projects_live's `primeira_mensagem/1`, which still discards the Ecto msgids that `errors.po` ALREADY has). Editing the catalog does not change those sentences: AS1 fails to the letter. The class is finite (grep for the form: only those 2 helpers) |
| 047/US2 — system messages in the catalog | #574 | **ACCEPTED with caveats** | The three causes of 024's refusal closed with evidence (dgettext at the points, leftovers redone with sampling, conditioned FR-007 recorded). Caveats: `origem_rotulo/1` classified by the role's decision as HEEx-leftover — it goes in named in the leftovers; the claim "FR-007's reason lives in the HEEx comments" was not confirmed at the three "Checks" points (gap in the claim's proof, corrected in the leftovers) |
| 051/US1 — register name+e-mail | #597 | **ACCEPTED with caveats** | 3/3 scenarios with evidence; the change to 045's test is legitimate (L71, reason in the test). Caveats: [redigido] (diverges from the moduledoc); two tests promised in the contract do not exist (query count L38 and temporary-password count) — behavior checked by reading, proof pending |
| 051/US2 — link the GitHub account | #598 | **NOT ACCEPTED** | 5 AS and 4 SC conforming; TWO edge criteria that the spec (lines 93-97), contract and tasks require fail: the search result does not show the ORGANIZATION (namesakes) and the ENDED OBSERVATION is not stated. The comment in the code ("organização não") contradicts the contract WITHOUT a recorded correction — the rule "a contract error is corrected in the same commit, with the reason" was not followed. Narrow refusal: everything else conforming |

## Derived phases {#fases-derivadas}

| Deliverable | Tasks | Materializes | Phase |
|---|---|---|---|
| D1 — migration of the 9 sentences + checker v2 | #609 | #573, #574 | `sro.not_accepted_deliverable` |
| D2 — leftovers redone + US3 aligned | #610 | #574 | `sro.accepted_deliverable` |
| D3 — registration with temporary password | #599, #600, #602 | #597 | `sro.accepted_deliverable` |
| D4 — the link in the area | #601, #603–#606 | #598 | `sro.not_accepted_deliverable` |

Successful tasks: #610, #599, #600, #602. Unsuccessful: #609, #601, #603–#606.
Sprint deliverable composed of **D2 and D3**. Rework: 2 of 4 deliverables.

## The rework, named (sprint 026's inheritance, first in the queue) {#o-retrabalho-nomeado-herança-do-sprint-026-primeira-da-fila}

1. **#573 (new task)**: the edge translates the reason — `PatternValidator` returns
   tuples and `humanizar/1` gains the missing clauses; `primeira_mensagem/1` and
   accounts_live's `motivo/1` go through the catalog (the Ecto msgids ALREADY exist in
   `errors.po`). 5 sentences + 2 helpers — migrating costs less than enumerating. And the lesson:
   hunt the counterexample's SIBLINGS by the class pattern before delivering.
2. **#598 (new task)**: organization in the search result (namesakes are decided by the
   identifier WITH context, as spec/contract/tasks wrote) and the
   ended-observation mark in the result.

## Process (DoD of the 025 backlog) {#processo-dod-do-backlog-025}

024's two violations **did not repeat**: review requested +1s after opening on
both PRs, and both on the board with Iteration and Status. Caveats: the request went to people
(the house procedure asks for the `the-band` TEAM); recorded reviews remain zero —
merges by the author ~50min after opening, under the maintainer's authorization
"go ahead and close it" *(original: "pode fechar")*, recorded in this session. State: *review did not happen, request
recorded* — the residue of the #89/#593/#594 family keeps accumulating; the
structural way out (PR opened by an agent identity) remains pointed out and undecided.
Issues in the right order: opened during the evaluation, closed AFTER this record.
