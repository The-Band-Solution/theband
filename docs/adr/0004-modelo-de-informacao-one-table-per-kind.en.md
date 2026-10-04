# ADR 0004 — Information model derived from the ontology by `one table per kind`

## Status

Accepted — 2026-08-09

Depends on: [ADR 0002](0002-yaml-como-base-de-conhecimento.md), [ADR 0003](0003-organizacao-por-ontologias.md)
Open questions this ADR does not resolve: [RFC 0001](../rfc/0001-derivacao-do-modelo-de-informacao.md)

## Context

The knowledge base declares 219 concepts in 12 ontologies. Generating the database
from it requires a decision that was implicit and unrecorded: **the ontological model
is not the database model**.

The thesis that underpins the project names this distinction. Quoting Carraretto
(2012), Section 5.3:

> An information model concerns what kind of information may be stored and
> exchanged considering demands of specific agents (the "recorded world"), while
> an ontology model concerns metaphysical aspects of a domain (i.e., it concerns
> what is considered to exist in the "real world").

And it defines the role of the result:

> the information model represents the canonical/common data model to be used to
> share and exchange data between OBSs

Without this intermediate layer, every metaphysical distinction would become a table.
A first manual derivation, made before this decision, produced 94 entities from the
219 concepts — but by curation, with no declared method and no possibility of auditing
or regenerating it.

The problem, then, was not *whether* to reduce, but **by which method**, and how to
keep that method explicit and verifiable.

## Decision

Adopt the **`one table per kind`** strategy of Guidoni, Almeida & Guizzardi (2020),
applied to the knowledge base and declared as a versioned artifact in
`priv/knowledge_base/transformations/`.

The information model is **derived**, never written by hand. Editing it directly would
make it diverge from the ontology — the same error that
[ADR 0002](0002-yaml-como-base-de-conhecimento.md) avoids for the documentation.

### Summary of the decisions

