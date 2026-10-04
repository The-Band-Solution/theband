# ADR 0010 — The API token is stored as a hash, and not encrypted like the other credentials

## Status

**Proposed** — 2026-09-18.

Required by: [`AGENTS.md` §16](../../AGENTS.md) — diverging from an established house standard requires an ADR. The standard is `TheBand.Encrypted.Binary`, and **every** credential of this platform uses it.

Depends on: [ADR 0009](0009-api-publica-com-token.md) — it is the one that decides to open the API by token.

Realizes: [spec 061](../../specs/061-api-publica/spec.md), FR-003 to FR-005.

Grounded in: [security assessment of 2026-09-09](../seguranca/2026-09-09-api-com-token.md), decision Q1.

## Context

The house has a standard for storing secrets at rest, and it is a good one: `TheBand.Encrypted.Binary`, which is Cloak with 256-bit AES-GCM, a master key coming from the environment, encryption in the `Ecto.Type` and never in application code. It is what protects the GitHub token, the model provider's key, and every third-party credential.

Applying it to the API token would be the frictionless path — and it would be wrong.

### The two things that look the same and are not

| | **third-party** credential | **API** token |
|---|---|---|
| who generates it | GitHub, the model provider | this platform |
| what the platform does with it | **replays** it — sends it back to the third party on every call | **checks** it — compares it with what arrives |
| does it need the value in clear afterwards? | **yes, always** | **no, never** |
| the right protection | reversible encryption | a digest function |

**The question that separates the two is a single one: does the platform need to recover the value?** For the GitHub token, yes — without it there is no call. For the API token, no: the client presents the value, and the platform only needs to know whether it matches.

Storing encrypted what only needs to be checked is keeping one more door. With the master key, `TheBand.Encrypted.Binary` gives **all** tokens back in clear.

## Decision

**SHA-256 of the secret, compared with `Plug.Crypto.secure_compare/2`, and the lookup made by the public id.**

The token has **three parts** — `tb_api_<id_publico>_<segredo>` (public id, secret) —, and the format is a consequence of the decision, not a preference.

## Alternatives, and why each was rejected

### `TheBand.Encrypted.Binary` — the house standard

**Rejected for being reversible.** It is the right protection for what the platform needs to replay, and the wrong one for what it only needs to check. Keeping the standard here would increase the surface without increasing the guarantee: a leak of the master key would come to include the credentials for getting into the platform itself, and not only the outgoing ones.

**The standard is still right where it is.** This ADR does not weaken it; it delimits it.

### `Bcrypt.hash_pwd_salt/1` — the "stronger" hash

**Rejected for cost and for lookup.** It is **~100 ms per verification**, measured and declared in `mix.exs` itself. That cost *is* the protection against low-entropy human passwords, where the attacker goes through a dictionary; in an API that serves request after request, it is a self-inflicted denial of service.

And there is a second, less obvious reason: bcrypt has a per-row salt, so **it cannot be looked up by index**. Checking would require loading candidates and testing them one by one.

**What decides is the entropy of the input, not a preference for the strongest hash.** It is 32 bytes from a cryptographic generator — 256 bits. There is no dictionary to go through, and key stretching protects against nothing that exists here.

## The two consequences the decision drags along, and the second is easy to get wrong

### The comparison has to be in constant time

Today the session compares the token with `==`, and **it is correct**: the value comes from a cookie signed by the server itself, and without the signature no value can be iterated to measure time.

In the API the value comes **raw from a header controlled by the caller**. The timing channel is reachable, and `Plug.Crypto.secure_compare/2` is mandatory.

### The lookup has to be by the public id, and never by the hash

`where: t.token_hash == ^hash` hands the comparison to **Postgres**, outside our timing control — and undoes the previous guarantee in the same gesture that seemed to fulfill it.

**That is why the token has two parts besides the prefix.** The public id is indexed and unique, and it is by it that the row is found; the secret is checked in memory, in constant time.

## Consequences

**What improves.** A database leak gives no token back. Verification costs one SHA-256 — microseconds —, and the API can handle requests in series.

**What gets worse.** The token gets longer, and the parser needs a fixed format with a test for each malformed input. The public id is one more piece of data that leaks in any header log — so **logging the `Authorization` header cannot exist**, and that becomes an invariant, not a recommendation.

**What the scheme loses for free.** There is no way to recover a lost token: the path is to revoke and generate another. It is the right behavior, and the screen has to say so at the moment it shows the value.

**What the house gains beyond this token.** The question that separates the two cases — *does the platform need to recover the value?* — becomes the default question for every new secret. It is more useful than "which hash is stronger", which is the question that leads to bcrypt in an API.
