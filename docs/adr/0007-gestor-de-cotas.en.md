# ADR 0007 — Quota manager: the quota belongs to the user, one process governs it, and collection resumes where it stopped

## Status

Accepted — 2026-09-05 ("implement it"). Amended on the same day by the implementation, at
the two points marked **Amendment** below.

Depends on: [ADR 0006](0006-coleta-paralela.md) — hibernating without sleeping is what the manager's wait triggers
Related: [ADR 0005](0005-telemetria-da-jornada.md) — J2 observes the wait this ADR decides

Study requested on 2026-09-05 ("since the problem is the shared quota, we can build a
quota manager in which we resume where we stopped"). Nothing here is implemented. The
decision to accept belongs to the Product Owner; the proposed delivery order is in the
"Delivery" section.

It succeeds ADR 0006 and closes it: ADR 0006 decided to parallelize and hibernate; this
one decides **who knows how much is left** and **where collection resumes from**.

## Context

### What the assessment of the Broadway alternative concluded

Two agents (technical and Product Owner) assessed Broadway on 2026-09-05 and rejected it
for the same reason: **the collection's bottleneck is not work distribution, it is a
shared quota that nobody coordinates.** Distributing faster what hits the same quota only
brings the 403 forward.

### How the quota works at the source — checked against the GitHub documentation on 2026-09-05

| fact | consequence for The Band |
|---|---|
| The primary REST quota is **5,000 requests per hour, per authenticated user**. All tokens of the same user count against the same balance ("all of these requests count towards your personal rate limit"). | **The quota does not belong to the token, nor to the connected tool, nor to the tenant.** Two tenants with PATs from the same user share 5,000. Today nothing in the model knows this: the token owner's login is discarded in three places. |
| The GraphQL quota is **5,000 points per hour**, in a balance **separate** from REST. | There are two buckets. Exhausting one does not close the other — collection can carry on in GraphQL while REST reopens, and vice versa. Today the job's wait reads the wrong bucket in one of the paths (fixed in #806, but by a patch). |
| Secondary quotas: **100 concurrent requests**, **900 points/min REST**, **2,000 points/min GraphQL**, 80 content creations/min. Signaled with 403 or 429 and, sometimes, `retry-after`. | The total in-flight concurrency per user needs a **global ceiling**, not only per stage. Today: 5 Oban slots × 3 stages with fan-out 5 = up to **25 in flight** per PAT, with nobody counting. |
| The headers `x-ratelimit-limit`, `-remaining`, `-used`, `-reset`, `-resource` come in **every** REST response. In GraphQL, the `rateLimit { cost remaining resetAt }` object comes in the body when requested. | **The source counts for us.** A manager does not need to count requests: it needs to read what the last response said and correct for what is still in flight. Counting on its own goes wrong every time the same user uses the token outside The Band. |
| `GET /rate_limit` **does not consume the primary quota** (it consumes the secondary one). | It is the source for rebuilding the state when the process is born or the reset passes. It is not meant to be queried on every request. |
| Official recommendation: do not retry before `x-ratelimit-reset`; for the secondary quota, respect `retry-after` or wait ≥ 1 min with exponential backoff. | That is what ADR 0006 §5 already does with `{:snooze}`. What is missing is **deciding beforehand**, and in a single place. |

### What the code does today — inventory of 2026-09-05

**Six exit doors, four policies.** Every request to GitHub goes through
`HTTP.impl().get/2` or `.post/3`, but the client calls them in six different places
(`verify_credential`, `commit_files`, `workflow_runs`, `run_jobs`, `graphql`,
`segundos_ate_reabrir`). There is no single `request/1`. On top of those doors, four
different quota policies grew:

| stage | quota policy | where it reads from |
|---|---|---|
| EO (organization, members, teams) | `pause_needed?`: `remaining < cost × 2` → `{:snooze}` | GraphQL `rateLimit` |
| checks (REST) | `pausar_se_a_janela_encurtou`: `remaining < 2 × concurrency` → `{:snooze}` (since #806) | headers of the 200 responses |
| commit files (REST) | `esperar_janela`: **`Process.sleep`** until the reset, in the job's process (the sync turns it off with `wait_for_rate_limit: false`) | headers of the 403 |
| repositories, issues, projects, comments, changes, branches (GraphQL) | **none** — they receive `rate_limit` and discard it; they only discover the quota through the error | — |

**Twenty-five in flight, zero coordination.** Fan-out of 5 inside three stages
(`github_verifications`, `github_issue_comments`, `github_change_requests`), 5 slots in the
`ingestion` queue, and the screen allows triggering one synchronization per tool without
serializing. The same PAT can be registered in N tools of N tenants: no index prevents it,
no process sees it.

**"Resuming where it stopped" is partial today.** The `sync_checkpoints` table exists
(`entity_type`, `cursor`, `page_count`, `status`) and only the EO stages record a cursor —
and they reset it on completion, so resumption redoes the pagination from the beginning.
Projects and branches have no marker at all and are redone entirely on every resumption.
Issues, comments, changes and checks resume from the repository's `*_collected_at`, which
works. A `{:snooze}` in the sixth stage redoes the requests of stages one, two and seven on
the way back.

**The screen shows a countdown.** `SyncLive.Index` displays only the seconds that came in
the `{:sync_paused, _, s}` message, erased by the next progress message. Nobody sees how
much is left, when it reopens, or how many requests are in flight.

**Single node.** One container on Dokploy, no Erlang distribution, no `libcluster`.
In-VM-memory state is correct today. The "Consequences" section says what changes with two
nodes.

## Proposed decision

### What lives where — the question "store it in the database to resume?"

Three different states, three places, and the reason for each:

| state | where it lives | why |
|---|---|---|
| **where I stopped** — stage, cursor, repository, `done` | **database**, `sync_checkpoints` (already exists) | it must survive deployment, restart and crash; it is what the resumption reads |
| **when I come back** — the job's `scheduled_at` | **database**, `oban_jobs` (already so) | Oban's snooze is a row in Postgres; the server goes down in the middle of the wait, comes back up, and the job wakes at the right time |
| **how much is left** — `remaining`, `reset`, `em_voo`, `esperando` | **memory**, the `GenServer` | rebuildable in **one** free call to `/rate_limit`; a copy in the database goes stale the instant it is written (the owner spends quota outside The Band and it does not know) and would cost one write per request. The source is the truth; the manager is a cache |

Only the third row changes place when there is a second node — see Consequences.

Six parts, in the order in which they are delivered. Each one has a visible consumer; none
is infrastructure on its own.

### 1. The quota's identity is the GitHub user, and it starts being recorded

`Client.verify_credential/2` already returns `%{login: ..., scopes: ...}`. The three
callers discard the `login`. It starts being recorded in `tool_credentials.owner_login`
when the credential is validated, and the **quota key** is:

```
{instance_url, owner_login}
```

It is not the token (two tokens of the same user share a balance), it is not the connected
tool, it is not the tenant. **Two tenants with PATs from the same user go through the same
manager** — and that is correct, because that is how GitHub counts. The manager does not
keep the token nor know which tenant the request came from: it only counts.

The credentials screen shows the token's owner next to the last four digits. If two of the
tenant's tools have the same owner, the screen says: "these two tools share the same quota
of 5,000 requests per hour".

### 2. One process per identity: `TheBand.Ingestion.Cota`

One `GenServer` per key, under a `DynamicSupervisor`, located by `Registry`. It is born on
the key's first request and dies idle after an hour without use.

**State**, per bucket (`:core` for REST, `:graphql`):

```
%{limit: 5000, remaining: 4212, reset: ~U[...], em_voo: 3, esperando: 2, visto_em: ~U[...]}
```

**Three calls:**

```elixir
Cota.pedir(chave, balde, custo)     # :ok | {:espera, segundos}
Cota.observar(chave, balde, leitura) # cabeçalhos REST ou rateLimit GraphQL
Cota.estado(chave)                   # para a tela e para os testes
```

(`pedir` asks for permission and returns `:ok` or a wait in seconds; `observar` takes the
REST headers or the GraphQL `rateLimit`; `estado` serves the screen and the tests.)

**The granting rule:**

```
grant if  remaining  ≥  cost × (em_voo + 1 + ceiling)
ceiling = total in-flight concurrency allowed (global, 10)
```

> **Amendment (2026-09-05, implementation).** The original proposal was
> `remaining − em_voo − cost ≥ margin`, in requests. In GraphQL the unit is the **point**,
> and one connector query costs 100: with 150 points left the original rule granted, and
> the next page would consume two thirds of what was left. The rule now counts in units of
> the bucket — in REST (cost 1) it reduces to the original — and the manager uses the
> **larger** of the cost estimated by the client and the last cost seen for the identity,
> because a query's cost is only known after it runs.

`em_voo` is already in the calculation — that is why the margin is the concurrency, and not
`2 × concurrency` as today. Whoever is not granted receives
`{:espera, seconds_until_reset + 60}` and the stage translates it into `{:snooze}` as it
already does. Nobody sleeps inside the manager, nobody sleeps in the job: the wait belongs
to Oban, as ADR 0006 §5 decided.

**The truth is the headers, not the count.** `observar/3` replaces `remaining` and `reset`
with what the most recent response said (ordered by `visto_em`, because concurrent
responses arrive out of order) and decrements `em_voo`. If the user spent quota outside The
Band, the next header corrects it. Counting alone — as a local token bucket would
(`Hammer`, `ExRated`) — goes wrong exactly in that case.

**Reset.** When `now ≥ reset`, the balance goes back to **unknown** and the manager grants;
the first response of the new window brings the real balance and corrects it.

> **Amendment (2026-09-05, implementation).** The proposal was a call to `GET /rate_limit`
> at the reset and at birth. It would require the token **inside** the process — and the
> same section decides that the process keeps no secret. The cost of not making it is, in
> the worst case, up to `ceiling` requests granted in the dark that come back as 403 if the
> owner spent the quota outside The Band; the 403 is handled as today and the next reading
> corrects it.
>
> **Second reason, measured in Verification 4 (2026-09-06):** `GET /rate_limit` **lies**
> for the collection's token. It returned `core 5000/5000 used 0` and
> `graphql 5000/5000 used 0` while, at the same instant, the header of `GET /user` said
> `remaining 3366, used 1634` and the GraphQL `rateLimit` said `remaining 3013, used 1987`.
> The `reset` it reports is always "now + 1 h". A manager fed by it would believe in a full
> quota; a job that asked it how long to wait would sleep for an hour when only minutes were
> left. The source of truth is the headers and the `rateLimit` — and the manager keeps each
> bucket's `resetAt`, which is what the job now consults when GraphQL refuses without saying
> when it comes back. `/rate_limit` remains as a last resort, without a manager.

**Secondary quota.** The `em_voo` ceiling (10) stays below the 100 concurrent requests. For
the 900 points/min REST: 10 in flight with ~300 ms latency produce ~33 req/s in the worst
case, above the per-minute ceiling in a burst. The manager records `retry-after` when it
comes and refuses until it passes; a per-minute limiter only comes in if measurement shows
429 — not before.

### 3. One exit door: every request goes through the manager

`Client` gains a single internal function:

```elixir
defp requisitar(ctx, balde, custo, fun)  # fun.() faz o HTTP.impl().get/post
```

which does `Cota.pedir` before, executes (`fun.()` performs the `HTTP.impl().get/post`),
calls `Cota.observar` with the response afterwards, and translates `{:espera, s}` into
`{:error, {:rate_limited, reset}}` — the same error the stages already handle. The six exit
points start calling `requisitar/4`.

With that, four treatments **go away**:

- `pause_needed?/1` in the job's `do_paginate`;
- `pausar_se_a_janela_encurtou/2` and `margem_da_janela/0` in the checks;
- `esperar_janela/1` with `Process.sleep` in the commit files;
- the silent discard of `rate_limit` in the five stages that handled nothing — they gain a
  preventive pause without writing a single line.

`Client.rate_limit?/1` and `transient?/1` stay: they are the translation of the error, and
the manager does not change what the error means.

### 4. Resumption: a checkpoint per stage, the cursor recorded, a completed stage is not redone

`sync_checkpoints` already exists. It starts being used by **all** stages, with two
changes:

- **The cursor recorded on every page** in all GraphQL paginations — not only the EO ones.
  For the per-repository stages, the `entity_type` includes the repository
  (`"github.change_request:<repo_id>"`), and the cursor is the `endCursor` of the last
  recorded page.
- **On completion, `status: "done"` instead of `cursor: nil`.** When resuming the same
  `sync_id`, a `done` stage is skipped. A stage in progress resumes from the cursor. A
  stage with no checkpoint starts.

What this closes, measured in the inventory:

| stage | today on resumption | afterwards |
|---|---|---|
| EO (org, members, teams) | redoes the pagination from the beginning | skipped |
| projects and boards | redone entirely, no marker | skipped or resumed from the cursor |
| branches | redone entirely (`branches_collected_at` is written and never read) | skipped |
| issues, comments, changes, checks | incremental by `*_collected_at` | the same, plus the cursor inside the repository in progress |
| commit files | continues from `files_collected_at IS NULL` | the same |

**What does not change:** the `sync` stays `running` during the wait (ADR 0006 §5). The
`*_collected_at` remains the incremental cut **between** synchronizations; the checkpoint is
the cut **within** one.

> **Amendment (2026-09-05, implementation).** The unit of resumption **within** a stage is
> the repository, not the page. The per-repository stages accumulate pages in memory and
> write at the end (`paginar` → `gravar`); a cursor per page would only be worth it if each
> page were written as it arrived, which changes the structure of the six stages. What went
> in: `etapa:<nome>` marked `completed` at the end of each stage (the completed stage does
> not run again on resumption), the same test for the EO entities (which already had a
> cursor per page and now also have "completed"), and branches started skipping the
> repository traversed in this synchronization — the mark was written and never read. Cost
> of what was left out: a `{:snooze}` in the middle of a repository redoes the pages of
> **that** repository on the way back — in the largest of the measured organization, ten
> pages. A cursor per page in the per-repository stages is left for when the real
> measurement (Verification 4) shows it matters. The **organization** query runs on every
> pass — one request: it is the parent of the context (`organization_node`), and rebuilding
> it from the preserved payload was not worth the cost of one call per resumption.

### 5. The screen: the quota is visible, with a name

Principle IV: nothing on the screen without a declaration — and the reverse holds too:
nothing that decides stays invisible. `SyncLive.Index` gains a panel per quota identity:

```
Quota of paulo-junior on github.com
REST      4,212 / 5,000   reopens 14:32   3 in flight
GraphQL   3,980 / 5,000   reopens 14:07   1 in flight   2 synchronizations waiting
```

Fed by `Cota.estado/1` and by a `{:cota, chave, estado}` on PubSub on every `observar/3`.
The current countdown becomes one line of that panel, with the reason ("REST exhausted,
reopens in 12 min") instead of a loose number.

### 6. The stages are a graph, and the next one is the one with its dependencies ready and its bucket open

Today `coletar_trabalho/1` is a fixed list of seven stages, and the wait of any one of them
closes the whole job. But the two buckets are independent: when GraphQL is exhausted, REST
is full — and the REST stages do not need GraphQL to move.

Each stage starts declaring a **bucket** and **dependencies** (checked in the code on
2026-09-05):

| stage | bucket | depends on |
|---|---|---|
| EO — organization, members, teams | GraphQL | — |
| 1 repositories and issues | GraphQL | EO |
| 2 projects and boards | GraphQL | 1 |
| 3 issue comments | GraphQL | 1 (the issues must exist) |
| 4 change requests | GraphQL | 1 |
| 5 commit files | **REST** | 4 (the commits are recorded by stage 4) |
| 6 checks | **REST** | 1 (only needs the observed repositories) |
| 7 branches | GraphQL | 1 |

**The selection rule**, in place of the list: the next stage is the one with **all
dependencies `done`** in this sync's checkpoint **and whose bucket has a window**
(`Cota.estado/1` above the margin). If no ready stage has a window, the job hibernates
until the **smallest** `reset` among the buckets that unblock something — and not until the
reset of the bucket that has just closed.

What this changes, with the GraphQL quota exhausted right after stage 1 (the case measured
on 2026-09-05):

| | today | with part 6 |
|---|---|---|
| GraphQL closes after stage 1 | the job hibernates until the GraphQL reset; REST untouched | stage 6 (checks, REST) runs while GraphQL reopens |
| REST closes in the middle of stage 6 | the job hibernates | stages 2, 3, 4 and 7 (GraphQL) run; stage 6 resumes from the cursor when REST reopens |
| both closed | hibernates | hibernates — until the smallest reset |

A whole hour of one bucket stops being wasted while the other reopens.

**What does NOT change:** the result. Different order, same data — the dependencies
guarantee that no stage reads what has not yet been written. That is why they are
**declared** in the code and checked by a test, and not deduced: a stage that ran before
its dependency **would not fail** — it would collect zero, count zero, and mark `done`. It
is the silent success the base has already recorded eight times, and Verification 5 exists
for it.

> **Implementation note (2026-09-05).** The job asks the manager `janela_aberta?/2` — the
> same granting rule, without reserving — before choosing. A stage that returns a wait
> closes its bucket **for this pass** (the manager already knows; recording it in the job
> avoids trying the same bucket again). A stage that fails for another reason blocks those
> that depend on it: they are recorded as `bloqueadas` (blocked) in the summary and go to
> the next synchronization, instead of running on data that does not exist. Without a quota
> identity (one-off scripts), the list behaves as before: in order, until someone returns a
> wait.

**What is left out of this part:** running a REST stage and a GraphQL stage **at the same
time**. The primary buckets are separate, but the secondary quota (100 in flight, CPU) is a
single one, and the job today is one process with one sequence. First the selection by
availability, sequentially; concurrency between buckets only after Verification 4 measures
where the time goes.

## Alternatives considered

**Counters in ETS, without a process.** `:ets.update_counter` is faster and has no queue.
But there is nobody to wait: without an owning process, "who asked and did not get it" does
not exist, and the screen has no `esperando`. Speed is not the problem — 5,000 req/h is
1.4 req/s; a `GenServer.call` costs microseconds.

**A local token bucket (`Hammer`, `ExRated`).** They count what **we** did. The quota
belongs to the user, and the user uses the token in the browser, in `gh`, in another
system. The only authoritative data is the source's header. Rejected for the same reason
the base rejects "a limitation declared without looking at the data".

**Oban Pro's rate limiter.** Paid, and it limits per **queue**, not per quota identity. Two
tools of the same user in different jobs would remain uncoordinated.

**State in the database (`quota_windows`).** Correct for several nodes and survives a
restart. But every request would make a write, and the state can be rebuilt with one call
to `/rate_limit`. Postponed: it comes in when there is a second node (see Consequences),
with the `GenServer` becoming a cache and the database the truth.

**Broadway.** Rejected on 2026-09-05 by both agents; ADR 0006, Alternatives. This ADR is
what was proposed in its place.

**One process per token instead of per user.** Wrong at the source: two tokens of the same
user share a balance, and the manager would grant twice what exists.

## Consequences

**Gained:**

- One quota policy, in one place, for the seven stages — including the five that have none
  today.
- No primary-quota 403 in normal operation: the manager refuses beforehand.
- Resumption without redoing what has already been done — ADR 0006 §5 step 4,
  generalized.
- The screen says how much is left and why it is waiting.
- PAT duplication across tools and tenants stops being invisible.

**Paid:**

- One `GenServer` per identity is a serialization point. At 1.4 req/s it is irrelevant;
  it is declared for whoever measures with ten active identities.
- If the process dies, `em_voo` and `esperando` are lost; `remaining`/`reset` come back
  with the first response or with a call to `/rate_limit`. An acceptable loss: the worst
  case is one extra 403, handled as today.
- **Two nodes** break the assumption: each node would have its own manager, and the two
  would add up to double. That is not the case today (one container, no distribution).
  When it is, the "state in the database" alternative comes in, and this ADR gets an
  amendment. It is declared here so it does not become a surprise.
- `owner_login` is personal data of the token's owner (public GitHub login). It stays in
  the same encrypted table as the credential, visible only to whoever already sees the
  credential. No new exposure risk; recorded for the security assessment.
- The manager needs a token to call `/rate_limit` at the reset and at birth. It receives
  the token **per call**, never in its state — the process cannot be the place where a
  secret outlives the request.

## Verification

Four proofs, none of them a green suite: the measure is at the source or in the counter.

1. **Zero 403s under concurrency.** With the mock returning a `remaining` decreasing from
   15 and 25 concurrent requests for one key, the manager grants exactly up to the margin
   and no 403 is produced. Today: 25 in flight and a guaranteed 403.
2. **Two tokens, one balance.** Two connected tools with PATs from the same `owner_login`
   land in the same process and the second `pedir` sees the first one's `em_voo`.
3. **Resumption does not redo.** `{:snooze}` in the fourth stage; on the way back, stages
   one to three produce **no** requests (counter in the mock). Today: EO and projects redo.
4. **Real measurement.** A complete collection of the `leds-conectafapes` organization
   from scratch, with the panel open: number of 403s (expected 0), total time, and the
   lowest `remaining` seen in each bucket. It is ADR 0006's Verification 1 that the quota
   prevented from being measured — with the manager, it fits in one window.
5. **No stage before its dependency, and REST moves with GraphQL closed.** With the mock
   closing GraphQL right after stage 1: the job runs stage 6 (checks) and does **not** run
   stage 3 (comments) nor stage 5 (files, which depend on 4). Second part of the same
   proof: a stage whose dependency is not `done` is never chosen — the mock's counter for it
   is zero, and not "zero collected successfully".

## Verification 4 — measured on 2026-09-06

A complete collection of the `leds-conectafapes` organization (125 repositories) on the
development server, with the code merged in #808, the panel open and the log kept.

| what | measured |
|---|---|
| start → end | 22:54:22 → 00:04:37 UTC — **70 min**, of which **43 min hibernating** (23:13 → 23:56) |
| 403 responses from the source | **0** |
| manager refusals | 1 — REST `core` with **9 of 5,000** left, at 23:13, in the checks |
| REST used | 4,991 in the first window + 2,016 in the second ≈ **7,000 requests** |
| GraphQL used | 2,138 points in the first window; **1** on resumption (the organization) |
| GraphQL stages (work, boards, comments, changes) | 22:54 → 22:57, **3 min** |
| commit files (REST, 500) | 22:57 → 23:02 |
| checks (REST) | 23:02 → 23:13 (window closes) and 23:56 → 00:04; **6,042 runs recorded** |
| branches (GraphQL) | **23:13:21 — ran with REST closed**, before hibernating (part 6) |
| resumption at 23:56 | six stages skipped by the checkpoint; **zero requests** from them (part 4) |
| `verifications_collected_at` | 122 of 125 repositories marked at the end |
| token owner | discovered and recorded on the first pass (part 1) |

**What the measurement confirms:** Verifications 1 (zero 403s under concurrency), 3
(resumption does not redo) and 5 (REST moves with GraphQL closed — here the reverse:
GraphQL moved with REST closed) hold on real data, and not only in the mock.

**What the measurement found that the ADR did not foresee:** `GET /rate_limit` **lies** for
the collection's token — `5000/5000, used 0` in both buckets throughout the whole
collection. Recorded in the amendment to part 2 and fixed in #809: the GraphQL wait now
comes from the manager.

**Second unforeseen finding:** on resumption, the local DNS resolver failed — 501
`nxdomain` and some timeouts in eight minutes — and the checks stage recorded **835 runs
"without jobs"** in 14 repositories, without marking them. The source was fine; the data on
the screen was not. A transient failure now **stops the stage** and comes back in two
minutes, without recording anything (the same path as the window); the permanent one (404,
refusal) keeps recording without jobs. Fixed in its own PR. One observation remains: the
resumption asked for ~325 requests per minute with concurrency 5 — within the secondary
quota (900/min), but perhaps above what the local resolver sustains; a pace ceiling only
comes in if the next measurement repeats the picture.

**What the measurement says about the budget:** a complete collection of checks costs more
than one REST window (≈ 7,000 requests for 6,042 runs: one per run, plus one per listing
page). It is the cost of the first pass and of the resumption of repositories the quota
prevented from being marked on 2026-09-05; the following incremental pass asks only for
what changed. ADR 0006's Verification 1 (gain of concurrency 5 × 1) is still **without a
controlled measurement**: this collection is not comparable to a serial one, because the
serial one never completed.

## Delivery

Proposed order, each item with a screen or a measurement at the end. The Product Owner
decides what goes in and when.

| order | delivery | visible consumer |
|---|---|---|
| 1 | `owner_login` recorded and displayed; warning of a quota shared between tools | credentials screen |
| 2 | `Cota` + `requisitar/4` at the single door; removal of the four local policies; minimal panel (remaining, reset, in flight) | `SyncLive.Index`; Verifications 1 and 2 |
| 3 | checkpoint with `done` and cursor in all stages | Verification 3; resumption visible in the panel ("stage 4 of 7, page 12") |
| 4 | real measurement of the complete collection, and an amendment to this ADR with the numbers | Verification 4; ADR 0006 Verification 1 |
| 5 | stages as a graph: bucket and dependencies declared, selection by availability | the panel shows "checks moved ahead: GraphQL reopens 14:07"; Verification 5 |

Outside this ADR: state in the database for multi-node; a per-minute limiter for the
secondary quota (only if measurement 4 shows 429); REST and GraphQL stages concurrently
(only after measurement 4).

## References

- ADR 0006 — Parallel collection, §5 (hibernate without sleeping) and Alternatives
  (Broadway).
- Assessment of Broadway by the technical and Product Owner agents, 2026-09-05
  (transcribed in the report of PR #806).
- GitHub Docs, "Rate limits for the REST API" and "Rate limits and node limits for the
  GraphQL API", read on 2026-09-05.
- Code inventory on 2026-09-05: `client.ex` (six doors), `sync_github_eo.ex` (order of the
  stages, snooze), `checkpoint.ex` and `sync_checkpoints`, `SyncLive.Index`,
  `application.ex`, `Dockerfile`, `docs/producao/runbook.md`.
