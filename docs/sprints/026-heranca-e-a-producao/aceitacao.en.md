# Sprint 026 — Acceptance record {#sprint-026--registro-de-aceitação}

**Features**: [050-em-producao](../../../specs/050-em-producao/spec.md) ·
[052-primeira-conta-do-ambiente](../../../specs/052-primeira-conta-do-ambiente/spec.md) ·
inheritance from [047](../../../specs/047-mensagens-internacionalizadas/spec.md) and
[051](../../../specs/051-cadastro-por-github/spec.md)
**Evaluated on**: 2026-09-01, on `development` (all PRs merged), with
evidence executed in this evaluation — gates, HTTP measurement against the real address
and the SC-004 measurement that was missing.
**Role**: Product Owner — evaluation proposed by the agent and **CONFIRMED by the
person allocated to the role on 2026-09-01**, with the verdicts as proposed: 5
deliverables accepted, 3 not accepted, and the refused user stories with their destination
written down instead of closed.
**PO type**: `sro.product_owner_client` — whoever demands is whoever maintains.

## Summary {#resumo}

| | Quantity |
|---|---:|
| Deliverables evaluated | 8 |
| Accepted | 5 |
| Not accepted | 3 |
| Tasks performed successfully | 12 |
| Tasks performed unsuccessfully | 7 (the seven from 050, through deliverables D5 and D6) |

**The refusal here is one of incomplete evaluation, not of defect.** The three not accepted
fail through **criterion without evidence** — none failed through observed wrong
behavior. The distinction matters: the destination is not to rewrite what exists, it is to measure
what was not measured.

---

## D1 — The phrases born in an origin function pass through the edge {#d1--as-frases-nascidas-em-função-de-origem-passam-pela-borda}

