# Extensions to the `one table per kind` strategy for ontology networks

**Working document** — a record of the decisions that depart from Guidoni,
Almeida & Guizzardi (2020), with a view to a possible publication.

**Status**: draft. The extensions are implemented and validated on three of the
twelve ontologies in the network; the systematic evaluation has not been done.

---

## 1. Context

The Band semantically integrates data from Software Engineering tools
against an ontology network — UFO in the foundational layer, SEON in the core and
domain, and Continuum as a Continuous Software Engineering subnetwork. There are 220
concepts in 12 ontologies, with a maximum hierarchy height of 5 and 148 leaf
classes.

Generating the relational schema from that network required adopting a
transformation strategy. We chose `one table per kind` because it is the only one, among those
evaluated, that simultaneously supports overlapping and incomplete generalizations,
dynamic classification, multiple inheritance and orthogonal hierarchies — all
present in our model.

When applying it, we found four points where the method does not decide, because it deals with
a different scope from ours. This document records what we did in each one.

## 2. What the original method establishes

Guidoni et al. propose three steps, guided by the meta-properties of
sortality and rigidity:

1. **Flattening** — non-sortals are flattened toward their sortal subclasses.
2. **Lifting** — sortals that are not kinds are lifted recursively to their kinds,
   with mandatory attributes propagated as optional.
3. **Generation** — one table per remaining class, with dependency foreign
   keys.

The result of lifting depends on the generalization set: disjoint produces an
enumerated discriminator; overlapping produces a discriminator table of
*qua-entities*; the absence of a generalization set produces a boolean.

## 3. Gaps found

| # | Gap | Why it appears in our case |
|---|---|---|
| L1 | The method transforms **one** isolated conceptual model | Our source is a stratified network, with dependencies between ontologies |
| L2 | The method deals with **endurants** | Our largest groupings are processes and activities — perdurants |
| L3 | The method does not define **how to recognize** the stereotype | Concepts coming from reference ontologies do not carry an OntoUML stereotype |
| L4 | The transformation **hides the domain's vocabulary** | Our 64 competency questions are written in concepts, not in tables |

L1 and L2 are a consequence of the paper's scope, not flaws in it. L3 and L4 are
side effects that only appear with continued use.

## 4. Proposed extensions

### E1 — Ontology networks by reference

**Problem.** A concept from a domain ontology specializes a kind that
lives in a core ontology. The method does not say where the table should go.

**Existing alternative.** The thesis on which the project is based resolves it by
replication: the same concept appears in several ontology-based
repositories, reconciled by an internal identifier and synchronized through a
message broker. It makes sense for autonomous services.

**Our decision.** The kind lives in the ontology that defines it; the others reference it.
Three rules:

- the kind is materialized once, in the ontology that introduces it;
- the external subtype contributes a value to the kind's discriminator;
- the subtype's own attributes become an extension table in the owning ontology,
  linked by a foreign key.

**Justification.** Extensibility, above all: a new ontology points to the
existing kinds and adds its own, without changing anything that already exists. With
replication, each new ontology creates one more place that needs to agree with the
others.

**Evidence.** CMPO, with 26 concepts, produces 5 tables of its own and 1 extension
table, contributing 13 values to SPO's discriminator **without changing SPO**.

**Favorable side effect.** The kind's table does not accumulate null columns from
unrelated subtypes. `sha`, `message`, `additions` and `deletions` live
in the commit's extension, not in a table that also holds Scrum ceremonies.

### E2 — Perdurants handled by the same test, with a declared identity criterion

**Problem.** Sortality and rigidity are defined for endurants. Processes and
performed activities are perdurants, and they concentrate 45 and 28 subtypes in our
network.

**Our decision.** Do not create a separate rule. Apply to perdurants the same
test that decides everything: *do the descendants share a principle of identity?*
And make the test operational by requiring the criterion to be **declared**:

```yaml
identity_criterion:
  form: composite_hash
  components: [tenant_id, organization_id, project_id, activity_type,
               performer_id, occurred_at, source_external_id]
  nullable_components: [performer_id, source_external_id]
  inherited_by_subtypes: true
```

**Practical consequence.** The test becomes an answerable question: *what is the natural
key?* If it differs among the descendants, the concept is not a kind, it is a
`category`, and it is flattened.

**Evidence of the impact.** Before applying the test, we treated the umbrella
concepts as kinds, and the schema came out at 27 tables with the largest
grouping concentrating 45 subtypes. Applying the test, `spo.artifact` and
`spo.performed_project_activity` turn out to be `category` candidates, and the schema
goes to 82 tables with a largest grouping of 13.

**Constraint discovered.** The hash must cover only identifying
components. Including a mutable descriptive attribute — `end_date`, null while
the activity runs and filled in when it ends — would make the identifier change on
completion, orphaning every reference. Absent components need a
canonical representation so that the hash remains deterministic: automated
activities have no human performer.

### E3 — Distinction between `role` and `phase` in materialization

**Problem.** The method distinguishes the cases by the structure of the generalization set.
For roles without a generalization set, it prescribes a boolean attribute.

**Our observation.** The boolean records the classification and discards what
supports it. A `role` is relationally dependent: `is_under_integration = true`
does not say in which process, since when, nor does it admit two simultaneous ones. A `phase`
is an intrinsic change, and there the discriminator is enough — a continuous
integration process is successful by its own result.

**Our decision.** Refine the rule by the nature of the stereotype:

| Stereotype | Nature | Materialization |
|---|---|---|
| `subkind` | rigid | enumerated discriminator |
| `phase` | intrinsic | enumerated or boolean discriminator |
| `role` | **relational** | relator; discriminator only as denormalization |

