# ADR 0006 — Parallel collection: concurrency per repository, and the counter that must be atomic first

## Status

Proposed — 2026-09-04

Depends on: [ADR 0001](0001-monolito-modular-elixir.md)
Related: [ADR 0005](0005-telemetria-da-jornada.md) — J2 observes what this one speeds up

## Context

The first collection against real data, on 2026-09-04, was measured:

| measure | value |
|---|---|
| repositories traversed in the changes stage | **86** |
| time | 09:32:04 → 10:06:39 = **34.5 min** |
| per repository | **~24 s** |
| simultaneous jobs | **1** |
| capacity of the `ingestion` queue | **5** |

**Four slots idle the whole time.** The code traverses serially:

```elixir
resultados = Enum.map(repositorios, &coletar_repositorio(ctx, &1))
```

And in the measured stage it was not the rate limit: the GraphQL quota is 5,000
points/hour, and ~2.5 repositories per minute does not come close. If it were, there
would be a `snooze` — and there was none.

**Correction of 2026-09-05, pointed out by the independent technical assessment**: that
sentence holds for the **changes**, which use GraphQL. The **checks** use REST — one
request per run, in the `core` bucket, which has its **own** quota and reset. It was that
bucket that blew up twice that day, and the original ADR treated the two as one.

The arithmetic that decides everything: 5,000 req/h is **1.39 req/s sustained**. The
collection with concurrency 5 did ~4 req/s — it spends the whole hour of quota in **~21
minutes**. The 3,316 runs of 10 repositories extrapolate to ~28,000 requests for the
initial load of 86: **at least 5.7 hours of quota at 100% utilization, with any
concurrency**. The design cannot go faster; it can only avoid wasting requests and cross
several windows without losing its place. **It is coordination of an external quota, not
processing.**

### The failure mode serialization produces

On the same day, a `KeyError` in a single repository brought down the whole job: five
attempts, `discarded`, and **the following stages never ran** — the checks stayed at zero.
An error in one repository cost the collection of all of them.

Serializing is not only slow: **it ties the fate of 88 repositories to the worst of
them**.

## Decision

### 1. The framework does not change: Oban stays

Persistence, resumption and state visibility are what an hours-long collection needs,
and that is what Oban provides. **The change is one of granularity, not of tool.**

Broadway, GenStage and Flow were considered and rejected: the source is a paginated API,
not a queue, and none of them persists. They would swap the problem we have for one we do
not have.

### 2. Before parallelizing: the counter must be atomic

`Ingestion.tally/2` is **read-modify-write**:

```elixir
%{records_collected: sync.records_collected + 1, records_created: sync.records_created + 1}
```

Under concurrency, two writes read the same value and one overwrites the other. The
result is not an error: it is **a number smaller than reality, with nothing reporting
it** — the family of defect this house hunts, now in the collection's own numbers.

**This is the first change, and it precedes any parallelism.** `update_all` with an
increment in the database, where the atomicity belongs to Postgres and not to our luck.

Parallelizing before that would produce a faster collection with wrong counters — and a
wrong counter on a progress screen is worse than a slow collection.

### 3. Concurrency within the stage, with a declared ceiling

`Task.async_stream` over the list of repositories, with `max_concurrency` declared as a
module attribute — not a literal scattered around.

The ceiling has two real limits, and the smaller one rules:

| limit | value | why |
|---|---|---|
| Ecto pool | 10 | each task needs a connection; exhausting the pool freezes the whole application, not just the collection |
| GitHub quota | 5,000 points/h | with 88 repositories it is not the bottleneck today; with 800 it would be |

**Initial ceiling: 5.** It leaves half the pool for the rest of the application, and it is
the same number as the `ingestion` queue — a useful coincidence, because it makes the cost
predictable.

`ordered: false` because the order of the results means nothing, and
`on_timeout: :kill_task` with a declared timeout, so that a slow repository does not hold
up the batch.

### 4. Fan-out per repository comes later, and starts with the checks

One job per `(repository × stage)` solves the coupling of fates — a repository that fails
does not take the others with it. It is the right change, and it is bigger: it requires
solving *when the collection has finished* (today the sync closes when the job ends), the
dependency between stages, and a global rate limit.

When it is done, **it starts with the checks**: it is the most expensive stage — one
request per workflow run — and the only one that depends on no other. Best return, lowest
risk, no DAG needed.

`Oban Pro` enters the conversation at that moment, and not before: `Batch`, `Workflow` and
global rate limiting are exactly this list of problems, solved. Buying it now would be
acquiring a solution to a problem we do not have yet.

### 5. The rate limit within the stage: hibernate without sleeping, and resume where it stopped

A request from the maintainer on 2026-09-05, after the real collection showed the cost of
what exists today: **98 repositories skipped and 586 runs without jobs**, all because of
the rate limit, in a collection that ended as `completed` as if nothing were missing.

What the code did when it hit the quota **in the middle** of a stage:

1. it marked the repository as not collected and **moved on to the next one** — which
   failed the same way, spending one more request against the secondary quota. There
   were 98 in a row;
2. it recorded the run without the jobs and moved on to the next run — 586 times;
3. it ended the stage with a partial summary, and the job with `:ok`. **The next
   collection redid everything**, including the request for the jobs of runs that
   **already had them** in the database — and hit the quota again, in the same place.

The obvious implementation is `Process.sleep` until the window reopens. **It is the wrong
one**, and the code already says why: a sleeping job looks stuck, `ReconcileStuckSyncs`
would terminate it, and the queue slot stays held for up to an hour doing nothing.

#### The algorithm

