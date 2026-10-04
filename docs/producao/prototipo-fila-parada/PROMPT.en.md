# PROMPT — the stalled queue notice on `/syncs` (issue #801, part 3)

Address: https://claude.ai/artifact/P1rCXLJdM4EqQCoUYZLjci · copy: `syncs-queue-stalled.html`

## 1. The requests, verbatim and in order

**From issue #801** (maintainer, 2026-09-04), section "What would close it", third item:

> and the `/syncs` screen saying **"the queue has not moved for X"** — today it shows the sync as
> `running` and does not distinguish *running* from *abandoned*.

**From the contract `docs/producao/saude-da-fila.md`** (PR #1029), section "What this contract does NOT
cover":

> **The `/syncs` screen saying "the queue has not moved for X".** It is a screen change, and goes through the
> prototype before the code. It stays for a later delivery of #801.

**From the request to the Design role** (2026-10-01, passed on by the agent coordinating the session):

> Design:
> 1. the normal state (queue moving) — what changes, if anything;
> 2. the stalled queue state: the notice with **how long** (minutes/hours since the last
>    completed job), what this means for the syncs listed as `running`
>    (they are not advancing), and **what whoever operates can do** (the runbook: restart the
>    container; the healthcheck already marks `unhealthy`) — without promising what the platform does not do;
> 3. the case "nothing has ever completed, and there is a job waiting for X" (an installation where Oban never
>    ran).
> Respect: whoever sees `/syncs` is an admin or has organization scope (an operations screen); the notice states the
> fact and the action, without alarmism; no color alone. Use REAL data from the dev database (READ
> ONLY — SELECT; never write) for the normal state, and mark the stalled queue state as `example`
> if it does not exist in dev.

## 2. The brief I followed

- **Who reads:** whoever operates — an administrator or an `organization` grant. A person who may not
  have access to the server.
- **The screen's job:** separate *running* from *abandoned* without stating more than is known.
  The observed fact (time of the last completed job) comes before the derived verdict (stalled,
  by the 15 min rule), which comes before the action.
- **Tone:** operations, not incident. Amber and hatching (the shape of "derived"), never clay. No
  *error*, *failure*, *down*.
- **Honesty:** say what is not known (the cause), what was not measured (whether Dokploy
  restarts on its own) and what is not lost (each page is saved after it is processed).
- **Tenants:** `oban_jobs` is global. The screen shows only times, never counts, workers or
  tenants.
- **Inherited design system:** tokens from `specs/060-tela-da-equipe/prototipo/`, marks
  `observed` / `derived` / `absent` with shape and text, written absence, English on screen,
  mobile-first.
- **Data:** real on screen 1 (dev database, read-only); `example` on screens 2–4.

## 3. The approved structure, section by section — it is against this that QA checks

> Status: **approved — Decided 2026-10-01, by the maintainer.** D1–D8 approved; Q1, Q2 and Q3
> decided by option A. This section holds as it is. P3 (security) in progress in parallel.

### Screen 1 · `/syncs` · queue moving

1. Tabs `Collection` (active) and `Profile generation`, and the header `Syncs` /
   `Bring in from the tool what the platform comes to know.`, as today.
2. **New — queue line**, right below the header and above everything else:
   mark `observed` · `Job queue moving` · `last job finished <duration> ago, at <HH:MM UTC>` ·
   `checked <HH:MM:SS UTC>`. (Q1: *Decided 2026-10-01*, show it.)
3. Variant with no history and no waiting (new installation): same line with mark `absent` and
   `no job has run yet`. No notice.
4. The rest of the screen is today's, unchanged.

### Screen 2 · `/syncs` · stalled queue (last completed ≥ 15 min)

1. Tabs and header as today.
2. **The notice**, in place of the queue line, above the API quota and the tools:
   1. strip: hatching + `Job queue stalled · derived from the last finished job`;
   2. title: `The job queue has not moved for <duration>`;
   3. facts, three lines, in this order:
      - `last job finished` — `<YYYY-MM-DD HH:MM UTC>` + mark `observed`;
      - `stalled since` — mark `derived` + `no job finished for 15 min or more. The scheduler
        queues work every 5 min, so a moving queue finishes something at least that often.`;
      - `checked` — `<HH:MM UTC>, updated every minute`;
   4. block `What this means here`, three paragraphs:
      - `Runs marked running below are not advancing. Their status still says running because
        the job that closes stuck runs waits in the same queue.`
      - `Nothing collected so far is lost: each page is saved after it is processed.`
      - `Sync and Reprocess are paused on this screen until the queue moves. A new run would
        only wait in the queue.` (Q2: *Decided 2026-10-01*, disable with the reason)
   5. block `What you can do`, numbered list:
      1. `Restart the application container. This needs access to the server. If you do not
         have it, send this notice to whoever runs the platform. Steps: runbook, stalled
         queue` (link to the runbook section, P1);
      2. `In production, the container healthcheck already reports unhealthy and /health
         answers 503. Whether the server restarts the container by itself has not been
         measured.`
      3. `This notice clears by itself once a job finishes. If it is still here 15 min after a
         restart, restarting is not the fix: report it with the time shown above.`
   6. footer: `What this notice does not know: why the queue stopped.`
3. Tool card: `running` button disabled (as today when there is a run) with the
   reason `already running, and not advancing: the queue is stalled`. With no run in progress, the
   button is `Sync` disabled with `paused: the queue is stalled` (Q2, decided).
4. `Reprocess mappings` card: button disabled with `paused: reprocessing runs in the
   stalled queue` (Q2, decided).
5. Each `running` run:
   1. `running` badge **kept**, and next to it the `derived` mark `not advancing · queue
      stalled`;
   2. two boxes side by side: `the run record says` — `running, since <HH:MM UTC>. Nobody
      closed it.` / `the queue says` — `no job has finished since <HH:MM UTC>, this run's
      included.`;
   3. the phases as today; a phase without a checkpoint writes `not run yet` (never `—`);
   4. the last-progress line as today (`no progress for <duration>`);
   5. with no work in `executing`: the text `Close stuck sync is not offered: this run's work
      is still in the queue, and closing the record would not move it. Restart first.` With a
      job in `executing`: today's button and confirmation (D5).
6. No number of jobs, worker name or tenant anywhere in the notice (D3).

### Screen 3 · `/syncs` · never completed, and a job has been waiting ≥ 15 min

Same as screen 2, with these differences:

1. strip: `Job queue stalled · derived from the oldest waiting job`;
2. title: `No job has ever finished here, and work has waited <duration>`;
3. facts, four lines: `last job finished` — mark `absent` + `none on this installation`;
   `oldest waiting job` — `queued at <YYYY-MM-DD HH:MM UTC>` + mark `observed`;
   `stalled since` — mark `derived` + `work has waited 15 min or more and nothing has ever
   run.`; `checked`;
4. `What this means here`: `Background work has not run on this installation since at least
   <HH:MM UTC>. The run below was started and has not collected its first page.` and `Sync and
   Reprocess are paused on this screen until the queue moves.`;
5. `What you can do`: only items 1 and 3 of screen 2 (the healthcheck item goes away: the container
   may never have been the production one);
6. footer: `What this notice does not know: why the queue never started.`;
7. `running` run without a checkpoint: dashed box with mark `absent` and `no page collected
   yet: the run is waiting in a queue that has never run`.

### Screen 4 · phone (360 px)

The facts stack label over value; the two blocks stack; no horizontal scrolling.
All the texts of screen 2 remain (the prototype shortens only to fit the frame).

### Cross-cutting rules

- duration: `47 min` · `3 h 12 min` · `4 d 2 h`, always with the absolute UTC time (D6);
- the screen rechecks the queue every minute, without reloading (D4);
- the notice disappears by itself when a job completes;
- no information by color alone: every mark has shape and text, and `title` for screen readers.

## 4. How each role uses this file

| role | use |
|---|---|
| **Product Owner** | Q1–Q3 already decided (2026-10-01); records the link and this prompt in the #801 backlog item; requires P1 (runbook) and P3 (security) before the plan |
| **Security** | assesses P3 and D3 before the code: state of a global table shown to `organization` scope |
| **Elixir/Phoenix Developer** | implements exactly section 3; what does not fit goes back to the prototype, not to the code. Needs the NEW read function next to `fila/2` (Q3, decided: `fila/2` and `/health` untouched) and a 60 s timer (D4) |
| **Knowledge Base** | declares the three measures of the README and the information need before the code |
| **QA** | checks the delivered screen item by item against section 3, with a capture in states 1, 2 and 3 (a stalled queue is induced by stopping Oban on a test database, never in production) |
| **Design** | marks *Decided <date>* on the answers and republishes at the same address |
