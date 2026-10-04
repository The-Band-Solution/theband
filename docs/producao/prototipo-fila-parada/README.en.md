# Prototype — the stalled queue notice on `/syncs` (issue #801, part 3)

| | |
|---|---|
| address | https://claude.ai/artifact/P1rCXLJdM4EqQCoUYZLjci (private) |
| copy that counts | `syncs-queue-stalled.html`, in this folder |
| published | 2026-10-01, version 1 |
| approval | **Decided 2026-10-01**, by the maintainer: D1–D8 approved, Q1–Q3 by option A (the recommendation). Republished at the same address |
| checker contract | `docs/producao/saude-da-fila.md`, `TheBand.Saude.fila/2` (PR #1029) |
| current screen | `lib/the_band_web/live/sync_live/index.ex` |

## The data, and where it came from

**Real**, from the development database (`the_band_dev`, container `the_band_postgres`), read
on 2026-10-01 at 10:15:13 UTC, in a `BEGIN READ ONLY` transaction with only `SELECT`:

| fact | value | query |
|---|---|---|
| last completed job | 2026-10-01 10:15:00 UTC | `max(completed_at)` in `oban_jobs`, `state='completed'` |
| waiting job (`available`) | none | `min(scheduled_at)` in `available` → null |
| states in `oban_jobs` | 1,157 `completed`, nothing else | `group by state` |
| completed in the last hour | 14 | `completed_at > now() - 1h` |
| completed workers | `ReconcileStuckSyncs` 578, `ScheduleDueSyncs` 578, `SyncGitHubEO` 1 | `group by worker` |
| syncs | 4 `completed`, 4 `interrupted`, 2 `failed`, **no `running`** | `group by status` |
| tool | `example-org`, interval `manual` | `connected_tools` |
| last run (screen 1) | 2026-09-28 12:49 → 15:03 UTC; 1,240 collected, 601 created, 588 updated, 0 skipped, 55 team memberships without a role; phases 1 / 64 / 8 / 59 / 131 of 131 / 5,624 of 5,624 / 610 / 28 of 64 | `syncs` and `sync_checkpoints` |

**Example** (marked `example` on screen): screens 2, 3 and 4 in full. The development
queue was moving, and there was no `running` run. The example numbers
follow the 2026-09-04 incident: last job 47 min before, a run that stayed
`running` in the middle of the issues.

## Decisions (numbered)

*Decided 2026-10-01* — maintainer — all as proposed: D1–D8 below, and Q1–Q3 by
option A (see the questions section).

1. **D1 — fact, verdict, action, in that order.** The time of the last job carries the mark
   `observed`; "stalled" carries the mark `derived` and writes out the rule (15 min, three cycles of
   5 min). The notice never says *error*, *failure* or *down*. Amber color and a hatched strip,
   never clay: it is a conclusion about the data, not an observed failure.
2. **D2 — the run record is not rewritten.** The `running` badge stays; next to it, the mark
   `not advancing · queue stalled`, and the two statements side by side ("the run record says"
   / "the queue says"), as 055 FR-012 requires.
3. **D3 — only times; no count, no worker, no tenant.** `oban_jobs` is
   shared among tenants, and whoever sees `/syncs` may have only organization scope.
   Counting waiting jobs would tell that viewer how much the other tenants have queued. Same
   reason as `/health`.
4. **D4 — the number moves without reloading.** With the queue stalled no progress event reaches
   the LiveView, and a number computed in `load/1` would freeze. The screen rechecks every minute
   and shows the time of the check (`checked 10:15 UTC`).
5. **D5 — "Close stuck sync" keeps today's rule.** A run with `available` work does not
   offer the button (`Ingestion.interruptible?/1` already works this way), and the card says why and tells you to
   restart first. A run with an orphan job in `executing` keeps the button and the current
   confirmation text.
6. **D6 — duration format.** `47 min`; `3 h 12 min`; `4 d 2 h`. Always with the absolute
   UTC time next to it. Today's `espera_em_texto/1` rounds `4 d 2 h` to `4 d`,
   and for the notice that is not enough.
7. **D7 — the "never completed" case writes the absence.** `last job finished: absent — none
   on this installation`, and the clock becomes the oldest waiting job, which is the only one
   that case has. The run without a checkpoint says `no page collected yet` instead of
   hiding the line, as it does today.
8. **D8 — a new installation (`:ok` with no history and no waiting) is not a notice.** One line with the
   mark `absent`: *no job has run yet*. Drawn only in the states table.

> **Real data replaced by an example on 2026-10-01** (decision P-3, finding S7): the repository is
> public. Organization login and collection numbers swapped for `example-org` and illustrative
> values. The private artifact keeps the version with the real data.
>
> (original: "**Dado real substituído por exemplo em 2026-10-01** (decisão P-3, achado S7): o repositório é
> público. Login da organização e números da coleta trocados por `example-org` e valores
> ilustrativos. O artifact privado guarda a versão com o dado real.")

## Premises the spec carries until they are contested

- **P1 — the runbook section needs to exist.** `docs/producao/runbook.md` **has no** stalled queue
  section today (checked on `origin/development`, 2026-10-01). The link and the steps of the
  notice depend on it. Recommendation: write it in the same delivery, before the screen links to it.
- **P2 — what the screen states about production is only what is measured.** The healthcheck marks
  `unhealthy` and `/health` answers `503` by construction (same rule). *Whether Dokploy
  restarts on its own* has **not** been measured, and the screen says exactly that.
- **P3 — security assessment before the code.** *In progress since 2026-10-01*, by another `security` agent, in parallel. The screen starts showing to whoever has organization
  scope a state read from a global table. D3 reduces this to times, but it is data
  across tenants and a new exposure: it calls for the `security` agent, from someone who did not design this.

## Questions — answered on 2026-10-01 by the maintainer, all by the recommendation

| | question | options | decision |
|---|---|---|---|
| Q1 | In the normal state, show the discreet queue line? | A. yes (screen 1) · B. nothing until it stalls | ***Decided 2026-10-01*: A** — without it, "there is no notice" and "the check did not run" look the same |
| Q2 | Sync and Reprocess with the queue stalled | A. disabled with the reason next to them · B. enabled, with a notice | ***Decided 2026-10-01*: A** — pressing Sync creates another `running` that does not move, the defect the notice exposes |
| Q3 | The screen needs more than `fila/2` returns | A. new read function alongside, `fila/2` and `/health` untouched · B. change `fila/2` | ***Decided 2026-10-01*: A** — `{:parada, minutos}` does not say which of the two cases it is, and changing `fila/2` touches the healthcheck contract for a screen need |

## Measures that need a name in the knowledge base before the code (principle IV)

> **Implementation decision, 2026-10-01: these three do NOT go into `priv/knowledge_base/`.**
> Principle IV calls for **domain** semantics in YAML: information needs about the
> measured Software Engineering, with `required_concepts` from the SEON/Continuum network, checked by the
> validator. "The Oban queue moved" is an **operational signal of the platform itself**, and there is no
> concept for it in any ontology of the network. Declaring one would be inventing a concept to fit
> the format. The signal's contract, with rule, threshold and rationale, lives in
> `docs/producao/saude-da-fila.md`. The table below stays as a record of what was proposed, and the
> decision stays in the PR, for the review to contest.
>
> (original: "**Decisão de implementação, 2026-10-01: estas três NÃO entram em `priv/knowledge_base/`.**")


| proposed name | what it is | type |
|---|---|---|
| `operation.queue.time_since_last_completed_job` | now − `max(completed_at)` | duration, observed |
| `operation.queue.oldest_waiting_job_age` | now − `min(scheduled_at)` of `available`, used only when there has never been a completed one | duration, observed |
| `operation.queue.stalled` | verdict: one of the two above ≥ `fila_parada_apos_minutos` (15) | indicator, derived |

Today `priv/knowledge_base/measurements/` has no operational measure; these would be the
first, and the information need ("is the platform processing background
work?") also needs to be declared.
