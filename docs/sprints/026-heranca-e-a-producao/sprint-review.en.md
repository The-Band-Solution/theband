# Sprint 026 — Review {#sprint-026--review}

**Period**: 2026-08-29 to 2026-09-01 — **closed four days before** the planned
end (2026-09-05), because the goal was reached and exceeded: the sprint
promised to leave production *three milestones away*, and production is live.
**Features**: [050-em-producao](../../../specs/050-em-producao/spec.md) and
[052-primeira-conta-do-ambiente](../../../specs/052-primeira-conta-do-ambiente/spec.md),
plus the inheritance from [047](../../../specs/047-mensagens-internacionalizadas/spec.md) and
[051](../../../specs/051-cadastro-por-github/spec.md).
**Address**: <https://theband.5.189.161.85.sslip.io/sign-in> — Contabo VPS
`vmi3547213`, Dokploy, image `ghcr.io/the-band-solution/theband` with the tags
`v0.1.0`, `v0.2.0` and `latest`.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 (050/US1–US3) | 6 evaluated (3 from 050 + 3 from 052, the latter not planned) |
| Tasks | 10 (3 inheritance + 7 from 050) | 21 performed (10 planned + 11 from 052) |
| Deliverables accepted | 4 | **5 of 8** |
| Releases | 0 (human milestone, out of scope) | **2** — v0.1.0 and v0.2.0 |

**Acceptance** ([full record](aceitacao.md)): 5 accepted, 3 not accepted.
The three — **050/US1**, **050/US2** and the deliverables outside the backlog — fall through
**criterion without evidence**, never through observed wrong behavior. Nothing of what
was measured failed; what is missing is measurement nobody did.

## What was done {#o-que-foi-feito}

