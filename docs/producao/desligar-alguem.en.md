# Offboarding someone from the platform — the procedure that works today

**Written on 2026-09-09**, from finding **H3** of the security assessment
(`docs/seguranca/2026-09-09-o-que-consertar-agora.md`).

> **This document exists because the gesture that looks like offboarding did not offboard, and the one that
> offboarded did not look like it.** It was born as the only control the organization
> had — and a control nobody knows how to use is not a control.

> **UPDATED ON 2026-09-10.** The fix landed: `/accounts` has the disable act, it
> **requires a reason**, and the screen carries the procedure. What follows is the long version; the short
> version is on the screen itself, at the point of acting — which is where this document proved it
> needed to be.

---

## What to do, today

**In `/accounts`, `Disable…` on the person's row.** Choose the reason and confirm.

The reason is a **closed list**: `left_the_organisation`, `access_no_longer_needed`,
`duplicate_account`, `suspected_compromise`, `other`. It is what the platform **reads** — the
suspicion of compromise changes what the screen shows next, and it is the question an
incident asks by count. The **note** is what you write, and it is mandatory for
`suspected_compromise` and `other`.

This cuts off access, and cuts it for real: `desativar_changeset/2` rotates the `session_token`, and
the rotation drops **all** open sessions of that account on the next action. Sign-in starts
refusing with the single message, and the record keeps the internal reason.

**There is no need to note anything outside the platform.** It was the most fragile part of the old
procedure, and it no longer exists: the act records **who, when, why** and your note, in an
episode that reactivation **closes** instead of deleting. The account row shows both
ends.

### Reactivate

`Reactivate…` on the row, with actor and reason. `disabled_by_mistake` marks the episode as a
mistake — it **stops counting** as an offboarding and remains visible.

**Reactivating does not give the password back.** If the offboarding was done the old way — a reset
whose temporary password nobody delivered —, the password is still that temporary one, and the reset
comes **after** the reactivation, never before. The screen refuses the reset on a disabled account and
states that order.

---

## The old way, and why not to use it anymore

**Reset the password and not deliver the temporary one.** It worked — the token rotation drops the
sessions — and it was fragile for three reasons, all measured:

1. **it was not written anywhere**, and depended on whoever administers knowing it;
2. **it was indistinguishable from a legitimate reset**: the offboarded account appeared as
   `temporária pendente`, **the same as a freshly created one**, and the routine act for the second
   **reactivated** the first;
3. **it stops working on the day API tokens exist** — the token is not the password, and
   changing the password does not invalidate it.

The two columns of `/accounts` close the second: `Account` answers *can they sign in?* and
`Sign-in credential` answers *what would they sign in with?*, and the two temporary passwords are told apart in
words — `from creation` versus `from a reset`.

---

## What **not** to do, and why it looks right

### Revoking the link does not offboard

`revogar_elo` is what the screen offers next to the person's name, and it is the gesture that
anyone would make. **It does not remove access.** Measured on 2026-09-09:

| after revoking the link | result |
|---|---|
| the person's own dashboard | **closes** — `pode_ver/3` starts refusing |
| signing in with e-mail and password | **keeps working** |
| `/people`, `/teams`, the tenant's work | **keep opening** |

Sign-in by GitHub identifier starts refusing; sign-in by **e-mail** does not require a
link. So whoever has the password keeps getting in.

**Revoking the link remains the right gesture for what it means** — the account stops
being that person. It just is not an offboarding, and the screen does not say so.

### ~~Marking the organization as suspended does nothing~~ — fixed on 2026-09-09

`tenants.status` existed, accepted `"suspended"` and **no code read it**: a suspended
tenant authenticated and opened the screens normally. It was a column that looked like a control.

**Since v0.7.0 the door reads it.** `Auth.verificar/2` refuses sign-in when the organization is not
active, and `/accounts` shows a banner saying nobody gets in today. Suspending the
organization **is** a control — and it is still not the act for offboarding **one** person.

---

## What was missing, and what landed

The `conta-desativada` item of the product backlog had two parts, and both landed:

1. **`tenants.status` is now read** — landed in **v0.7.0**. A non-active organization does not
   authenticate, and `/accounts` shows the banner.
2. **`users.disabled_at`** with the act in `/accounts` — landed in **v0.7.0**, and the delivery was
   **refused** by the Product Owner role for three reasons: the act did not record a reason,
   `enable_user/2` reactivated without actor or reason, and the screen changed without an approved prototype. The
   prototype came on **2026-09-10**
   ([`accounts-disable.html`](../../specs/045-autenticacao-e-acesso/prototipo/accounts-disable.html)),
   and the fix for the three is what this document now describes: a closed-list reason
   plus a note (FR-025), an episode with both ends (FR-026), and the refusal that stays on the screen
   (FR-028).

**What remains open has a deadline, and it is not our choice.** A disabled account **does not
authenticate by password** — measured, with a test. **By token, it cannot be stated yet**: the token
does not exist ([spec 061](../../specs/061-api-publica/spec.md)). On the day it exists,
disabling has to close it too; until then, the screen line that promises this is a **promise and
not a control**, and it is written that way.

---

## And meanwhile, what the organization should assume

A person offboarded by the procedure above **does not get in**. But:

- **there is no record** that they tried, nor of when. No authentication
  or authorization event is recorded today — it is finding **H4**, and that is why nobody knows whether
  any improper access has already happened;
- **what they read before leaving, they know.** None of this is retroactive;
- **the procedure depends on whoever administers knowing about it.** It is the reason this document
  exists, and the reason it does not replace the fix.

---

## References

- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — finding H3, with the three parts
  measured and the scenario for QA;
- `docs/backlog/conta-desativada.md` — the item, with its position in the queue and the reason for it;
- `specs/061-api-publica/spec.md` — FR-074 (mass revocation per account) and the
  declared limitation;
- `docs/producao/runbook.md` — the rest of the operation.
