# The public API — for integrators

A JSON read of what the platform observed: teams, people, projects and collections.
**Read only.** No write method answers.

> **Going to connect an agent?** The MCP server, at `/mcp`, has its own document:
> [mcp.md](./mcp.md). Read it before generating the token: what an agent reads can leave the platform's
> control, and the choice of owning account and term is the control that is in your hands.

**Address**: `https://theband.5.189.161.85.sslip.io`
**Version live**: `0.9.0` — check it at `/version`, which is open.

> Every number in this document was **measured in production** on 2026-09-23. Where a
> number appears, it came from a real call, and not from an invented example.

---

## In three minutes

**1. Generate a token** at `/api-tokens`, logged in to the platform.

**Copy it at the moment of creation.** It cannot be shown again: leaving the screen erases it, and the
platform keeps only the hash. If you lose it, revoke it and generate another.

**2. Call:**

```bash
TOKEN='tb_api_...'

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://theband.5.189.161.85.sslip.io/api/v1/teams?page_size=5"
```

**3. Read the description** — it is open, it needs no token:

```
/api/openapi     a descrição OpenAPI, gerada do código
/api/docs        a interface para navegar, atrás de login
```

> **The token is only read from the `Authorization` header.** In a query string, body or cookie it
> is ignored and the request gets a `401` — a query string leaks into server logs and into
> browser history.

---

## The eight routes

| Route | Answers |
|---|---|
| `GET /api/v1/teams` | the teams of your tenant |
| `GET /api/v1/teams/:id` | one team: identity, provenance, composition, roster |
| `GET /api/v1/teams/:id/members` | who belongs, and **by which assertion** |
| `GET /api/v1/teams/:id/measures` | open work, review wait, competencies |
| `GET /api/v1/people` | the observed people |
| `GET /api/v1/people/:id` | one person, with everything their screen shows |
| `GET /api/v1/projects` | the declared projects |
| `GET /api/v1/syncs` | the collections, and **what each one did not reach** |

No other exists under `/api/v1`, and there is a test that fails if someone adds one outside
this list.

---

## Six traps — read before adding anything up

This section exists because each of these was **measured in production**, and a number misread
is worse than no number at all.

### 1. The two wait medians do not add up, and you do not pick one either

`/teams/:id/measures` returns:

```json
"time_to_first_review": {
  "reviewed": { "count": 23, "median_hours": 0.2 },
  "waiting":  { "count": 79, "median_days": 46 }
}
```

Measured **in production**, on the `LEDS - ConectaFapes` team, on 2026-09-23:

```json
"reviewed": { "count": 20, "median_hours": 0.2 },
"waiting":  { "count": 64, "median_days": 43.0 }
```

Twenty reviewed in **twelve minutes**. Sixty-four waiting for **43 days**.

A single median would answer *"twelve minutes"* about 84 requests of which 64 nobody
touched. **Leaving out the ones in progress makes the measure improve the worse the team is doing**, because
the ones nobody reviewed are precisely the ones that matter most. Counting them as zero would assert
an instantaneous review.

If you are going to show a single number, show both.

A real example, from the same measurement:

```json
"competencies": [
  { "domain": "repository bootstrap and collaboration docs",
    "completed_tasks": 6, "evidence_issue_numbers": [1, 2, 3],
    "most_recent_period": "2026-02" },
  { "domain": "CloudEvents and Redis Streams",
    "completed_tasks": 3, "evidence_issue_numbers": [4, 7, 8],
    "most_recent_period": "2026-02" }
]
```

`completed_tasks` are **completed** tasks — delivery, never promise. A domain with no
completed task does not appear. And `evidence_issue_numbers` lets each competency drill down to
the record that supports it.

**`skills` is something else.** They are labels the model wrote, with no count and no evidence.
Treating them as equivalent would give the same authority to a domain with 24 tasks and to a
loose word.

### 2. `null` and `[]` say different things

In `competencies`, in the people listing:

