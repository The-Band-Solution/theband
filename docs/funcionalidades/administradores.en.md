<div class="tb-assinatura">Features · the accounts screen</div>

# Promoting and demoting administrators

<dl class="tb-recibo">
<dt>the screen</dt><dd><code>/accounts</code>, column <code>Management</code></dd>
<dt>the spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>072 · Draft · 2026-10-02</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/072-papel-de-administrador">specs/072-papel-de-administrador, on GitHub</a></dd>
<dt>in production</dt><dd><span class="tb-marca tb-ausente"><span class="tb-q"></span>not yet</span> in development; it ships in the next release</dd>
<dt>the yardstick</dt><dd>only what the screen does in development; what the spec asks for and the screen does not do is named at the end</dd>
</dl>

Whoever administers an organization gives the administrator mark to another active account, and
removes it from whoever should no longer have it. That way the organization does not depend on a single person to connect
tools, manage credentials and administer accounts. The `Who administers this
organisation` block, at the top of the screen, says what an administrator does and the rule that always holds: the
organization keeps at least one active administrator.

## What you can now do

- **Promote** an active account: `Make administrator…` in the `Management` column. The confirmation
  names the person and accepts an optional note, in the `Note` field.
- **Demote** an administrator: `Remove admin role…`. The person keeps signing in, as a member.
- **Step down from your own role**: on your row the button is `Step down…`, and the confirmation asks
  you to type your e-mail in `Type your e-mail to confirm`. It is only possible if there is another
  active administrator.
- **See each account's role on its own row**: since when it has been an administrator and who
  promoted it, or the period during which it was one, and whether it left on its own (`stepped down`) or was
  demoted (`removed by` …). Whoever never had the role appears as `never an administrator`; the
  only active administrator carries `the only active administrator`.
- **See who changed what**: the `Administrator changes` section, below the table, lists each
  change with who, when and the note. An administrator whose mark is older than the record
  appears as `since the organisation was created`, followed by `no role change recorded` —
  the screen says there is no record, instead of inventing a date.

After each change, the screen confirms in place of the panel, and says how many active administrators
the organization now has.

## What the screen refuses, and says why

| situation | what the screen says |
|---|---|
| demoting the last active administrator, including yourself | `The organisation would have no active administrator. Make someone else administrator first.` — the button is disabled; if someone else acted before you, the refusal says `Not changed:` and names who acted |
| promoting a disabled account | `Role changes wait for reactivation.` |
| administrator with a disabled account | `not counted while the account is disabled` — they do not count as an active administrator |
| stepping down from your own role by typing a different e-mail | `Not changed. That is not the e-mail of your account. You are still an administrator.` |
| an account from another organization | `Account not found.` — and never "no permission" |

## What it does not do

- Whoever is not an administrator sees no controls at all.
- It does not ask for a reason from a closed list; the note is free and optional, and without it the record says
  `no note`.
- It does not change the password or session of whoever is demoted: the person keeps signing in, as a member.
- It does not create roles beyond administrator and member.