| # | Decision | Origin | Explanation |
|---|---|---|---|
| D1 | Adopt `one table per kind` | Guidoni et al. (2020) | The table lands on the **Kind**, which is the type that provides the principle of identity — what makes it possible to say whether two records are the same individual. Types that do not provide their own identity (`subkind`, `role`, `phase`) do not get a table: they are absorbed into the kind. This resolves by construction the four gaps the paper points out in the dominant strategies — overlapping generalization, incomplete generalization, multiple inheritance and orthogonal hierarchies — because the primary key lives in a single place and never moves. The alternatives fail precisely in the most common transitions of our domain: in `one table per class` and `per leaf class`, reclassifying a deliverable from not accepted to accepted would require a `DELETE` plus an `INSERT`, breaking every existing reference. |
| D2 | Suppress the foundational layer; keep core and domain | Thesis, §5.3 | UFO exists to **categorize** the concepts of the other layers, not to describe the application domain. `ufo.object` and `ufo.event` are not things about which The Band has data — they are the grammar used to classify the things about which it has data. Replicating them as tables would create rows with no referent in the world. The classification stays in the knowledge base as metadata, where it keeps serving validation and guiding this very transformation. |
| D3 | Preserve associations inherited from a suppressed category | Thesis, §5.3 | Suppressing the category cannot suppress what it grounds. `caused by`, between intended and performed process, is defined at the foundational level; if it disappeared along with the category, there would be no way to link what was planned to what was performed — and every analysis of adherence between plan and reality, one of the reasons the system exists, would become impossible. |
| D4 | Information model derived, never written by hand | Consistency with ADR 0002 | If the schema could be edited directly, it would diverge from the ontology within weeks, and there would be two truths about the same domain — with no one knowing which is right. By deriving, a conceptual correction propagates to the database by regeneration, and any divergence between the two becomes a build failure instead of a late discovery. It is the same reason `docs/ontology/` is generated. |
| D5 | `role` materializes as a relator; `phase` and `subkind` as a discriminator | Our refinement on top of the paper | The distinction is between **relational** dependence and **intrinsic** change. A `role` only exists in relation to something else: nobody is a "team member" in a vacuum, they are a member of *that* team, in *that* period. A boolean column records the classification and discards exactly that — the context, the temporality and the possibility of accumulation. A `phase`, on the other hand, is a state of the individual itself: a CI process is successful or unsuccessful because of its own result, with no reference to third parties, and there the discriminator is enough. The paper allows a boolean for roles because it presupposes the relator modeled alongside; since 41 of our 44 roles have no relator, that presupposition does not hold here. |
| D6 | `role` reified as a catalog, instantiated per period through a relator | Our own decision, validated on EO | A role becomes a **row**, not an enum value. This makes extension cheap — a new role is an `INSERT`, not a migration —, puts start and end on the relator, allows simultaneous accumulation without additional construction, and lets each organization define its own roles in a multitenant system. The cost is one more join to ask "what is this person's role", acceptable because the useful question is almost never that one, but rather "what is this person's role **in this team**, **in this period**" — which would require the join anyway. |
| D7 | Events are `append-only`; situations are not materialized | Our extension | The paper deals with **endurants** and covers neither case. An event records something that occurred: updating a failure to say it did not occur would rewrite the past, so corrections come in as new records. A situation is reality before and after an event, entirely derivable from its instants; persisting it separately would create three places to disagree about the same fact. |
| D8 | Perdurants are kinds when they share an identity criterion, declared explicitly | Our own decision | The method of Guidoni et al. deals with endurants and does not say what to do with processes and activities. Instead of creating a separate rule, we apply to them the **same test**: a concept is a kind when its descendants share the principle of identity. For `spo.performed_project_activity` this was resolved by declaring the criterion — `tenant + organization + project + type + performer + instant + identifier at the source`, combined in a deterministic hash that becomes the `internal_id`. Only **identifying** components go in: `end_date` is left out on purpose, because it is null while the activity is running and filled in when it ends, and including it would make the hash change on completion, breaking every existing reference. `performer_id` is nullable because build, automated test and deployment have no human performer. The practical test is direct: **if you do not know what the natural key is, it is not a kind** — and it was for not knowing that `spo.artifact` remained a `category`. |
| D9 | In an ontology network, the kind lives in the most general ontology; the specific ones **reference** it, they do not copy it | Our own decision | The paper transforms **one** conceptual model and does not deal with networks. The thesis does, but by replication: the same concept appears in several OBDRs, reconciled by `internal_id` and synchronized by a broker. That makes sense for autonomous services and does not for a monolith, where we would be paying for eventual consistency inside the same database. We adopted reference for three reasons, in order of weight: **extensibility** — a new ontology only points to the existing kinds and adds its own, without changing anything already there, whereas with copying each new ontology would replicate kinds and create one more place that has to agree; **performance** — the kind's table keeps only what is common, and specific attributes live in extension tables, avoiding dozens of null columns where commits and ceremonies sit side by side; **modularity** — each ontology keeps its tables, and the boundary exists in the schema without requiring a replica. The `internal_id` and `record_version` columns are still present, ready for the day a module becomes a service and the replica becomes necessary. |
| D10 | Each absorbed concept gets a **view** that reconstitutes it | Our own decision | The transformation is correct and has a side effect: whoever queries no longer finds the names they know. `sro.sprint`, `cmpo.commit` and `sro.developer` disappear as tables, become a discriminator value or a relator row, and querying now requires the writer to know where each concept ended up. The 64 competency questions are written in terms of the concepts, not the tables. The view gives the vocabulary back: each absorbed concept reappears as a queryable object with its own name, encapsulating the join with the extension, the discriminator filter or the join with the relator. The cost is zero in storage, and the planner resolves the filter as if it had been written by hand. So the schema optimizes writing and integrity, while the view layer preserves reading through the domain vocabulary — and the ontology becomes visible again to whoever queries. |

### Layer policy — from the thesis, Section 5.3

| Layer | Treatment | Explanation |
|---|---|---|
| Foundational (UFO) | suppressed | It categorizes the other layers and contains no concepts of the application domain. There is no data to keep about `ufo.object` — it is the ruler, not what is measured. |
| Core (EO, SPO, SysSwO) | kept | It contains the concepts that give identity to almost everything: person, organization, project, artifact, software item. It is where most tables land. |
| Domain | kept | It contains the specializations the user recognizes by name — sprint, pull request, pipeline. The thesis requires keeping them so that each ontology can sustain its service and its repository. |
| Associations inherited from a suppressed category | **kept** | See D3: the relation survives the suppression of the category that defined it, otherwise the link between intended and performed is lost. |

### Transformation strategy — from the paper, three steps

1. **Flattening** — non-sortals (`category`, `role_mixin`, `mixin`) are flattened
   towards the sortal subclasses, with attribute replication. A non-sortal classifies
   individuals of different kinds; no table is possible for it without mixing
   principles of identity.
2. **Lifting** — sortals that are not kinds (`subkind`, `role`, `phase`) are lifted
   recursively from the leaves up to their kinds, with mandatory attributes propagated
   as optional.
3. **Generation** — one table per remaining class; existentially dependent entities
   get a mandatory foreign key to what they depend on.

### What lifting produces — refined beyond the paper

The paper distinguishes the cases by the structure of the generalization set. We adopt
that rule **and refine it by the nature of the stereotype**, because the distinction
between role and phase matters here:

