# Sprint 030 — The team screen by team membership, and the inheritance that got a screen {#sprint-030--a-tela-da-equipe-por-vínculo-e-a-herança-que-ganhou-tela}

**Period**: 2026-09-07 to 2026-09-12 (one-week cadence) · **closed on 2026-09-13**
**Feature**: [060 — the team screen](../../../specs/060-tela-da-equipe/spec.md)
**Plan**: [plan.md](../../../specs/060-tela-da-equipe/plan.md) ·
**Research**: [research.md](../../../specs/060-tela-da-equipe/research.md) ·
**Prototype**: [prototipo/](../../../specs/060-tela-da-equipe/prototipo/) — approved on 2026-09-07 and 2026-09-08
**Inheritance**: [045](../../../specs/045-autenticacao-e-acesso/spec.md) (D06 of v0.7.0) ·
[055](../../../specs/055-equipes-declaradas/spec.md) (FR-003 and the sub-team act)

> **This backlog was written after the sprint, on 2026-09-13.** The `sprint-backlog` skill is
> mandatory before implementing and did not run: 060 went from spec to screen without this document,
> without issues and without an iteration. What is here is the **reconstructed intent** based on the
> `tasks.md` of 2026-09-07 and the PRs — not the intent recorded before executing. The
> distinction matters because the analysis of adherence between plan and execution, which this document
> exists to enable, **cannot be done** for this sprint: whoever writes it already knows what
> happened. See gap 1 at the end, and lesson L108.

## Sprint goal {#objetivo-do-sprint}

**The team page starts showing who is in it by team membership — observed and declared, side by
side —, and whoever manages the structure becomes able to act on each line**: say that the person left,
that the team membership never existed, declare or change the role, and create organizational roles based on
what the structure shows. And, in the second tab, the team's flow at three granularities.

## Where this sprint came from {#de-onde-este-sprint-veio}

Spec 060 was born on 2026-09-06/07 from the team screen epic: the page showed participation
without saying where each statement came from, and someone's departure could not be declared. The prototype
(`team-dashboard-structure.html`) was approved before the code, and the prompt that generated it is in
`prototipo/`. The order of the tasks is that of the **vertical slices**: the first screen is T010, and before
it only what the screen needs to decide who sees a button — the *manage team structure* grant
(T002–T007).

**The inheritance came in through review, not through planning.** The review of 2026-09-10 (`RETOMAR.md`
of that day) found three things outside 060: FR-003 of 055 had been a MUST clause since 2026-09-06 and
**had no screen** — `declare_team_membership/5` existed with 11 tests and zero calls in
`lib/`; the act of creating a sub-team made **two writes without a transaction**; and D06 of v0.7.0 (the
disabled account) was rejected for three reasons that #853 set out to close. All three
came in during the same period, and that is why they are here.

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md). **Recorded afterwards** — what can be
stated is what the evidence from the PRs shows, not what was read when opening.

