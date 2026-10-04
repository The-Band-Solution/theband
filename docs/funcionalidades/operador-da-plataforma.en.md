<div class="tb-assinatura">Features · the platform operator area</div>

# Suspending and reactivating an organization

<dl class="tb-recibo">
<dt>the screen</dt><dd><code>Organisations</code>, in the platform operator area, and each organization's page</dd>
<dt>the spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>070 · Draft · 2026-10-01</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/070-operador-da-plataforma">specs/070-operador-da-plataforma, on GitHub</a></dd>
<dt>in production</dt><dd><span class="tb-marca tb-ausente"><span class="tb-q"></span>not yet</span> in development; it ships in the next release</dd>
<dt>the yardstick</dt><dd>only what the screen does in development; what the spec asks for and the screen does not do is named at the end</dd>
</dl>

The platform operator is a role above the organizations: it belongs to none of them, and it is the one who
suspends an organization and reactivates it later. Suspending cuts everyone's access at once — every
person is signed out, on every device, and every API token of the organization is revoked — and
reactivating **does not give back** any of that: every person signs in again, and every token is issued again.
Every suspension is recorded, with who, when and why.

## What you can now do

This page is for whoever operates the platform. Whoever uses an organization does not see this area.

- **See the organizations and the state of each one**: the `Organisations` screen lists `organisation`,
  `slug`, `state` and `last suspended`. An organization that was never suspended says `never suspended`,
  instead of an empty cell. The screen also says what you do **not** see: the people, the teams, the
  work and the numbers of each organization. Operating the platform opens no organization at all.
- **See an organization's history**: on its page, `Suspension history` shows each
  suspension in two halves, `suspended` and `reactivated`, with who, when, the reason and the note. A
  suspension that is still open says `not reactivated — still suspended`.
- **Suspend**: the `Suspend` + organization name form asks for a reason from the list (`Reason —
  required`), accepts a note (`Note`), lists what is going to happen (`What suspending does, at once
  and in one step`) and asks you to type the organization's slug to confirm. The button says what
  it does: `Suspend, sign everyone out, revoke all tokens`. The organization's data stays as
  it is; nothing is deleted.
- **Reactivate**: on a suspended organization, the page shows only the `Reactivate` + name form
  — the act that fits the state, and never both. It also asks for a reason, an optional note and the slug, and
  says what reactivating does and what it does not (`What reactivating does, and what it does not`): the
  people can sign in again, each one from the start; no session and no token come back; the
  collection resumes at the normal interval, without starting one right away.

The suspension reasons are `Suspected compromise`, `The contract ended`, `Requested by the
organisation` and `Other`; the reactivation reasons are `Investigation closed — no compromise found`, `The
contract resumed`, `Suspended by mistake` and `Other`. Some reasons offered on reactivation only
appear when they answer the reason of the open suspension, and the screen says so next to them.

After the act, the page confirms: `Suspended. Every session was ended and every API token
revoked.` or `Reactivated. No session or token came back.`

## What the screen refuses, and says why

| situation | what the screen says |
|---|---|
| the typed slug does not match | `Not suspended. The confirmation did not match.` (or `Not reactivated.`) — `Type` + slug + `exactly. Nothing changed.` |
| no reason chosen | `Choose a reason from the list.` — `Nothing changed.` |
| a reason that requires a note, without a note (`Suspected compromise` and `Other`, on suspension) | `A note is required for this reason` — and it says what to write: `Write what was seen and why it calls for suspension.` |
| suspending an organization that is already suspended | `Not suspended.` + name + `is already suspended`, with since when and by whom; `The page now shows the reactivate form.` |
| reactivating an organization that is not suspended | `Not reactivated.` + name + `is not suspended.` — `The page now shows the suspend form.` |
| someone who is not an operator tries this area | "not found", and never "no permission" |

## What it does not do

- It does not show or open domain data of any organization: no people, no teams, no
  issues, no measures — not even "just for support".
- It does not suspend all organizations at once: it is one act per organization, each with its own
  reason.
- It does not grant or revoke the operator role: no screen does that, and whoever signs in through an
  organization cannot become an operator.
- It does not create, delete or rename an organization.
- It does not promote or demote an administrator within an organization: that is the
  [accounts screen](administradores.md), for whoever administers their own organization.
- A suspension made before this record existed appears in the history with no author or reason, and the
  screen says so (`The reason was not recorded`), instead of inventing who it was.
