# Sprint 023 — Review {#sprint-023--review}

**Period**: 2026-08-28 (opened and closed on the same day)
**Feature**: [045-autenticacao-e-acesso](../../../specs/045-autenticacao-e-acesso/spec.md)
**PRs**: [#562](https://github.com/The-Band-Solution/theband/pull/562) (feature, squash),
[#564](https://github.com/The-Band-Solution/theband/pull/564) (fix for the profile schema),
[#565](https://github.com/The-Band-Solution/theband/pull/565) (post-squash complement),
[#566](https://github.com/The-Band-Solution/theband/pull/566) (the checks bar) and
[#567](https://github.com/The-Band-Solution/theband/pull/567) (/ai operational — acceptance caveat)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 14 | 14 |
| Accepted deliverables | 3 | 3 |

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| T001–T003 | [#548](https://github.com/The-Band-Solution/theband/issues/548)–[#550](https://github.com/The-Band-Solution/theband/issues/550) | Clean baseline, bcrypt justified, migrations with a seed that preserves the admins' view (3 = 1 admin × 3 orgs, checked) | yes |
| T004–T005 | [#551](https://github.com/The-Band-Solution/theband/issues/551)–[#552](https://github.com/The-Band-Solution/theband/issues/552) | Auth (single refusal, throttle, temporary password) and Access (union with origin, verdict with reason, FR-022) per the contracts | yes |
| T006–T008 | [#553](https://github.com/The-Band-Solution/theband/issues/553)–[#555](https://github.com/The-Band-Solution/theband/issues/555) | Prototype's login, versioned session with destination preserved, /accounts with a show-once temporary password | yes |
| T009–T011 | [#556](https://github.com/The-Band-Solution/theband/issues/556)–[#558](https://github.com/The-Band-Solution/theband/issues/558) | /access-scopes with derived scopes hatched, single verdict on the screens, FR-023 with filtering | yes |
| T012–T014 | [#559](https://github.com/The-Band-Solution/theband/issues/559)–[#561](https://github.com/The-Band-Solution/theband/issues/561) | /profile, check against the source, gates and PR following the standard | yes |

**Acceptance**: product-owner on 2026-08-28 — 24 scenarios with evidence, 43 suite tests
re-run, 6 standalone ones (including the SC-001 sweep: 27 routes, 100%
protected), SQL on dev, captures. **3/3 accepted**, with two caveats taken to the
maintainer and resolved on the spot:

1. **/ai is operational** — FR-023 holds as written (decision of 2026-08-28); the key
   remains one per tenant. Fixed in PR #567 with a note in the spec.
2. **Management of the administrator mark** (slice of FR-008) not delivered — returned to the
   backlog as a named gap ([#568](https://github.com/The-Band-Solution/theband/issues/568)),
   with the FR-009 guard to be born tested together with it.

## What was not done {#o-que-não-foi-feito}

The slice "grant and revoke the administrator role" of FR-008 — returned to the
backlog by recorded decision (#568). Nothing else was left out.

## Defects found and fixed along the way {#defeitos-encontrados-e-consertados-no-caminho}

- **Generate again with 400**: the profile schema outside the provider's strict mode —
  issue [#563](https://github.com/The-Band-Solution/theband/issues/563), PR #564, with a
  recursive guard that fails the next forgotten field in the commit.
- **Settings that "would not open"**: the dropdown opened clipped by the bar's
  `overflow-x-auto` (a 046 defect) — PR #565, with lesson L73 about the diagnosis.
- **Arthur without dashboards**: the organization scope reached 4/88 — belonging is now
  promoted team ∪ evidence in force; 84/88, PR #565.

## Evidence {#evidências}

- Local gates 13/13 with EXIT in the log (L60); CI green on all PRs (gates +
  coverage).
- Real flow on dev: temporary→lock→definitive→released; single refusal;
  login by GitHub username.
- Captures in session evidence (sign-in, access-scopes, profile, accounts,
  person page before/after, open menu).
- Adversarial independent review on #562: 1 real finding (grant without checking
  account/actor against the tenant), fixed with violations tested in both directions.

## Debt generated {#dívida-gerada}

- Orphan grant: implemented and displayed, without a dedicated test.
- SC-004 (<30s) attested in use, not instrumented.
- Formal PR approval (`pulls/N/reviews`) remains empty — the review lives in a
  comment; **#564 was merged without a requested reviewer** (violation recorded,
  unrecoverable).
- Specs 047 (messages), 048 (button without a key) and 049 (sign in with GitHub)
  specified during the sprint and held in the backlog.

## Lessons from this sprint {#lições-deste-sprint}

In the [cumulative record](../licoes-aprendidas.md): **L72** (the iterations API
replaces the entire list), **L73** (`isVisible` does not see clipping by overflow — the proof
is the image, looked at), **L74** (the working tree decides what the dev server serves),
**L75** (squash-merge opens a window for orphan commits), and **L38 annotated as a defense
that worked** (the cost guard failed the new verdict before a slow screen
existed).
