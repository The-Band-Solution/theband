<div class="tb-assinatura">Features · the credentials</div>

# Every secret protected at rest

<dl class="tb-recibo">
<dt>the screen</dt><dd><code>/tools</code>, the credentials of each connected tool, and <code>/ai</code>, the model provider's key</dd>
<dt>the spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>064 · Draft · 2026-09-12</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/064-segredo-em-repouso">specs/064-segredo-em-repouso, on GitHub</a></dd>
<dt>in production</dt><dd><span class="tb-marca tb-observado"><span class="tb-q"></span>since v0.11.0</span> no recorded acceptance; the credential's age on screen not yet, it is in <code>development</code></dd>
<dt>the yardstick</dt><dd>only what the screen does; what the spec asks for and is not on the screen is named at the end</dd>
</dl>

The Band keeps three kinds of secret: the password of whoever signs in, what proves a session is
open, and third-party credentials — a tool's token, a model provider's
key — that the platform needs to present to whatever it collects from. This feature treats each one
the way it calls for, so that a copy of the database is of no use to sign in as anyone nor to use
anyone's credential. Almost all of this happens far from the screen. What shows on it is little, and it is
described below: what changes when signing in and out, and the age of each credential where it is administered.

## What you can now do

**Signing out now means signing out.** When you sign out, the session really ends, and not just in this browser.
A disabled account loses its open sessions immediately, and reactivating it does not give them back: whoever was
inside signs in again.

**Everyone signed in again once.** When v0.11.0 arrived, every open session stopped being valid, and
each person had to log in again. It was the only time, and it was on purpose: no session from
before the change becomes valid again.

**Seeing the credential without seeing it.** In the credentials table at `/tools`, the `credential` column shows
only the last characters of the token. The screen itself says why:

> *"The credential is encrypted at rest and is never shown in usable form. The last four
> characters exist only to tell one credential from another."*

At `/ai`, the provider's key follows the same rule: *"Checked against the provider before being
written, encrypted at rest"*.

**Knowing how long each credential has been in use** <span class="tb-marca tb-ausente"><span class="tb-q"></span>not yet in production</span>.
In `development`, the `registered` column at `/tools` now shows the date on which the credential was
stored, how long ago, and a mark with the state, readable without relying on color:

| the mark | what it means |
|---|---|
| `within … months` | within the term; below it, the date from which the replacement will be asked for (`replacement asked from …`) |
| `replace · … in use` | past the term and active; the screen asks for the replacement |
| `past … months · inactive` | past the term, but disabled; the screen does not ask for a replacement, it asks to remove it if it is no longer needed |
| `age unknown` | the platform does not know when it was stored — and therefore does **not** count it as within the term |

When an active credential goes past the term, the notice appears right below `Credentials`, before the
table: *"Replace the token “…”."*, with the date on which it was registered and how long ago. The notice says
three things that matter for deciding:

- **nothing stops**: *"Collection goes on with this token meanwhile. Nothing stops and nothing is
  blocked."* The platform asks for the replacement; it never interrupts collection because of age;
- **how to replace it**: generate a new token on GitHub, add it with the `replace the token` button, and,
  once it works, disable or remove the old one — and revoke it on GitHub too, because
  removing it here does not revoke it there;
- **who can**: *"an administrator, or someone who answers for"* the tool's organization.

Once the new token is added, while the old one remains active, the notice changes to *"The new token is in.
“…” is still active."* — the replacement is only complete when the old one is gone.

At `/ai` the same applies to the model provider's key (*"Replace this key."*), and the screen keeps the
history of the replacement: in `previous key`, from when to when the previous key was in use, with the phrase
*"the date is kept; the secret is gone"*. The key configured in the server environment appears as
`age unknown`, and the screen says whose absence it is: *"The absence is the platform's, not the
provider's."*

## What the screen refuses, and says why

This feature adds no new refusal to the screen. What it adds are **requests** — replace
the credential, remove the inactive one — and none of them blocks anything.

| situation | what the screen says |
|---|---|
| an active credential past the term | *"Replace the token “…”."* — and, right below, *"Nothing stops and nothing is blocked."* |
| a credential with no known date | *"The age of “…” is unknown."* — *"The platform has no record of when it was saved, so it cannot tell whether it is due. Replacing it starts a dated count."* |
| an inactive credential past the term | *"“…” is inactive and was registered …. Its secret is still stored; remove it if it is no longer needed."* |
| removing a credential | asks for confirmation: *"Destroy this credential? The secret stops existing, and this cannot be undone."* |

## What it does not do

- **It does not expire credentials.** Past the term, the token keeps working and collection continues. The
  replacement is requested, never imposed: whoever decides to replace it is whoever administers the tool.
- **It does not revoke anything at the source.** Removing a credential in The Band erases the secret here; on GitHub
  or at the provider, it remains valid until someone revokes it there.
- **It does not encrypt the password of whoever signs in.** The password is not stored in a recoverable form, not even by the
  platform — and encrypting it would create exactly that path. It is the first correction the spec makes to the
  request that originated it.
- **It does not show the credential's age in production yet.** The `registered` column, the marks and the
  replacement notices are in `development` and arrive in the next release.
- **It has no recorded acceptance.** The part that is live shipped in v0.11.0 for being a security
  fix, and acceptance is done later, in production. Live and not accepted is different from accepted.