```
on receiving {:rate_limited, reset} within a stage:

  1. STOP the stage — do not try the next repository or the next run.
     They would all fail the same way, and every attempt is a request the
     secondary quota counts. With Task.async_stream this is reduce_while over
     the stream: tasks already started finish, tasks not started do not begin.

  2. DO NOT record a checkpoint for what was left incomplete — it is already
     so (L29), and it is what lets the resumption know where to continue.

  3. The stage returns {:snooze, reset} instead of {:ok, resumo_parcial}.
     The job propagates it: Oban reschedules WITHOUT consuming an attempt, the
     queue slot is released, the sync stays `running`, and no process sleeps.

  4. ON RESUMPTION, a repository without a checkpoint is redone — BUT a run
     that ALREADY HAS jobs in the database does NOT generate a new request for
     jobs. It is the difference between "resume where it stopped" and "start
     over": today the resumption redoes the same 3,316 requests and falls into
     the same hole.

  5. Repeat until the stage completes without a snooze.
```

**Step 4 is what makes the others useful.** Without it, hibernating and coming back only
postpones the same failure: the quota reopens, the collection redoes what it already had,
spends the quota again at the same point, and hibernates again — forever, on the same
repository.

#### What this does NOT change

The preventive `pause_needed?` (`remaining < cost * 2`) remains the first defense: it is
better to pause before hitting the limit than to handle the hit. This algorithm is the
second level — what happens when the preventive pause did not get there in time, because
something else spent the quota (a second collector, or the person using the same token in
`gh`).

## Alternatives considered

**Raising the limit of the `ingestion` queue.** It solves nothing: there is **one** sync
job, and it would be the same sequential job with more idle neighbors.

**Broadway.** Backpressure and concurrency ready-made, and no persistence of its own.

*Amended on 2026-09-05, after an independent technical assessment requested by the
maintainer.* The original argument — "the source is a paginated API, not a queue" — is
**weak**: the source of a pipeline here would be the list of pending
`(repository, stage)` pairs in Postgres, and an `ack` that records a checkpoint is enough
persistence. The correct argument is another one: **that producer is Oban** — a queue in
Postgres with `SKIP LOCKED`, `snooze` without consuming an attempt, `unique`, telemetry,
and `ReconcileStuckSyncs` decides "stuck" by querying `oban_jobs`. A pipeline outside Oban
would be terminated as an orphan within 60 seconds. Broadway on Postgres is reimplementing
the half of Oban that already pays for itself, to gain the half we do not need.

And Broadway's native `rate_limiting` measures the wrong thing: **messages per pipeline**,
at a fixed rate. The quota is **requests per token**, shared between stages, collectors and
the maintainer's `gh` — and every REST response already carries `x-ratelimit-remaining`,
which is the token's truth at that instant. Reading the header makes a fixed limiter
unnecessary.

**OTP + Broadway, plain GenStage, and the hybrid** were assessed and rejected for the same
reason: for a finite list of ~100 items with concurrency 5, `async_stream` **already is** a
demand-driven consumer. Backpressure solves a source faster than its consumer; here the
destination accepts less than what is produced. What pays off is a GenServer per token
only if it is a **budget read from the header**, not a fixed rate — and the first step of
that does not even need a process: it is returning the `remaining`/`reset` of the 200
responses, which today are discarded.

**`Task.async` without a stream.** No concurrency limit: 88 simultaneous requests blow the
Ecto pool and the GitHub quota at the same time.

**Full fan-out now.** Rejected on ordering, not on merit: it requires an atomic counter
(item 2), *"when did it finish"*, a DAG and a global rate limit. Doing everything together
is a big change with no intermediate measurement — and the intermediate measurement is
what tells whether fan-out is still worth it.

## Consequences

**Gained**: wall-clock time — the theoretical ceiling is 5× on the stage that takes 34
minutes today — and a counter that becomes correct, which today **nobody knows whether it
is**.

**Paid**:

- **concurrency in database access.** Five tasks writing at the same time to the same
  sync; item 2 is what makes this safe, and that is why it comes first;
- **an error inside `async_stream` changes shape.** A task that raises becomes
  `{:exit, reason}` in the stream, and not an exception in the parent process. Treating
  it as success is the classic way to lose a failure in silence — it needs an explicit
  branch and a test;
- **interleaved logs.** Five repositories log at the same time, and the log stops being
  readable in order. That is what J2 of [ADR 0005](0005-telemetria-da-jornada.md) solves,
  with a span per repository instead of a log line;
- **the test becomes sensitive to the Ecto sandbox.** A new task does not inherit the
  test connection automatically. Either `allow/3` is used, or the concurrency is
  configurable and the test runs with 1 — and the second option **does not test what
  matters**, so it is the first.

**Not solved**: a failing repository can still bring down the stage, because the job is
still a single one. That is item 4, and it is declared as not done.

## Verification

1. **the gain measured, not estimated** — the same stage, on the same set of
   repositories, with and without concurrency. Today: 86 repositories in 34.5 min. If the
   real gain is much smaller than 5×, the bottleneck is the network and not the design —
   and the ADR needs to be revisited;
2. **the counter is correct** — a test that runs N concurrent increments and asserts that
   the sum is N. With the current `tally` it fails, and that is what makes it proof;
3. **a task's failure does not become success** — a test that makes a task raise and
   asserts that the summary counts it as not reached;
4. **the pool does not blow up** — the application keeps responding during the
   collection.

## References

- [#801](https://github.com/The-Band-Solution/theband/issues/801) — the stopped Oban, and
  how the collection's progress became invisible
- [ADR 0005](0005-telemetria-da-jornada.md) — J2, which observes the journey this one
  speeds up
- `lib/the_band/ingestion/github_change_requests.ex` — the measured `Enum.map`
- `lib/the_band/ingestion.ex` — `tally/2`, the counter that has to change first
