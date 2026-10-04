# RFC 0001 — Derivation of the information model from the ontology network

**Status**: Open for comments
**Created**: 2026-08-09
**Related**: [ADR 0004](../adr/0004-modelo-de-informacao-one-table-per-kind.md)

## Summary

[ADR 0004](../adr/0004-modelo-de-informacao-one-table-per-kind.md) decided
*how* to transform the ontology into an information model: `one table per kind`, from
Guidoni, Almeida & Guizzardi (2020). This RFC gathers what that decision does **not**
resolve, and what needs to be discussed before generating migrations.

Ten questions. Five block the derivation; the others affect performance, ingestion
scope or modularity. Each one carries context, alternatives measured when it was
possible to measure, and what it holds up.

A question leaves this list in one of two ways: by becoming an ADR, when the decision is
architectural and expensive to reverse, or by becoming work in the knowledge base,
when it is a modeling matter.

**Convention**: a stable `Q<n>` — numbers are not recycled. A resolved question
stays on the list, marked, with its destination recorded.

| # | Question | Blocks | Priority |
|---|---|---|---|
| [Q1](#q1) | How to handle perdurants, which the method does not cover | model derivation | **high** |
| [Q2](#q2) | Application boundary: network, ontology or module | 26 vs 94 tables | **high** |
| [Q3](#q3) | Imported kind: copy or reference | schema and autonomy | **high** |
| [Q4](#q4) | OntoUML stereotype of 142 concepts | the method does not run | **high** |
| [Q5](#q5) | Undeclared generalization sets | discriminator vs table | **postponed** |
| [Q6](#q6) | 41 roles with no relator mediating them | loss of context | medium |
| [Q7](#q7) | Is `spo.artifact` a `category`? | size of the god table | medium |
| [Q8](#q8) | Partitioning as an alternative to the boundary | performance | low |
| [Q9](#q9) | Origin of the organizational role | ingestion slice 1 | medium |
| [Q10](#q10) | Query profile: polymorphic vs specific | choice of boundary | medium |
| [Q11](#q11) | Extract the derivation as an independent library | nothing for now | low |

---

## Q1 — How to handle perdurants, which the method does not cover {#q1}

**Context.** Guidoni et al. deal with *object sortals* and relators — endurants.
Processes and performed activities are perdurants, and they are precisely the largest
absorbers in our model: `spo.performed_project_activity` with 46 subtypes,
`spo.performed_project_process` with 29.

Sortality and rigidity are defined for endurants. Applying them to events is
analogy, not application of the method.

**Alternatives.**

- Treat them by analogy, assuming that activity occurrences share a
  principle of identity. Simple, but without support in the method.
- Define a strategy of our own for perdurants, with an explicit criterion.
- Check whether there is later work by the NEMO group covering events — there is
  a 2021 paper by the same authors on *forward engineering* that may have
  advanced on this.

**How to resolve.** Consult João Paulo A. Almeida, co-author of the paper and
co-advisor of the thesis. It is the shortest and most reliable route.

**Blocks.** The derivation of the information model for SPO, CMPO, ROoST, QAPO,
SRO, CIRO and CDRO — that is, almost everything.

---

## Q2 — Application boundary of the transformation {#q2}

**Context.** The paper deals with **one** conceptual model. The thesis works with a
**network** of ontologies, and speaks of *information models* in the plural, with one OBDR per
ontology. Applying the method to the whole network or to each ontology gives very
different results.

| Boundary | Tables | Largest grouping |
|---|---:|---:|
| Whole network | 26 | 45 subtypes in one table |
| Per ontology, importing the external kind | 94 | 8 |
| Per module | 144 | 6 |

**Relevant observation.** The number 94, derived formally, coincides with the 94
entities obtained by manual curation, by an independent path.

**Depends on.** Q7 — if `spo.artifact` is a `category`, it is flattened in step 1 and
the god table shrinks without needing a boundary. The boundary would become a choice
of modularity, not a remedy for a symptom.

**Blocks.** The number of tables, the design of the Elixir modules, and the indexing
strategy.

---

## Q3 — Imported kind: copy or reference {#q3}

**Context.** Applying the transformation per ontology, a concept from a more general
ontology needs to appear in the specific ontology. The thesis resolves it by
**replication**:

> the same ontological concept (e.g., Code appears in SysSwO and CIRO) can appear
> in different OBDRs (…) we added two attributes, Internal_id and Version

**Alternatives.**

- **Copy.** Faithful to the thesis. Each module autonomous, ready to become a service.
  Cost: 21 concepts replicated in CIRO, 14 in SRO, and synchronization that in the
  monolith would be our own code — paying for eventual consistency inside the same database
  is the worst of both worlds.
- **Reference.** An FK to the owning ontology's table. No synchronization, but the
  modules come to touch each other at the database level, and extracting one into a service later
  requires undoing the FKs.

**Current inclination.** Reference, for coherence with [ADR 0001](../adr/0001-monolito-modular-elixir.md):
as long as it is a single database, a local transaction solves what `internal_id`
would solve. The `internal_id` and `record_version` columns still exist,
ready for the day a module becomes a service.

**Not decided.** The inclination has not been confirmed.

---

## Q4 — OntoUML stereotype of 142 concepts {#q4}

**Context.** The transformation decides everything by two meta-properties:
sortality and rigidity. The knowledge base declares `ufo_category`, which mixes OntoUML
stereotypes (`role`, `phase`, `relator`, `collective` — 65 concepts) with UFO top-level
categories (`object`, `action`, `social_object` — 142 concepts), and the latter
**do not decide** whether the concept is a kind, subkind or category.

**Proposal.** A new and explicit field, `ontouml_stereotype`, declared and reviewed
— not derived, because the decision is conceptual.

**Suggested order.** Start with the **24 kind candidates** (concepts without a parent):
they are the ones that decide where the tables land, and each mistake there propagates to dozens
of descendants.

**Operational tests.**

1. *Identity*: to compare two of them and say whether they are the same individual, do I
   always use the same criterion? If it changes from case to case → non-sortal.
2. *Rigidity*: can it stop being this and keep existing? → anti-rigid.
3. *Role vs phase*: is what makes it this a relation with something else, or a
   property of its own?

**Blocks.** Everything. Without it the method does not run.

---

## Q5 — Undeclared generalization sets {#q5}

**Status: postponed by conscious decision.** The model is not yet mature enough to
declare generalization sets with confidence, and the method to get there will be
discussed separately. This section records the state and proposes a provisional
behavior, not a solution.

**Context.** No concept in the knowledge base declares a generalization set. Step 2 of the
method needs to know whether a set is **disjoint** or **overlapping** to choose
between an enumerated discriminator and a discriminator table of qua-entities, and whether it is
**complete** or **incomplete** to decide whether the discriminator admits null.

**Why it matters.** The overlapping case is not hypothetical: a person accumulating
simultaneous roles is one of the questions the platform exists to answer.

**Current state.** There are 38 sets of sibling subtypes in the knowledge base:

| Nature of the siblings | Sets | Reading |
|---|---:|---|
| Only `phase` | 5 | **disjoint by nature** — nobody is in two phases of the same axis |
| Only `role` | 8 | **candidates for overlapping** — roles accumulate |
| Mixed or rigid | 25 | require case-by-case analysis |

The eight sets of roles are the ones most likely to need a table instead
of a column:

`spo.project_stakeholder` · `sro.scrum_role` · `sro.scrum_team_member` ·
`sro.product_owner` · `sys_swo.software_resource` · `sys_swo.hardware_resource` ·
`spo.resource` · `cmpo.branch`

**Proposed provisional behavior.** While the question matures, and so as
not to block everything else:

- sets of only `phase` → treated as **disjoint and complete**, with a
  non-null enumerated discriminator;
- sets of only `role` → **do not derive a discriminator**; the role waits for the
  reification of the relator foreseen in [Q6](#q6), which resolves overlap by
  construction;
- mixed or rigid sets → derivation **blocked**, listed as an explicit pending item
  instead of receiving a silent default.

The third rule is the one that matters: a silent default here would produce a
plausible and wrong schema, and the error would only show up when someone needed to record
two values at the same time.

**To discuss later.** The method for establishing disjointness and completeness — whether by
concept-by-concept review, by evidence in the data already collected, or by
inference from the constraints already declared in `rules/`.

## Q6 — 41 roles with no relator mediating them {#q6}

**Context.** The knowledge base has 44 roles and 5 relators. Only 3 roles are mediated by a
declared relator. In UFO every role is relationally dependent — a role without a
relator is a relation that was not reified.

**Consequence.** A boolean discriminator records the classification and loses the
context: `codes.is_under_integration = true` does not say in which CI process,
since when, nor does it admit two simultaneous processes.

**Examples of what is left to reify.**

| Role without a relator | Missing relator |
|---|---|
| `ciro.code_under_integration` | the code's participation in the CI process |
| `cdro.delivered_code` | delivery of that code in that activity |
| `ciro.building_software_resource` | use of the resource in that build environment |
| `roost.code_to_be_tested` | link between the code and the test case |
| `cmpo.source_branch` / `target_branch` | the branch's role in that check-in |

**Precedent in the knowledge base itself.** `eo.team_membership` already is this pattern — person,
team, role and period, instead of `is_team_member` on the person.

---

## Q7 — Is `spo.artifact` a `category`? {#q7}

**Context.** `spo.artifact` has 52 descendants in 9 ontologies, and its direct
children include `software_item`, `information_item` and `software_product`.

By the identity test: do a software item and an information item have the same
identity criterion? One is a piece of software, the other is information for human
use. Apparently not — which would make `spo.artifact` a `category`,
non-sortal, **flattened** in step 1 and with no table of its own.

**Consequence if confirmed.** The largest god table disappears by construction, and
Q2 changes nature: the per-ontology boundary is no longer needed to
fix a symptom.

**The same test is pending** for `spo.performed_project_activity`, with the
complication of Q1: it is a perdurant.

**How to resolve.** Conceptual review, preferably with someone who knows SPO.

---

## Q8 — Partitioning as an alternative to the boundary {#q8}

**Context.** PostgreSQL allows `PARTITION BY LIST` on the discriminator: one logical
table, N physical partitions. A polymorphic query is still one table;
a specific query does *partition pruning*.

It would bring the best of both worlds from Q2, at the cost of partition DDL that is more
laborious to evolve — and with 46 discriminator values, 46 partitions.

**It only makes sense to evaluate after Q1, Q2 and Q7.**

---

## Q9 — Origin of the organizational role {#q9}

**Context.** `eo.team_membership` requires a role. GitHub does not provide one:
`MAINTAINER` and `MEMBER` are platform access levels. The observed team membership
stays as pending evidence, and `memberships_pending_role` is a gap metric.

**Question.** Does the role come from manual registration in The Band, or is there another source
that already records each person's function — Jira, Azure DevOps, an HR system, an allocation
spreadsheet?

**Blocks.** Deciding whether role registration goes into ingestion slice 1 or
is left for later. Raised three times, still without an answer.

---

## Q10 — Query profile: polymorphic vs specific {#q10}

**Context.** The choice of boundary in Q2 depends on which query profile
dominates. Polymorphic queries favor fewer tables; specific queries favor
more and smaller tables.

**How to resolve.** It is decidable with what already exists: classify the 64 competency
questions declared in the knowledge base into polymorphic and specific, and measure the
proportion.

**Hypothesis.** Most are specific to an ontology — *which ceremonies*, *which
user stories*, *which builds failed*. The few polymorphic ones are those of
cross-cutting traceability, which would require a join either way.

If confirmed, the per-ontology boundary optimizes the common case.

---

## Q11 — Extract the derivation as an independent library {#q11}

**Context.** `scripts/derive_information_model.py` has nothing specific to
The Band: it implements `one table per kind` plus two extensions — an ontology
network by reference and view generation — that serve any project
starting from OntoUML.

The authors maintain a reference implementation at
[nemo-ufes/ontouml2db](https://github.com/nemo-ufes/ontouml2db), over isolated
models. If the group is interested, contributing there is preferable to maintaining a
parallel implementation — the thesis's co-advisor is a co-author of the paper.

**Prerequisites**, detailed in [scripts/README.md](../../scripts/README.md):
close Q4 (142 concepts without a stereotype), separate method from this
project's conventions, accept the OntoUML standard JSON as input, emit DDL as output, and
test against the ten public models used in the paper.

**It blocks nothing.** Recorded so it is not lost — the sign that the time has
come is the derivation running over the twelve ontologies without manual intervention.