| Task | Issue | PR | Deliverable | Accepted |
|---|---|---|---|---|
| 047/T014 | [#617](https://github.com/The-Band-Solution/theband/issues/617) | [#630](https://github.com/The-Band-Solution/theband/pull/630) | D1 — the origin-function phrases pass through the edge | yes |
| 047/T015 | [#634](https://github.com/The-Band-Solution/theband/issues/634) | [#635](https://github.com/The-Band-Solution/theband/pull/635) | D2 — the verifier hops one node, and the class dies whole | yes |
| 051/T009 | [#618](https://github.com/The-Band-Solution/theband/issues/618) | [#631](https://github.com/The-Band-Solution/theband/pull/631) | D3 — the search states the organization and the ended observation | yes |
| 050/T001–T007 | [#623](https://github.com/The-Band-Solution/theband/issues/623)–[#629](https://github.com/The-Band-Solution/theband/issues/629) | [#632](https://github.com/The-Band-Solution/theband/pull/632) | D4 — image, CI, CD and runbook | yes |
| — (human milestones) | — | [#636](https://github.com/The-Band-Solution/theband/pull/636), [#641](https://github.com/The-Band-Solution/theband/pull/641), [#639](https://github.com/The-Band-Solution/theband/pull/639) | D5 — production live, and its measurement by criterion | **no** — 050/US1 and US2 with criterion without evidence |
| 052/T001–T014 | **no issues** | [#640](https://github.com/The-Band-Solution/theband/pull/640) | D6 — the first account is born from the environment | yes |
| — | — | [#637](https://github.com/The-Band-Solution/theband/pull/637) | D7 — the public door speaks through the metaphor | not classifiable — no user story |
| — | — | [#642](https://github.com/The-Band-Solution/theband/pull/642) | D8 — the bar does not say 100% during the collection | not classifiable — it is a defect, not a user story |

## What was not done {#o-que-não-foi-feito}

| What | Reason | Destination |
|---|---|---|
| SC-003 — restore rehearsal **in production** | the local dry-run proved the procedure; the Dokploy backup was never restored | **first in the queue of sprint 027**, with named blocker: access to the panel |
| SC-006 — 7 days of copy routine | the routine started on 2026-09-01 | falls due by itself on 2026-09-08 |
| AS4/AS5 and SC-001 of 050/US1 | nobody timed the release or the first access | new measurement task in the next release |
| 052 issues on GitHub | the cycle skipped `/speckit-taskstoissues` | create before closing 052 |
| Closing #620–#629 | correct by the DoD — only after acceptance | depends on the confirmation of the [record](aceitacao.md) |

## Deliverables not accepted {#entregáveis-não-aceitos}

**D5 — production live**, through user stories 050/US1 and 050/US2.

**050/US1** fails on three *not evaluated* criteria: the session surviving the
release (AS4), the unavailability window being short (AS5) and the journey of
signing in and seeing a dashboard in under two minutes (SC-001). The other four
criteria conform, two of them measured in this evaluation: plain HTTP returns
**301** to HTTPS, and `/sign-in` responds **200 in 0.65s**. The US returns to the product
backlog as a **new measurement task** — never reopening #620.

**050/US2** fails on AS1 (there is no evidence that the copy exists **outside** the
production machine) and AS3 (a backup failure was never provoked to see whether it
shows up), and AS2 only has the local half: source `88/12/3` restored as `88/12/3`,
checked by the image itself. **The window to rehearse is closing** — production
already has 4,895 issues collected, and the rehearsal was cheap while there was no
data that mattered.

**D7 and D8 are not refusals**: they are deliverables with no user story in the sprint backlog.
By axiom `sro.rule01`, scope that came in without going through planning. D8 is a
production defect — `osdef.defect`, not a user story.

## Evidence {#evidências}

- **Gates**: `mix gates` → **14/14 green**, `CODIGO_DE_SAIDA_DO_GATE=0`, read in a
  separate command (L60), on 2026-09-01 on `development`.
- **Production, measured from outside in this evaluation** (2026-09-01 11:52 UTC):
  `http://…/sign-in` → **301** with `Location: https://…`; `https://…/sign-in` →
  **200 in 0.650s**; seven data routes without a session (`/people`, `/teams`,
  `/organizations`, `/work`, `/syncs`, `/accounts`, `/roles`) → **302 on all**.
- **052's SC-004, measured here**: ten consecutive calls of
  `Bootstrap.criar_primeira_conta/1` → **1 administrator and 1 organization**, with
  `%{criada: 1, ja_existe: 9}`. The test enters the repository at this closing.
- **Two injections in 052**, made to prove the new test: the first
  (administrator check turned off) was caught by the different-e-mail
  test; the second (reading of the lost race turned off) **passed all 16
  tests** and revealed a weak test — the race test counted only the winner. With the
  loser's assertion added, the same injection fails: **15/16**.
- **Collection checked against the source**: 125 repositories, 4,895 issues, 15
  boards, 3,981 board items.
- **Measurement by criterion of 050**:
  [medicao-do-primeiro-release.md](../../../specs/050-em-producao/medicao-do-primeiro-release.md).
- **CI**: green in the sprint's nine PRs, with the three workflows (quality-gates, the
  production image builds, coverage).

## Debt generated {#dívida-gerada}

**Security — pending rotations**, all born from things that went through the
chat during deployment:

1. [redigido];
2. [redigido];
3. [redigido];
4. [redigido].

**Technical**, recorded in [pendencias.md](../../../specs/050-em-producao/pendencias.md):

- **P1** — the socket origin depends on `PHX_HOST`; it becomes a bug on the day there
  is a second address;
- **P2** — `force_ssl` depends on a third-party header, with no test;
- **P4** — the runbook did not cover the first access (closed by 052/T014).

**Process**: the 052 issues do not exist, six PRs were merged without a
reviewer requested, and no PR of the sprint has a recorded review. Detailed in
[aceitacao.md](aceitacao.md), section "Process gaps".

## Lessons from this sprint {#lições-deste-sprint}

Eight, consolidated in [licoes-aprendidas.md](../licoes-aprendidas.md):

| # | Lesson |
|---|---|
| L83 | Squash-merge on the release diverges the histories |
| L84 | The panel saying `Done` does not mean the application is live |
| L85 | An HTTP 200 can assert what the socket contradicts |
| L86 | A moving denominator lies just like an invented denominator |
| L87 | An invisible stage makes work look stuck |
| L88 | An 8-second secret — and the contract that saved the diagnosis |
| L89 | A PR without a reviewer requested is not a reviewed PR, and the merge does not know it |
| L90 | Counting only the winner of the race does not prove the loser |

And one **recurrence**, the fifth: text replacement without an assertion passing
silently — `mix format` broke the line of a call, the replacement did not
match, and the test kept failing while the cause was sought elsewhere.

## What production proved right {#o-que-a-produção-provou-estar-certo}

Worth recording because it was a design decision, made beforehand and against
convenience:

- **the entrypoint brought the container down** when it could not resolve the database, instead of serving
  zero on every screen;
- **the migration ran before the endpoint** served;
- **the CD failed saying what was missing** — *"the image and the tag exist, but there was NO
  delivery"* —, and so nobody looked for the image in the wrong place;
- **the image carries no secret at all**, measured before the first release.
