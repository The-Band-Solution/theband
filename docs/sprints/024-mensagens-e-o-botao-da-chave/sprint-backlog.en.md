# Sprint 024 — Messages and the key button {#sprint-024--mensagens-e-o-botão-da-chave}

**Period**: 2026-08-28 to 2026-09-04
**Features**: [047-mensagens-internacionalizadas](../../../specs/047-mensagens-internacionalizadas/spec.md) and
[048-botao-sem-chave-desabilitado](../../../specs/048-botao-sem-chave-desabilitado/spec.md)
**Plans**: [047/plan.md](../../../specs/047-mensagens-internacionalizadas/plan.md) ·
[048/plan.md](../../../specs/048-botao-sem-chave-desabilitado/plan.md)

## Sprint goal {#objetivo-do-sprint}

Everything the platform says to people leaves the code and goes into a catalog with
verification in the gates (047), and the generation buttons say BEFORE the click when
the provider's key is missing — with the domain guard that measurement revealed to be missing
(048). Two features, two branches, two PRs — never mixed (constitution).

## Lessons applied {#lições-aplicadas}

From the [cumulative record](../licoes-aprendidas.md), considered in this sprint:

| Lesson | Origin | How it is being applied |
|---|---|---|
| L60 | Sprint 016/022 | full form in every gate: `> log 2>&1; echo "EXIT=$?" >> log` |
| L71 | Sprint 022 | directed search in both plans: 047 proves that NO text test breaks (msgid = current sentence); 048 maps the gerar_perfil and run_now tests |
| L03 | Sprint 001 | 047's checker and 048's guard are born from the violation test |
| L38 | Sprint 009 | 048: 1 credential read per mount, never per row; 047: zero queries |
| L61 | Sprint 021 | 047: a translation gap falls back to the msgid (never a raw key); 048: no key becomes a branch with a sentence, not a late error |
| L72 | Sprint 023 | **applied preventively**: iteration 024 was created by resending the three in force, with the 34 assignments captured BEFORE and reassigned AFTER, checked by query (15+19 before = 15+19 after) |
| L75 | Sprint 023 | check by CONTENT before any squash-merge; it was what rescued the 1.6.0 amendment (#571) hours before this sprint |

## Sprint on GitHub {#sprint-no-github}

**Iteration**: Sprint 024 — Mensagens e o botão da chave · 2026-09-05 · 7 days (id `1dbd69cf`)
**Project**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Calendar note**: the iteration dates follow the field's grid (022 and 023
occupy up to 2026-09-04); the REAL period of the sprint is the one in this document's header.

**Preventive repair recorded (L72)**: adding 024 requires resending the entire
list — ids `a00ce208`/`a61c4aa5` became `19bfe13e`/`d56dc05c` and the 34 items
were reassigned on the spot, checked by query.

**Inherited limitations**: types `Epic`/`User Story` remain nonexistent in the
organization (creating them requires approval); hierarchy through sub-issues not used — a task
references the US in its body. The project's `Priority` only has P0/P1/P2 — 047's US3
(P3 in the spec) gets P2 in the field, with the real priority stated here.

## Selected user stories {#user-stories-selecionadas}