| Lesson | Origin | How it shows in the evidence |
|---|---|---|
| **principle IV** — contract before the first public function | constitution | T001 wrote the contracts before anything else (#817) |
| **vertical slice** — never infrastructure without a consumer on the screen | constitution VIII | T010 is the first screen, and T002–T007 exist only because it needs the verdict |
| **L38 / L53** — the cost of a screen is measured by the difference, with a ceiling on both sides | 009, 013 | T013 measured the query ceiling of both tabs |
| **L30** — check the number against the source | 003 | T006 replaced `pode_declarar_estrutura/4` and **measured**: zero accounts lost write access |
| **L60** — the verdict is the exit code | 019 | #853 `exit 0` (2,026 tests), #857 `exit 0` (2,028), #863 `exit 0` (2,112), #860 `exit 0` (2,085) |
| **defect reinjection** as proof of the test | 029 | #853 reinjected 4 and all 4 failed; #857 undid the transaction and the test named the invariant; #863 reinjected 4; #860 reinjected 3 |
| **L95** — requesting a reviewer is not obtaining a review | 027 | **applied halfway**: #816–#821 requested a reviewer (1 each, `reviews` 0); **#853, #857, #860 and #863 did not request one** |
| **L102** — `git add -A` in a shared tree | **born here**, 2026-09-09 | a PR that said it changed three files changed six; redone with explicit paths |
| **L103 / L104** — the prototype is not the product; a discarded warning becomes a certificate | **born here**, 2026-09-10 | the design detector started ignoring `prototipo/` (#858) and requiring the libraries |

## Sprint on GitHub {#sprint-no-github}

**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) · **1 PR** in the
project (#817, with a null `Iteration`); the other six, outside.

### Three limitations — declared, not worked around {#três-limitações--declaradas-não-contornadas}

1. **060 has no issues at all.** No epic, no user story, no task. `/speckit-tasks`
   ran, `/speckit-taskstoissues` **did not**. The 29 tasks below have no link **on
   purpose** — a task without an issue is an explicit pending item, never an invented link. It is the same gap
   as 052 in sprint 026, and the destination is the same: **retroactive creation after confirmation of
   acceptance**, with each issue saying it was born after the work;
2. **No iteration.** The iteration active during the period (*Sprint 024 — Mensagens e o botão da chave*,
   2026-09-05 to 2026-09-12) received no item from this feature;
3. **No type.** A consequence of 1 — there is nothing to type.

## Selected user stories {#user-stories-selecionadas}

From spec 060, the **six** that `tasks.md` calls *PR 1*. US6, US7 and US8 were left for *PR 2*
(see *Out of scope*).

| # | User story | Priority | Issue | Tasks | Criteria |
|---|---|---|---|---|---|
| US1 | Who is on the team, and where each statement came from | P1 | — | T010–T013 | AS 1–5, FR-001 to FR-013, SC-004, SC-007 |
| US2 | Declare the role of whoever the source shows, and change it | P1 | — | T018–T020 | FR-014 to FR-018 |
| US3 | The person left, and what they did still counts | P1 | — | T014–T015 | FR-019 to FR-023, SC-001, SC-013 |
| US4 | The team membership that never was | P1 | — | T016–T017 | FR-024 to FR-028, SC-002 |
| US5 | Create the organizational role from the structure | P1 | — | T021–T022 | FR-029 to FR-034, SC-005 |
| US9 | The whole team's flow: burn, Promised × Delivered, Monte Carlo | P3 | — | T026–T029 | FR-064, FR-084, SC-009; the three charts at the three granularities |

`Priority` is the *importance* — value to the organization, and it comes from the spec. `Estimate` (the
*complexity*) **was not recorded**: without an issue there is no field; the column does not exist in this table
so as not to suggest there was an estimate.

## Tasks {#tarefas}

All executed — the PRs are in the *State* column. The *Issue* column is `—` in all of them, due to
limitation 1.

| # | Task | Serves | Issue | State |
|---|---|---|---|---|
| T001 | Write the contracts before the first public function | foundation | — | done · #817 |
| T002 | Declare the two grants in the knowledge base (`role_grants.yaml`) | foundation | — | done · #817 |
| T003 | Amend the evidence rule to v3 | foundation | — | done · #817 |
| T004 | The table and the schema of the management grant | foundation | — | done · #819 |
| T005 | `EO.StructureGrants` — declare, revoke, list and reach | foundation | — | done · #821 |
| T006 | `pode_gerir_estrutura/3` replaces `pode_declarar_estrutura/4` | foundation | — | done · #821 |
| T007 | `/roles` grants and revokes *manages team structure* | foundation | — | done · #821 |
| T008 | The declared departure and the declaration date in the schema | foundation | — | done · #821 |
| T009 | The roster queries | US1 | — | done · #821 |
| T010 | The two tabs of `/teams/:id`, with the tab in the URL | US1 | — | done · #821 |
| T011 | The *Members* section by team membership, the legend, the disagreement and *Where this team sits* | US1 | — | done · #821 |
| T012 | Whoever does not manage reads everything and sees no action — and the event is refused with a reason | US1 | — | done · #821 |
| T013 | The query ceiling of both tabs, measured | US1 | — | done · #821 |
| T014 | The departure records who and when, reaches both roles, and the collection does not recreate it | US3 | — | done · #821 |
| T015 | "Left the team…" on the line, with a mandatory date and the origin of the end stated | US3 | — | done · #821 |
| T016 | The mistake reaches all in-force team memberships of the pair | US4 | — | done · #821 |
| T017 | "Mistake…" on the line, with a mandatory reason and the text that sets it apart from "left" | US4 | — | done · #821 |
| T018 | `declare_role/6` and `change_role/5` | US2 | — | done · #821 |
| T019 | "Declare role" / "Change role" on the line, and "＋ new role…" without leaving it | US2 | — | done · #821 |
| T020 | The "Declare all roles" batch, by team membership, in the Structure | US2 | — | done · #821 |
| T021 | `role_holder_counts/3` — how many people per role | US5 | — | done · #821 |
| T022 | The *Roles* section: catalog and created ones, create with a suggested code, rename, hide | US5 | — | done · #821 |
| T023 | Project writing lives in the Structure, under the same verdict | closing | — | done · #821 |
| T024 | Isolation between tenants in the new queries | closing | — | done · #821 |
| T025 | Gates, quickstart and documents | closing | — | done · #821 |
| T026 | The granularity and the window live in the address, with a default per granularity | US9 | — | done · #821 |
| T027 | *Promised × Delivered*, with the definition next to the title | US9 | — | done · #821 |
| T028 | The three charts on the composite team, over the whole team's set | US9 | — | done · #821 |
| T029 | The small chart on the sub-team card | US9 | — | done · #821 |

### Inheritance and what came in without a task — deliverables outside 060's `tasks.md` {#herança-e-o-que-entrou-sem-tarefa--entregáveis-fora-do-tasksmd-da-060}

| # | Deliverable | Feature | Origin | State |
|---|---|---|---|---|
| H4 | **The *Flow per person* tab** — the burn per person and the forecast that states its confidence; three queries for any number of members | 060 · US10–US12 of the `spec-graficos-por-membro.md` extension (FR-085 to FR-112) | `tasks.md` declared them **without a task** ("depends on US9 and on the prototype of this tab, which does not exist yet"); the prototype was approved on 2026-09-08 and the screen went in anyway | done · #860 (2026-09-12) — **not assessed**; the requirements are being transcribed from the prototype in #913 |
| H1 | The disabled account as the prototype asked — reason from a closed list, episode with both ends, the refusal on the screen | 045 · D06 of v0.7.0 | `docs/releases/v0.7.0.md`, D06 rejected | done · #853 (2026-09-10) |
| H2 | Link person to team — FR-003 gets a screen, with the verdict before the button | 055 · FR-003 | review of 2026-09-10 | done · #863 (2026-09-12) |
| H3 | Declaring a team inside another is **one** act, in a transaction | 055 · `criar_subequipe` | review of 2026-09-10 | done · #857 (2026-09-11) |

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

| What | Why |
|---|---|
| **US6** — the sub-teams: who makes up this team, since when (P2) | *PR 2*; the sub-team card was moved to US7 by decision 11 of 2026-09-07 (#820) |
| **US7** — the reorganized Dashboard (P2) | *PR 2*; FR-041 (card and the door) without a task |
| **US8** — the manager's overview (P2) | *PR 2* |
| **US10–US12** — the four per-member charts (FR-085 to FR-112) | `tasks.md` declared them without a task; **they went in anyway** through #860, outside the plan — see H4 |
| **FR-007** | confirmed without change (`pode_ver_equipe/3`) |

## Risks and dependencies {#riscos-e-dependências}

- **The six open questions in `plan.md`** did not block starting and did block closing T002,
  T014, T017 and T022. Four of them were on the agenda on 2026-09-08: `started_at` of
  `eo_team_compositions` mandatory × "date or unknown" (FR-037); five transitions without
  a test; `eo_organizational_units` without a schema and without a reader; the per-sub-team table coexists with or
  replaces the cards (#820). **No answer is recorded** — the tasks closed anyway,
  and this is debt (see the review);
- **Two YAMLs and two migrations** — `role_grants.yaml`, evidence v3, `saida_declarada_com_autor`,
  `concessao_de_gestao_da_estrutura`. Additive;
- **Pessimistic `Periodos.interseccao/1`** (debt from 057/058) — the screen by team membership consumes the
  partial-period mark, and a team without `started_at` will see it on every line.

## Sprint Definition of Done {#definition-of-done-do-sprint}

- [x] quality gates green — `mix gates` `exit 0` on each PR, and CI green on `development`
- [x] valid knowledge base — part of the gates
- [ ] issues closed or reprioritized — **there are no issues** (limitation 1)
- [x] `sprint-review.md` written — retroactive, 2026-09-13
- [x] `aceitacao.md` written — role's proposal, confirmation pending
- [x] `licoes-aprendidas.md` updated — L108
