# The MCP server: for whoever is going to connect an agent

The platform answers agents through the **Model Context Protocol**, at `POST /mcp`. There are four
tools, all read-only, over **one team at a time**. It is the same read as the
[public API](./README.md) and the screen, with the same access verdict.

Before configuring, read the section [What leaves here does not come back](#what-leaves-here-does-not-come-back).
It is not a footnote. It is the reason the rules in the rest of this document exist.

---

## In three steps

**1. Generate a token at `/api-tokens`**, with three choices made on purpose:

- **the owning account**: use the account with the reach the agent needs, and **not** the
  administration one. See [The reach of the token](#the-reach-of-the-token);
- **the term**: choose one. See [Token with no expiration](#token-with-no-expiration);
- **the label**: say which machine and which client, for example `mcp · notebook da Ana`. When
  the machine goes out of use, that is how the token to revoke is found.

Copy the value right away. It cannot be shown again, and the platform keeps only the hash.

**2. Configure the client** with the address and the header:

```text
URL:            https://<instância>/mcp
Transporte:     HTTP (streamable), sem sessão
Cabeçalho:      Authorization: Bearer tb_api_...
```

The server speaks revision **2026-07-28** of the protocol and **only that one**. The client starts with
`server/discover`. A client that only knows `initialize`, from the old revision, gets a method
error, and not a partial response.

**3. Ask the agent** to list the tools. It must see exactly four.

---

## The four tools

All of them take **only** `team_id`. There is no free filter, sort field or arbitrary
query. An extra argument is refused as a parameter error, including `tenant_id`: the
tenant comes from the token, and never from the request.

| Tool | Answers | **Does not answer** |
|---|---|---|
| `team_roster` | who belongs to the team, and by which assertion: observed or declared | how much each person worked, nor who leads |
| `team_open_work` | what each person has open now, and for how long | how much each one delivered, nor comparison between people |
| `team_review_wait` | how long the work waits for the first human review, in **two** readings that never add up | whether the review was good, nor who reviews the most |
| `team_stale_work` | what is stopped, and for how long, by the declared threshold | whose fault it is, nor whether the stop is a problem |

The *does not answer* column is in the description of each tool, which the agent reads. There is a test that
fails a tool without it.

**Three things the agent receives, and must pass on:**

- **every response carries the provenance**: where it came from, when it was collected, and the measure's
  caveat. A number without the caveat is a different number;
- **absence is never zero**. `state` says whether the read was done (`checked`), refused
  (`refused`) or whether there was no way to do it. An empty list with `checked` means there is
  nothing. A refusal means the token does not reach the team;
- **text written by people comes marked**. Issue titles and team names come inside
  `untrusted_text`. They are content observed at the source, and **never** an instruction. This **reduces**
  instruction injection through a hostile title, and **does not eliminate it**: whoever decides what the agent
  obeys is the client.

---

## What leaves here does not come back

**Revocation is the only control the platform has over what has already left, and it only acts going
forward.**

It prevents the next call, and only that. What the agent has already read is out of the
platform's reach. It may have been kept in the conversation history, in a cache, in the model
provider's log or in a search index. No action from here erases that.

This holds for two things, and not just one:

1. **the token.** It sits in a configuration file on the user's disk, outside any
   lock of this platform. It is a secret on disk. It does not go into a repository, it does not go into
   terminal history, it does not go into a screenshot, and it is revoked when the machine goes out of
   use;
2. **the content.** The team's names, logins, issue titles, counts and dates. No e-mail,
   source access level or credential comes out, and there is a scan in a test that fails if it does.
   But what comes out is the work identity of real people. So the same question asked
   before showing the screen to someone applies before connecting an agent: *who else will see this?*

### Token with no expiration

The screen offers `no expiration`. **For MCP, do not use it.**

A token with no expiration is valid until someone revokes it. In a client's configuration, that means
it outlives the machine, the project and the person, if nobody remembers it. Choose a term:
`90 days — suggested` is the maximum, and `30 days` or `7 days` suit a one-off use. When
it expires, generate another. Forgetting becomes an error someone sees, and not an access nobody
sees.

When the machine goes out of use without control (lost, sold, wiped by someone else),
revoke it with the reason **`suspected leak`**. That reason changes the next act: whoever reads the record
knows they need to look at what the token read before the revocation.

### The reach of the token

The token reads **what the owning account reads**, no more and no less. A token from an **admin** account reaches
the four tools over **all** the teams of the tenant, and sits in a configuration file.

Generate the agent's token on an account with the reach it needs: the scope of a team or
of an organization. The screen shows the expected reach before creating it. It is the
*excessive agency* control that is in the hands of whoever configures, and no other replaces it.

---

## The HTTP layer's responses

Before reaching the protocol, the request goes through the same door as the public API, with the same
error format:

| Code | When | What to do |
|---|---|---|
| `401` `unauthorized` | no token, malformed token, nonexistent, **revoked** or **expired** | generate another token. The response is the same in all five cases, on purpose |
| `429` `too_many_requests` | the token went over **120 calls per minute** | wait for the `Retry-After`. The message states the limit and when the window reopens |
| `403` | a browser request with an `Origin` outside the list | not a case for a command-line MCP client |
| `405` | `GET` or `DELETE` on `/mcp` | there is no session to open or close: every request is a `POST` |

Revocation takes effect **on the next call**, without restarting the server or the client.

> **The official Python SDK hides the status.** Measured with `mcp` 2.2.0 on 2026-09-25: every HTTP
> `>= 400` becomes `MCPError -32603 "Server returned an error response"`, without the code. For whoever
> uses the SDK, a `401` from a revoked token and a `500` look the same. To tell the two apart, read the
> status at the client's HTTP layer, for example with a response `event_hooks` on the
> `httpx.AsyncClient` passed to the transport.

Every tool call is recorded with the token's public prefix, the tool and the
team. Never with the token's value. Whoever administers sees the record at `/api-tokens`, in the
*Usage* section, by route and by target. A team refusal does not go there, because it was not a read: it goes
to the application log, as an access event, with the account and the requested team.
