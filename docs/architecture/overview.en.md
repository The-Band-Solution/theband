# The Band architecture

The **data model** — tables, Ecto schemas and the reason for the shape of each one — is
in [modelo-de-dados.md](modelo-de-dados.md).

## 1. The problem

Software organizations use dozens of tools — GitHub, GitLab, Azure DevOps,
Jira, Sonar, CI/CD, monitoring, time tracking. Each one has its own data model,
its own vocabulary and its own notion of what "a task", "a bug", "a delivery" is.

Putting that data together in a data lake does not solve it: the names coincide, the concepts do not.
A Pull Request is not a merge. A Jira issue can be a user story, a requirement
or a defect, depending on a field. A Sonar *code smell* is not a defect.
Adding up numbers from systems that disagree about what they are counting produces
indicators that look reliable and are not.

The Band tackles this through semantics: the data is harmonized against **reference
ontologies**, and every piece of data carries its provenance. That makes it possible to answer not only
"what is the team's cycle time", but "where did that number come from, how was it calculated and
which data supports it".

## 2. Origin

The architecture derives from the doctoral thesis of Paulo Sérgio dos Santos Júnior
(UFES, 2023). There, The Band is the data integration component of the
*Immigrant* environment, built on **Continuum** — a Continuous Software Engineering
ontology (sub)network integrated with **SEON** and grounded in **UFO**.

The thesis describes The Band as a *Federated Information System*: autonomous
ontology-based services (OBS), each with its own repository (OBDR), communicating through a
message broker to keep consistency.

## 3. From the thesis to this implementation

This implementation **preserves the semantics and simplifies the topology**. The thesis's
layers become internal boundaries of a modular monolith, not separate services.

| Thesis layer | Here | Why |
|---|---|---|
| Application Integration Layer (ASAs, Extract Components) | `lib/the_band/integrations/`, `ingestion/`, `priv/connectors/` | same responsibility, with no separate process |
| Internal Data Communication Layer (message broker, Transform/Load) | Oban + `semantic_integration/` | Oban delivers queues, retries and scheduling on top of the PostgreSQL that already exists |
| Federated Ontology-Based Service Layer (OBS + OBDR) | `lib/the_band/ontology/<rede>/<ontologia>/` + prefixed tables | each ontology is a module with a public API and private schemas |
| Federated Data Access Layer | `analytics/`, `reportify/`, LiveView and APIs | same responsibility |

**What does not change.** The ontology modules remain autonomous from each other: one only talks to
another through the public API, never through the Ecto schemas. Federation becomes boundary discipline
instead of a network boundary — which is reversible when a module justifies
becoming a service.

**What the thesis requires and remains mandatory in the data model:**

- `internal_id` — stable identity of the data across ontology modules;
- `record_version` — the record's version, to detect desynchronization;
- **Application Reference** — `source_system` + `source_instance` + `external_id`,
  linking each record to the source entity in the external tool.

Without these three, there is no traceability — and without traceability the data does not serve the
system's purpose.

## 4. Data flow

```text
Fontes externas (GitHub, GitLab, Jira, Sonar…)
  → conectores declarativos (definição YAML + query GraphQL, executados com Req)
  → payload bruto + proveniência          ← nada é descartado nesta etapa
  → mapeamento semântico (YAML)           ← equivalência, justificativa e limitações
  → validação semântica
  → API pública do módulo ontológico      ← o conector nunca escreve no schema
  → PostgreSQL / Ecto (tabelas prefixadas pela ontologia)
  → necessidades de informação → medidas → indicadores
  → Reportify → Phoenix LiveView e APIs
```

One external entity feeds **several** ontologies. A GitHub Pull Request produces:

- **CMPO** — the change request;
- **EO** — author and reviewers as persons;
- **SPO** — activities and participations;
- **SysSwO** — changed artifacts;
- **CIRO** — a possible pipeline trigger.

Each of these is a mapping of its own, with its own declared limitations.

## 5. Domain organization

The core is organized **by the ontologies**, not by the tools. There is no
`TheBand.GitHub` module in the domain: GitHub is a source, not a concept.

```text
lib/the_band/ontology/
├── ufo/                                    camada fundacional
├── seon/{eo,spo,sys_swo,rsro,cmpo,          core e domínio da SEON
│         roost,qapo,osdef}/
└── continuum/{sro,ciro,cdro}/              Continuous Software Engineering
```

Each ontology module exposes a public API through its root module and keeps `schemas/`,
`commands/`, `queries/`, `services/`, `relations/`, `constraints/` and `events/`
as internal details.

The direction of dependencies goes from the specific to the general and is verified
automatically. The complete graph is in [Ontology network](../ontology/README.md).

## 6. Knowledge base

The conceptual model does not live in the code: it lives in `priv/knowledge_base/`, as versioned,
validated and reviewed YAML. The code **loads** that model.

This is an architectural decision, not a convenience — see
[ADR 0002](../adr/0002-yaml-como-base-de-conhecimento.md). The practical consequence is that
a conceptual change shows up as a diff reviewable by whoever understands the domain, and not
as a change scattered across schemas and migrations.

## 7. Multitenancy

One PostgreSQL database, shared tables, `tenant_id` on every relevant entity,
access policies. No database per tenant.

Every domain query receives the tenant explicitly; every Oban job carries and validates
`tenant_id`. A missing tenant filter is treated as a security failure, not as a
correctness bug.

The knowledge base YAMLs are global. Per-tenant extension only comes in through a specified
feature.

## 8. Stack

```text
Elixir / Erlang OTP     Phoenix + LiveView
Ecto + PostgreSQL       Oban (filas, retries, agendamento)
Req (HTTP)              ExUnit + Mox
Credo + Dialyzer        ExDoc
Docker Compose (dev)    Phoenix Releases (deploy)
```

Outside the foundation, by explicit decision: Python, Go, a separate TypeScript frontend,
NATS, Kafka, RabbitMQ, Apache AGE, Neo4j, pgvector, Kubernetes, microservices.
Each one requires its own feature, a comparative analysis and an ADR — see
[ADR 0001](../adr/0001-monolito-modular-elixir.md).

## 9. Observability

All processing records, when applicable: `tenant_id`, `correlation_id`,
`source_system`, `source_instance`, `external_id`, `internal_id`, `ontology`,
`concept`, `mapping_id`, `schema_version`, `record_version`, `job_id`, `attempt`,
`duration`, `record_count`, `checkpoint`, `status`, `error_code`, `error_reason`.

Operational metrics: collection duration; records collected, transformed,
rejected and duplicated; synchronization delay; failures per source; retries; Oban jobs;
YAML validation failures; competency questions with errors.

## 10. Constraints the architecture imposes

- A connector does not write to an ontology module's Ecto schema.
- An ontology module does not access another module's schema.
- An external API model does not become the domain model.
- A concept that exists in a more general ontology is reused, never duplicated.
- Repeated processing is idempotent.
- All integrated data preserves provenance.
- No measure exists without a declared information need.
- No mapping exists without semantic justification and explicit limitations.
