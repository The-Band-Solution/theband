# Sprint 030 — Review {#sprint-030--review}

**Period**: 2026-09-07 to 2026-09-12 · **closed on 2026-09-13** (retroactive record)
**Feature**: [060 — the team screen](../../../specs/060-tela-da-equipe/spec.md) ·
**Inheritance**: 045 (D06), 055 (FR-003 and the sub-team act)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories of 060 | 6 (US1–US5, US9) | 6 executed · **1 accepted** (US4) · **5 not accepted** — 1 due to a defect (US9), 3 due to an unmeasured criterion (US2, US3, US5), 1 due to a promised test that is absent (US1) |
| Tasks of 060 | 29 | 29 · **18 successful** · **9 unsuccessful** (T010–T012, T015, T019, T020, T022, T028, T029) · 2 not assessed (T023, T025) |
| Inheritance | 3 (D06, FR-003, sub-team) | 3 executed · **1 accepted** (H3) · **2 not accepted** (H1, H2) · #860 **not assessed** |
| Issues | — | **none** — 060 never had an issue |
| `mix gates` | — | `exit 0` on each PR (#853: 2,026 tests · #857: 2,028 · #863: 2,112 · #860: 2,085); CI green on `development` |

**Everything `tasks.md` asked for was executed, and this is the sprint with the least trace of the
last twenty.** No backlog, no issue, no iteration, and with acceptance done only on
2026-09-13/14 — after v0.8.0 had already been assessed carrying these deliverables. What the
acceptance found is in [`aceitacao.md`](aceitacao.md), and the summary below.

## What was done {#o-que-foi-feito}

| User story | Tasks | PR | What reached the screen |
|---|---|---|---|
| US1 — who is on the team, and where each statement came from | T009–T013 | #821 | the two tabs of `/teams/:id` with the tab in the URL; the *Members* section by team membership, with the observed/declared legend, the named disagreement and *Where this team sits*; whoever does not manage reads everything and sees no action — and the event is refused with a reason; the query ceiling measured |
| US2 — declare the role of whoever the source shows, and change it | T018–T020 | #821 | *Declare role* / *Change role* on the line, *＋ new role…* without leaving it, and the *Declare all roles* batch by team membership |
| US3 — the person left, and what they did still counts | T014–T015 | #821 | *Left the team…* on the line, with a mandatory date and the origin of the end stated; the departure records who and when, reaches both roles, and the collection does not recreate it |
| US4 — the team membership that never was | T016–T017 | #821 | *Mistake…* on the line, with a mandatory reason and the text that sets it apart from "left"; the mistake reaches all in-force team memberships of the pair |
| US5 — create the organizational role from the structure | T021–T022 | #821 | the *Roles* section: catalog and created ones, create with a suggested code, rename, hide; how many people per role, here and in the organization |
| US9 — the whole team's flow | T026–T029 | #821 | granularity and window in the address, *Promised × Delivered* with the definition next to the title, the three charts on the composite team, the small chart on the sub-team card |
| foundation — the *manage team structure* grant | T001–T008 | #817, #819, #821 | `/roles` grants and revokes *manages team structure*; `pode_gerir_estrutura/3` replaces `pode_declarar_estrutura/4` — **zero accounts lost write access, measured** |

### The inheritance, and what came in without a task {#a-herança-e-o-que-entrou-sem-tarefa}

| Deliverable | PR | What changed |
|---|---|---|
| **The *Flow per person* tab** — US10–US12 of the extension, **without a task** | #860 (2026-09-12) | the burn per person and the forecast that states its confidence; **three queries for any number of members** (`flow_per_person_test.exs:113`). 25 tests, 3 defects reinjected. `tasks.md` said there was no prototype; there was one, approved on 2026-09-08 — and the requirements are only being written now (#913). **Not assessed** by the acceptance: it needs its own record |
| **D06 of v0.7.0 redone** — the disabled account as the prototype asked | #853 (2026-09-10) | reason from a closed list plus a note, episode with both ends (`account_disablements`), the refusal that stays on the screen, the vocabulary in the knowledge base. Migration `20260910050000`, additive; the backfill created zero episodes because there were zero disabled accounts |
| **FR-003 of 055 gets a screen** — link person to team | #863 (2026-09-12) | the act that had been a MUST clause since 2026-09-06 and had a function with 11 tests and zero calls in `lib/`. Six verdicts from `vinculo_possivel.ex` computed **before the button**; mandatory role, optional date; 35 tests (21 domain, 14 screen). **The screen came before the prototype was merged** — the prototype is in #915, open |
| **Declaring a team inside another is one act** | #857 (2026-09-11) | `Repo.transaction` covering `declare_structural_team/4` and `compose_teams/4`; the test isolates the second step (foreign key `whole_team_id`) and proves that **no team remains** in the organization. Reinjected: with the transaction undone, the test named the invariant |

## What the acceptance found {#o-que-a-aceitação-achou}

The assessment by the Product Owner role, on 2026-09-14, with executed evidence — the details in
[`aceitacao.md`](aceitacao.md):

1. **The *Squads at a glance* card is not the prototype's.** Three numbers `open items / median
   wait / pipeline` instead of `members / open / stopped`, without the mix of concepts
   `TASK n · US n · BUG n · EPIC n`. It is the only **behavior** defect observed in 060, and
   it brings down US9. **`tasks.md` itself confesses it** (T029, "Aberto ainda" — still open) and marks it `[x]`
   anyway;
2. **Three promised tests do not exist** — `abas_da_equipe_test`, `estrutura_membros_test`,
   `estrutura_permissao_test` (T010–T012, marked `[x]`). The behavior they would guard is
   right: the role's probe proved invalid tab → Dashboard with a warning, the seven marks in text,
   `MAINTAINER` absent, the header with the four counts. But the probe does not live in the repository
   and does not guard against regression — constitution XI;
3. **Four user stories rejected due to an unmeasured criterion, not due to a defect**: SC-013 (time of the
   departure, US3), AC2 (history in the list, US2), SC-005 and FR-081 (role in another team and the grants
   column, US5). They can become accepted **at the act of confirmation**, if the role measures them;
4. **Inheritance H1 (#853)**: the five points that v0.7.0 rejected in D06 **are closed with
   executed evidence** — 32 tests, `exit 0`. What prevents acceptance: three clauses of
   FR-025/027 without a test (absent vocabulary refuses; the phrase *"no note"*; `not recorded`), the
   transaction invariant without an injected-failure test, and the QA item-by-item check not
   found. Incomplete assessment, not wrong behavior;
5. **Inheritance H2 (#863)**: the prototype's `README.md` — in both copies, `development` and #915 —
   says **"Aprovação: aguardando a pessoa mantenedora — três perguntas abertas, duas mudam o que a
   tela desenha"** (Approval: awaiting the maintainer — three open questions, two of which change what the
   screen draws); `vinculo_possivel.ex` says "aprovado em 2026-09-11" (approved on 2026-09-11). Both cannot be
   true. The yardstick §3.1 item 2 and §3.4 are not implemented, §3.7 does not refuse a future
   date, and the domain refusal reaches the flash **in Portuguese, raw**, on a screen in English — the
   test itself asserts the word "papel". And #915 carries **content identical** to what was already merged:
   a republication, not a new prototype;
6. **Inheritance H3 (#857)**: accepted — `Repo.transaction` with `Repo.rollback`, and the test that injects the
   failure of the second step proves that no team remains. 72 tests, `exit 0`;
7. **#860 is not T026–T029.** It is the body of #821 that cites T026–T029; #860 is the *Flow per
   person* tab, US10–US12 of the extension, which `tasks.md` said had neither task nor prototype. It came in
   outside the plan and **was not assessed** — it needs its own record.

## Evidence {#evidências}

| What | Measure |
|---|---|
| `mix gates` | `exit 0` on #853 (2,026 tests), #857 (2,028), #863 (2,112), #860 (2,085); #821 without an evidence section in the body — **gap**; CI green on `development` (run 34779226200 on `0ccf02b`) |
| reinjected defects | #853: 4 injected, 4 caught · #857: 1, caught · #863: 4, caught (3 by the search no longer computing the verdict) · #860: 3, caught |
| query ceiling | T013 — both tabs measured; US9: **3** queries for any number of members (`flow_per_person_test.exs:113`) |
| inheritance migration | `20260910050000_episodio_de_desativacao.exs`: only `add`/`create table`/indexes/backfill `INSERT`; the `down` does `drop table` — rollback loses episodes written afterwards |
| review | #816–#821: reviewer requested, `reviews` 0 · **#853, #857, #860, #863: reviewer not requested**, `reviews` 0. No PR of the sprint has a recorded review |
| acceptance | tests named per US: US1 **65** · US3+US4 **54** · US2+US5 **72** · US9 **41** · inheritance H1 **32**, H2+H3 **72** — all `EXIT=0` on `0ccf02b`; role's screen probe 3/3. Logs in the session scratchpad, outside the repository |

## What was not done {#o-que-não-foi-feito}

| What | Reason | Destination |
|---|---|---|
| the **issues** of 060 | `/speckit-taskstoissues` did not run; the sprint ran without a backlog | retroactive creation **after** confirmation of acceptance, like 052 in sprint 026 — each issue saying it was born after the work |
| **US6, US7, US8** | *PR 2* of the spec, out of this sprint by decision of `tasks.md` | they remain in the product backlog; FR-041 and FR-084 without a task |
| **US10–US12** — the per-member charts | extension of 2026-09-08 without a prototype | behind US9; prototype first |
| the **six questions in `plan.md`** | they blocked closing T002, T014, T017 and T022 — and the tasks closed without a recorded answer | **debt**: `started_at` of `eo_team_compositions` (FR-037), the five transitions without a test, `eo_organizational_units` without a reader, table × sub-team cards (#820) |
| the **independent review** | none of the seven PRs was reviewed; four did not even request one | unrecoverable residue for the merged ones; the maintainer's dated attestation is what can be recovered |

## Deliverables not accepted {#entregáveis-não-aceitos}

| Deliverable | Why | Proposed destination |
|---|---|---|
| **US1** (D1) | promised test absent (T010–T012) — constitution XI; FR-004 "composed of K" without an assertion | **new task**, next sprint, first: the three test files — the role's probe is the skeleton. The delivered value stays |
| **US3** (D2) | SC-013 (< 1 min) not measured | **measure at confirmation** — the role times the departure on `?tab=structure`; compliant → accepted without a task |
| **US2** (D4) | AC2 — "history accessible in the list" not measured; the screen says "from the given date or from today" | **role's decision**: if the ended team membership on the line counts as history, accepted; otherwise, a task for the assertion and the FR-017 text |
| **US5** (D5) | SC-005 on **another** team and FR-081 (grants column) not measured | **measure** — probe with two teams in the same organization + reading of the *Roles* section |
| **US9** (D6) | *Squads at a glance* card ≠ prototype; SC-009 and FR-064 without an assertion | **new task via Design** — `median wait` per sub-team and the hue are open decisions (T029, L67); afterwards the card matching the prototype, the SC-009 assertion and the FR-064 sentence |
| **H1** — D06 redone (#853) | 4 clauses without a test; QA check absent; FR-025–029 **without a user story** in 045 | **new task** (never reopen #853): four tests + §3 check with capture; and 045 declares the missing US |
| **H2** — FR-003 with a screen (#863) | yardstick with approval **pending**; §3.1/§3.4/§3.7 broken; refusal in Portuguese; `declared_by_user_id` not asserted | **mandatory order**: P1–P3 answered → *Decided* and republication at the same address → (if P1 = A) `origin` and the three measures in YAML → §3.4/§3.7 → refusals through the catalog → tests → QA. #703 (055/US2, closed on 2026-09-02 with FR-003 without a screen) **is not reopened** |

**Accepted**: US4 (D3) — 10 of 10; H3 — 9 of 9. With the reservation common to all: review never
recorded, and the classification (*attested without a record* × *did not happen*) belongs to the role.

## Debt generated {#dívida-gerada}

- **the six questions in `plan.md` closed without an answer** — the task that depended on them was
  marked done anyway. It is the most silent form of debt: it shows up in no test at all;
- **`Periodos.interseccao/1` remains pessimistic** (from 057/058) — the screen by team membership inherits the
  partial-period mark on every line when `started_at` is missing;
- **the declared team membership prototype (#915) is open** and the #863 screen is already in
  `development` — the order "prototype before code" was inverted, and the record needs to say
  which of the two is the yardstick;
- **`#821` without an evidence section** in the body — the largest PR of the sprint (T005–T025) does not state the
  gates' exit code where the template asks for it.

## Lessons from this sprint {#lições-deste-sprint}

For the [cumulative record](../licoes-aprendidas.md):

- **L108** — three features without a sprint backlog; 060 is the one left without any issue;
- **L102** was born here (2026-09-09) and so were **L103/L104** (2026-09-10) — they are in the record;
- **L95, recurred**: four PRs without a reviewer requested, none reviewed;
- **L109 seen here too** — T029 marked `[x]` with its own text confessing that the card
  diverges from the prototype, and T010–T012 marked `[x]` without the promised test: manual marking of
  "done", which is what `sro.rule03` forbids for acceptance;
- **two sources diverging about the same approval** (README "pending" × code "approved on
  2026-09-11") — the same family as the compose–Dokploy parity (#911) and the duplicated `RETOMAR.md`:
  a record that is not unique lies on one of its sides;
- **a spec extension got a screen without a task** (#860) — L108 is not only "without a backlog": it is
  work that comes in with no plan at all, and acceptance does not find it.