| Stereotype | Nature | Materialization | Explanation |
|---|---|---|---|
| `subkind` | rigid | enumerated discriminator | The individual is of that subtype for its whole existence and never stops being so. The distinction is permanent and exclusive, so it fits in a single value. `eo.project_team` and `eo.organizational_team` become `eo_teams.type`. |
| `phase` | **intrinsic** | enumerated discriminator; boolean if there is no generalization set | The individual changes phase over its life, but because of an **intrinsic property**, without depending on a link to third parties. A CI process is successful because of its own result. Since the change is intrinsic, it fits in a column that gets updated — and reclassification becomes an `UPDATE`, without moving the row. |
| `role` | **relational** | **relator / qua-entity table**; discriminator only as optional denormalization | The role only exists in relation to something, and the column would lose precisely that relation. `codes.is_under_integration = true` does not say in which process, since when, nor does it allow two simultaneous processes. The relator keeps all three, and also allows accumulation through multiple rows. |
| overlapping generalization set | — | discriminator table of qua-entities | When the individual can be in several subtypes at the same time, no single value works. The paper introduces a table whose rows are qua-entities, each linking the bearer to one of the subtypes it takes on — that is how a person with dual citizenship is represented without duplicating the person. |

The refinement exists because a `role` is relationally dependent: it only exists in
relation to something. A boolean `is_under_integration` on the code records the
classification and loses what matters — in which process, since when, and whether there
is more than one at the same time. For `phase`, which is intrinsic change, the
discriminator is enough.

The paper can use a boolean for roles because in well-modeled OntoUML the relator
already exists alongside, and the discriminator is derivable from it. Our base is not
yet in that condition — see [RFC 0001](../rfc/0001-derivacao-do-modelo-de-informacao.md), Q6.

### Reified role: a catalog plus a relator with a period

This follows from the previous point and is our own decision: the `role` becomes a
**catalog table**, and the kind instantiates it **for a period**, through the relator.

```text
eo_organizational_roles      catalog — one row per role
eo_people                    the kind that takes on the role
eo_team_memberships          the relator: person + team + role + period
```

What this buys, compared with a discriminator on the kind's table:

- **Extensibility** — a new role is a row, not an enum migration.
- **Temporality** — start and end live on the relator, and the history survives the
  person's departure.
- **Accumulation** — several relator rows express simultaneous roles without any
  additional construction.
- **Multitenancy** — each organization defines its own roles.

The cost is one more join to answer "what is this person's role", which is acceptable
given that the right question is almost never that one, but rather "what is this
person's role **in this team**, **in this period**" — which would require the join
anyway.

Validated by derivation on EO: 9 concepts produce 5 tables, and `eo.team_member` is
absorbed into `eo.person` without becoming a column.

### Application in an ontology network

The paper transforms an isolated conceptual model. The network adds a problem it does
not face: a CMPO concept specializes a kind that lives in SPO. Three rules solve this
without replicating data.

**The kind lives in the ontology that defines it.** `spo.performed_project_activity` is
the kind of activity occurrences across the whole network — commits, test executions,
ceremonies, deployments. The domain ontologies do not each define their own.

**The subtype contributes a value to the kind's discriminator.** CMPO does not get a
table for `checkout`, `checkin` or `commit`: it contributes thirteen values to
`spo_performed_project_activities.activity_type`.

**A specific attribute becomes an extension table in the owning ontology.** When the
subtype carries structure its siblings do not have, it does not go up to the kind — it
stays in a table of the ontology itself, linked by a foreign key:

```text
spo_performed_project_activities        kind, common attributes, discriminator
    id, tenant_id, project_id, activity_type, occurred_at, performer_id

cmpo_commits                            extension, in the owning ontology
    performed_project_activity_id → FK
    sha, message, additions, deletions
```

A polymorphic query scans the base table; a specific query joins with the extension.
The result is that the kind's table does not accumulate null columns from subtypes that
have nothing to do with each other.

Verified by derivation: CMPO produces 26 concepts → 5 tables of its own plus one
extension, contributing 13 values to SPO's discriminator, **without changing anything
in SPO**.

### Views: the ontology back in the query layer

After the transformation, `cmpo.commit_artifact_copy` is not a table: it is
`activity_type = 'commit_artifact_copy'` in the kind's table, plus a row in the
extension. Querying commits would come to require knowledge of the information model,
and not of the domain.

Three forms of view solve this, one per form of absorption:

**Subtype view** — reconstitutes what was lifted with a discriminator, joining the
extension when there is one:

```sql
CREATE VIEW cmpo_commits AS
SELECT a.id, a.tenant_id, a.project_id, a.occurred_at, a.performer_id,
       c.sha, c.message, c.additions, c.deletions
  FROM spo_performed_project_activities a
  JOIN cmpo_commits_ext c ON c.performed_project_activity_id = a.id
 WHERE a.activity_type = 'commit_artifact_copy';
```

