# ADR 0005 — Journey telemetry: `:telemetry` as the bus, a local collector, and a declared taxonomy

## Status

Proposed — 2026-09-04

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
| `attach_hook(:handle_event)` | in the same `on_mount` | every interaction, without instrumenting screen by screen |
| domain events | explicit `:telemetry.execute` | *"login failed because the account has no password set"* |

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
span name       the_band.<dominio>.<passo>      the_band.acesso.entrar
attributes      journey.name / journey.id / journey.step
                outcome           ok | falha | abandonada
                failure.reason    conta_sem_senha_definida
                tenant.id, user.id             opaque
                ontology.concept               only when there is one
```

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
   metric label without blowing up cardinality. `user.id` cannot; `conta_sem_senha_definida`
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
code.** A `deny-list` of attributes applied before sending, plus a test that injects a
password and a token into a journey and **proves they do not leave** — the same technique
as today's security review: inject the defect and verify that the mechanism catches it.

Without that test, the rule is a comment.

### S2. Identity is personal data, and the request is legitimate

The request — *"I want to know **who** got an error"* — is operationally necessary:
without identifying them, nobody resets anybody's password.

And the privacy decision made on that same date (FR-024 of feature 058) says that
**reading the work of a named person requires reach over that person's team**. Telemetry
cannot be the back door to that.

The rules:

- **an opaque `user.id`, never an e-mail.** The id solves everything the e-mail would
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

It stays as the **base**, not as the solution: the automatic ones go in, and the domain
spans are added on top.

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