| Value | Means |
|---|---|
| `null` | **there was no reading** — no profile was generated for this person |
| `[]` | **there was a reading, and nothing was demonstrated** |

Flattening the two into `[]` turns a gap in the record into a judgement of the person. When it is
`null`, the `competencies_note` field says why.

The same rule holds across the whole API: `null` is **stated** absence, never zero.

### 3. `completed` does not mean *complete*

`/syncs` returns, for each collection:

Measured **in production**, on the three most recent collections:

| `status` | collected | repositories skipped |
|---|---:|---:|
| `completed` | 5 233 | **29** |
| `completed` | 5 989 | 0 |
| `completed` | 479 | **34** |

**Two of the three finished without reaching dozens of repositories** — quota, permission, or the
source being unavailable.

Whoever reads only the `status` concludes the data is whole. That is why `gaps` travels in the same
object. And the four record counters **do not add up**: `collected` is what the source
returned; `created`, `updated` and `skipped` is what was done with each one, and each record falls
into exactly one of the three.

### 4. Two totals that look the same and are not

In `/projects`:

| Project | `issues.direct` | `start_criterion.total` | Boards |
|---|---:|---:|---:|
| ConectaFapes | **2 756** | **0** | 0 |
| Valida | 0 | **498** | 1 |

`issues` counts by the project's **repositories**; `start_criterion.total` counts by the
**boards**. A project can have one without the other.

Without noticing this, the reading of ConectaFapes would be *"2 756 issues with no start criterion"*.
What is actually there is that it has no declared board. The response carries `denominator_note`
warning about it.

### 5. `assigned` and `authored` do not add up, and the difference can be huge

Measured in production, on a real person:

```json
"assigned": 3, "authored": 57
```

Three issues assigned, fifty-seven opened by them. Adding would give 60, which is nothing:
whoever opens an issue does not necessarily work on it, and whoever works on it is rarely the one who
opened it.

The same holds in `verification`: `passed: 26` on the same person, next to
`unattributed_in_tenant: 4653` — runs that match no person at all. They stay
**out** of the first three counts, and adding them would assert a measure where there is none.

### 6. Adding people per organization gives more than the total

A person in two organizations appears **once**, with both listed. So adding up the
people of each organization gives more than the total of people — and that is correct.

A person's organization comes from their **teams**: there is no direct link. Whoever is in no
team at all comes with an empty list and the reason written.

---

## The marks that travel in the body

**`origin`** says how the platform came to know:

| | |
|---|---|
| `observed` | it came from a connected tool, and `source_system` says which |
| `declared` | someone declared it on this platform |

In `/teams/:id/members`, the mark lives **on each team membership**, not on the person: someone can be
observed on one team and declared on another, and both assertions hold at the same time.

**`ended_at` and `mistake`** are distinct fields: the first says *left*, the second *should never
have been asserted*. Flattening them would turn history into error.

**The profile is `derived`** — written by a language model from the collected record.
The mark comes in the object, along with the caveats it makes about itself in `limits`.

---

## Pagination

Cursor, not offset:

```bash
# primeira página
curl -s -H "Authorization: Bearer $TOKEN" "$API/api/v1/people?page_size=100"

# as seguintes: passe o next_cursor
curl -s -H "Authorization: Bearer $TOKEN" "$API/api/v1/people?page_size=100&after=<next_cursor>"
```

Stop when `page.has_next` is `false`.

**`total` comes as `null` in listings**, with the reason alongside in `total_note`: an estimated total is
worse than an absent total. `/projects` and `/teams/:id/members` **do have** a total, because they are
bounded collections.

Offset skips or repeats rows when the collection changes between pages. With a cursor the order
becomes by identifier — that is the price, and it is what makes the traversal stable.

---

## Usage limit

**120 calls per minute, per token.**

Measured in production: **200 calls with 20 in parallel → 121 went through, 79 refused.** The
cut is exact.