**Important caveat.** The original method is not wrong: it presupposes the
relator modeled alongside, and in that case the discriminator is derivable and serves as a
query optimization. The presupposition does not hold in our knowledge base — 41 of the 44 roles
have no declared relator, which is our gap and not the method's. The extension can
be read as: *when the relator does not exist, the boolean is not denormalization, it is
loss of information.*

### E4 — Reifying the role as a catalogue with validity

**Problem.** Roles fixed as enum values require a migration for each new role,
have no temporality and do not admit accumulation.

**Our decision.** The role is a **row** in a catalogue table, and the kind
instantiates it for a period through the relator:

```text
organizational_roles     catálogo — uma linha por papel
people                   o kind que assume o papel
team_memberships         o relator: pessoa + equipe + papel + período
```

**Gains.** A new role is an `INSERT`; start and end live in the relator, and the history
survives the person's departure; simultaneous roles are multiple rows, with no
additional construction; in a multitenant system, each organization defines its own.

**Cost.** One more join for the question "what is this person's role" — acceptable
because the useful question is almost never that one, but rather "what is this person's role
*on this team*, *in this period*", which would require the join anyway.

### E5 — Derived views that restore the vocabulary

**Problem.** After the transformation, `sprint`, `commit` and `developer` stop
being tables: they become a discriminator value, a relator row or a join with an
extension. Whoever queries needs to know the information model, not the domain.
In our case the 64 competency questions are written in concepts.

**Our decision.** Each absorbed concept reappears as a view, derived together
with the schema by the same transformation:

| Form of absorption | View |
|---|---|
| lifted with a discriminator | filters the discriminator, joins the extension if there is one |
| materialized by a relator | joins kind, relator and catalogue, exposing validity |
| lifted as a phase | filters the state |

**Justification.** Zero storage cost, and the planner resolves the filter as
if it were written in the query. The schema optimizes writing and integrity; the
view layer preserves reading through the domain's vocabulary.

**A point of method.** The views are derived, never written by hand — otherwise
they reintroduce the divergence the derivation exists to avoid.

## 5. Summary of contributions

| # | Contribution | Nature |
|---|---|---|
| E1 | Ontology network by reference, with discriminator contribution and extension tables | method extension |
| E2 | Perdurants by the same test, with a declared identity criterion | scope extension |
| E3 | Distinct materialization for `role` and `phase` | refinement |
| E4 | Role reified as a catalogue with validity | modeling pattern |
| E5 | Derived views that restore the domain's vocabulary | method extension |

E3 is a conditional refinement, not a correction. E4 is a known pattern in temporal
modeling, here derived systematically from the stereotype instead of
chosen case by case.

## 6. Limitations

**No empirical evaluation.** There is no performance measurement on real data. The
schema size comparisons are static counts, not benchmarks. The
argument that the extension table avoids sparsity is structural, not measured.

**Partial coverage.** Three of the twelve ontologies were classified with an
OntoUML stereotype and derived: EO (10 concepts → 6 tables), SPO (21 → 6) and
CMPO (26 → 5 + 1 extension). The other 163 concepts remain unclassified.

**Undeclared generalization sets.** The knowledge base declares neither disjointness nor
completeness, which prevents exercising the overlapping set case — precisely
where the original method proposes the *qua-entities* table. The extensions here do not
touch that point.

**A single network.** All observations come from UFO + SEON + Continuum. Whether the
extensions generalize to other networks is a hypothesis, not a result. The ten OntoUML
models used in the original paper's evaluation would be the natural suite to
test them.

**Classification as a source of error.** The most consequential finding of this
work — that the god table was an effect of classifying a non-sortal as a kind — is
also a warning: the results depend entirely on the quality of the
classification, which is a human activity and not automatically verifiable.

## 7. Related work to consult

- Guidoni, Almeida & Guizzardi. *Forward Engineering Relational Schemas and
  High-Level Data Access from Conceptual Models.* ER 2021 — it may already cover part
  of what we treat as an extension.
- The group's work on *multi-level modeling*, relevant to E4: the role catalogue
  is type reification, which is a matter of multi-level modeling.
- UFO-B literature on events, relevant to E2.

Check these three fronts before treating any item in Section 5 as an
original contribution.

## 8. Implementation

Rules declared in
[`priv/knowledge_base/transformations/ontology_to_information_model.yaml`](../../priv/knowledge_base/transformations/ontology_to_information_model.yaml)
— 19 rules in 5 steps, 9 of them marked as an extension of this project.

Derivation in [`scripts/derive_information_model.py`](../../scripts/derive_information_model.py).
Decisions and justifications in [ADR 0004](../adr/0004-modelo-de-informacao-one-table-per-kind.md).
Open questions in [RFC 0001](../rfc/0001-derivacao-do-modelo-de-informacao.md).

## References

- Guidoni, G. L.; Almeida, J. P. A.; Guizzardi, G. **Transformation of
  ontology-based conceptual models into relational schemas.** ER 2020, Vienna,
  Springer, p. 315–330.
- Carraretto, R. **Separating Ontological and Informational Concerns: A
  Model-driven Approach for Conceptual Modeling.** Master's dissertation,
  UFES, 2012.
- Santos Júnior, P. S. **From Continuous Software Engineering Reference
  Ontologies to the Integration of Data for Data-Driven Software Development.**
  Doctoral thesis, UFES, 2023.
- Guizzardi, G. **Ontological foundations for structural conceptual models.**
  Doctoral thesis, University of Twente, 2005.