**Produced by**: 047/T014 · [#617](https://github.com/The-Band-Solution/theband/issues/617) ·
PR [#630](https://github.com/The-Band-Solution/theband/pull/630)
**Materializes**: 047/US1 — errors in the catalog · [#573](https://github.com/The-Band-Solution/theband/issues/573)

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| The 5 literal phrases leave the domain and are born in the catalog | functional | yes | PR #630, gates green on the branch; `mix mensagens.verificar` EXIT=0 |
| The sibling hunt (L81) sweeps the form `(erro\|ok\|error\|aviso): funcao(` before delivering | process | yes | executed in the sprint backlog, **zero remaining** |

**Derived phase**: `sro.accepted_deliverable`.
**Task phase**: `sro.successfully_performed_scrum_development_task`.

---

## D2 — The verifier sees the origin-function class (one-node hop) {#d2--o-verificador-vê-a-classe-função-origem-salto-de-um-nó}

**Produced by**: 047/T015 · [#634](https://github.com/The-Band-Solution/theband/issues/634) ·
PR [#635](https://github.com/The-Band-Solution/theband/pull/635)
**Materializes**: 047/US1 · [#573](https://github.com/The-Band-Solution/theband/issues/573)

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| The verifier reaches the phrase that is born one call back | functional | yes | `test/mix/tasks/mensagens_verificar_test.exs` +53 lines in PR #635 |
| The class dies whole, and not only the counterexample (L81) | functional | yes | 7 new msgids in `sistema.pot`/`errors.pot`; 047's contract and pending items updated in the same PR |

**Derived phase**: `sro.accepted_deliverable`.
**Task phase**: `sro.successfully_performed_scrum_development_task`.
**Recorded caveat**: the definitive acceptance of 047/US1 belongs to feature 047
and depends on a new evaluation of the whole — what is accepted here is **the inheritance
task**, which was what sprint 026 committed to deliver.

---

## D3 — The search states the organization and the ended observation {#d3--a-busca-diz-a-organização-e-a-observação-terminada}

**Produced by**: 051/T009 · [#618](https://github.com/The-Band-Solution/theband/issues/618) ·
PR [#631](https://github.com/The-Band-Solution/theband/pull/631)
**Materializes**: 051/US2 — link GitHub · [#598](https://github.com/The-Band-Solution/theband/issues/598)

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| The search result shows the ORGANIZATION (edge case of namesakes) | functional | yes | `test/the_band_web/live/accounts_elo_test.exs`; PR #631 |
| The ENDED OBSERVATION is stated on the screen | functional | yes | same test; PR #631 |
| The comment that contradicted the contract was removed, and the contract gained the note (L82) | process | yes | PR #631, 051's contract with date and reason |

**Derived phase**: `sro.accepted_deliverable`.
**Task phase**: `sro.successfully_performed_scrum_development_task`.

---

## D4 — The image, the CD and the runbook {#d4--a-imagem-o-cd-e-o-runbook}

**Produced by**: 050/T001–T007 · [#623](https://github.com/The-Band-Solution/theband/issues/623)–[#629](https://github.com/The-Band-Solution/theband/issues/629) ·
PR [#632](https://github.com/The-Band-Solution/theband/pull/632)
**Materializes**: nothing on its own — it is the **foundation** of 050/US1–US3. Evaluated as an
intermediate deliverable; the criteria of the three user stories are evaluated in D5.

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| The image builds and refuses to start without the variables (violation first) | functional | yes | CI "a imagem de produção builda" green; `docker run` without env refusing |
| The CD publishes with the version tag and fails saying what is missing | functional | yes | contract `contracts/pipeline-de-release.md`; proven in release v0.1.0 — the webhook failure said *"the image and the tag exist, but there was NO delivery"* |
| The runbook describes the path in Dokploy | non-functional | yes | `docs/producao/runbook.md`, executed by a person on 2026-09-01 |

**Derived phase**: `sro.accepted_deliverable`.
**Phase of tasks T001–T007**: derived from D5, not from this line — see the note there.

---

## D5 — Production live (v0.1.0) and its measurement {#d5--a-produção-no-ar-v010-e-sua-medição}

**Produced by**: releases [#636](https://github.com/The-Band-Solution/theband/pull/636) (v0.1.0) and
[#641](https://github.com/The-Band-Solution/theband/pull/641) (v0.2.0), measurement in
PR [#639](https://github.com/The-Band-Solution/theband/pull/639)
**Materializes**: 050/US1 ([#620](https://github.com/The-Band-Solution/theband/issues/620)),
050/US2 ([#621](https://github.com/The-Band-Solution/theband/issues/621)),
050/US3 ([#622](https://github.com/The-Band-Solution/theband/issues/622))

### 050/US1 — The platform at a stable address {#050us1--a-plataforma-num-endereço-estável}

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AS1 — plain HTTP leads to HTTPS | functional | **yes** | measured in this evaluation, 2026-09-01 11:52 UTC: `http://…/sign-in` → **301** with `Location: https://…/sign-in` |
| AS2 — valid credentials open the dashboards with real data | functional | **yes** | the maintainer signed in to production and triggered the collection: **125 repositories, 4,895 issues, 15 boards, 3,981 items**, checked against the source |
| AS3 — a pending migration runs before the version serves | functional | **yes, partial** | v0.1.0 started on an empty database and the log gave the order `migrações aplicadas.` → `Running TheBandWeb.Endpoint`. **The "previous data remains" half was not exercised**: no later release carried a migration |
| AS4 — a valid session survives the release | functional | **NOT EVALUATED** | nobody had an open session during the v0.2.0 deploy, and nothing was measured |
| AS5 — the unavailability window is short | non-functional | **NOT EVALUATED** | SC-002 records: *"the unavailability window was not timed"* |
| SC-001 — an outside person signs in and sees a dashboard in under 2 min | non-functional | **NOT EVALUATED** | the door responds in 0.65s (measured now), and there was an account since 052 — but the complete journey was never timed |
| SC-002 — release in under 15 min of procedure | non-functional | yes | CD: build+push+tag in **1m43s**; delivery through the webhook in **11s** |

**Derived phase**: `sro.not_accepted_deliverable` — three criteria without evidence
(AS4, AS5, SC-001).
**What was missing**: measuring, not building. Timing the next release with an
open session answers AS4, AS5 and SC-002-window at once; SC-001 is timed
with a clock and an incognito tab.
**Destination of the user story**: **returns to the product backlog** as a new measurement
task linked to the same atomic US — never reopening #620.

### 050/US2 — The data survives {#050us2--os-dados-sobrevivem}

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AS1 — an intact, dated copy exists **outside** the production machine | functional | **NOT EVALUATED** | the backup was scheduled in Dokploy; **there is no evidence of a destination outside the machine** |
| AS2 — the restore brings the platform up with the same numbers | functional | **not in production** | **local** rehearsal conforming on 2026-08-31 (`eo_people=88 eo_teams=12 eo_organizations=3` → 88/12/3, checked by the image itself). SC-003 records: *"not met in production"* |
| AS3 — the failure of the copy routine is visible to whoever administers | functional | **NOT EVALUATED** | no failure was provoked; nothing says how it would show up |
| SC-006 — the routine runs 7 days in a row | non-functional | **not measurable yet** | scheduled on 2026-09-01; the deadline falls on 2026-09-08 |

**Derived phase**: `sro.not_accepted_deliverable` — fails on AS1 and AS3 through
absence of evidence, and AS2 only has the local half.
**What was missing**: the rehearsal against the Dokploy backup, **before there is data that
matters** — and that window is closing: production already has 4,895 issues
collected.
**Destination of the user story**: **first in the queue of sprint 027**, with a named
blocker (requires access to the Dokploy panel, which belongs to the maintainer).

### 050/US3 — Production refuses the development regime {#050us3--a-produção-recusa-o-regime-de-desenvolvimento}

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AS1 — the development seeds are refused in production | functional | **yes, by reading** | `priv/repo/seeds.exs:17` raises when `env == :prod`. **It was not executed in the real environment** — a gap of proof, not of behavior |
| AS2 — without the master key the platform refuses to start, saying what is missing | functional | yes | `rel/entrypoint.sh` checks the variables and brings it down; the violation is in CI (`docker run` without env) |
| AS3 — no secret in log, error page or image | functional | yes | `docker history` and `Config.Env`: **0** occurrences; container log: **0** |
| SC-004 — zero secrets in the repository, image and logs | non-functional | yes | same measurement, recorded in `medicao-do-primeiro-release.md` |
| SC-005 — 100% of data routes refuse without a session | non-functional | yes | 19 of 21 return 302 (the remaining 2 are public by design). **Rechecked in this evaluation**: `/people /teams /organizations /work /syncs /accounts /roles` → **302 on all** |

**Derived phase**: `sro.accepted_deliverable` — **with a named caveat** on AS1
(conformity by reading the code, without execution in the real environment).
**Task phase**: tasks T001–T007 produced D4 (accepted) and D5 (two
deliverables not accepted) — hence
`sro.non_successfully_performed_scrum_development_task`, by the rule that a
task with several deliverables counts once even with only one refused.

---

## D6 — The first account is born from the environment {#d6--a-primeira-conta-nasce-do-ambiente}

**Produced by**: 052/T001–T006, T010–T014 · **no issues on GitHub** (see
"Process gaps") · PR [#640](https://github.com/The-Band-Solution/theband/pull/640) ·
release v0.2.0 [#641](https://github.com/The-Band-Solution/theband/pull/641)
**Materializes**: 052/US1, 052/US2, 052/US3

### 052/US1 — Install without a console {#052us1--instalar-sem-console}

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AS1 — starts with the four variables, creates organization and admin, and the log states e-mail and organization | functional | yes | executed against the **real image**: 1 organization and 1 admin, in the order `migrações aplicadas.` → `primeira conta criada:` → `Running TheBandWeb.Endpoint` |
| AS2 — the person signs in with those credentials and has administration power | functional | yes | `POST /session` → 302; `/people` → 200 **with** the session and 302 without. And in production: the maintainer signed in |
| AS3 — the password does NOT appear in any line of the log | functional | yes | sweep of the startup log: **0 occurrences**; tests "o retorno de sucesso não carrega a senha" and "o changeset de recusa não carrega a senha" |
| SC-001 — installs without opening a console | non-functional | yes | production v0.2.0 was born this way, through the panel |
| SC-003 — zero occurrences of the password in the records | non-functional | yes | same sweep |

**Derived phase**: `sro.accepted_deliverable`.

### 052/US2 — Restarting neither duplicates nor overwrites {#052us2--reiniciar-não-duplica-nem-sobrescreve}

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AS1 — starts again and nothing is created; the log says an administrator already exists | functional | yes | restart against the real image said `já existe administrador` and kept 1 admin |
| AS2 — the password changed through the interface remains valid | functional | yes | test "a senha trocada pela interface sobrevive a cinco subidas (SC-005)" |
| AS3 — a different e-mail does not create a second account | functional | yes | test "e-mail DIFERENTE também não cria um segundo" |
| SC-004 — ten consecutive startups produce **exactly one** person with the administration mark | non-functional | **yes — measured in this evaluation** | `bootstrap_sc004_test.exs`: ten calls → **1 administrator, 1 organization**, with `%{criada: 1, ja_existe: 9}` |
| SC-005 — the changed password survives five startups | non-functional | yes | the test of the same name |

**Derived phase**: `sro.accepted_deliverable`.
**Finding of this evaluation, fixed here**: the two injections made to prove the
SC-004 test found a **weak test** in FR-005. Turning off the reading of the
lost race — the loser starting to return `{:error, changeset}` instead of
`{:ok, :ja_existe}` —, **the 16 tests stayed green**: the race test
counted only the winner. The loser is precisely who FR-005 promises to serve, and
on a real second startup it is the common path. The loser's assertion was
added, and with it the same injection fails (15/16).
**Note**: until this evaluation SC-004 was conforming *by argument* — uniqueness
came from `unique_index(:tenants, [:slug])` and `unique_index(:users, [:email])`, and
the closest test exercised two calls. Argument is not evidence: the
ten-startups test was written and executed here, and enters the repository along with this
record.

### 052/US3 — The absence is stated, and does not bring it down {#052us3--a-ausência-é-dita-e-não-derruba}

| Criterion | Type | Conforming | Evidence |
|---|---|---|---|
| AS1 — with no variable at all, the platform serves and the log names the absent ones | functional | yes | against the image: the log named the four and `/sign-in` responded **200** |
| AS2 — with three of the four, nothing is created — not even an orphan organization | functional | yes | tests "falta parcial não deixa organização órfã" and "faltando duas variáveis, a lista traz as DUAS" |
| AS3 — a value refused by the rules of the regular sign-up: nothing is created, the log says which rule refused, and the platform starts | functional | yes | against the image, with an invalid slug: the refusal named the rule and nothing was created; tests of short password and slug with a space |
| SC-006 — starting with no variable at all keeps the platform responding, naming each absent one | non-functional | yes | same execution |

**Derived phase**: `sro.accepted_deliverable`.
**Phase of the 052 tasks**: `sro.successfully_performed_scrum_development_task`.

---

## D7 — The public door speaks through the metaphor {#d7--a-porta-pública-fala-pela-metáfora}

**Produced by**: PR [#637](https://github.com/The-Band-Solution/theband/pull/637) —
**no task and no issue**
**Materializes**: **no user story of sprint backlog 026**

Copy of the sign-in screen moved to the catalog (7 new msgids), three image
findings fixed (the panel disappeared at 390px), and the image rehearsal becoming
executable.

**Derived phase**: **not classifiable by criteria** — there is no user story, hence
there is no acceptance criterion. By axiom `sro.rule01`, a deliverable that does not
materialize a story of the sprint backlog is scope that came in without going through
planning. **Recorded, neither accepted nor refused.**

---

## D8 — The bar does not say 100% while the collection is still running {#d8--a-barra-não-diz-100-enquanto-a-coleta-ainda-anda}

**Produced by**: PR [#642](https://github.com/The-Band-Solution/theband/pull/642) —
**no task and no issue**
**Materializes**: **no user story of sprint backlog 026**

A fix born from production itself: the denominator grew along with what was
collected, and the bar showed 100% during the whole collection; the boards stage had
no line on the screen. 14 gates green, 9/9 tests.

**Derived phase**: **not classifiable by criteria**, for the same reason as D7.
It is a defect found in production — by the routing rule it would be `osdef.defect`,
and a defect is not a user story.

---

## Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

None. The criteria evaluated are the ones that were written in `spec.md` at
closing — 050 since 2026-08-30, 052 since 2026-09-01.

## Criteria without evidence {#critérios-sem-evidência}

| Criterion | User story | What is missing |
|---|---|---|
| AS4 — session survives the release | 050/US1 | open a session, publish a release, check that it remains valid |
| AS5 — short unavailability window | 050/US1 | time the next deploy |
| SC-001 — sign in and see a dashboard in under 2 min | 050/US1 | time the complete journey, from outside |
| AS1 — copy outside the production machine | 050/US2 | check the destination of the Dokploy backup |
| AS2 — restore in production | 050/US2 | execute the rehearsal against the real backup (SC-003) |
| AS3 — backup failure visible | 050/US2 | provoke the failure and see what shows up |
| SC-006 — 7 days of routine | 050/US2 | time: falls due on 2026-09-08 |
| AS1 — seeds refused in the real environment | 050/US3 | execute the seed against production (read-only of the refusal) |

## Process gaps {#lacunas-de-processo}

Named because they do not close by themselves:

1. **The whole of 052 was implemented without issues on GitHub.** The cycle was
   `/speckit-specify` → `plan` → `tasks` → implementation, without
   `/speckit-taskstoissues`. The commit cites `052/T001–T006, T010–T012, T014` — which
   are the tasks of `tasks.md`, not issues. Consequence: these tasks do not
   exist on the board, and `flow.wip.count` undercounts the whole sprint.
2. **052 was not in sprint backlog 026.** It came in midway, and it is the **legitimate
   exception** — it fixes 050's P3 (*"the first account has no path in the
   product"*), and waiting for the next sprint would keep production inaccessible. What
   was missing was **recording the exception in the risks**, not the exception itself.
3. **Six PRs were merged without a reviewer requested**: #635, #637, #638, #639, #640
   and #642. The first three of the sprint (#630, #631, #632) requested review from two
   people, and **none reviewed** — `reviews` empty in all nine. Distinguishing what
   the skill says to distinguish: there is no **recorded review** in any PR of the sprint;
   in the six without a request there was not even a request. The one who implemented was the agent, and the
   maintainer appears as `author`, which makes them a legitimate reviewer — but
   that is **review attested without a record**, and the attestation was not written.
4. **Issues #620–#629 remain open.** That is correct by the DoD (close after
   acceptance) — and that is why their destination depends on the confirmation of this record.

## What happened to the issues, after the confirmation {#o-que-aconteceu-com-as-issues-depois-da-confirmação}

Executed on 2026-09-01, right after the confirmation:

| Issue | Action | Reason |
|---|---|---|
| #622 (050/US3) | **closed** | deliverable accepted, with the AS1 caveat recorded in the comment |
| #623–#629 (050/T001–T007) | **closed** | tasks performed. Their phase is `non_successfully_performed` because they feed D5, and that is written in each comment — closing the issue does not erase the phase |
| #620 (050/US1) | **remains open**, with a destination | returns to the product backlog as a new measurement task |
| #621 (050/US2) | **remains open**, first in the queue of 027 | with the named blocker: access to the Dokploy panel |
| #648–#662 (052/T001–T015) | **created and closed** | retroactive record of gap 1 below. Each one says it was born after the work — the opening date does not lie by omission |

The retroactive creation **does not fix** what the gap cost: `flow.wip.count`
undercounted sprint 026 while it ran, and that is unrecoverable. What it
recovers is traceability from here on.

## Destination of the user stories {#destino-das-user-stories}

| User story | Issue | Destination |
|---|---|---|
| 050/US1 | [#620](https://github.com/The-Band-Solution/theband/issues/620) | returns to the product backlog — **new measurement task**, not a reopening |
| 050/US2 | [#621](https://github.com/The-Band-Solution/theband/issues/621) | **first in the queue of sprint 027**, with named blocker: access to the Dokploy panel |
| 050/US3 | [#622](https://github.com/The-Band-Solution/theband/issues/622) | done — close after the confirmation, with the AS1 caveat in the pending items |
| 052/US1–US3 | — (no issue) | done; the gap is the absence of the issues, recorded above |
| 047/US1 | [#573](https://github.com/The-Band-Solution/theband/issues/573) | the two inheritance tasks were accepted; the US belongs to 047 and is evaluated there |
| 051/US2 | [#598](https://github.com/The-Band-Solution/theband/issues/598) | inheritance task accepted; close #618 |
