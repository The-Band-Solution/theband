# ADR 0003 — Domain organized by the ontologies, not by the tools

## Status

Accepted — 2026-08-08

## Context

There are two obvious ways to organize a data integrator.

The first is **by source**: a `GitHub` module, a `Jira` one, a `Sonar` one, each with
its schemas mirroring the payloads of the corresponding API. It is the organization
that integration work naturally suggests, and the one that appears on its own when no
one decides otherwise.

The second is **by concept**: modules that represent what the data means — person,
project, change request, continuous integration process — with the sources coming in
as adapters at the edges.

The first looks pragmatic and is a trap. When the domain mirrors the APIs, the vendor's
data model becomes the system's model. Measures come to be defined in terms of "field X
of the GitHub API", break when the API changes, and cannot be compared across sources:
"task" in Jira and "issue" in GitHub become similar-looking columns with different
semantics, added together without anyone noticing.

That destroys exactly what justifies The Band's existence.

## Decision

The core of the domain is organized **by the ontologies**, mirroring the UFO → SEON →
Continuum network:

```text
lib/the_band/ontology/
├── ufo/
├── seon/{eo,spo,sys_swo,rsro,cmpo,roost,qapo,osdef}/
└── continuum/{sro,ciro,cdro}/
```

There is no `TheBand.GitHub` module in the domain. GitHub is a source, not a concept.
The connectors live in `integrations/` and `priv/connectors/`, and the crossing between
the two worlds is made by **declared semantic mappings**, with explicit equivalence,
justification and limitations.

Rules that come with the decision:

- the connector stores the raw payload and the provenance, then calls the ontological
  module's **public API** — it never writes to a domain Ecto schema;
- an external entity can feed several ontologies, each with its own mapping;
- a concept that exists in a more general ontology is reused, never duplicated —
  `Person` lives in EO, and SRO, CIRO and CDRO only reference it in roles;
- dependencies point from the specific to the general, and this is verified
  automatically;
- tables are prefixed by the ontology that owns the concept (`eo_`, `spo_`, `cmpo_`, …).

## Alternatives considered

**Organizing by source.** Faster for the first connector and harder for all the others.
Each new source adds a parallel vocabulary, and comparing data across sources becomes
manual reconciliation work — done in a query, with no record, by whoever happens to be
assembling the report.

**Our own canonical model, without reference ontologies.** It would solve
comparability without requiring the ontology network, but it would throw away what the
thesis offers ready-made: already validated distinctions (intended vs. performed,
defect vs. fault vs. failure, role vs. person) and a grounding that supports the choices
when a divergence arises. A home-grown canonical model tends to be decided by whoever
shouts loudest in the meeting.

**A translation layer on top of per-source schemas.** It keeps the schemas mirroring
the APIs and translates on read. It postpones the problem: the translation becomes
implicit logic scattered across queries, with no provenance and no semantic review.

## Consequences

**Positive**

- Measures are defined in terms of concepts, not API fields.
- Data from different sources becomes comparable by construction.
- A change in an external API stays contained in the connector and the mapping.
- The traceability of "where did this number come from" is structural, not
  reconstructed afterwards.
- The ontology network provides a criterion for resolving conceptual divergence.

**Negative**

- The first connector costs more: it requires mapping concepts before writing code.
- It requires the team to know the ontology network — there is a real learning curve.
- Tool concepts that do not fit in any ontology require an explicit decision, and cannot
  simply be persisted "just in case".

**Mitigations**

- Documentation generated from the base: [ontology network](../ontology/README.md) and
  [concept index](../ontology/concept-index.md).
- A glossary that links the tools' vocabulary to the formal concepts.
- The raw payload is always preserved: what has not been mapped yet is not lost, only
  not promoted to the domain.
