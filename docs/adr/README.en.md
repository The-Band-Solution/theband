# Architecture Decision Records

The record of The Band's architectural decisions: the context, the decision, the
alternatives considered and the consequences. An ADR does not describe how the system
works — it describes **why** it works that way, so that the decision can be revisited
with the information that existed when it was made.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-monolito-modular-elixir.md) | Modular monolith in Elixir/Phoenix, not microservices | Accepted |
| [0002](0002-yaml-como-base-de-conhecimento.md) | Versioned YAML as a declarative knowledge base | Accepted |
| [0003](0003-organizacao-por-ontologias.md) | Domain organized by the ontologies, not by the tools | Accepted |
| [0004](0004-modelo-de-informacao-one-table-per-kind.md) | Information model derived from the ontology by `one table per kind` | Accepted |
| [0005](0005-telemetria-da-jornada.md) | Journey telemetry: `:telemetry` as the bus, a local collector, a declared taxonomy | **Proposed** |
| [0006](0006-coleta-paralela.md) | Parallel collection: concurrency per repository, an atomic counter first, and the rate limit that hibernates without sleeping | **Proposed** |
| [0007](0007-gestor-de-cotas.md) | Quota manager: the quota belongs to the GitHub user, one process governs it, and collection resumes where it stopped | Accepted |
| [0008](0008-vinculo-observado.md) | The observed team membership: the participation the tool shows counts as a member, and the role is what is declared | Accepted |
| [0009](0009-api-publica-com-token.md) | The public API: the token identifies who, and the verdict is still a single one | **Proposed** |
| [0010](0010-hash-do-token-de-api.md) | The API token is stored as a **hash**, and not encrypted like the other credentials — the question that separates the two cases is whether the platform needs to **recover** the value | Proposed · 2026-09-18 |

## When to write an ADR

Every decision on this list requires an ADR before it is implemented:

- abandoning the modular monolith or introducing microservices;
- introducing Python, Go or another backend;
- introducing a separate frontend;
- replacing PostgreSQL or Oban;
- introducing an external broker, a graph database or pgvector;
- changing the multitenant strategy;
- changing the organization by ontologies;
- changing the role of YAML as the knowledge base, or its versioning;
- changing the separation between external source and domain;
- changing public contracts;
- abandoning Spec Kit.

## Format

A file `NNNN-title-in-kebab-case.md` with the sections: Status, Context, Decision,
Alternatives considered, Consequences. An accepted ADR is not edited to change one's
mind — a new one is created that supersedes it, and the old one becomes *Superseded by
NNNN*.
