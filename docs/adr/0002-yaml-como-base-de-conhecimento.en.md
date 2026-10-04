# ADR 0002 — Versioned YAML as a declarative knowledge base

## Status

Accepted — 2026-08-08

## Context

The Band's conceptual model — 12 ontologies, 219 concepts, 141 relations, 64
competency questions — is the system's central asset. It is what distinguishes the
platform from a data lake with dashboards.

This model needs properties that Elixir code alone does not offer well:

- **being reviewable by those who understand the domain**, including those who do not
  read Elixir;
- **being semantically versioned**, with a diff that shows the conceptual change;
- **carrying provenance**, pointing to the section of the thesis that originated each
  concept;
- **being mechanically validatable** — references, cycles, cardinalities, required
  fields;
- **being the same source** for the code, the documentation and the conceptual tests.

If concepts lived only in modules and Ecto schemas, a conceptual change would appear
scattered across schema, migration, changeset and documentation — and the
documentation would diverge from the real model within weeks.

## Decision

The conceptual model lives in **`priv/knowledge_base/`, as versioned, validated and
reviewed YAML**. The Elixir code loads this model; it does not duplicate it.

The base covers: ontologies and their metadata, concepts, relations, cardinalities,
constraints, competency questions, mappings between sources and ontologies, information
needs, measures, glossary, rules and examples.

Rules that come with the decision:

- every YAML has a schema in `schemas/`, a version, a stable identifier, declared
  dependencies and provenance;
- unknown fields are rejected when the schema is strict;
- validation runs in CI and fails the build;
- a change that alters semantics, contract or behavior requires a test and a semantic
  review;
- no YAML contains a token, password or credential;
- loading happens at compile time, at boot or through a controlled cache — **never**
  reading from disk per request;
- the documentation in `docs/ontology/` is **generated** from the base, and not edited
  by hand.

Granularity: **one file per module/subontology**, not per concept. One concept per file
would produce ~200 files and make a concept and its relations appear in separate diffs,
rendering the review of a semantic change illegible. The module is the same granularity
as the corresponding Elixir modules.

## Alternatives considered

**Concepts as Elixir modules, directly in the code.** It eliminates the loading step and
gives type checking, but it loses reviewability by non-programmers, dilutes provenance
into comments and makes the documentation diverge. A conceptual change stops being a
conceptual diff.

**OWL/RDF with a triplestore.** It is the native format for ontologies and would bring
automated reasoning for free. It costs a heavy infrastructure dependency, a language the
team does not master, and tooling far from the Pull Request review flow. The reasoning
gain is not needed for the current case: the checks that matter — references, cycles,
cardinalities — are obtained with schema validation.

**Tables in the database, editable through an interface.** It would make editing by end
users easier, but it takes the model out of version control. A conceptual change would
become an `UPDATE` with no review, no readable history and no link to the code that
depends on it.

**JSON Schema with JSON files.** Equivalent in capability, but without comments and with
a noisier syntax for multiline text — and concept definitions are long texts, in two
languages.

## Consequences

**Positive**

- A conceptual change is a readable diff, reviewable by those who understand ontology.
- Provenance stays next to the concept, pointing to the section of the thesis.
- Mechanical validation catches broken references, dependency cycles and orphan
  concepts before the merge.
- Generated documentation does not diverge from the model, because it is derived from
  it.
- Conceptual tests and competency questions read the same source as the code.

**Negative**

- There is a loading and caching layer to build and maintain.
- YAML gives no compile-time type checking; the safety net is schema validation.
- There is a risk of divergence between the base and the Ecto schemas if there is no
  test that ties the two together.

**Mitigations**

- `mix knowledge.validate`, `knowledge.graph`, `knowledge.compile`, `knowledge.test` and
  `knowledge.diff` as mandatory gates in CI.
- Conceptual tests per ontology verifying that the Ecto schemas reflect the declared
  concepts.
- No disk reads at request time — controlled, cached loading.
