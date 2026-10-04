# ADR 0001 — Modular monolith in Elixir/Phoenix, not microservices

## Status

Accepted — 2026-08-08

## Context

The thesis that underpins The Band describes its architecture as a *Federated
Information System*: autonomous ontology-based services (OBS), each with its own
repository (OBDR), communicating through a message broker to propagate changes and keep
the repositories consistent.

Read literally, that description suggests an implementation with one service per
ontology — twelve services, twelve databases, a broker, and all the operations that
implies.

What the thesis actually requires is **semantic autonomy** between the ontologies: a
module cannot depend on another's internal model, reused concepts cannot be duplicated,
and every piece of data must be traceable to its origin. None of that requires separate
processes.

The project starts with a small team, no known scale demand, and the main risk
concentrated in **semantic correctness** — not in processing capacity. Distributing
early turns a modeling error into a distributed error, which is more expensive to
diagnose and slower to fix.

## Decision

The Band is born as a **multitenant modular monolith in Elixir/Phoenix**, with
PostgreSQL, Ecto and Oban.

The thesis layers become internal boundaries:

- each ontology is a module with a public API and private schemas;
- communication between modules goes exclusively through the public API;
- queues, retries, scheduling and propagation use **Oban** on the existing PostgreSQL,
  in place of the message broker;
- tables are prefixed by the ontology that owns the concept, preserving the separation
  of the OBDRs within a single database.

Autonomy is kept by boundary discipline verified in review and in tests, not by a
network boundary.

## Alternatives considered

**One service per ontology, with a broker (literal reading of the thesis).** Faithful to
the text, but it pays a high operational cost — deployment, distributed observability,
eventual consistency across twelve repositories — before there is any evidence that
scale justifies it. Modeling errors, which are the real risk at this stage, would become
more expensive to fix.

**Monolith without explicit internal boundaries.** Faster at the start, but it dissolves
precisely the property the thesis requires: if any module can read another's schema,
semantic autonomy disappears within a few months and does not come back without a
rewrite.

**Kafka or RabbitMQ as the backbone from the start.** It would solve propagation and
decoupling, but it adds an infrastructure component that has to be operated, monitored
and versioned — with no load to justify it. Oban covers the current case using a
database that is already mandatory.

## Consequences

**Positive**

- One deployment, one database, one observability stack.
- Conceptual refactoring is local and cheap while the model is still being validated.
- Local transactions guarantee consistency without distributed coordination.
- Oban delivers queues, retries and scheduling without additional infrastructure.

**Negative**

- Scaling is for the whole process, not per ontology.
- Autonomy depends on discipline: without review, the boundary erodes silently.
- An ontology with a much larger load than the others cannot be scaled in isolation
  without first being extracted.

**Mitigations**

- A public API per module with `defdelegate`; accessing another module's schema is a
  review failure, not a matter of style.
- Tables prefixed by ontology, keeping the logical separation of the repositories.
- Extracting a module into a service remains viable: the boundary already exists in the
  code.

**Triggers for revisiting**

- An ontology needing independent scaling or an independent release cycle.
- Ingestion volume exceeding what Oban comfortably sustains.
- A real need for independent external consumers per ontology.

Any of these requires a new ADR — this one is not revoked by preference.