**Role view** — reconstitutes what was materialized by a relator, joining the catalog
and respecting the validity period:

```sql
CREATE VIEW sro_developers AS
SELECT p.*, m.team_id, m.started_at, m.ended_at
  FROM eo_people p
  JOIN eo_team_memberships m ON m.person_id = p.id
  JOIN eo_organizational_roles r ON r.id = m.organizational_role_id
 WHERE r.code = 'developer';
```

**Phase view** — reconstitutes what was lifted as a state:

```sql
CREATE VIEW sro_accepted_deliverables AS
SELECT * FROM sro_deliverables WHERE acceptance_status = 'accepted';
```

The views are **derived together with the schema**, by the same transformation and from
the same base — not written by hand. A conceptual change updates table and view in the
same regeneration, and there is no way for one to diverge from the other.

Writing and integrity happen against the tables; reading can happen against the views.
Non-materialized views cost nothing in storage, and the discriminator filter is
resolved by the planner as if it were written in the query.

This is distinct from materialized views for measures and indicators, which are an
analytics matter and not this ADR's.

### Our own extensions, outside the paper's scope

The paper deals with **endurants**. Two rules are ours and are marked as
`source_of_rule: proposed`:

- **Events are append-only.** They record something that occurred; correcting by
  update would rewrite the past.
- **Situations are not materialized.** They are derivable from the event's instants;
  persisting them would create three places to disagree with each other.

## Alternatives considered

**One table per class** (one table per class, joins along the hierarchy). With `h=5` in
our model, it costs up to 5 joins to read an entity, and reclassification requires a
`DELETE` plus an `INSERT` — breaking referential integrity exactly in the most common
transitions of the domain: a deliverable that becomes accepted, a pipeline re-run
successfully, a defect that manifests as a fault.

**One table per leaf class.** It would produce 148 tables, and a polymorphic query would
require a union of 148. Worse: it does not represent overlapping generalization —
someone who takes on two roles at the same time would need to exist in two tables with
two primary keys — nor incomplete generalization, since whoever takes on no role at all
would have nowhere to exist. Both cases are everyday here.

**One table per hierarchy.** It would give 26 tables and good performance on
polymorphic queries, but it does not support multiple inheritance, and it would
concentrate 46 subtypes in a single table of performed activities.

**Manual curation, without a method.** It was the starting point and produced a
plausible result, but one that is not auditable, not regenerable, and with no criterion
for resolving divergences.

## Consequences

**Positive**

- The reduction stops being an opinion and becomes an auditable derivation.
- Reclassification becomes a discriminator `UPDATE`: the row does not move, the key does
  not change, nothing points into the void.
- Overlapping and incomplete generalizations, multiple inheritance and orthogonal
  hierarchies become representable — the four gaps the paper points out in the dominant
  strategies.
- The primary key lives in the kind's table, so the individual exists independently of
  the roles it takes on.
- A conceptual correction in the ontology propagates to the schema by regeneration.

**Negative**

- A polymorphic query may require up to `nk` unions when the attribute is on a
  non-sortal that classifies all kinds.
- The transformation depends on metadata the base **does not yet declare**: the OntoUML
  stereotype of 142 of the 207 concepts, and the generalization sets. Without them, the
  method does not actually run.
- Reifying the roles' relators increases the number of tables, even if they are narrow
  tables.

**Accepted risks**

- The method does not cover perdurants, and processes and performed activities are
  perdurants. Treating them by analogy is our decision, recorded as an open question.
- The choice of application boundary — the whole network, an ontology or a module —
  changes the result from 26 to 94 tables and remains open.

## Verification

`scripts/validate_knowledge_base.py` validates the base against the schemas, including
`transformation.schema.yaml`. The derivation of the information model, once
implemented, must be reproducible: the same base and the same rules produce the same
model, and any divergence is a build failure.

## References

- Guidoni, G. L.; Almeida, J. P. A.; Guizzardi, G. **Transformation of
  ontology-based conceptual models into relational schemas.** ER 2020, Vienna,
  Springer, p. 315–330. Reference implementation:
  [nemo-ufes/ontouml2db](https://github.com/nemo-ufes/ontouml2db)
- Carraretto, R. **Separating Ontological and Informational Concerns: A
  Model-driven Approach for Conceptual Modeling.** Master's dissertation,
  UFES, 2012.
- Santos Júnior, P. S. **From Continuous Software Engineering Reference
  Ontologies to the Integration of Data for Data-Driven Software Development.**
  Doctoral thesis, UFES, 2023 — Section 5.3.