And something only measurement shows: **sequentially you do not reach the limit.** With a
network latency of ~1 s per call, the maximum is 60 per minute — half. The limit exists
to contain a parallel loop that does not converge, not to hinder whoever walks through pages.

Above it:

```
HTTP/1.1 429 Too Many Requests
retry-after: 8
x-ratelimit-limit: 120
x-ratelimit-remaining: 0

{"error":{"code":"too_many_requests",
          "message":"Rate limit of 120 requests per 60s exceeded. The window reopens in 8s.",
          "request_id":"..."}}
```

Every successful response carries `x-ratelimit-remaining`. Obey `retry-after` instead of
retrying immediately.

The count is **per token**: a noisy token does not spend the limit of another one from the same
organization.

**The window slides.** The minute is counted in ten-second slices, and the limit looks at the sum
of those covering the last sixty — there is no instant when everything resets and you can issue
double. `retry-after` points to when the next slot opens, and not to the end of an arbitrary
minute.

---

## Errors

A single format, always:

```json
{"error": {"code": "unauthorized",
           "message": "The credential presented is not usable.",
           "request_id": "GNf8sTqAFGzHi6QAAA7i"}}
```

| Code | When |
|---|---|
| `unauthorized` | 401 — credential absent, invalid, revoked or expired |
| `not_found` | 404 — does not exist, or is out of your reach |
| `method_not_allowed` | 405 — the API is read only; the `Allow` header says what it accepts |
| `too_many_requests` | 429 — usage limit |
| `internal_error` | 500 |

**Two deliberate things, and it is worth understanding why:**

**The message never says which cause it was.** For the `401`, it is identical for a token that never
existed, a revoked one, an expired one, and one whose account was disabled. Distinguishing them would confirm to
whoever tests a stolen credential that it once existed.

**Out of reach returns `404`, and not `403`.** A `403` would confirm the resource exists —
for whoever is scanning, that is half the answer.

The `request_id` links the refusal you see to the real reason, which stays in the platform's internal
log. Quote it when asking for help.

---

## What the API does **not** do

| | |
|---|---|
| **writing** | none. There is no honest author for the provenance of a write by token: the credential says whose account it is, and not who decided |
| **e-mail** | it does not come out of any route — neither the observed person's, nor that of whoever declared a team membership |
| **credentials and keys** | the API that lists them is the API that leaks them |
| **accounts, grants and roles** | administering access through the API widens the surface of the resource that **governs** access |
| **raw collected data** | the value is in the promoted data, not in the raw |
| **choosing the measures' window** | fixed at 56 days, and **declared** in `window` |
| **searching and paginating a person's list of issues** | the first page of 25 comes, like the screen |

---

## What is recorded when you call

Every successful read writes a row: **which credential, which route, which target, and
when**. The response body is **not** recorded — the record says *who read what*, never *what
they read*.

It exists so that abuse is detectable: someone accumulating, call by call, what the
verdict denies in each isolated query.

**That record is kept indefinitely** — decision of 2026-09-23, in
`api.access.thresholds`. There is no purge.

## Where the token lives is your responsibility

The platform has **a single control** over a token that has already left: revocation.

- outside the repository, outside the terminal history;
- revoke it when the machine goes out of use, or when someone leaves the team;
- revoking **marks**, it never deletes: the row remains, with the date and who revoked it.

---

## Two known limitations, declared

**The measures do not carry the knowledge base's declared limitations.** `/teams/:id/measures`
carries hand-written notes and the window, but not the formal provenance of each measure. It is
criterion SC-007 of the spec, not met — it is recorded in the
[feature's acceptance](../sprints/033-a-api-publica/aceitacao.md).

**The internal log does not distinguish the three causes of token refusal.** Nonexistent, revoked and
expired produce the same entry. It changes nothing for integrators — the response is already
identical on purpose — but it limits what the platform can say when investigating.
[Backlog item](../backlog/sc004-o-log-nao-distingue-as-tres-recusas.md).