| # | User story | Feature | Issue | Priority | Estimate | Criteria |
|---|---|---|---|---|---|---|
| US1 | Every error message comes from a translation file | 047 | [#573](https://github.com/The-Band-Solution/theband/issues/573) | P1 | 5 | 3 |
| US2 | System messages under the same regime | 047 | [#574](https://github.com/The-Band-Solution/theband/issues/574) | P2 | 3 | 2 |
| US3 | One language chosen, two available | 047 | [#575](https://github.com/The-Band-Solution/theband/issues/575) | P2 (P3 in the spec) | 3 | 2 |
| US1 | The disabled button says what is missing | 048 | [#587](https://github.com/The-Band-Solution/theband/issues/587) | P1 | 3 | 5 |

`Priority` is the SRO *importance*; `Estimate` is the *complexity*. Blank =
unknown, not zero.

## Tasks {#tarefas}

| # | Task | Serves | Issue | Estimate | State |
|---|---|---|---|---|---|
| 047/T001 | Open the gates baseline | US1 | [#576](https://github.com/The-Band-Solution/theband/issues/576) | 1 | done |
| 047/T002 | Configure the catalog's locales and domains | US1 | [#577](https://github.com/The-Band-Solution/theband/issues/577) | 1 | done |
| 047/T003 | Literals checker, from the violation | US1 | [#578](https://github.com/The-Band-Solution/theband/issues/578) | 3 | done |
| 047/T004 | The messages-in-the-catalog gate | US1 | [#579](https://github.com/The-Band-Solution/theband/issues/579) | 1 | done |
| 047/T005 | 045's messages migrate without changing a byte | US1 | [#580](https://github.com/The-Band-Solution/theband/issues/580) | 2 | done |
| 047/T006 | LiveView error flashes to errors | US1 | [#581](https://github.com/The-Band-Solution/theband/issues/581) | 5 | done |
| 047/T007 | Confirmations and warnings to system | US2 | [#582](https://github.com/The-Band-Solution/theband/issues/582) | 3 | done |
| 047/T008 | Screen leftovers, measured and named | US2 | [#583](https://github.com/The-Band-Solution/theband/issues/583) | 1 | done |
| 047/T009 | The gaps report | US3 | [#584](https://github.com/The-Band-Solution/theband/issues/584) | 2 | done |
| 047/T010 | The language switch proven | US3 | [#585](https://github.com/The-Band-Solution/theband/issues/585) | 2 | done |
| 047/T011 | Green gates and PR following the standard | US3 | [#586](https://github.com/The-Band-Solution/theband/issues/586) | 1 | done |
| 048/T001 | Open the gates baseline | US1 | [#588](https://github.com/The-Band-Solution/theband/issues/588) | 1 | done |
| 048/T002 | The domain guard, from the violation | US1 | [#589](https://github.com/The-Band-Solution/theband/issues/589) | 2 | done |
| 048/T003 | The person page says it before the click | US1 | [#590](https://github.com/The-Band-Solution/theband/issues/590) | 3 | done |
| 048/T004 | The monthly generation says it before, tenant-only | US1 | [#591](https://github.com/The-Band-Solution/theband/issues/591) | 2 | done |
| 048/T005 | Green gates and PR following the standard | US1 | [#592](https://github.com/The-Band-Solution/theband/issues/592) | 1 | done |

A task does not get a `Priority`: it inherits the one of the user story it serves.

States: `a fazer` (to do) · `em andamento` (in progress) · `feito` (done) · `bloqueado` (blocked) · `não iniciado` (not started)

## Out of scope for this sprint {#fora-do-escopo-deste-sprint}

- **HEEx text of the screens (notices, empty states, titles)** — stays ENUMERATED in
  `specs/047-mensagens-internacionalizadas/pendencias.md` (T008), burned down in
  future sprints; checker v1 covers the `put_flash` drains (the
  contract's boundary).
- **Complete pt translation** — born through the refusals (T010); the rest stays visible in the
  gaps report, never silent.
- **050 (production)** — specified and postponed by the maintainer's decision
  ("do the deploy later" *(original: "faça o deploy depois")*).
- **049 (sign in with GitHub)** — depends on 050.
- **#568 (management of the administrator mark)** — backlog, needs a spec.
- **Credential PubSub (048)** — rejected in the plan: the problem does not exist
  (principle VIII).

## Risks and dependencies {#riscos-e-dependências}

- 047/T006 touches 12 files with 55 calls — the risk is changing ONE byte of text;
  the defense is the whole suite as sentinel (L71) and the contract that forbids it.
- 047's new gate is born red on purpose until T007 — the full run of the
  gates is only required in T011; intermediate PRs do not exist (one PR per feature,
  at its end).
- 048 changes the contract of `Profiles.request/3` — whoever else calls it needs to handle
  `:sem_chave` (the directed search in the plan says: only the two screens).
- Both features touch `people_live/show.ex` — 048 goes in AFTER 047's merge
  or rebases; never both open on the same file without a declared order.

## Sprint Definition of Done {#definition-of-done-do-sprint}

In addition to the per-task DoD:

- [x] quality gates green on both branches (L60 form, EXIT in the log) — 14/14 on both, EXIT=0
- [x] knowledge base valid (part of the gates)
- [x] issues #573–#592 closed by hand with evidence (PRs following the 1.6.0 standard do not close them on their own)
- [x] `sprint-review.md` written
- [x] `licoes-aprendidas.md` updated — L76–L79
