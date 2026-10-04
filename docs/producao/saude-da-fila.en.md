# Queue health — a checker outside Oban (issue #801)

**The defect, measured on 2026-09-04 in development:** the server stayed up for four days
answering `200` on every route, with the database up, and **no job was processed**. The queue
piled up 524. Nothing flagged it:
- the application answered normally;
- the healthcheck only looked at Postgres;
- `TheBand.Jobs.ReconcileStuckSyncs`, the guard for this family of defect, **is an Oban job**, and
  stopped along with it.

This page is the contract of the checker that sits **outside** Oban.

## The rule: `TheBand.Saude.fila/2`

| state | when |
|---|---|
| `:ok` | the last completed job is less than **15 minutes** old |
| `{:parada, minutos}` | the last completed job is 15 minutes old or more |
| `{:parada, minutos}` | there has never been a completed job, **and** there is a job waiting (`available`) for 15 minutes or more. It is the database where Oban never ran |
| `:ok` | there has never been a completed job and nothing is waiting: a fresh installation, before the first `Cron` cycle |

**Why 15 minutes:** `Oban.Plugins.Cron` schedules `ReconcileStuckSyncs` and `ScheduleDueSyncs`
**every 5 minutes** (`config/config.exs`). In a healthy queue, some job completes at least
every 5 minutes. Three cycles without any is a stalled queue, not slowness. The threshold is
configurable in `config :the_band, :fila_parada_apos_minutos`.

**What it reads:** `max(completed_at)` and the oldest `scheduled_at` of `available` in
`oban_jobs`. They are two queries, and **neither of them goes through Oban**.

## The `Cron` in a queue of its own — finding S1, 2026-10-01

The rule counts on the `Cron` completing something every 5 minutes. Until 2026-10-01, the `Cron` jobs
(`ReconcileStuckSyncs`, `ScheduleDueSyncs`, `ApagaSessoesAntigas`) were in the `ingestion` queue,
the same as the collection, which has 5 slots, and each collection holds a slot for hours. **Five simultaneous
collections made the rule say "stalled" with the queue working**, the healthcheck marked
`unhealthy`, and restarting the container would kill the collections. The security assessment found the path
by reading the code, and there was no measurement.

Now they are in the **`manutencao`** queue, with 2 slots, and `test/the_band/jobs/fila_do_cron_test.exs`
fails if any `crontab` worker goes back to the collection queue.

**The false negative that remains (S8):** the verdict is for the whole installation. A queue that keeps
completing masks another one that is stalled. A saturated or stalled `ingestion` with the `Cron` moving is **not**
flagged by this rule.

## `TheBand.Saude.leitura/2` — what the `/syncs` screen needs (issue #801, part 3)

Decision Q3 of 2026-10-01: **a new function, next to `fila/2`**, which stays intact, and with it
`/health` and the healthcheck. The screen needs more than the verdict: to tell apart the two stall
cases and to show the times.

```elixir
%{
  estado: :andando | :parada | :sem_historico,
  causa: :ultimo_completado | :esperando_mais_antigo | nil,
  ultimo_completado_em: DateTime.t() | nil,
  esperando_desde: DateTime.t() | nil,
  parada_ha_minutos: non_neg_integer() | nil,
  conferido_em: DateTime.t()
}
```

| `estado` | when | `causa` |
|---|---|---|
| `:andando` | the last completed one is less than 15 min old | `nil` |
| `:parada` | the last completed one is 15 min old or more | `:ultimo_completado` |
| `:parada` | never completed, and the oldest waiting job is 15 min old or more | `:esperando_mais_antigo` |
| `:sem_historico` | never completed, and nothing has been waiting for 15 min | `nil` |

The verdict is **the same** as `fila/2`, by the same rule and the same threshold: `fila/2` is now
computed from `leitura/2`, and the two cannot disagree.

**An exception to principle V, written as an exception** (finding S3 of the 2026-10-01 assessment).
`oban_jobs` belongs to the installation, not to a tenant: the `Cron` jobs have no tenant, and filtering by
tenant would make every organization without a recent collection see "stalled" forever. That is why `leitura/2`
does **not** filter by tenant, and that is why it returns only a **scalar aggregate**:

- **returns:** the verdict, the cause, two times (the last completed and the oldest waiting),
  the minutes stalled and the time of the check;
- **never returns:** rows, `args`, `errors`, `meta`, worker name, queue name, job
  count, nor anything that identifies a tenant.

**Who sees it:** the `/syncs` screen, which requires `require_operacao` (admin or organization scope). The
verdict itself is already public at `/health`.

**What the screen shows with the queue moving** (decision P-1 of 2026-10-01, finding S2): only the verdict and
the time of the check, **without** the time of the last job. That time may belong to another organization,
and between two `Cron` cycles it would reveal the minute at which it finished a collection. With the queue
stalled, the time appears, because it is the fact the warning asserts, and in that case it is old.

**Where the recheck is armed** (finding S4): the 60-second timer is armed **only in the connected
`mount`**, and rearmed **only in its own `handle_info`**, which reads `leitura/2` and does **not** call the
screen's `load/1`. `load/1` runs the reconciliation, which is a global write, and is called from ten
places; arming the timer there would multiply the timers on every event.

## The two doors

### `GET /health`, without authentication

| response | body (plain text) |
|---|---|
| `200` | `ok` |
| `503` | `queue stalled` |

**It says nothing more than that.** No minutes, no count, no queue or worker name: the route
has no session, and each extra field would be new surface for convenience. Whoever operates sees the
detail in `/syncs` or in the log. It is the same decision as `/version`.

### The container healthcheck

```dockerfile
HEALTHCHECK … CMD /app/bin/the_band rpc 'IO.puts(TheBand.Release.saude_da_fila())' | grep -qx ok
```

The `rpc` runs **inside the node that is serving**, through the release's own cookie, and opens no
new port. The choice was the maintainer's on 2026-09-30, against installing `curl` in the image.
With the queue stalled, the container becomes `unhealthy`, and the orchestrator can restart it.

**`saude_da_fila/0` never brings the node down.** It returns `"ok"` or `"parada"`, and the decision is the
`grep`'s, on the outside. A function called by `rpc` that stopped the node would turn the
checker into a defect.

## What this contract does NOT cover

- **The `/syncs` screen saying "the queue has not moved for X".** It is a screen change, and goes through the prototype
  before the code. It stays for a later delivery of #801.
- **The root cause** of the Oban that stopped on 2026-09-04. It remains unknown: the checker detects,
  but does not explain.
- **Whether Dokploy restarts an `unhealthy` container.** In swarm mode, yes. This was not measured in
  this project's production.
