# Sprint 001 — Acceptance record {#sprint-001--registro-de-aceitação}

**Feature**: [001-github-eo-ingestion](../../../specs/001-github-eo-ingestion/spec.md)
**Evaluated on**: 2026-08-10
**Role**: Product Owner — **to be confirmed by Paulo Sérgio dos Santos Júnior**

**Product Owner type**: `sro.product_owner_client` — the maintainer is
also the one who makes the demand. Consequence: the acceptance decision is **final**, not
representative, and does not carry the residual risk of divergence from an
absent client.

> **This document proposes; it does not decide.** The agent evaluated each criterion against
> evidence and derived the classification the evidence supports. The phase of each
> deliverable only takes effect once the person allocated to the role confirms it.

## Proposed summary {#resumo-proposto}

| | Count |
|---|---:|
| Deliverables evaluated | 3 |
| Acceptance criteria walked through | 14 functional + 10 non-functional |
| Accepted, after the fix in #88 | 3 |
| Not accepted in the first evaluation | 1 — D01 |
| Criteria without evidence | 0 |
| Tasks performed without success | 2 — T033, T038 |

---

## D01 — Connected tool with protected credential {#d01--ferramenta-conectada-com-credencial-protegida}

**Materializes**: US1 (atomic) · [#3](https://github.com/The-Band-Solution/theband/issues/3)
**Produced by**: T032 to T040 · issues [#37](https://github.com/The-Band-Solution/theband/issues/37) to [#45](https://github.com/The-Band-Solution/theband/issues/45)

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — an admin connects GitHub by providing the instance and a valid credential; the platform confirms access and registers the tool | functional | **yes** | three organizations connected against the real GitHub: `The-Band-Solution`, `ifesserra-lab`, `leds-conectafapes`; scopes returned `gist, project, read:org, repo, workflow` |
| AC2 — an invalid credential, or one without permission, is refused with an explanation, and nothing is stored | functional | **yes** | a run with an invalid token returned `:unauthorized`; tool count before 1, after 1. Tests `credencial recusada não grava nada` and `escopo insuficiente recusa nomeando o que falta` |
| AC3 — the credential appears only as a partial identification, never in usable form | functional | **yes** | the screen shows the masked credential with only its last characters [redigido]; token absent from the HTML of the four screens; `select secret` returns an `AES.GCM.` ciphertext [redigido]; a test guarantees that no error message leaks a struct |
| AC4 — two service accounts on the same GitHub coexist and can be **used or deactivated independently** | functional | **yes**, after the fix | see the re-evaluation below. Five tests in `test/the_band/sources_test.exs`: deactivating the one in use makes the other one be used; reactivating returns it to the selection; with none active the sync is refused with `:no_active_credential`; deactivating one does not change the other |
| AC5 — a credential that stopped working marks the tool as needing attention, with date and reason, without interrupting the others | functional | **yes** | test `marcar uma não afeta as outras do tenant`; test `credencial revogada durante a coleta` checks `status = needs_attention`, `needs_attention_since` filled in and the sync in `interrupted` with progress preserved |

**Non-functional criteria assigned to this user story**

| Criterion | Conforms | Evidence |
|---|---|---|
| SC-001 — connect and validate in under 2 minutes, without consulting documentation | **yes** | a single-screen form, with immediate validation and a message saying what was missing |
| SC-005 — no credential recoverable from the database, the logs or the interface | **yes** | the three checks of AC3, plus the key rotation that proved the secret intact with only the new key |

### First evaluation — 2026-08-10 {#primeira-avaliação--2026-08-10}

**Derived phase**: `sro.not_accepted_deliverable` — it failed AC4.

**Confirmed by the maintainer**: "D01 stays as not accepted." *(original: "D01 fica como não aceito.")*

**Phase of the tasks**: T033 and T038, which produced the credential registration and the
screen, stay `sro.non_successfully_performed_scrum_development_task` —
permanently. They were performed and did not produce an accepted deliverable, and that
is the information the measure `rework.not_accepted_deliverable_ratio` computes.

**What was missing**: verification that deactivating a credential makes the collection
switch to using the other one. `Sources.active_credential/1` picked the most recent active one, so
the behavior probably existed — **probably is not evidence**.

**Chosen destination**: a new intended task
[#88](https://github.com/The-Band-Solution/theband/issues/88), linked to the same
US1. T033 and T038 were **not** reopened.

### Re-evaluation — 2026-08-10, after #88 {#reavaliação--2026-08-10-após-88}

The fix found more than the missing test.

**A latent defect.** `active_credential/1` ordered only by
`validated_at`. Two credentials registered **in the same second** — the normal case
when both come in through the same form or by script — tied, and the database
broke the tie in whatever order it pleased. The same database state could pick
different credentials across runs.

This matters because different credentials see different sets: the same
sync would bring different data without anything having changed at the source, and the record
would say which credential was used without saying **why that one**.

Fixed with two tie-break criteria — creation instant and identifier —
whose function is to make the choice deterministic, not to express a preference.

**Contract gap fixed in the same commit**, as principle VI requires: the
contract `connected-tools.md` did not say which credential was chosen among the
active ones. Now it does, with the reason.

**Honesty about the strength of the evidence**: the determinism test repeats the
query twenty times and always gets the same credential. That does not **prove** that the
previous version was unstable in practice — Postgres may be stable by
accident of the execution plan. What is claimed is weaker and sufficient: without a
tie-break criterion, the ordering is indeterminate by SQL semantics, and
relying on an implementation accident is no guarantee.

**Derived phase now**: `sro.accepted_deliverable` — the five functional
criteria and the two non-functional ones of US1 conform, with evidence.

**The phase of the tasks does not change.** T033 and T038 remain
`sro.non_successfully_performed_scrum_development_task`, and #88 is a new
successful task. The effort shows up twice because it was spent twice.

---

## D02 — Roster of people and teams collected {#d02--quadro-de-pessoas-e-equipes-coletado}

**Materializes**: US2 (atomic) · [#4](https://github.com/The-Band-Solution/theband/issues/4)
**Produced by**: T041 to T060c · issues [#46](https://github.com/The-Band-Solution/theband/issues/46) to [#65](https://github.com/The-Band-Solution/theband/issues/65)

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — the sync makes the platform know the organization, its people and its teams | functional | **yes** | three organizations collected: 3 observed organizations, 72 people, 10 teams, 62 team memberships. `leds-conectafapes` alone: 128 records collected, 71 created |
| AC2 — the second sync neither duplicates nor alters a record whose source did not change | functional | **yes** | second run: `criados 0, atualizados 0`; counts unchanged from 6 → 6 people and 2 → 2 teams in the first organization |
| AC3 — an interrupted sync resumes where it stopped | functional | **yes** | resume test: with a checkpoint stored, the next run asks for `after: cursor-1` — the **next** page, not the first |
| AC4 — an automation account is registered and classified separately, without counting as a person | functional | **yes, with a caveat** | test `conta de automação é classificada pelo __typename do payload` checks that `bot` is classified and kept out of the people count. **Caveat**: no automation appeared in the three real organizations — automations: 0. The path is proven by fixture, not observed in real data |
| AC5 — the person–team membership is preserved with the observed access level, and remains pending a role | functional | **yes** | 62 pending team memberships; the members screen shows `MAINTAINER` and `MEMBER` in the column labeled **access on the platform**, with the organizational role marked as pending |
| AC6 — on noticing the usage limit is near, it pauses and resumes on its own, without losing progress and without failing | functional | **yes, with a caveat** | a test with a tight simulated window returns `{:snooze, n}`, preserves the cursor and keeps the sync in progress. **Caveat**: GitHub's real limit was never reached — 4,656 points remaining in the largest collection |

**Non-functional criteria assigned to this user story**

| Criterion | Conforms | Evidence |
|---|---|---|
| SC-002 — 100% of the source's people and teams registered | **yes** | checked against the three organizations |
| SC-003 — second sync creates 0 and alters 0 | **yes** | see AC2 |
| SC-006 — resuming queries at most one extra page | **yes** | see AC3 |
| SC-007 — a mapping fix applied without querying the source | **yes** | reprocessing of 32 payloads: 0 created, 0 updated, 32 unchanged; the test runs with no expectation on the HTTP-edge Mox, so any call to GitHub brings it down |
| SC-009 — an organization with up to 100 people and 20 teams completes without manual intervention, **even when hitting the limit** | **partially** | the volume is within the statement and was exercised: 64 people and 8 teams completed without intervention. The clause "even when hitting the limit" is covered by a test, not by a real occurrence |
| SC-010 — team memberships pending a role presented explicitly | **yes** | `62` in the sync report and in the header of `/equipes` |

**Derived phase**: `sro.accepted_deliverable` — all functional criteria
conform, with evidence.

**Caveats that accompany the acceptance**, and that do not prevent it: AC4 and AC6 are
proven by test and not by an occurrence in real data. It is the difference between "the
code handles the case" and "the case happened and was handled". Recording it here is what
lets someone later know which of the two things was verified.

---

## D03 — Query with provenance {#d03--consulta-com-proveniência}

**Materializes**: US3 (atomic) · [#5](https://github.com/The-Band-Solution/theband/issues/5)
**Produced by**: T061 to T068 · issues [#66](https://github.com/The-Band-Solution/theband/issues/66) to [#73](https://github.com/The-Band-Solution/theband/issues/73)

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — the people list shows each person with their source, their identifier in the tool and the collection date | functional | **yes** | `/pessoas` shows the 72 with `github`, `https://github.com`, the GitHub identifier and `collected_at` |
| AC2 — the teams list shows each team, who belongs to it, and how many team memberships lack a role | functional | **yes** | `/equipes` shows the 10 with source and identifier; `/equipes/:id` shows members with access on the platform and pending role; the header carries the count of pending ones |
| AC3 — the user sees exclusively data from their own organization | functional | **yes** | two populated tenants; a session of `outra-org` shows 0 people and 0 teams; another tenant's team id returns a redirect, not the record; nine interface tests cover the path |

**Non-functional criteria assigned to this user story**

| Criterion | Conforms | Evidence |
|---|---|---|
| SC-004 — 100% of records show source, identifier and date | **yes** | checked on the 72 rows |
| SC-008 — a user of one organization does not see another's data by any path | **yes** | see AC3 |

**Derived phase**: `sro.accepted_deliverable`.

### A note on AC1 that belongs in the record {#uma-observação-sobre-ac1-que-pertence-ao-registro}

The criterion asks for "their source". It was written when there was **one** observed
organization, and "source" meant system and instance. With three organizations,
`github / https://github.com` no longer identifies where the person came from — and the
criterion, as worded, **is still met**.

This does not change D03's acceptance: the deliverable does what the criterion asks. But
it records that **the criterion did not catch the defect** that feature 002 exists to
fix. It is information about the quality of the criterion, and the responsibility for
it belongs to this role.

---

## Sprint deliverable {#entregável-do-sprint}

`sro.sprint_deliverable_composed_of_accepted_deliverable` admits **only**
accepted deliverables.

| Moment | Composition |
|---|---|
| first evaluation | **D02 and D03** — D01 out, due to failing AC4 |
| after #88 | **D01, D02 and D03** |

The record keeps both moments on purpose. A sprint whose deliverable
needed a fix to become complete is different from one born complete, and
erasing the first evaluation would erase that difference — which is exactly the rework
measure the product exists to compute.

---

## Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

No acceptance criterion was changed. Two **tasks** had their wording
corrected — T005 and T019 —, because they promised more than they delivered; no
user story criterion changed.

## Criteria without evidence {#critérios-sem-evidência}

**None.** The 14 functional criteria and the 10 non-functional ones were evaluated
against evidence.

There was one — AC4 of US1 — and it was closed by #88. The record of that passage is
in D01's re-evaluation, not erased from here.

### Two checks that remain by test, and not by occurrence {#duas-verificações-que-continuam-sendo-por-teste-e-não-por-ocorrência}

They do not prevent acceptance, and are recorded so that no one later confuses one
thing with the other:

| Criterion | Why there was no real occurrence |
|---|---|
| AC4 of **US2** — automation classified separately | no automation account exists in the three observed organizations |
| AC6 of **US2** — pause before the usage limit | the real limit was never reached; the largest collection ended with 4,656 points remaining |
| Edge case — absence is not removal | it would require **removing someone from a real team** in the maintainer's organization. It was not done, and should not be: the test covers the behavior, and altering another person's organization to validate software is a price not worth paying |

---

## What acceptance does **not** unlock {#o-que-a-aceitação-não-destrava}

Two distinct things are pending, and confusing them would let the merge happen without
what the constitution requires:

| What | Whose | Where |
|---|---|---|
| **acceptance of the deliverables** | Product Owner — this document | `aceitacao.md` |
| **independent code review** | Reviewer, someone who did not implement | pull request approval |

Principle VII speaks of the second.

Accepting D02 and D03 does not approve their code. They are different questions: the PO
asks whether what was delivered meets what was specified; the reviewer asks whether the code
is correct, secure and compliant.

### The merge happened, and the independent review did not {#o-merge-aconteceu-e-a-revisão-independente-não}

**2026-08-10** — [PR #89](https://github.com/The-Band-Solution/theband/pull/89)
merged into `main` at `45d21a0`, by decision of the maintainer, with CI
green.

**`GET /repos/.../pulls/89/reviews` returns an empty list**, and the same holds for #90 and
#91. No formal approval was recorded on any of the three.

### The review happened; what didn't is the record {#a-revisão-aconteceu-o-registro-é-que-não}

**Attested by the maintainer on 2026-08-10**: *"I looked and agreed, that's why
I didn't leave a comment."* *(original: "eu olhei e concordei, por isso não coloquei comentário.")* The code reading took place before each merge. What does not
exist is the formal approval on GitHub.

This matters more than it seems, because **it corrects a misreading of principle VII
that this document propagated**. The previous version of this section said that the PR author is
whoever implemented, and concluded that the review could not have happened. That is wrong:

| Role | Who it is | How GitHub sees it |
|---|---|---|
| **who implemented** | the agent — the commits carry `Co-Authored-By: Claude Opus 5` | does not appear; has no account |
| **who reviewed** | `paulossjunior`, who read and agreed | recorded as the PR **author**, because the PR was opened with his token |

The `422 Review cannot be requested from pull request author` is, in this project, **a
tool artifact and not a conflict of interest**. GitHub has no way to
express that the implementer is an agent without an account, so it assigns authorship to whoever
operated the tool — and then prevents that person from reviewing what they did not write.

### What remains true {#o-que-continua-sendo-verdade}

| Question | Answer | Evidence |
|---|---|---|
| does what was delivered meet what was specified? | **yes** | this document, 14 functional and 10 non-functional criteria |
| do the quality gates pass? | **yes** | eight green gates, locally and in CI |
| was the code read by a human who did not write it? | **yes** | the maintainer's attestation, 2026-08-10 |
| is there a recorded, verifiable approval? | **no** | `pulls/{89,90,91}/reviews` empty |
| is the code on `main`? | **yes** | `45d21a0`, `41b8636`, `82ce72f` |

The fourth row is the real gap, and it differs from the one this document asserted
before. **What is missing is not review — it is proof of review.** The distinction is not formalism:
an attestation depends on who remembers, and a record does not. A project whose thesis is provenance
cannot have its own review sustained by memory.

### What would close the gap {#o-que-fecharia-a-lacuna}

Three paths, in order of solidity:

| Path | What changes |
|---|---|
| **open the PRs with an agent identity** — bot or GitHub App | the implementer becomes the actual author, and `paulossjunior` can **formally approve**. It fixes the cause, not the symptom |
| approval by `Adylla027` or `EduardoNFraiz` | a second human reviewing; already possible today, since the `the-band` team was granted access |
| record the attestation on the PR itself, as a comment | weaker, and still better than nothing: it is dated and public instead of spoken |

**None of this is recoverable for #89, #90 and #91**: a merged PR does not receive a review. The
attestation above is the record those three will have.

**What the merge changes for the following sprints**: the exception sprint 002 took on
stops being about code outside `main` and becomes about code **inside** it with
review attested and not recorded. The risk decreased — it did not disappear.

---

## Decisions awaiting the role {#decisões-que-aguardam-o-papel}

**1. Confirm or change the proposed classification**

| Deliverable | Proposed |
|---|---|
| D01 — connected tool | **not accepted** — AC4 without evidence |
| D02 — roster collected | accepted, with two recorded caveats |
| D03 — query with provenance | accepted |

**2. Destination of US1, if D01 is confirmed as not accepted**

| Option | When it fits | What happens |
|---|---|---|
| goes back to the product backlog | the value still stands, with no urgency | leaves the iteration, reprioritized by importance |
| enters sprint 002 | the gap is small and worth closing now | a **new** intended task linked to US1, in sprint backlog 002 |
| accept with the gap recorded | credential independence is not used today | requires changing the acceptance decision explicitly, not silently |

The second looks the cheapest: what is missing is a test, not a feature. But the
choice belongs to the role.

**Do not reopen T033 or T038.** They remained performed and unsuccessful;
reopening them would erase the rework record, which is precisely what the measure
`rework.not_accepted_deliverable_ratio` computes. A new intended task, linked to the
same user story.
