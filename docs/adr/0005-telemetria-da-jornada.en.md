# ADR 0005 — Journey telemetry: `:telemetry` as the bus, a local collector, and a declared taxonomy

## Status

**Accepted — 2026-10-03**, decided by the maintainer on 2026-10-03, with SigNoz as the
backend and decisions D1–D7 below.

History: Proposed on 2026-09-04 · amended on 2026-10-03 with the choice of backend, hosting,
retention, network and the Hex dependencies — see
[Amendment of 2026-10-03](#amendment-of-2026-10-03--the-backend-is-signoz) · accepted the same day.

### The maintainer's decisions (2026-10-03)

Options and reasons in [074's seguranca.md](../../specs/074-jornada-entrar-e-sair/seguranca.md),
*Decisões da pessoa mantenedora* (the maintainer's decisions). All of them followed the recommendation.

| | decision |
|---|---|
| **D1** person identifier | raw `users.id`, **with minimization**: identity only in the outcomes that call for action, and in the sign-in's `concluiu` only when the success erased failed attempts. Moves to HMAC when another person gains access to SigNoz |
| **D2** dashboard access | **only through an SSH tunnel**; no route in Traefik |
| **D3** hosting | **same VPS, via Dokploy** (option A of E3), a 3 GB cap across the four containers, a dedicated network only between the application and the collector, no published port. **Falls** if the VPS has less than 4 GB free — checked in 074's T024 |
| **D4** retention | traces 7 days, metrics 30 days, no logs; the ClickHouse volume stays **out** of the backup |
| **D5** dependencies | accepted: `opentelemetry_api` 1.5.0, `opentelemetry` 1.7.0, `opentelemetry_exporter` 1.11.0, with exact versions, and `grpcbox ~> 0.18.0` for the ceiling; `mix.lock` reviewed; no new port listening |
| **D6** order | follows the §14.0 rule: 074's code waits for PR #1227 (#1222) to be merged. #887 (064/US3) has its tasks delivered (#871, #872, #873 closed) and waits only for the Product Owner's acceptance. #1162 comes before the SigNoz deploy |
| **D7** per-IP limit on `POST /session` | its own issue, outside 074: [#1229](https://github.com/The-Band-Solution/theband/issues/1229) |

Origin: [EPIC #802](https://github.com/The-Band-Solution/theband/issues/802), a request
from the maintainer · Depends on: [ADR 0001](0001-monolito-modular-elixir.md),
[ADR 0002](0002-yaml-como-base-de-conhecimento.md)

Closes, if accepted: [#801](https://github.com/The-Band-Solution/theband/issues/801)

## Context

On 2026-09-04, in the first collection against real data, three defects broke the
platform **without producing a single visible error**: Oban stopped processing for four
days while the application kept answering `HTTP 200`; an upsert with a race condition
brought down the sync after writing almost everything; and a failure handler broke while
recording the failure, discarding the job and the steps that followed.

All three were found by chance, with `psql`.

The platform is built on the thesis that **absence is not zero and the absence of errors
is not the same as working** — it applies this rigorously to the organizations' data,
and did not apply it to itself.

The maintainer defined the axis: **observe the journey of the people who use it, and
derive the metrics from that** — *"I want to know who got an error when logging in or
logging out"*.

### The constraint that decides the design

**A Plug does not see this application's journey.** After the initial `GET`, LiveView
exchanges messages over the WebSocket — `handle_event`, `handle_params`, `handle_info`.
A middleware would see the first load of the team screen and nothing of what the person
did inside it.

Login via `POST /session` would go through a Plug. *"Opened the team, tried to promote a
team membership, was refused"* goes through none.

## Decision

### 1. `:telemetry` is the bus, and it already exists

The application already has `TheBandWeb.Telemetry` with Phoenix and Ecto metrics
declared — what is missing is the exporter. Phoenix, LiveView, Ecto and Oban **already
emit** events. `:telemetry.execute/3` with no attached handler is an ETS lookup: a
negligible cost.

Nothing in the domain knows OpenTelemetry. The domain emits an event; whoever translates
it into a span is the handler, and the handler can be replaced without touching business
rules.

```
domain · LiveView · Plug
        ↓  :telemetry.execute          bus, zero coupling
   thin handlers (attach)
        ↓  create span/metric
   OTel BatchProcessor                 its own process, asynchronous
        ↓  OTLP to localhost
   collector (sidecar container)       retry, buffer, backend down
        ↓
   backend
```

### 2. The journey is captured in three layers

| layer | where | what it gives |
|---|---|---|
| `on_mount` | `TheBandWeb.Live.Hooks`, which already has three | identity and journey start in **every** LiveView, in a single place |
| `attach_hook(:handle_event)` | in the same `on_mount` | every interaction, without instrumenting screen by screen — **only the event name and the screen, never the parameters** (amendment of 2026-10-03; 074's seguranca.md, S2) |
| domain events | explicit `:telemetry.execute` | *"login failed because the account has no password set"* |

> **Amendment of 2026-10-03 (074's security assessment, S2)**: the `handle_event`
> parameters carry the GitHub token and the model provider's key typed into the tool
> screens (`source_live/index.ex`, `ai_live/index.ex`). The hook, when it exists, emits
> **only** the event name and `socket.view`, and comes in with its own security assessment.
> 074 does not implement it.

The first two are almost free and capture the whole journey. **The third is the one that
delivers the requested value**, and it is the only one that requires writing code in the
steps — because no automatic instrumenter knows the difference between *wrong password*
and *account with no password set*.

### 3. The journey is **not** a trace

A LiveView session lasts tens of minutes. A trace open all that time does not close,
does not export, and overflows the batch processor.

**One span per step**, with `journey.id` as the correlating attribute. The journey is
reassembled in the query, not in the process's memory.

### 4. Two classification axes, and they do not mix

| axis | answers | example |
|---|---|---|
| **journey** | what the person came to do | `entrar`, `sair`, `ler_painel_da_pessoa`, `coletar` |
| **domain** | what it is about | `eo.team`, `spo.performed_project_activity` |

Login is not an ontology concept, and `eo.team` is not a journey. Using a single axis
puts `login` on the same list as `equipe` (team), and neither question becomes
answerable.

```
span name       the_band.<dominio>.<passo>      the_band.acesso.entrar_com_senha
attributes      journey.name / journey.id / journey.step
                outcome           concluiu | falhou | abandonou
                failure.reason    conta_sem_senha
                tenant.id, user.ref            opaque
                ontology.concept               only when there is one
```

*Vocabulary aligned on 2026-10-03 with the knowledge base's taxonomy
(`rules/journey_entrar_e_sair.yaml`, spec 074), which is the single source: the filter on what
leaves (S1) validates the **value** against it, and two enumerations would produce two filters.
It was `ok | falha | abandonada`, `conta_sem_senha_definida` and `user.id`.*

**`outcome` and `failure.reason` are attributes, never part of the name.** A span named
`login_falhou_senha_errada` explodes the cardinality of names and loses the most basic
question — *how many login attempts were there?*. **The name is what was attempted; the
attribute is how it ended.**

### 5. The taxonomy is declared in the knowledge base, with a gate

`priv/knowledge_base/journeys/` declares each journey, its steps and the **closed list of
failure reasons**. A gate rejects a span whose `journey.name` or `failure.reason` is not
declared — the same design that [ADR 0002](0002-yaml-como-base-de-conhecimento.md)
established for concepts and measures, and that
[#527](https://github.com/The-Band-Solution/theband/issues/527) closed for ontology
modules.

Three consequences:

1. **`failure.reason` becomes a closed enumeration** — and a closed enumeration can be a
   metric label without blowing up cardinality. `user.ref` cannot; `conta_sem_senha`
   can, because there are five known values;
2. **the taxonomy does not rot**: a new failure without a declaration fails the gate,
   instead of becoming an orphan value nobody aggregates;
3. **there is a single vocabulary** — trace, spec, base and screen use the same names.

---

## Telemetry security

This section is normative. Telemetry is **a copy of what happens in the application
leaving the process** — with longer retention and looser access control than the
database. It is the path by which a secret leaves the system without anyone deciding it
should.

### S1. What NEVER goes into a span, event or log

A closed list, and no exception is accepted "for debugging":

| forbidden | why |
|---|---|
| the attempted password, **including truncated or hashed** | a password prefix is attack material; the hash of a weak password is reversible by dictionary |
| session token, cookie, `Authorization` | whoever has the trace can impersonate whoever was observed |
| the tool's token, the master key, an LLM credential | these are the credentials the platform encrypts in the database — exporting them in plain text cancels the encryption |
| OAuth code or `state` | exchangeable for a token while the window is open |
| body of the source's payload | it carries the client organizations' data, and is not platform data |
| a person's e-mail, name, login | see S2 |

**The guarantee is a filter in the exporter, not the discipline of whoever writes the
code.** ~~A `deny-list` of attributes applied before sending~~ — **amended on 2026-10-03**
(074's security assessment, S1): a deny list fails open, because the new attribute nobody put
on it leaves. The filter is a **list of what may leave**, and it **rebuilds** each span at the
last point before sending: the span name from a closed enumeration; attributes allowed **by
name and by the shape of the value** (the enumerations validated against the knowledge base;
UUID, HMAC or correlator checked by shape); **no events** (no `record_exception`, whose stack
carries the arguments); **status without a description**; the **resource rebuilt** with only
`service.name`, `service.version` and `deployment.environment`. Every drop is counted. Plus a
test that injects a password and a token into a journey and **proves they do not leave** — the
same technique as today's security review: inject the defect and verify that the mechanism
catches it.

Without that test, the rule is a comment.

### S2. Identity is personal data, and the request is legitimate

The request — *"I want to know **who** got an error"* — is operationally necessary:
without identifying them, nobody resets anybody's password.

And the privacy decision made on that same date (FR-024 of feature 058) says that
**reading the work of a named person requires reach over that person's team**. Telemetry
cannot be the back door to that.

The rules:

- **an opaque `user.ref`, never an e-mail.** The id solves everything the e-mail would
  solve, and leaks nothing on its own. Whoever needs the e-mail resolves it in the
  database, where there is access control;
- **shorter retention for traces with identity** than for aggregated metrics. The metric
  *"three failures due to account-without-password today"* can live for months; the trace
  that says **who** cannot;
- **who sees the telemetry is a declared decision**, like everything here. A *"who got
  the password wrong"* dashboard open to any account in the organization is surveillance
  under another name — and it would contradict FR-024 on the very day it was written;
- **an aggregate per tenant is internal-public; individual data is not.** The same line
  feature 058 drew between the team's median and the per-person breakdown.

### S3. The distinction that holds in telemetry and does **not** hold on the screen

*"Account does not exist"* and *"wrong password"* must be **distinct in telemetry** — the
actions are different — and **identical on the screen**, because distinguishing them
there hands an account enumeration oracle to anyone guessing e-mails.

It is the same information saying two things depending on the audience, and it is the
kind of decision that gets lost when it is not written down.

### S4. Telemetry cannot become a vector

- **The OTLP endpoint is `localhost`.** The application never talks to the external
  network to export; what crosses the boundary is the collector, and it is configured by
  whoever operates it;
- **the collector is not publicly exposed.** An open OTLP collector accepts forged spans
  from any origin, and poisoned telemetry is worse than absent telemetry — it produces
  wrong decisions that look like evidence;
- **the backend has its own authentication**, and its secret follows the same rule as the
  master key: an environment variable, never in the repository;
- **an exporter failure does not bring the application down, and is not silent.** The
  exporter is supervised, and whatever it discards because of a full queue **must be
  counted** — telemetry lost in silence is this house's defect applied to observability
  itself.

### S5. `:telemetry` detaches a handler that raises an exception

Behavior of the library, not of our code: a handler that fails is **removed
automatically**, the application carries on normally, and the telemetry vanishes without
warning.

That is exactly the failure mode of Oban's four days, one level up. **It requires a
test**: a handler that raises cannot take down all of observability without anything
reporting it.

### S6. What telemetry observes about access is auditing, and auditing has another owner

Login failure, scope grant and promotion to administrator are **security events**.
Recording them in telemetry is useful for operations, and does **not** make them an audit
trail: the trail requires long retention, immutability and chain of custody — the
opposite of the short retention S2 requires for data with identity.

This ADR does **not** create an audit trail, and that gap is declared rather than
assumed.

---

## Amendment of 2026-10-03 — the backend is SigNoz {#amendment-of-2026-10-03--the-backend-is-signoz}

**Origin**: the maintainer's direction on 2026-09-24 (*the focus becomes tracing with
SigNoz*) and on 2026-09-27, in the [comment on #802](https://github.com/The-Band-Solution/theband/issues/802):
*"create the tracing in SigNoz, based on the scenarios and the journeys"*. It closes decision 6 of
`docs/backlog/observabilidade-com-opentelemetry.md` (*where the data lives*). The first slice
that uses it is [spec 074](../../specs/074-jornada-entrar-e-sair/spec.md), J1.

The choice of product is the maintainer's, and it has been made. This amendment records **what
it costs, where it runs, and what must be true for it not to open a new door** — the four
things the original ADR left for "when there are numbers".

### E1. The alternatives, compared on what matters here

| | Tempo + Loki + Prometheus (+ Grafana) | Managed service (Grafana Cloud, Honeycomb, SigNoz Cloud) | **SigNoz on our own server** |
|---|---|---|---|
| what it is | four products, one per signal, with Grafana on top | another company's backend | one product: traces, metrics, logs and alerts on top of ClickHouse |
| pieces to operate | 4 services, 3 stores, trace↔metric correlation configured by hand | none | 4 long-running containers (ClickHouse, ZooKeeper, SigNoz, collector) and 2 migration ones |
| where data with identity goes | stays on the VPS | **leaves for a third party** — the `user.id` of whoever got the password wrong comes to live outside, under someone else's contract | stays on the VPS |
| dashboard authentication | Grafana's | the vendor's | its own, with roles (admin, editor, viewer) |
| alert on **absence** (the epic's US3) | Prometheus/Alertmanager, yes | yes | yes, alerts on metrics and on traces |
| cost | memory of 4 services; no per-event cost | by volume; free up to a ceiling, and the ceiling changes by the vendor's decision | the VPS's memory and disk (E3); no per-event cost |
| license | Grafana, Loki and Tempo under AGPL-3.0; Prometheus under Apache-2.0 | commercial contract | MIT outside `ee/` and `cmd/enterprise/` (own license there); ClickHouse under Apache-2.0 |
| what weighs against | four things to observe, in a project with one person operating | **S2**: personal identity leaves the system by a configuration decision, and [058's FR-024](../../specs/058-medidas-da-equipe/spec.md) stops being verifiable | ClickHouse is the VPS's biggest memory consumer after Postgres (E3), and SigNoz changed how it is installed (E2) |

**Why SigNoz**: of the three, it is the only one that meets at the same time **S2** (data with
identity does not leave the server) and **the operating cost of one person** (one product, not
four). The managed option would win on operations, and loses on the requirement this ADR
declared normative. The Grafana stack would win on memory per component, and loses on the
number of things to keep standing — which is, ironically, the defect this epic exists to see.

**What gets worse**: a product with its own opinion about storage (ClickHouse), whose
supported installation changed shape in mid-2026 (E2), and whose enterprise edition lives in
the same repository. Switching backends remains cheap **because the domain does not know the
backend** (decision 1 of this ADR): the application speaks OTLP, and OTLP is what all three accept.

### E2. How SigNoz is installed — and the version trap

Measured on 2026-10-03:

- the latest version is `v0.144.0` (`gh api repos/SigNoz/signoz/releases/latest`);
- **the packaged `docker-compose.yaml` no longer exists**: `deploy/docker/` is present in
  `v0.125.0` and absent in `v0.130.0`. `deploy/MIGRATION.md` of `v0.144.0` says that
  `install.sh` and the compose under `deploy/` are **deprecated** in favor of *Foundry*
  (`foundryctl forge` generates the manifests from a `casting.yaml`; `foundryctl cast`
  applies them). The Docker installation page already describes only Foundry;
- the `v0.125.0` compose publishes `4317`, `4318` and `8080` on **all interfaces** of the host,
  and ships `SIGNOZ_TOKENIZER_JWT_SECRET=secret` written in the file.

Consequences, all binding on the deployment:

1. **The deployed compose is generated and versioned**, not downloaded on the day. `foundryctl forge`
   runs on the operator's machine, the result goes into the repository with images pinned by
   tag, and Dokploy deploys **that** file. A `latest` image does not identify what runs —
   the same argument as the house's finding H7;
2. **no port of the collector, ClickHouse or ZooKeeper is published on the host.** The
   application reaches the collector through Docker's internal network;
3. **the secret of SigNoz's token issuer comes from the environment** (a variable in Dokploy, never
   in the file). The reference compose's value, `secret`, is public, and whoever knows it
   forges a session on the dashboard.

### E3. Where SigNoz runs, and what it costs

**Measured on this machine** (Docker Desktop, aarch64, 10 CPUs, 7.75 GiB for Docker), with the
`v0.125.0` compose (`signoz/signoz:v0.125.0`, `signoz/signoz-otel-collector:v0.144.4`,
`clickhouse/clickhouse-server:25.5.6`, `signoz/zookeeper:3.7.1`), the ports switched to
`127.0.0.1` and the project isolated (`docker compose -p signoz-medida up -d`), without touching
`the_band_postgres`:

```bash
docker compose -p signoz-medida up -d          # the v0.125.0 compose, ports on 127.0.0.1
docker stats --no-stream signoz signoz-otel-collector signoz-clickhouse signoz-zookeeper-1
python3 carga.py 100000                        # 100,000 OTLP/HTTP spans in J1's format
docker exec signoz-clickhouse clickhouse-client -q \
  "SELECT table, sum(rows), sum(bytes_on_disk) FROM system.parts
   WHERE database='signoz_traces' AND active GROUP BY table"
docker system df -v
docker compose -p signoz-medida down -v        # nothing left standing
```

| container | idle (~4 min after start) | right after 100,000 spans | 20 s later |
|---|---|---|---|
| `signoz-clickhouse` | 1.27 GiB | 1.63 GiB | 1.48 GiB |
| `signoz-zookeeper-1` | 773 MiB | 774 MiB | 774 MiB |
| `signoz` (query and dashboard) | 54 MiB | 54 MiB | 54 MiB |
| `signoz-otel-collector` | 28 MiB | 291 MiB | 291 MiB |
| **total** | **≈ 2.1 GiB** | **≈ 2.7 GiB** | **≈ 2.6 GiB** |

- **disk per span**: 100,000 J1 spans (six attributes, random ids) took
  **≈ 18.8 MB** in ClickHouse — `signoz_index_v3` 11.1 MB, `tag_attributes_v2` 5.1 MB,
  `trace_summary` 2.7 MB —, that is **≈ 190 bytes per span**. The 100,000 went in in 4.8 s;
- **image disk**: 2.58 GB (ClickHouse 851 MB, ZooKeeper 779 MB, collector 705 MB,
  SigNoz 248 MB). Empty volumes: ~70 MB;
- **what this measurement is NOT**: it is not the VPS (it is aarch64 with Docker Desktop), it is not
  SigNoz's current version (it is `v0.125.0`, the last with a packaged compose), and ClickHouse had
  no memory cap. It serves as an order of magnitude, and it matches the external source below.

**A defect found in the measurement itself, and it is the kind this house hunts.** On the
first start, the collector (`v0.144.4`) received its configuration from the server (`v0.125.0`) over
OpAMP; the server answered with an error, and the collector applied a **`nop`** configuration — with no
OTLP receiver in the pipelines. It stayed up, *healthy*, and **refused every connection on 4318**. A
collector that comes up green and receives nothing is Oban's four days, in the telemetry backend.
Running the collector with `--config` only solved it in the measurement; in the deployment, the defense is E2's —
server and collector versions **pinned together**, and 074's quickstart checking that a
test span **arrived** in ClickHouse, not that the container came up.

**J1 on disk**: with 50 people signing in and out twice a day, about 300 spans per day
— **≈ 57 KB per day, less than 1 MB in 7 days**. J1's disk is negligible; the cost is
idle memory.

**The external source, to check the order of magnitude**: Virtua Cloud measured `v0.116.1`
on a VPS with 4 vCPU and 8 GB — ~1.6 GB idle (ClickHouse ~775 MB, ZooKeeper ~775 MB, SigNoz
~50 MB, collector ~35 MB), ~3.4 GB under ~1,000 log lines/s and 100 traces/s, images taking
~2.7 GB and ~4.2 GB of disk in 24 h **under that load**
([virtua.cloud](https://www.virtua.cloud/learn/en/tutorials/self-host-signoz-openobserve-vps)).
The official documentation requires **at least 4 GB of memory for Docker**
([signoz.io/docs/install/docker](https://signoz.io/docs/install/docker/)).

**J1's load is another order of magnitude.** Signing in and out produces a handful of spans per
person per day; the source's load is ~8.6 million traces per day. What dominates the cost here
is the **idle memory** of ClickHouse and ZooKeeper, not the volume.

**The production VPS**: the runbook (§1.1) sizes **8 GB** for dashboard + app + Postgres. The
real size and the free memory **were not measured** in this amendment — the session has no access
to the server, and the house rule forbids stating what was not measured.

| option | what it costs | what weighs against |
|---|---|---|
| **A. On the same VPS, via Dokploy, with a memory cap** | ≈ 2.1 GiB of idle RAM, ≈ 2.7 GiB at the measured peak; ≈ 2.6 GB of images and less than 1 MB per week of J1 data; no new monthly cost | shares memory with Postgres and the application: without a cap, a ClickHouse peak becomes an OOM for whoever is serving |
| B. On a second VPS | one more small VPS per month, at Contabo's price on the day | the collector stops being local: the trace crosses the internet, and the collector needs TLS and authentication — S4 gets harder, not easier |
| C. Managed | by volume | rejected in E1 (S2) |

**Recommendation: A**, with three conditions, and the criterion that knocks it down written in advance:

1. **A memory cap** on SigNoz's containers (`mem_limit`) and on ClickHouse
   (`max_server_memory_usage` at 1.5 GB, below the measured peak of 1.63 GiB, which came from a
   burst of 100,000 spans in 5 s that J1 does not produce), adding up to at most **3 GB** for the
   four containers;
2. **measure before starting**: the maintainer runs `free -m` and `docker stats --no-stream`
   on the VPS and records it in the corresponding 👤 task. **If the available memory, with the application and
   Postgres up, is less than 4 GB** (the 3 GB cap plus 1 GB of headroom for Postgres's page
   cache), option A falls and B applies;
3. **measure after starting**: the same `docker stats` with SigNoz idle for 5 minutes, on the
   VPS, replaces this machine's measurement in this document.

### E4. Retention

SigNoz retains **per signal** (traces, logs, metrics), not per attribute. So S2's rule —
*shorter retention for what carries identity* — is met through the signal that carries the
identity:

| signal | carries identity? | recommended retention | why |
|---|---|---|---|
| **traces** | yes — `user.ref` and `tenant.id` (spec 074) | **7 days** | what says **who** got it wrong serves to act this week: reset the password, investigate a campaign. After that it is stored surveillance |
| **metrics** | **no** — labels only from closed enumerations (`journey.name`, `journey.step`, `outcome`, `failure.reason`) and `tenant.id` | **30 days** | it is the series that answers *"did this get worse?"*, and it does not say who |
| **logs** | the first slice **sends no logs** to SigNoz | — | the application's log stays where it is; sending logs is another slice's decision, with the same redaction as #1222 |

It is configured in SigNoz's screen (*Settings → General → Retention*). The configuration **is not
code**, and that is why the slice that uses it has a 👤 task with a check, not a test.

### E5. Authentication, access and network

- **SigNoz's dashboard is not public.** Recommended: no route in Traefik; access through an
  SSH tunnel (`ssh -L`) to the dashboard's port. Alternative, if the tunnel is too inconvenient:
  a Traefik route with HTTPS **and** an allowed-IP list **and** SigNoz's login. The
  first account created in SigNoz becomes the administrator — **the dashboard cannot be reachable
  before the maintainer creates that account**;
- **who sees it**: only whoever operates the platform. No client organization account sees SigNoz.
  That is what keeps S2 and 058's FR-024 true: the dashboard has the identity of people from
  **all** organizations, and so it cannot be offered to any of them;
- **the network** (refined in E7, item 2: a network only between the application and the collector): the application and the collector on the same Docker network; **the collector does not
  publish a port on the host**, and the application's OTLP endpoint is the service name on the internal
  network. This **corrects S4's wording**: "the endpoint is `localhost`" does not hold for an
  application in a container, where `localhost` is the container itself. What S4 wanted — *no
  collector reachable from outside* — holds as **no published port**;
- **the protocol**: OTLP over HTTP (`4318`), without TLS **inside** the Docker network, because it does not
  leave the machine. If option B of E3 is chosen, TLS and an authentication header
  become mandatory, and this line changes.

### E6. The Hex dependencies — what goes in, and what does not

Versions and dates measured at `hex.pm/api` on 2026-10-03:

| package | version | published | license | goes in? | why |
|---|---|---|---|---|---|
| `opentelemetry_api` | 1.5.0 | 2025-10-17 | Apache-2.0 | **yes** | the API the handler calls to open and close a span. Maintained by the OpenTelemetry project (`open-telemetry/opentelemetry-erlang`); ~32 M downloads |
| `opentelemetry` | 1.7.0 | 2025-10-17 | Apache-2.0 | **yes** | the SDK: the batch processor, sampling and the resource. Requires `opentelemetry_api ~> 1.5.0`. **1.4.1 was retired** for a *breaking bug* |
| `opentelemetry_exporter` | 1.11.0 | 2026-09-16 | Apache-2.0 | **yes** | the OTLP exporter. Requires `opentelemetry ~> 1.7.0`, `opentelemetry_api ~> 1.5.0`, `tls_certificate_check ~> 1.18` and `grpcbox` |
| `grpcbox` | 0.18.0 | 2026-07-11 | Apache-2.0 | **declared directly, `~> 0.18.0`** | the exporter requires it **with no ceiling** (`>= 0.0.0`) even when using HTTP; declaring it directly is only to set the ceiling (074's seguranca.md, S9). Requires `gproc ~> 1.2.0`, `ctx ~> 0.6.0`, `acceptor_pool ~> 1.0.0`, `ts_chatterbox ~> 0.16.0` |
| `ts_chatterbox` (transitive) | 0.16.0 | 2026-06-28 | MIT | comes along | requires `hpack_erl ~> 0.3.0` |
| `hpack_erl` (transitive) | 0.3.0 | 2023-06-03 | — | comes along | — |
| `ctx` (transitive) | 0.6.0 | 2020-12-23 | Apache-2.0 | comes along | **no release in almost six years** |
| `gproc` (transitive) | **1.2.0** | 2026-04-11 | Apache-2.0 | comes along | `~> 1.2.0` does not accept 1.3.0 |
| `acceptor_pool` (transitive) | 1.0.1 | 2025-12-15 | Apache-2.0 | comes along | — |
| `tls_certificate_check` (transitive) | 1.35.0 | 2026-08-13 | MIT | comes along | versions ≤ 1.6.0 were retired for *Outdated Certification Authorities*; requires `ssl_verify_fun ~> 1.1` |
| `ssl_verify_fun` (transitive) | 1.1.7 | 2023-06-20 | MIT | comes along | it is not in today's `mix.lock` |
| `opentelemetry_phoenix` | 2.0.1 | 2025-02-21 | Apache-2.0 | **no, in the first slice** | the route span carries `url.path` and `url.query`, and the query is where what S1 forbids lives. It answers *"is the server fine?"*, which this ADR already rejected as an axis |
| `opentelemetry_bandit` | 0.3.0 | 2025-08-21 | Apache-2.0 | **no** | same reason |
| `opentelemetry_ecto` | 1.2.0 | **2024-02-06** | Apache-2.0 | **no** | 20 months without a release. And the query span is exactly the path that [#1222](https://github.com/The-Band-Solution/theband/issues/1222) closed in the log. The rule in `TheBand.Repo.LogDaConsulta.redigir?/2` (over `TheBand.Rotacao.campos_cifrados/0`) is **necessary and not sufficient**: the login query passes the typed identifier over `users`, and the password `UPDATE` carries the `password_hash` — tables with no encrypted field. If it ever goes in, it goes in with its own assessment and also redacting `users`, `user_sessions` and the operator's credentials (074's seguranca.md, S3) |
| `opentelemetry_oban` | 1.2.0 | 2026-02-27 | Apache-2.0 | **no, in this slice** | it belongs to J2/US3 (collection and the stopped Oban) |
| `opentelemetry_req` | 1.0.0 | 2024-11-21 | Apache-2.0 | **no** | the outgoing HTTP span carries the URL and headers of the call to the source — where the tool's token travels |
| `opentelemetry_telemetry` | 1.1.2 | 2024-09-24 | Apache-2.0 | **no** | the house's own handler already attaches to `:telemetry` (decision 1); the generic bridge is generality without a second use |

**No instrumenter goes in in the first slice.** The spans are the **journey steps**,
emitted by the domain through `:telemetry.execute` and translated by **one** handler — which is where the
list of what may leave (S1) is applied. Each automatic instrumenter would be a second
path for attributes out of the process, without going through that list.

**There are eleven new packages**: three direct, `grpcbox` declared directly only for the ceiling, and seven
transitive (inventory corrected on 2026-10-03 by 074's security assessment, S9; the
first version of this amendment counted nine and gave `gproc` 1.3.0). They go through `mix hex.audit`
**and** `mix deps.audit` **before** the merge, with the `mix.lock` diff reviewed line by line
(a new package in the lock is a decision, not a side effect), and with the check, after the release
boots, that **no new port is listening** — `grpcbox`, `ts_chatterbox` and `acceptor_pool` are an
HTTP/2 client **and server**, and the HTTP exporter uses none of them.

**A risk the gates do not cover**: a single personal Hex account publishes `grpcbox`, `ctx`,
`ts_chatterbox` and `hpack_erl` (that of the OpenTelemetry Erlang maintainer). `hex.audit` sees
retirements and `deps.audit` sees known advisories; neither sees a malicious version
just published. `mix.lock` protects the versions already published, not the next ones — hence
exact versions on the direct ones and the ceiling on `grpcbox`.

Accepting the eleven is the maintainer's decision, together with this ADR's.

### E7. What 074's security assessment added to this amendment

The [assessment](../../specs/074-jornada-entrar-e-sair/seguranca.md), made by someone who did not write
this design, found three **high** points (S1, S2, S6) and eleven medium ones. Those that change this ADR are already
applied above (the ADR's S1, decision 2, alternatives, E6, vocabulary). Those that change the
**deployment** hold as conditions of option A in E3:

1. **The SigNoz deployment is blocked until there is evidence that was read** (S6): a versioned compose with
   no `ports:` key; on the VPS, `ss -ltnp` without 8080, 4317, 4318, 8123, 9000, 2181; **and** a
   connection attempt from outside the VPS, refused — because a port published by Docker comes in through the
   `DOCKER` chain of `iptables` **before** `ufw`, and checking the firewall proves nothing; the
   JWT key with no default value in the compose (without the variable, the container does not start); the first
   account created through the tunnel, and the user list checked afterwards; ClickHouse with a password from the
   environment; images pinned by **digest** (`@sha256:`), not only by tag;
2. **separate networks** (S7): one network only between the application and the collector; ClickHouse, ZooKeeper and
   the dashboard on another, without the application. The collector runs with a versioned `--config` and **without OpAMP** —
   which, in E3's measurement, rewrote the pipeline to `nop` and, in general, would let whoever administers the
   dashboard change where the data goes. A bearer token on the OTLP receiver is recommended in option A
   and mandatory in B;
3. **#1162** (Erlang distribution on `0.0.0.0`) is a prerequisite of option A: putting four third-party images
   within the application's reach is building on the door known to be open;
4. **what leaves through SigNoz itself** (S8): the product's usage telemetry turned off, checked
   through the container's **outgoing traffic** and not through the variable; the alert is on a metric, with no
   trace attribute in the body, and the channel is declared in the runbook;
5. **the real retention** (S13): ClickHouse's TTL acts on part merges, so the check is the
   age of the oldest trace after eight days; the ClickHouse volume stays **out** of the
   backup (or the backup has the same retention); the dimensions of any metric derived from traces
   are a second list of what may leave, versioned, without `user.ref` or `journey.id`;
6. **the SDK configuration** (S10): the SDK reads `OTEL_*` from the environment on its own. The application
   configures it **explicitly**, validates the destination against the allowed hosts and, without the variable,
   configures no exporter at all — the exporter's default is `localhost:4318`, which in the container
   is the application itself, and would be telemetry "on" failing silently.

### E8. What this amendment does NOT decide

- **the cost per request** (Verification 1) and **the volume of a collection** (Verification 2)
  still have no number: the first only exists with J1 instrumented, the second with J2. J1
  is negligible volume, and so the choice of backend does not depend on it; J2 does,
  and reopens E3 when it arrives;
- **sampling**: J1 is exported **in full** (no sampling). *Tail sampling* becomes a
  question again when J2 brings volume;
- **where the taxonomy lives, for now**: decision 5 foresaw `priv/knowledge_base/journeys/`.
  For **one** journey, 074 declares it as a `derivation_rule` in `rules/` (precedent:
  `access.account_lifecycle`), with no new schema — 074's research R7. The dedicated folder comes in with the
  third declared journey, and decision 5 still holds for what it requires: a closed
  list, and a gate;
- **pseudonymization of the person identifier**: decided in D1 (raw id with minimization; HMAC
  when another person gains access to SigNoz);
- **the order** (D6): 074's code waits for PR #1227
  ([#1222](https://github.com/The-Band-Solution/theband/issues/1222)) to be merged — §14.0, item 2:
  same surface. [#887](https://github.com/The-Band-Solution/theband/issues/887) (064/US3)
  has its three tasks delivered (#871, #872, #873 closed, checked on 2026-10-03) and waits only for the
  Product Owner's acceptance; it does not block.
  [#1162](https://github.com/The-Band-Solution/theband/issues/1162) is a prerequisite of the
  deployment under option A (E7, item 3).


---

## Alternatives considered

### Plug/middleware as the capture point

**Rejected** because of the constraint in the context: LiveView does not go through a
Plug after the mount. A middleware would deliver the login journey and lose all the rest
— and it would give the impression of coverage, which is worse than not having it.

### Automatic instrumentation only

Turn on the Phoenix, Ecto and Oban instrumenters and stop there. **Rejected**: it delivers
route latency and query counts, which answer *"is the server fine?"* — and the server
**was fine** during the four days Oban was stopped. It does not distinguish the five
outcomes of login, which is what was asked for.

~~It stays as the **base**, not as the solution: the automatic ones go in, and the domain
spans are added on top.~~ **Amended on 2026-10-03** (074's security assessment, S2 and S3):
the automatic ones do **not** go in by default. Each one is a second path for attributes out
of the process — the route carries the query string; the query carries the typed identifier and
the `password_hash` as a parameter, over tables that #1222's redaction does not cover; the HTTP
call carries the tool's token. An instrumenter only goes in through a slice of its own, with
its own security assessment, and through the same S1 filter (E6).

### One trace per LiveView session

**Rejected** for mechanical reasons: a 40-minute trace does not close and overflows the
batch processor.

### Structured logs instead of OTel

**Rejected** with a caveat. Structured logs with `journey_id` would answer a good part of
it, and are cheaper. They lose the automatic correlation between application, database
and jobs, and give no metrics without a second tool.

The caveat: if the cost measurement (see Verification) shows a relevant impact, this
alternative is back on the table — it is not ruled out on principle.

## Consequences

**Gained**: the ability to answer *who could not sign in and why*, *where the connect
journey gets stuck*, and *how many times the screen refused to show a number* — the
metric only this platform has, and which measures how much of the product's promise is
reachable with the data the organization has.

**Paid**:

- **one more process that can fail** — the exporter, supervised, with counted discards;
- **one more container on the VPS** — the collector, with measurable memory and disk;
- **manual spans in the journey steps.** This is where instrumentation ages badly: a
  `span` in every function pollutes the code. The defense is the axis — a span exists
  where there is a **journey step**, not where there is a function;
- **a taxonomy to maintain**, with a gate. A cost of discipline, and the same one the
  knowledge base already charges.

**Not solved**: none of this would have caught the stopped Oban. An inert Oban emits no
span — it emits nothing, and that is the definition of the problem. A trace shows what
happened; the failure was what **stopped** happening. What closes that hole is
verification **of absence** — a metric of completed jobs with an alert when it drops to
zero, or a *dead man's switch*. It is in the epic's US3, and it is the part that does not
come from the tool.

## Verification

This ADR is only accepted with measured numbers, not with estimates:

1. **cost per request** — instrument only the login journey and compare latency with
   and without it, in the same scenario. It is the number that decides whether the
   design pays off;
2. **volume** — how many spans a collection of 125 repositories produces. It decides
   between a self-hosted or a managed backend, and today nobody knows;
3. **the leak test** — inject a password and a token into a journey and prove they do
   not come out of the exporter (S1);
4. **the failing handler test** — prove that a handler with an exception does not erase
   observability in silence (S5);
5. **the taxonomy gate test** — an undeclared `journey.name` fails (item 5).

Without 1 and 2, the backend decision would be a choice in the dark. Without 3, 4 and 5,
the rules of this ADR are comments.

## References

- [EPIC #802](https://github.com/The-Band-Solution/theband/issues/802) — the proposal and
  the slicing into journeys
- [#801](https://github.com/The-Band-Solution/theband/issues/801) — the Oban that stopped
  without producing an error
- [#800](https://github.com/The-Band-Solution/theband/issues/800) — the race in the upsert
- `specs/058-medidas-da-equipe/spec.md` — FR-024, the access boundary S2 cannot bypass
- `docs/backlog/observabilidade-com-opentelemetry.md` — the five mapped journeys
