# Sprint 002 — Acceptance record {#sprint-002--registro-de-aceitação}

**Feature**: [002-escopo-por-organizacao](../../../specs/002-escopo-por-organizacao/spec.md)
**Assessed on**: 2026-08-10
**Role**: Product Owner — Paulo Sérgio dos Santos Júnior
**Confirmed on**: 2026-08-10 — *"D01 .. accepted"* *(original: "D01 .. aceito")*

**Product Owner type**: `sro.product_owner_client` — the maintainer is also the one who
makes the demand. The acceptance decision is final, not representative.

> **Confirmed by the role.** Each criterion was walked through against evidence, the
> classification was derived from what the evidence supports, and the person allocated to the role
> confirmed: **D01 accepted**. The phase is valid from here on.

## Summary {#resumo}

| | Count |
|---|---:|
| Deliverables assessed | 1 — D01 |
| Functional criteria walked through | 5 |
| Non-functional criteria walked through | 6 |
| Accepted | **1** — D01, confirmed |
| Criteria without evidence | 0 |
| User stories not delivered | 2 — US2 and US3 |

---

## D01 — Each record says which organization it came from {#d01--cada-registro-diz-de-qual-organização-veio}

**Materializes**: US1 (atomic) · [#80](https://github.com/The-Band-Solution/theband/issues/80)
**Produced by**: T001 to T012, T020 to T024 · issues
[#83](https://github.com/The-Band-Solution/theband/issues/83),
[#84](https://github.com/The-Band-Solution/theband/issues/84),
[#85](https://github.com/The-Band-Solution/theband/issues/85),
[#86](https://github.com/The-Band-Solution/theband/issues/86)

### Functional criteria {#critérios-funcionais}

| Criterion | Conforms | Evidence |
|---|---|---|
| AC1 — two organizations collected; each person shows the organization they came from | **yes** | `/pessoas` has the "organizations" column; interface test `/pessoas mostra as organizações de cada pessoa`. In the real database, all 72 people have an organization — V9 returns **0** without one |
| AC2 — an account in two organizations appears **once**, showing both | **yes** | test `a pessoa em duas organizações aparece uma vez, com as duas` counts the occurrences in the HTML; in the real data, `Paulo` appears once with three organizations and `EduardoNFraiz` with two |
| AC3 — each team shows the organization it belongs to | **yes** | `/equipes` has the column; test `/equipes mostra a organização de cada equipe`. No organizational team can be left without one — the database refuses |
| AC4 — two organizations with teams that share the same short identifier stay distinct | **yes, by construction** | the Application Reference is `source_system + source_instance + external_id`, and GitHub's `external_id` is unique per team; the `slug` takes no part in the identity. **Caveat**: there was no slug collision across the three real organizations, so this is guaranteed by the model and not observed in data |
| AC5 — a connected organization that has not been synced appears with no records, and the empty state says the collection did not happen | **yes** | `empty_message/2` distinguishes "no sync has brought people yet" from "no person matches the filters"; test `estado vazio explica a causa em vez de só dizer que está vazio` |

### Non-functional criteria assigned to this user story {#critérios-não-funcionais-atribuídos-a-esta-user-story}

| Criterion | Conforms | Evidence |
|---|---|---|
| SC-001 — 100% of people and teams indicate the organization | **yes** | V9: 0 of 72 people without an organization; no organizational team without one, guaranteed by the `check_constraint` |
| SC-003 — an account in two organizations appears once unfiltered and in both filtered views | **yes** | interface test, plus V7 and V8 on real data |
| SC-003a — **no person is left without an organization** | **yes** | V9: from 18 before the derivation to **0** after |
| SC-004 — the sum per organization is ≥ the total, and the difference is the number of overlaps | **yes** | total 72, sum 75, and V8 finds exactly 3 overlapping team memberships (`Paulo` in 3 organizations accounts for 2 of the difference, `EduardoNFraiz` in 2 accounts for 1) |
| SC-005 — previously collected records receive the team membership **without querying the source** | **yes** | V3: 10 of 10 assigned, 0 unresolved. The five tests run **with no expectation on the HTTP-edge Mox** — any call would bring them down |
| SC-007 — two teams from different organizations with the same short identifier remain distinct | **yes, by construction** | same caveat as AC4 |
| SC-009 — an organization with members outside teams gets **exactly one** derived team, with **exactly** the ones that were missing | **yes** | all three cases occurred in real data: The-Band-Solution 6/6 in teams → no derived team; ifesserra-lab 5 members, 0 teams → derived with 5; leds-conectafapes 64 members, 15 outside → derived with 15 |

**Phase**: `sro.accepted_deliverable` — the five functional and the seven non-functional
criteria conform, with evidence. **Derived from the criteria and confirmed by the role
on 2026-08-10**, in that order: the classification followed from the assessment, and the confirmation
came afterwards. Reversing the order is what `sro.rule03` forbids.

**Phase of the tasks**: T001 to T012 and T020 to T024 are
`sro.successfully_performed_scrum_development_task` — all of them produced only
accepted deliverables. **No task in this sprint was performed unsuccessfully**, and the
distinction matters: the four tasks whose definition was wrong had their *definition*
corrected, not their deliverable refused.

### Two caveats that come with the acceptance {#duas-ressalvas-que-acompanham-a-aceitação}

They do not prevent it, and are recorded so that nobody later confuses one thing with the
other.

**AC4 and SC-007 are guaranteed by the model, not observed in data.** No
`slug` collision between the three real organizations occurred. What supports the criterion
is that the Application Reference does not include the `slug`, which is strong — but it is an argument by
construction, not a measurement.

**The emptying of the derived team is covered by a test, not by an occurrence.**
It would require a person to join a real GitHub team between two collections. Same
class as the "absence is not removal" limitation in sprint 001.

---

## A defect the assessment would have let through {#um-defeito-que-a-avaliação-teria-deixado-passar}

Recorded here because it is the most useful piece of information in this document.

The first run of V9 returned **0 people without an organization** — criterion SC-003a
met. And it was wrong: `ifesserra-lab`, with 5 members, had received **72**
people in the derived team, the whole tenant. All three organizations started
showing all 72 people.

**Criterion SC-003a passed, and the platform was lying.** Only reading the
counts per organization — which is SC-009, not SC-003a — exposed the problem.

The lesson for this role: **a criterion met is not a sufficient criterion.**
Walking through the criteria one by one found the defect because SC-009 requires "exactly the
members that were missing", and 72 is not 5. A record content with V9 would have
accepted the deliverable.

---

## User stories not delivered {#user-stories-não-entregues}

| # | User story | State | Proposed destination |
|---|---|---|---|
| US2 | Query one organization at a time | the filter exists in the queries and is tested; the selection screen was not built | **returns to the product backlog**, with the query part already done recorded |
| US3 | See who crosses organizations | the query answers and `/pessoas` already signals "in N organizations"; the dedicated screen and `list_people_in_several_organizations/2` are missing | **returns to the product backlog** |

**Neither of them produced a deliverable**, so there is no deliverable to refuse: they were
not performed, which is different from having been performed unsuccessfully. No task
of US2 or US3 is `sro.non_successfully_performed_scrum_development_task`.

Both were **outside the declared MVP** in the sprint backlog, which was F1, F2, F3, US1
and F7. The sprint delivered the MVP.

## Sprint deliverable {#entregável-do-sprint}

`sro.sprint_deliverable_composed_of_accepted_deliverable` admits only accepted
deliverables.

| Composition |
|---|
| **D01** — confirmed on 2026-08-10 |

## Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

**No acceptance criterion was changed.** Four **tasks** had their definition
corrected — T001, T003, T007 and T020 —, because what they asked for was unverifiable or
impossible. Each correction is written in the task itself. No user story
criterion changed.

## Criteria without evidence {#critérios-sem-evidência}

**None.** The five functional and the seven non-functional criteria were assessed against
executed evidence.

## What the acceptance does **not** unlock {#o-que-a-aceitação-não-destrava}

| What | By whom | Where |
|---|---|---|
| acceptance of the deliverables | Product Owner — this document | `aceitacao.md` |
| **independent code review** | Reviewer, someone who did not implement it | pull request approval |

### The review of PR #93, and what it is {#a-revisão-do-pr-93-e-o-que-ela-é}

**2026-08-10** — [PR #93](https://github.com/The-Band-Solution/theband/pull/93)
merged into `main` at `f8941ee`, with one recorded review:

```text
GET /repos/.../pulls/93/reviews
  paulossjunior  COMMENTED  2026-08-10T21:24:21Z
```

**It is a record, and it is not an approval.** GitHub refuses `requested_reviewer` for the author of the
PR — `422 Review cannot be requested from pull request author` —, and refuses the author
approving their own PR. No permission level gets around it: the maintainer is admin
of the repository and of the organization, and the refusal is the same.

What is asserted, then, is the strongest the evidence supports and no more than that:

| Question | Answer | Evidence |
|---|---|---|
| does what was delivered meet what was specified? | **yes** | this document, 5 functional and 7 non-functional criteria |
| do the gates pass? | **yes** | nine green, including the reproducibility one |
| was the code read by a human who did not write it? | **yes** | review recorded in `pulls/93/reviews`, with a date |
| is there a recorded **approval**? | **no** | the review is `COMMENTED`; GitHub does not allow `APPROVE` from the author |

This is better than sprint 001, where the review existed only as an attestation in this
file — an attestation depends on who remembers, a record does not. And it is still below what
principle VII asks for.

**The cause is named, and it is a tooling one.** The one who implemented is the agent, whose commits
carry `Co-Authored-By: Claude Opus 5` and who has no account; whoever opens the PR with their own
token is recorded as the author without having written the code. It is closed by opening the PRs with
an agent identity — GitHub App or bot account —, and then this same review can be
an `APPROVE`.

**Two identical reviews were left on #93**, from repeating the command. A submitted review
cannot be deleted through the API — only a draft. Noise recorded instead of hidden.

**The residue from sprint 001 cannot be recovered**: #89, #90 and #91 were merged without
any recorded review, and there is no way to review a merged PR.

## Decisions of the role {#decisões-do-papel}

| Decision | Outcome |
|---|---|
| classification of D01 | **accepted** on 2026-08-10, with the two caveats recorded — slug collision guaranteed by the model and not observed; emptying of the derived team covered by a test and not by an occurrence |
| destination of US2 and US3 | **return to the product backlog** — done: iteration cleared and status `Backlog` on items [#81](https://github.com/The-Band-Solution/theband/issues/81) and [#82](https://github.com/The-Band-Solution/theband/issues/82), which remain open |
| debt of the 10 unbacked links | **closed by declared limitation**, with the concept id named in each mapping. Closing it for real requires declaring 10 relations across 5 ontologies — a feature of its own |

**The caveats accompany the acceptance and do not dilute it.** A deliverable accepted with
a recorded caveat is different from one accepted with none, and whoever reads later needs
to be able to tell the two apart without investigating.
