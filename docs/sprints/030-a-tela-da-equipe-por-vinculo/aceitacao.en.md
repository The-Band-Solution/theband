# Sprint 030 — Acceptance record {#sprint-030--registro-de-aceitação}

**Features**: [060 — the team screen](../../../specs/060-tela-da-equipe/spec.md) (US1–US5, US9) ·
inheritance from [045](../../../specs/045-autenticacao-e-acesso/spec.md) (D06 of v0.7.0) and from
[055](../../../specs/055-equipes-declaradas/spec.md) (FR-003 and the sub-team act)
**Evaluated on**: 2026-09-14, on `development` at `0ccf02b`, with executed evidence — named
tests with exit code, a screen probe over a real scenario, reading of the migration and of the
prototype. Full suite and gates **not** run: CI run
[34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) is the evidence.
**Role**: Product Owner — evaluation **proposed by the agent**, in two parts written by two
executions of the role (the 060; the inheritance). **Confirmation by the person allocated to the role: PENDING.**
**PO type**: `sro.product_owner_client` — the one who demands is the one who maintains.
**Retroactive record**: the sprint ran without a backlog, without issues and without an iteration (2026-09-07 to
2026-09-12); this record is born after v0.8.0 had already been evaluated carrying these
deliverables. `sro.rule01` (a materialized US must be in the sprint backlog) **is not verifiable**
for this sprint.

## Summary {#resumo}

| | Count |
|---|---:|
| Deliverables evaluated | 9 — six from the 060 (D1–D6), three inherited (H1–H3) |
| Accepted | **2** — D3 (US4) and H3 (sub-team in one transaction) |
| Not accepted due to an **observed defect** | 1 — D6 (US9: card outside the prototype) |
| Not accepted due to an **unmeasured criterion** | 4 — D2 (US3), D4 (US2), D5 (US5), H1 (#853) |
| Not accepted due to a **missing promised test** | 1 — D1 (US1) |
| Not accepted due to an **unapproved yardstick and non-conforming criteria** | 1 — H2 (#863) |
| Not evaluated | 1 — #860, the *Flow per person* tab (US10–US12 of the extension, no task) |
| Tasks of the 060 successfully performed | 18 — T001–T009, T013, T014, T016–T018, T021, T024, T026, T027 |
| Tasks of the 060 not successfully performed | 9 — T010–T012, T015, T019, T020, T022, T028, T029 |
| Tasks not evaluated | 2 — T023, T025 (closing) |

**Four of the seven refusals are due to incomplete evaluation, not to wrong behavior** — and
they can become accepted in the same act as the confirmation, if the role measures SC-013, decides the reading of
AC2, and measures SC-005/FR-081. The two behavior defects are the *Squads at a glance* card
(D6) and the broken yardstick of the declared team membership (H2). The heaviest record is not about a criterion: it is
that **none of the sprint's ten PRs has a recorded review**, and four did not even request one.

---

# Part A — feature 060 {#parte-a--a-feature-060}

**Feature**: [060-tela-da-equipe](../../../specs/060-tela-da-equipe/spec.md) — US1, US2, US3, US4, US5, US9.
US6, US7, US8 were left out (PR 2) and are not evaluated here.
**Evaluated on**: 2026-09-14, on `development` at `0ccf02b` (clean tree), with evidence
executed in this evaluation — `mix test <arquivo>` with `echo $?` captured right after, and reading of the
rendered HTML where the criterion is about the screen. Full suite and gates were **not** run here: CI run
[34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) over
`0ccf02b` (`push`, `conclusion: success`, 2026-09-13T19:56:51Z) is the evidence for the suite.
**Role**: Product Owner — evaluation **proposed by the agent**; confirmation by the person allocated
**pending**.
**PO type**: `sro.product_owner_client` — the one who demands is the one who maintains.

### Record gaps that cut across all deliverables {#lacunas-de-registro-que-atravessam-todos-os-entregáveis}

| Gap | What was observed | Consequence |
|---|---|---|
| **No GitHub issue** | `gh issue list --state all --search "060"` → `[]`; searching for "tela da equipe", "Structure roster", "Flow per person" only returns issues from 055/057/058 | no US or task of the 060 has a `#` — the *Materializes* column says "no issue"; `flow.wip.count` never counted this work |
| **No sprint backlog for 030** | `docs/sprints/` ends at `029-medidas-da-equipe`; `030/` does not exist | `sro.rule01` (a materialized US must be in the sprint backlog) **is not verifiable** — the record is retroactive, and this is a gap, not conformance |
| **Review not recorded** (#817, #819, #821) | `reviewRequests = [The-Band-Solution/the-band]`, `reviews = []` | reviewer requested from the team, as the house requires; **review recorded: no**. Situation for the role to classify: *attested without record* (with date and sentence) or *did not happen* |
| **PR #860 with no reviewer requested** | `reviewRequests = []`, `reviews = []`, merged 2026-09-12 | violates "every PR is born with a reviewer requested"; enters as a process non-conformance in D6 |
| **Five test files promised in tasks.md do not exist under the promised name** | `abas_da_equipe_test`, `estrutura_membros_test`, `estrutura_permissao_test`, `saida_na_tela_test`, `equivoco_na_tela_test` — absent by name | see, per deliverable, where the promised assertion was found — or not |

---

---

### D1 — The two tabs, and the member list by team membership with source, role, start and sub-teams {#d1--as-duas-abas-e-a-lista-de-membros-por-vínculo-com-origem-papel-início-e-subequipes}

**Produced by**: T010, T011, T012, T013 (screen) · supported by T001–T003 (PR [#817](https://github.com/The-Band-Solution/theband/pull/817)), T004 (PR [#819](https://github.com/The-Band-Solution/theband/pull/819)), T005–T009 and T024 (PR [#821](https://github.com/The-Band-Solution/theband/pull/821))
**Materializes**: US1 — *Who is on the team, and where each statement came from* (P1, atomic) · **no issue**

Commands:
- `MIX_ENV=test mix test test/the_band/ontology/seon/eo/roster_test.exs test/the_band_web/live/teto_de_consultas_da_equipe_test.exs test/the_band_web/live/duas_afirmacoes_test.exs test/the_band_web/live/estado_na_url_test.exs test/the_band/ontology/seon/eo/isolamento_da_060_test.exs test/the_band/tenants/gerir_estrutura_test.exs` → **65 passed, 0 failures, `EXIT=0`** (log `scratchpad/us1-run.log`).
- **Screen probe** (outside the repository, `scratchpad/sonda_060b_test.exs`, `mix test <caminho> --seed 0` → **3 passed, `EXIT=0`**, log `scratchpad/sonda-run.log`): a team with four people — Ana (declared, role, start 2026-01-01), Bia (observed, no role), Caio (declared, departure on 2026-06-01), Dora (declared, mistake "cadastro errado") — rendered by an administrator account and by a `member` account with no linked person.

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — each person once, with role or *not declared*, source (*observed* / *declared by X on D*), start or *unknown*, sub-teams (FR-009, FR-010) | functional | yes | `roster_test.exs:100-167` (one row per person, team memberships inside); probe `[PALAVRA]`: `observed`, `declared by`, `unknown`, `not declared`, `direct` — **all present as text** in the HTML of `?tab=structure` |
| AC2 — direct and in a sub-team: one row, marks *direct* and the sub-team, counted once | functional | yes | `roster_test.exs:101` "direta na equipe E numa subequipe: uma linha, dois vínculos"; `:129` "os chips: squads traz a PARTE, e direct diz que há vínculo na própria equipe"; `:146` only in the sub-team, without `direct` |
| AC3 — whoever left remains, marked *left on D*, with period and author, outside those in force (FR-011) | functional | yes | `roster_test.exs:301` "fim DECLARADO traz autor e o instante do registro"; probe `[HEADER]` "2 people here · **1 left**" with Caio ended; word `left` present |
| AC4 — a mistake remains, marked, with reason/author/date, and the text says it is excluded from every measure on every date (FR-011) | functional | yes | `roster_test.exs:361` "o equívoco traz razão, autor e instante"; list legend `show.ex:5001` "mistake — the person was never here. The link counts for no date at all."; probe `[HEADER]` "1 recorded by mistake" |
| AC5 — the source still lists whoever the organization declared as departed: the two statements side by side, the screen does not choose (FR-013, 055 FR-012) | functional | yes | `duas_afirmacoes_test.exs:71` "a tela mostra AS DUAS afirmações, cada uma com a sua origem"; `:92` "não escolhe"; `:107` the reverse direction; `:122` a mistake is a case of its own |
| AC6 — a non-administrator account with no grant reads the whole list and **no** write action (FR-006, SC-011) | functional | yes | probe `[LEITOR botões]` — `Declare role`, `Add role`, `Left the team`, `Mistake…`, `New role`, `Change`: **all `false`**; `saida_e_equivoco_na_tela_test.exs:232` |
| AC6' — the attempt via event is refused with the reason named (FR-006, FR-082) | functional | yes | probe `[LEITOR promover / criar_papel / registrar_saida / registrar_equivoco]` → flash "Your account is not linked to a person yet, and managing a team's structure is granted to organizational roles." — refusal, **not exception**; the three reasons in the domain: `gerir_estrutura_test.exs:127-185` |
| AC7 — the observed/declared/left/mistake distinction survives without color (SC-004) | functional | yes | probe: the four marks are words in the HTML; legend `show.ex:4996-5008` in a textual `<dl>` |
| FR-001, SC-007 — tab in the URL; no `?tab` → Dashboard; invalid → Dashboard **and** notice | functional | yes | probe `[ABAS]`: no tab → `Dashboard aria-selected="true"`; `?tab=structure` → `Structure aria-selected="true"`; `?tab=members` → Dashboard **and** flash "A team has no “members” tab. Showing the dashboard."; `show.ex:150-154`. **Note**: there are three tabs (`Flow per person`, `?tab=people`) — an amendment declared in FR-085 of the 2026-09-08 extension, not a divergence |
| FR-004 — common header: name, team source, *N in force*, *M with no role*, *composed of K* | functional | partial | probe `[HEADER]`: "SONDA · 2 people here · 1 left · 1 recorded by mistake · **1 with no organizational role** · source github … collected at …" — N, M and source conform; **"composed of K sub-teams" not probed** (the probe's team has no parts; `equipe_composta_test` runs green but the header assertion was not checked by name) |
| FR-012 — in force, left and mistakes counted separately, matching the query | functional | yes | `roster_test.exs:180` "vigentes, saíram e equívocos somam o total de pessoas do roster"; `:231` invalidated + in force counts as in force; probe: 2 · 1 · 1 over 4 people |
| SC-004, FR-008 — 0 rows with platform access level | non-functional | yes | `roster_test.exs:420` "nível de acesso da plataforma NÃO sai do roster (FR-008, SC-004)"; probe `[MAINTAINER?] false | access-at-platform? false`; `screens_test.exs:148-163` |
| FR-005 — reading without administer permission; everything restricted to the tenant | non-functional | yes | probe: a `member` account opens `?tab=structure`; `isolamento_da_060_test.exs:61-176` (roster, totals, reach, commands); `screens_test.exs:210,218` another tenant's team → redirect |
| Query ceiling of the tab (T013) — constant at 1×11 people and 1×3 sub-teams | non-functional | yes | `teto_de_consultas_da_equipe_test.exs:242` "o número de consultas não cresce com as pessoas"; `:270` "nem com as subequipes"; `:295` declared ceiling `@teto_da_estrutura 7`; `:317` one tab does not pay for the other |
| **Process (constitution XI) — the test promised in `tasks.md` exists, with a named assertion** | process | **no** | T010 `abas_da_equipe_test.exs` (five cases, `assert_patched`): **does not exist** — the behavior is only proven by this evaluation's probe, which does not live in the repository and does not guard against regression. T011 `estrutura_membros_test.exs`: **does not exist** (text marks partially covered by `screens_test.exs:163` and by the probe). T012 `estrutura_permissao_test.exs` ("the three reasons per event"): **does not exist**; the refusal per event is scattered across `saida_e_equivoco_na_tela_test:240`, `declarar_papel_na_linha_test:393`, `papeis_na_estrutura_test:270`, always with **one** reason; `promover` was only proven by the probe |
| Process — PR with reviewer requested, review recorded, linked to the project | process | **no** | #817: reviewer `the-band` requested, `reviews=[]`, in the project with `Status=Done` and `Iteration=null`; #819 and #821: reviewer requested, `reviews=[]`, **outside the project** |

**Derived phase**: `sro.not_accepted_deliverable` — **all functional and non-functional criteria of US1 conform with executed evidence**; the refusal is due to the process criterion of constitution XI: three tasks marked `[x]` whose promised test does not exist in the repository. Alternative reading for the role: accept on the value delivered and open a new task for the three test files — the agent records both and does not choose the one that closes the sprint.
**Task phase**: T010, T011, T012 — `sro.non_successfully_performed_scrum_development_task` (promised test missing); T013 — success; T001–T009, T024 — success by their own criteria (all files exist and ran green).
**What was missing**: the three test files, with the assertions named in tasks.md — this evaluation's probe (`scratchpad/sonda_060b_test.exs`) is already their skeleton.

### D2 — The declared departure: the team membership gains an end, author and instant, and the collection does not undo it {#d2--a-saída-declarada-o-vínculo-ganha-fim-autor-e-instante-e-a-coleta-não-desfaz}

**Produced by**: T008, T014, T015 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821) (T008 already in #821; migration `saida_declarada_com_autor`)
**Materializes**: US3 — *The person left, and what they did still counts* (P1, atomic) · **no issue**

Command: `MIX_ENV=test mix test test/the_band/ontology/seon/eo/saida_declarada_test.exs test/the_band/ontology/seon/eo/vinculo_observado_test.exs test/the_band_web/live/saida_e_equivoco_na_tela_test.exs test/the_band/ontology/seon/eo/discordancia_test.exs test/the_band/ontology/seon/eo/team_membership_test.exs` → **54 passed, 0 failures, `EXIT=0`** (2026-09-14, `0ccf02b`; log at `scratchpad/us3-us4-run.log`).

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — departure on D ends the team membership, keeps who and when, no row removed (FR-019, FR-021) | functional | yes | `saida_declarada_test.exs:82` "quem tem dois papéis vigentes sai numa chamada, e os dois ficam encerrados"; `:157` "saída sem autor é recusada"; `saida_e_equivoco_na_tela_test.exs:93` "registrar a saída fecha o vínculo e diz quantos alcançou" |
| AC2 — numbers for a period before D are exactly the same (FR-020, SC-001) | functional | yes | `saida_declarada_test.exs:110` "o número de um período anterior à saída é o mesmo antes e depois (SC-001)" — compares `count_team_members_at` before/after |
| AC3 — a future date is refused with a reason (FR-023) | functional | yes | `saida_declarada_test.exs:139` "data no futuro é recusada"; `saida_e_equivoco_na_tela_test.exs:127` same on the screen |
| AC4 — after the departure, the collection does not re-create while the source lists it; the screen shows the two statements (FR-026, SC-002) | functional | yes | `saida_declarada_test.exs:286` "depois da saída, a coleta NÃO recria o vínculo enquanto a origem seguir mostrando"; `duas_afirmacoes_test.exs:71` "a tela mostra AS DUAS afirmações, cada uma com a sua origem" |
| AC5 — a second departure on an ended team membership is refused without rewriting the date (FR-023) | functional | yes | `saida_declarada_test.exs:168` "a segunda saída não reescreve a data da primeira (FR-023)"; `:126` "par sem vínculo vigente é erro, e nunca {:ok, 0}" |
| AC6 — the row says whether the end was declared (by whom) or ascertained by the collection, with the cadence limitation (FR-022) | functional | yes | `roster_test.exs:301` "fim DECLARADO traz autor e o instante do registro"; `:317` "fim constatado pela COLETA vem sem autor, e a tela precisa dizer isso"; `:339` an old record reads "sem autor" |
| FR-027 — a new observation after an ascertained absence creates a new team membership (return) | functional | yes | `saida_declarada_test.exs:304` "depois de ausência constatada E reobservação, nasce vínculo NOVO — é retorno" |
| FR-023 — date required; field **not** prefilled with today; named refusal | functional | yes | `saida_e_equivoco_na_tela_test.exs:57` "o botão abre o formulário sob a linha, e a data vem VAZIA"; `:112` "data vazia é recusada pelo SERVIDOR, com a razão" — sentence at `show.ex:469` "A departure needs a date — the platform does not assume today." |
| Prototype — note "ended, not deleted" in the inline form | functional (screen) | yes | `saida_e_equivoco_na_tela_test.exs:80` "a nota diz que o vínculo é encerrado, e não apagado"; `show.ex:5466` |
| T008 — writing `ended_by_user_id` without `end_declared_at` refused by the **database** | non-functional | yes | `saida_declarada_test.exs` runs green; the assertion of the violation via `Repo.update_all` is in the file (tasks.md T008) — **not reread line by line in this evaluation** |
| SC-013 — record a departure in under 1 minute without leaving the tab | non-functional | **not measured** | there is no timing; the test `saida_e_equivoco_na_tela_test` shows that the act happens in the same `live` at `?tab=structure`, which supports "without leaving the tab", not the time |
| SC-012 — 0 rows removed | non-functional | yes | `saida_declarada_test.exs:82` checks that the team memberships stay ended (not absent); contract `contracts/estrutura-da-equipe.md` declares that no function deletes |
| Unhappy paths of the act — empty, future, already ended, other tenant, no author | functional | yes | all five have a named test: `saida_declarada_test.exs:126,139,157,168` and `isolamento_da_060_test.exs:160` "a saída com a equipe do outro tenant não encerra nada" |

**Divergence of label, not of criterion**: tasks.md T015 promised the sentence "the platform does not **presume** today"; the screen says "does not **assume** today". No FR fixes the word. Recorded, does not penalize.

**Derived phase**: `sro.accepted_deliverable` **conditional** — all functional criteria conform with executed evidence; SC-013 (time) not measured. The skill says: criterion without evidence → not accepted. **Proposal to the role**: SC-013 is a non-functional usability criterion that requires measurement with a person; either the role measures it in a session (under one minute, timed) and the deliverable becomes accepted, or it stays **not accepted due to incomplete evaluation** — not due to a defect. The agent does not choose the reading that closes the sprint.
**Task phase**: T008, T014, T015 — follow the decision on SC-013.

---

### D3 — The mistake: the team membership that never was, in observed and declared {#d3--o-equívoco-o-vínculo-que-nunca-foi-em-observado-e-declarado}

**Produced by**: T016, T017 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821)
**Materializes**: US4 — *The team membership that never was* (P1, atomic) · **no issue**

Command: the same as D2 (`saida_declarada_test` contains the mistake `describe`; `saida_e_equivoco_na_tela_test` contains T017) → **54 passed, `EXIT=0`**.

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — a mistake on a declared team membership invalidates it for every period, with reason, author and date (FR-024) | functional | yes | `saida_declarada_test.exs:193` "quem tem dois papéis vigentes é invalidado nos dois numa chamada"; `roster_test.exs:361` "o equívoco traz razão, autor e instante" |
| AC2 — a mistake on an **observed** team membership: leaves every measure; the collection does not re-create; the screen shows the two statements (FR-025, FR-026, SC-002) | functional | yes | `vinculo_observado_test.exs:176` describe "o equívoco vale para o vínculo observado, e a coleta não recria (decisão de 2026-09-07)"; `duas_afirmacoes_test.exs:122` "declaração de que nunca esteve, com a coleta ainda mostrando" |
| AC3 — without a reason it is refused (FR-028) | functional | yes | `saida_declarada_test.exs:242` "razão vazia continua recusada, e sem autor também"; `saida_e_equivoco_na_tela_test.exs:186` "razão vazia é recusada, e nada é gravado" |
| AC4 — *never was* and *left on D* are distinct texts; neither is "removed" (FR-028) | functional (screen) | yes | `saida_e_equivoco_na_tela_test.exs:148` "o formulário exige razão, e o texto separa equívoco de saída"; `duas_afirmacoes_test.exs:92` "a tela NÃO diz que a pessoa simplesmente saiu"; `show.ex:5502` "This is not \"left the team\"" |
| AC5 — a person who belonged and later had a second team membership invalidated does **not** appear as *never was* (aggregate verdict per person) | functional | **yes, with a caveat** | `discordancia_test.exs` runs green in the same command; `roster_test.exs:231` "a pessoa com um vínculo invalidado E um vigente conta como VIGENTE" covers the aggregate in the roster. **I did not find an assertion named exactly for "ended + invalidated → is not never was"** in the disagreement test — the role should ask QA to point to the line or record it as a test gap |
| FR-025 — invalidated excluded from every measure on every date | functional | yes | `saida_declarada_test.exs:213` "o invalidado não conta em data ALGUMA, nem antes do reconhecimento"; `saida_e_equivoco_na_tela_test.exs:169` "registrar o equívoco tira a pessoa de TODA data" |
| Prototype — the whole note ("applies to declared and observed alike", "the next collection does not re-create") | functional (screen) | yes | `show.ex:5503-5506` carries both sentences; `saida_e_equivoco_na_tela_test.exs:148` checks the text |
| FR-006 — whoever does not manage does not see *Mistake…* and the direct event is refused | functional | yes | `saida_e_equivoco_na_tela_test.exs:232` "lê a lista inteira e não vê os botões"; `:240` "o evento disparado direto é recusado, e nada muda" |
| Unhappy paths — empty reason, pair with nothing in force, other tenant | functional | yes | `saida_declarada_test.exs:242,271`; `isolamento_da_060_test.exs:176` "o equívoco com a equipe do outro tenant não invalida nada" |
| SC-012 — 0 rows removed | non-functional | yes | invalidation is a mark (`saida_declarada_test.exs:193` reads both team memberships afterwards) |

**Derived phase**: `sro.accepted_deliverable` — all criteria with executed evidence; the caveat on AC5 is about **locating the assertion**, not about wrong observed behavior. If the role prefers the strict reading (unnamed assertion = no evidence), the phase becomes `sro.not_accepted_deliverable` due to incomplete evaluation — the agent records both readings and does not choose.
**Task phase**: T016, T017 — `sro.successfully_performed_scrum_development_task`, under the same caveat.

---

### D4 — Declaring and changing the role on the row, and the batch by team membership {#d4--declarar-e-alterar-o-papel-na-linha-e-o-lote-por-vínculo}

**Produced by**: T018, T019, T020 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821)
**Materializes**: US2 — *Declare the role of whoever the source shows, and change it* (P1, atomic) · **no issue**

Command: `MIX_ENV=test mix test test/the_band/ontology/seon/eo/declarar_e_alterar_papel_test.exs test/the_band_web/live/declarar_papel_na_linha_test.exs test/the_band_web/live/promocao_na_tela_test.exs test/the_band_web/live/papel_declarado_test.exs test/the_band_web/live/papeis_na_estrutura_test.exs` → **72 passed, 0 failures, `EXIT=0`** (log `scratchpad/us2-us5-run.log`).

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — declaring on an observed team membership completes the **same** team membership; start stays *unknown*; the row says *declared* (FR-015, FR-016) | functional | yes | `declarar_e_alterar_papel_test.exs:68` "num vínculo OBSERVADO, completa o mesmo vínculo — mesmo id"; `:108` "início vazio FICA vazio, e nunca vira hoje"; `declarar_papel_na_linha_test.exs:132` same on the screen |
| AC2 — changing leaves the previous one with a period and the new one in force; the list shows the one in force **with access to the history** (FR-017) | functional | **partial** | two records: `declarar_e_alterar_papel_test.exs:241`; on the screen: `declarar_papel_na_linha_test.exs:326` "encerra o antigo e abre o novo na mesma data". **"Access to the history" and "the screen says whether it applies from the given date or from today" have no named assertion** — not measured in this evaluation |
| AC3 — a second simultaneous role accepted and shown beside it (FR-018) | functional | yes | `declarar_e_alterar_papel_test.exs:138`; `declarar_papel_na_linha_test.exs:218` "com dois papéis, há dois botões Change"; `:268` "trocar UM papel deixa o outro intacto" |
| AC4 — *new role…* opens the form without leaving the row and the created one is already selectable (FR-034) | functional | yes | `declarar_papel_na_linha_test.exs:172` "'＋ new role…' cria o papel e declara, sem sair da linha (FR-034)" |
| AC5 — a blank start never becomes today (FR-016) | functional | yes | `declarar_papel_na_linha_test.exs:115` "a data 'since' vem VAZIA, e o texto diz o que vazio significa"; `declarar_e_alterar_papel_test.exs:108` |
| FR-014 — batch in the Structure, same command, saying how many rows were skipped | functional | yes, with a caveat | `promocao_na_tela_test.exs` runs green at `?tab=structure` (describes "a seção de promoção", "a data de início", "confirmar todas"); **the count of "skipped" was not checked by name** |
| FR-006 — whoever does not manage does not see the button; direct event refused | functional | yes | `declarar_papel_na_linha_test.exs:386,393`; probe `[LEITOR promover]` → named refusal "Your account is not linked to a person yet, and managing a team's structure is granted to organizational roles." |
| Unhappy paths — same role, role from another organization, concept outside the catalog, ended team membership, other tenant, no name, nothing chosen | functional | yes | `declarar_e_alterar_papel_test.exs:165,187,225,315,331,353`; `declarar_papel_na_linha_test.exs:154,199,351` — all return a named refusal, none raises |
| SC-012 — 0 rows removed | non-functional | yes | `declarar_e_alterar_papel_test.exs:241` reads both records after the change |
| Prototype — *Declare role* on the row; inline form; "＋ new role…" in the selector | functional (screen) | yes | `declarar_papel_na_linha_test.exs:74,102`; `show.ex:5181,5390` |

**Derived phase**: `sro.not_accepted_deliverable` **due to incomplete evaluation** — AC2 has two parts without evidence ("access to the history" in the list; the screen saying "from the given date or from today"). No wrong behavior observed. **Alternative for the role**: if it accepts that the history is the ended team membership remaining on the row (the roster lists all of the person's team memberships — `roster_test.exs:167,231`), AC2 becomes conforming and the phase becomes accepted. I do not choose.
**Task phase**: T018 — success (all its criteria conform); T019/T020 — follow the decision on AC2.

---

### D5 — The organization's roles, from the Structure {#d5--os-papéis-da-organização-a-partir-da-estrutura}

**Produced by**: T021, T022 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821)
**Materializes**: US5 — *Create the organization's role from the structure* (P1, atomic) · **no issue**

Command: the same as D4 → **72 passed, `EXIT=0`**. Note: tasks.md T021 promised `roster_test.exs — describe "contagem por papel"`; the assertion lives in `papeis_na_estrutura_test.exs:79-108`. It changed file; it exists.

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — create with name and code: it exists for the organization, with author and date; it appears in the selector of this and of **any** team and in `/roles` (FR-030) | functional | **partial** | `/roles`: `papeis_na_estrutura_test.exs:143` "criar aqui aparece em /roles — é o MESMO papel (SC-005)"; selector of **this** team: `declarar_papel_na_linha_test.exs:172`. **Selector of ANOTHER team of the organization (SC-005) has no assertion** — not measured |
| AC2 — a repeated code in the same organization refused; in another it is not a conflict (FR-031) | functional | yes | `papeis_na_estrutura_test.exs:160,169` |
| AC3 — removing a role in use refused saying **how many** (FR-033) | functional | yes | `papeis_na_estrutura_test.exs:205` "ocultar papel COM vínculo vigente é recusado, dizendo quantos" |
| AC4 — SRO catalog marked, not removable, with the count here and in the organization (FR-029) | functional | yes | `:63` "traz catálogo e criados, com origem e código"; `:234` "papel do CATÁLOGO não oferece renomear nem ocultar"; `:79,95` count of distinct people |
| AC5 — renaming preserves the team memberships (FR-032) | functional | yes | `:183` "renomear mantém os vínculos apontando para o mesmo papel" |
| AC6 — code suggested and editable (FR-031) | functional | yes | `:123` "o código é sugerido do nome"; `:131` "o código editado NÃO é sobrescrito pela sugestão" |
| FR-081 — the *Roles* section shows which roles carry the *manage structure* grant (read) | functional | **not measured** | no named assertion found in `papeis_na_estrutura_test.exs`; tasks.md T022 lists the *grants* column — not checked on the screen |
| FR-006 — whoever does not manage reads and does not act | functional | yes | `:260` "vê a tabela e nenhum botão nem formulário"; `:270` "o evento de criar é recusado"; probe `[LEITOR criar_papel]` refused with a reason |
| FR-005 — isolation: counts and code from another tenant | non-functional | yes | `isolamento_da_060_test.exs:109,113` |
| SC-012 — hiding is a mark, it does not delete | non-functional | yes | `:219` "ocultar papel sem ninguém funciona, e é MARCA — não apaga" |
| Prototype — *Roles* (catalog + created; "New role" name and code; rename; remove only without team membership) | functional (screen) | yes, with a pending decision | button label: the prototype says "remove", spec FR-033 says "hide", tasks T022 proposes *Hide* as **open question 1** — decision by the role/Design pending, not a defect of the implementation |

**Derived phase**: `sro.not_accepted_deliverable` **due to incomplete evaluation** — AC1 (selector of another team) and FR-081 (grants column) without evidence. No defect observed.
**Task phase**: T021 — success; T022 — not successful while FR-081 and the SC-005 part are not measured.

---

### D6 — The flow of the whole team in three granularities, and the small chart on the card {#d6--o-fluxo-da-equipe-inteira-em-três-granulações-e-o-gráfico-pequeno-no-cartão}

**Produced by**: T026, T027, T028, T029 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821) — the body of #821 cites T026, T028 and T029. **PR [#860](https://github.com/The-Band-Solution/theband/pull/860) is not from this US**: it delivers the *Flow per person* tab (extension `spec-graficos-por-membro.md`, US10–US12), outside the six evaluated.
**Materializes**: US9 — *The flow of the whole team: burn, Promised × Delivered, Monte Carlo* (P3, atomic) · **no issue**

Command: `MIX_ENV=test mix test test/the_band/work_items/fluxo_da_equipe_test.exs test/the_band_web/live/equipe_composta_test.exs test/the_band_web/live/fluxo_na_tela_test.exs` → **41 passed, 0 failures, `EXIT=0`** (log `scratchpad/us9-run.log`).

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| AC1 — burn-up/down of the **whole** team, starting from those already open, region between curves, text "is not the sum" (FR-056, FR-059, FR-060) | functional | yes | `fluxo_da_equipe_test.exs:178` "mede o trabalho de quem está nas SUBEQUIPES"; `:248` "a mesma pessoa em DUAS partes conta uma vez no todo (FR-060)"; `equipe_composta_test.exs:151` "a tela diz por que não soma"; `show.ex:2941` "not the sum" |
| AC2 — changing granularity regroups the same items; equal sums in all three (FR-061) | functional | yes | `fluxo_da_equipe_test.exs:109` "a soma de abertos e de fechados é igual em semana, mês e ano"; `fluxo_na_tela_test.exs:156` a nonexistent granularity draws week **and warns** |
| AC3 — Promised × Delivered with the definition next to the title and "there is no committed scope" (FR-062, FR-063) | functional | yes | `fluxo_na_tela_test.exs:366` "a palavra 'promised' nunca aparece sem a definição operacional ao lado"; `:389` closed is an act of the tool; `show.ex:1600-1601` |
| AC4 — Monte Carlo **weekly regardless of the granularity**, two hypotheses, confidence, proportion that did not finish (FR-064) | functional | **partial** | two hypotheses: `fluxo_na_tela_test.exs:327` "desenha as duas hipóteses na MESMA régua"; proportion: `:338` "runs that never reached zero". **"Weekly regardless of the granularity, and the screen says so": no assertion; `grep -i weekly|regardless` in `show.ex` returns only "closed per week —" (`:3088`)** — not measured |
| AC5 — below the floor no forecast, and the screen says what is missing | functional | yes | `fluxo_na_tela_test.exs:316` "sem histórico não há gráfico, e a tela diz o que falta" |
| AC6 — identical forecast in two queries (057 FR-036, SC-014) | functional | yes, by inheritance | covered in `test/the_band/forecast_test.exs` (feature 057), **not re-run here**; CI 34779226200 green |
| AC7 — each sub-team card carries the small chart and is a door to its Dashboard (FR-041, FR-084) | functional | yes | `equipe_composta_test.exs:159` "FR-041/FR-084: cada subequipe é um CARTÃO, com faísca, e o cartão é porta" + assertion that the **table** has no `<svg>` |
| SC-009 — distance between the curves at any point = items open at that point, in the three granularities | non-functional | **not measured** | no named assertion in `fluxo_da_equipe_test.exs` or in `fluxo_na_tela_test.exs` (search for "distância", "aberto naquele ponto", "open_at"); T028 promised to prove exactly this |
| FR-078 — default window per granularity (8 weeks / 12 months / all years), in the title and in the URL | functional | yes | `fluxo_na_tela_test.exs:170,186`; `fluxo_da_equipe_test.exs:331` "primeira_atividade devolve a abertura mais antiga da equipe"; `:197,205` absurd/zero period falls back to the default |
| SC-008 — no total cell; statement that it is not a sum | non-functional | yes | `equipe_composta_test.exs:151`; 057 SC-003 inherited |
| **Prototype — *Squads at a glance*: three numbers `members / open / stopped` and the mix of concepts `TASK n · US n · BUG n · EPIC n` below them** | functional (screen) | **no** | **tasks.md T029 itself records it**: "the three numbers on the card diverge from the prototype (`open items`/`median wait`/`pipeline` against `members`/`open`/`stopped`), the mix of concepts is missing, and the per-sub-team hue is a pending Design decision". Divergence from the prototype is a defect (house rule: the implemented screen is exactly the approved one) |
| Prototype — the burn writes the identity `open(t) = base + opened − closed`, and the baseline | functional (screen) | yes, with a caveat | `fluxo_na_tela_test.exs:229,248,302` (values, horizon with a caveat); the body of PR #860 cites "the identity without the initial open" as an item **fixed** there — PR #860 is outside this US, but the fix is in `0ccf02b` |
| Prototype — *Delivery forecast*: two histograms on the same axis, the hatched "never" column separate | functional (screen) | yes | `fluxo_na_tela_test.exs:327,346-348` (">never<" separate from the weeks); `:351` textual description with the numbers |
| Process — PR with reviewer requested and in the project | process | **no** | #821: reviewer requested from the `the-band` team, **no review recorded**, **not linked to the project** (`projectItems = []`) |

**Derived phase**: `sro.not_accepted_deliverable` — fails an **observed** screen criterion (the card diverges from the approved prototype, as confessed by tasks.md itself), in addition to SC-009 and half of AC4 without evidence.
**Task phase**: T026, T027 — success by their criteria; T028 — not successful (SC-009 promised and not proven); T029 — not successful (card outside the prototype).
**What was missing**: the card with the prototype's three numbers and the mix of concepts; the assertion of the distance between curves; the sentence that the forecast is weekly whatever the granularity.
**Proposed destination of US9**: a new intended task linked to US9 (never reopen T028/T029) for (1) the card conforming to the prototype — it goes through Design first, because `median wait` per sub-team requires a grouped query that does not exist and the per-sub-team hue is a pending decision (T029, L67); (2) the SC-009 assertion; (3) the FR-064 sentence. It enters the next sprint backlog, in first place, as inheritance.

---

### Summary {#resumo_1}

| | Count |
|---|---:|
| Deliverables evaluated | 6 |
| Accepted (proposal) | 1 (D3 — US4) |
| Not accepted due to an **observed defect** | 1 (D6 — US9: card outside the prototype) |
| Not accepted due to **incomplete evaluation** (criterion without evidence) | 3 (D2 — US3: SC-013; D4 — US2: AC2; D5 — US5: AC1/SC-005 another team, FR-081) |
| Not accepted due to a **process criterion** (constitution XI: promised test missing) | 1 (D1 — US1) |
| Tasks successfully performed | 17 — T001–T009, T013, T014, T016, T017, T018, T021, T024, T026, T027 |
| Tasks not successfully performed | 9 — T010, T011, T012 (test missing); T015 and T019/T020 and T022 (follow the decision on the unmeasured criterion); T028, T029 |
| Tasks not evaluated | T023, T025 (closing; FR-052 belongs to US7) |

| US | Proposed verdict | Criteria measured | Conforming | Non-conforming | Not measured | Proposed destination |
|---|---|---:|---:|---:|---:|---|
| US1 | `sro.not_accepted_deliverable` (process XI) | 16 | 13 | 2 (promised test missing; PR without review/project) | 1 (FR-004 "composed of K") | **new intended task**: write `abas_da_equipe_test`, `estrutura_membros_test`, `estrutura_permissao_test` (three reasons × event, including `promover`) — the probe is the skeleton; next sprint, in first place. The value delivered stays in production |
| US3 | `sro.not_accepted_deliverable` (incomplete) | 13 | 12 | 0 | 1 (SC-013, time < 1 min) | **measure at confirmation**: the role times the departure at `?tab=structure`; conforming → accepted with no new task |
| US4 | `sro.accepted_deliverable` | 10 | 10 | 0 | 0 (AC5 with a caveat on locating the assertion) | done; ask QA for the line of the assertion "ended + invalidated ≠ never was" or record a test gap |
| US2 | `sro.not_accepted_deliverable` (incomplete) | 10 | 9 | 0 | 1 (AC2: history accessible in the list; the screen says "from the given date or from today") | **decision by the role**: if the ended team membership on the row counts as history, accepted; otherwise, a new task for the assertion and the FR-017 text |
| US5 | `sro.not_accepted_deliverable` (incomplete) | 11 | 9 | 0 | 2 (SC-005 selector of **another** team; FR-081 grants column) | **measure**: probe on a second team of the same organization + reading of the Roles section; if conforming → accepted; otherwise, a new task |
| US9 | `sro.not_accepted_deliverable` (defect) | 14 | 9 | 2 (card ≠ prototype; PR without review/project) | 3 (AC4 "weekly whatever the granularity" said on the screen; SC-009 distance between curves; AC6 only by inheritance from 057) | **new intended task** linked to US9: *Squads at a glance* card conforming to the prototype (`members/open/stopped` + mix of concepts) — **goes through Design first**, because `median wait` per sub-team and the hue are open decisions (T029, L67); SC-009 assertion; FR-064 sentence. Next sprint, as inheritance |

**Sprint deliverable** (`sro.sprint_deliverable`): composed only of accepted ones. In the proposal as it stands, **only D3 (US4)** belongs to it. If the role measures SC-013 and decides AC2/FR-081/SC-005 at confirmation, D2, D4 and D5 can enter in the same act.

### Observed defects (wrong behavior or outside what was approved) {#defeitos-observados-comportamento-errado-ou-fora-do-aprovado}

| # | Where | What | Criterion | Source |
|---|---|---|---|---|
| 1 | Dashboard of the composite team, *Squads at a glance* card | three numbers `open items / median wait / pipeline` instead of `members / open / stopped`; the mix of concepts `TASK n · US n · BUG n · EPIC n` is missing | prototype §3 (2026-09-08); FR-084; house rule "implemented screen = approved screen" | tasks.md T029, "Aberto ainda" — **the task's own record confesses it and marks `[x]`** |
| 2 | tasks.md | T010, T011, T012 marked `[x]` without the promised test existing | constitution XI | search by name and by content in `test/` |
| 3 | PR #860 | merged without a reviewer requested (`reviewRequests=[]`) | "every PR is born with a reviewer requested" | `gh pr view 860` |
| 4 | PRs #819, #821, #860 | outside the project (`projectItems=[]`); #817 in the project with `Iteration=null` | "linked to the project, with Iteration and Status" | `gh pr view --json projectItems` |

No unhappy path exercised raised an exception: every refused event returned a flash with a named reason (probe, four events; refusal tests in the six domain files).

### Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

There is no sprint backlog for 030 to compare against. Amendment declared **before** this evaluation and outside the 060: FR-085 (`spec-graficos-por-membro.md`, 2026-09-08) adds the third tab `?tab=people` to the FR-001 parameter — the screen has three tabs and this conforms to the amendment, not to the literal FR-001. Recorded; does not penalize.

### Criteria without evidence {#critérios-sem-evidência}

| Criterion | US | What is missing to measure it |
|---|---|---|
| SC-013 — departure recorded in < 1 min without leaving the tab | US3 | time a real session; no test measures time |
| AC2 (part) — "the list shows the one in force with access to the history"; the screen says "from the given date or from today" (FR-017) | US2 | assertion on the row after `change_role`; reading of the form text |
| SC-005 (part) — a created role appears in the selector of **another** team of the organization | US5 | probe with two teams in the same organization |
| FR-081 — the Roles section shows which roles carry the grant | US5 | assertion on the *grants* column |
| FR-004 (part) — "composed of K sub-teams" in the header | US1 | named assertion in `equipe_composta_test` or a probe with parts |
| FR-064 (part) — the screen says the forecast is weekly whatever the granularity | US9 | text not found in `show.ex`; assertion nonexistent |
| SC-009 — distance between curves = open at that point, in the three granularities | US9 | assertion promised in T028 and not written |
| AC6 — identical forecast in two queries | US9 | re-run `test/the_band/forecast_test.exs` (057) — not run in this evaluation |

### Process gaps {#lacunas-de-processo}

1. **No issue** for any US or task of the 060; **no sprint backlog** for 030 — `sro.rule01` not verifiable; this record is retroactive.
2. **Review**: #817, #819, #821 with a reviewer requested from the team and `reviews=[]`; #860 with no reviewer requested. None of the four has a *recorded review*. The role must classify each one as *attested without record* (with date and sentence) or *did not happen*.
3. **Project**: three of the four PRs invisible to the board; `flow.wip.count` undercounted the sprint.
4. **tasks.md marks `[x]` what has no test** (T010–T012) and **what confesses diverging from the prototype** (T029) — manual marking of "done", exactly what `sro.rule03` forbids for acceptance.
5. **PR #860 attributed in this evaluation to T026–T029 by the request** — it is the body of #821 that cites T026, T028, T029; #860 delivers the *Flow per person* tab (US10–US12), which was not evaluated here and needs its own record.
6. **PO type**: `sro.product_owner_client`; the final decision belongs to the one who demands.

### Commands and logs of this evaluation {#comandos-e-logs-desta-avaliação}

| Round | Command (all in `MIX_ENV=test`, `0ccf02b`) | Result | Log |
|---|---|---|---|
| US1 | `mix test roster_test teto_de_consultas_da_equipe_test duas_afirmacoes_test estado_na_url_test isolamento_da_060_test gerir_estrutura_test` | 65 passed, `EXIT=0` | `scratchpad/us1-run.log` |
| US3+US4 | `mix test saida_declarada_test vinculo_observado_test saida_e_equivoco_na_tela_test discordancia_test team_membership_test` | 54 passed, `EXIT=0` | `scratchpad/us3-us4-run.log` |
| US2+US5 | `mix test declarar_e_alterar_papel_test declarar_papel_na_linha_test promocao_na_tela_test papel_declarado_test papeis_na_estrutura_test` | 72 passed, `EXIT=0` | `scratchpad/us2-us5-run.log` |
| US9 | `mix test fluxo_da_equipe_test equipe_composta_test fluxo_na_tela_test` | 41 passed, `EXIT=0` | `scratchpad/us9-run.log` |
| Screen probe | `mix test scratchpad/sonda_060b_test.exs --seed 0` | 3 passed, `EXIT=0` | `scratchpad/sonda-run.log` |
| Full suite and gates | **not run here** — CI run 34779226200 over `0ccf02b`: `success` | — | GitHub Actions |

---

# Part B — the inheritance (045 and 055) {#parte-b--a-herança-045-e-055}

**AGENT'S PROPOSAL — confirmation by the person allocated to the role PENDING.** Nothing below is
consummated acceptance: it is the criterion-by-criterion evaluation, with the evidence executed in this session,
so that `sro.product_owner` confirms or refuses each derived phase.

**Features**: [045-autenticacao-e-acesso](../../../specs/045-autenticacao-e-acesso/spec.md) ·
[055-equipes-declaradas](../../../specs/055-equipes-declaradas/spec.md)
**Evaluated on**: 2026-09-14, on `development` at `0ccf02b` (clean), with no checkout or editing.
**Executed evidence**: `mix test <arquivos>` with exit code, reading of migration and of
code, `git show` of the prototype's branch, GitHub API for PRs and issues. Gates and full suite
**not** run here — CI run [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200)
over `0ccf02b` is `success`.
**Role**: Product Owner — evaluation proposed by the agent; confirmation pending.
**PO type**: `sro.product_owner_client` — the one who demands is the one who maintains.

**Three process invariants cut across the three deliverables, and are recorded once here:**

| Invariant | #853 (H1) | #863 (H2) | #857 (H3) |
|---|---|---|---|
| review requested (`timeline: review_requested`) | **never requested** | **never requested** | **never requested** |
| review recorded (`pulls/<n>/reviews`) | 0 | 0 | 0 |
| issue closed by the PR (`closingIssuesReferences`) | none | none | none |
| item in the sprint backlog (`sro.rule01`) | `docs/sprints/030*` **does not exist** yet | same | same |

Classification of the review, by the house rule: **review did not happen** — there is no record and no
request; and it is not possible to request a review of a merged PR. The skill says *"do not accept a deliverable whose
review was never requested"*; v0.7.0 and v0.8.0 treated the same gap as a **release exception
decided by the role** (21 of 21 PRs). Both readings are recorded; the choice belongs to the role, and
this document **does not make it**. `rule01` closes in the act of the retroactive record of sprint 030 — which is
what this document feeds — provided that `sprint-backlog.md` lists the three as inheritance.

---

### H1 — D06 of v0.7.0, re-evaluated: the disabled account as the prototype asked {#h1--d06-da-v070-reavaliado-a-conta-desativada-como-o-protótipo-pediu}

**Produced by**: PR [#853](https://github.com/The-Band-Solution/theband/pull/853), merged
2026-09-10T14:15Z into `development` · **no issue** (`closingIssuesReferences: []`; the 18 closed
issues matching "045" are T001–T014, US1–US3 and 047/T005 — none deals with the disabled account)
**Migration**: `20260910050000_episodio_de_desativacao.exs` — creates `account_disablements` (reason and
note at both ends, `disable_reason NOT NULL`), partial unique index
`account_disablements_aberto_index` (one open episode per account), backfill with `not_recorded`,
and `users.password_source` / `users.password_set_by_user_id`.
**Materializes**: FR-025 to FR-029 of spec 045 (written **in the same PR**, formalizing the criteria
that the backlog item `docs/backlog/conta-desativada.md` had carried since 2026-09-09). The 045 has
three user stories (US1 sign in, US2 scopes, US3 profile) and **none of them mentions disabling**:
the deliverable materializes a requirement with no declared atomic user story. Gap recorded, not
named.
**Prototype**: `specs/045-autenticacao-e-acesso/prototipo/` — `PROMPT.md` (§3 is the yardstick),
`README.md` (11 decisions, 4 questions closed by the recommendations), `accounts-disable.html`.
Approval: README, *"the maintainer answered 'go ahead and implement'"* (2026-09-10) *(original: "a pessoa mantenedora respondeu 'pode implementar'")*. **Prototype
and code entered in the same PR** — the order prototype → approval → code is not demonstrable from the
repository history, only from the text of the README and of the backlog item.
**Executed evidence**: `mix test test/the_band/tenants/conta_desativada_test.exs
test/the_band_web/live/accounts_test.exs test/the_band_web/live/accounts_elo_test.exs` →
**32 passed, EXIT=0** (2026-09-14 18:53).

#### The criteria that D06 refused, one by one, against the new evidence {#os-critérios-que-o-d06-recusou-um-a-um-contra-a-evidência-nova}

| Criterion (as in D06) | Type | D06 | Now | Evidence |
|---|---|---|---|---|
| the record says **who, when and WHY**; nothing is deleted | functional | **NO** | **yes** | `disable_user/4` requires a reason map; `AccountDisablement.abrir_changeset` `validate_required [.., :disable_reason]` + `validate_inclusion` against `AccountLifecycle.codigos_de_desativacao()`; tests `:232` *"desativar EXIGE razão, e a razão fica escrita na linha"*, `:250` *"a nota é obrigatória para suspeita de comprometimento"*; column `disable_reason NOT NULL` in the migration |
| **re-enabling is a recorded act, with author and reason** | functional | **NO** | **yes** | `enable_user/4` (tenant, id, **actor**, reason); `fechar_changeset` `validate_required [:enabled_by_user_id, :enable_reason]`; test `:305` *"reativar fecha o episódio e NÃO apaga a desativação"*; `:367` *"duas desativações caem no registro, e o par de colunas cabia uma"* |
| the person's roster, measures and history **do not change** | non-functional | no evidence | **yes, with a caveat** | `:407` compares **before/after** `length(EO.list_people)`, grants in force, `person_id`/`person_revoked_at` and `password_hash`, with a guard against zero. **No computed measure of the person is compared**; for "measures" the evidence is indirect — the act writes only to `users` and `account_disablements` (`desativar_na_transacao`). The backlog item reports mutation (revocation injected into the disable → the test failed) |
| Part C — the *revoke* text says it **does not remove access** | functional | **NO** | **yes** | `accounts_live/index.ex:867` `nao_faz="Does not remove access. Signing in by e-mail does not need the link..."`; `:1492` `data-confirm="... It does NOT remove access ..."`; test `:448` asserts `"Does not remove access"` |
| Part C — a test that **fails** if revoking becomes the only act again | non-functional | **NO** | **yes** | `:448` *"revogar o elo NÃO é o único ato oferecido a quem desliga"* — asserts `"Removing someone's access"` and `"Disable account"` |
| a disabled account **does not authenticate by token** | functional | n/a | **not evaluable** | the token does not exist (spec 061 without code). The screen writes *"the platform has none yet"* as a promise. It remains a criterion that cannot be measured — **does not count as conforming** |

The other six criteria of D06 (identical refusal `:60`; rotates the session token `:99`, `:121`;
distinction without color `:197`; a named act of its own `:448`; not oneself / other tenant / twice `:130`,
`:139`, `:153`; re-enabling does not give back the password `:162`, `:178`) **still conform** in the same
execution.

#### The three findings outside the D06 table {#os-três-achados-fora-da-tabela-do-d06}

| Finding | Now | Evidence |
|---|---|---|
| the screen changed **without an approved prototype** | **closed, with a caveat** | the prototype exists, with PROMPT/README/HTML; approval recorded in the README and in `docs/backlog/conta-desativada.md`. Caveat: same PR as the code; and **QA's item-by-item check with a capture of the real screen was not found** — the §3 yardstick has 7 sections and 6 table rows, and the evidence here is the presence of the texts (20 of 21 terms from §3 in `index.ex`; `from a reset` comes from the knowledge base label and appears in the rendered HTML, `:208`, `:226`) |
| **four decisions** taken by the code | **closed** | decision 1 moved to recommendation (b) — its own relator `account_disablements`; questions 12–15 closed by the recommendations **after** the "go ahead and implement", recorded in the README with where each one lives |
| `sro.rule01` — no sprint backlog, no task, no issue | **still open** | `#853` with no issue; `docs/sprints/030*` does not exist. It closes with the retroactive backlog listing this item as inheritance |

#### The criteria the spec came to carry (FR-025 to FR-029), and what of them was measured {#os-critérios-que-a-spec-passou-a-carregar-fr-025-a-fr-029-e-o-que-deles-foi-medido}

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| FR-025 reason from a closed list, coming from `access.account_lifecycle` | functional | yes | `AccountLifecycle` reads `KnowledgeBase.rule("access.account_lifecycle")`, with no list written in the module; `:232` |
| FR-025 **with no declared vocabulary, the act refuses** and does not write an empty value | functional | **no executed evidence** | `disable_user/4` has `vocabulario_declarado()` → `:vocabulario_nao_declarado`; **no test in `test/` exercises the missing knowledge base** (`grep vocabulario_nao_declarado test/` empty). Reading code is not evidence |
| FR-025 note required **only** for `suspected_compromise` and `other` | functional | yes | `:250`; `exige_nota` reads `note_required.on_disable` from the knowledge base |
| FR-025 where the note is omitted, the record writes the **absence sentence**, never an empty cell | functional | **no executed evidence** | `frase_sem_nota/0` (*"no note"*) used in `index.ex` (2 occurrences); no test assertion found |
| FR-026 actor and reason when re-enabling; the disabling **is not deleted** | functional | yes | `:305`, `:367` |
| FR-026 one open episode per account, by partial unique index | functional | yes | migration `account_disablements_aberto_index where enabled_at IS NULL`; `unique_constraint` in `abrir_changeset:82`; `:367` |
| FR-026 `disabled_at` and the episode in the **same transaction** | non-functional | **not measured** | `Repo.transaction` + `Repo.rollback` in `desativar_na_transacao` and `reativar_na_transacao` (reading); **no test injects a failure of the second step** — exactly the test that H3 has and this one does not |
| FR-026 `disabled_by_mistake` marks the episode, stops counting, stays visible | functional | yes | `:324` *"o equívoco é dito, e para de contar como desligamento"*; `resumir/1` excludes mistakes from `desligamentos` |
| FR-026 `investigation_closed_no_compromise` **only** against `suspected_compromise`, refused by the domain | functional | yes | `:340`; `account_disablement.ex:155` `abertura_exigida_pela_reativacao/1` |
| FR-027 two vocabularies, two columns (`Account` · `Sign-in credential`) | functional | yes | `:197` |
| FR-027 the two temporary ones distinguished **in words** | functional | yes | `:208` asserts `temporary · from a reset`; `:221` refutes `from creation` on the row; `password_source`/`password_set_by_user_id` in the migration |
| FR-027 unrecorded provenance stated as `temporary_source_not_recorded` | functional | **no executed evidence** | `not recorded` in `index.ex` (2 occurrences); no test assertion found |
| FR-028 a refused action **stays on the screen**, inert, with the reason | functional | yes | `:268` (reset on the disabled account), `:288` (disabling oneself) |
| FR-028 a disabled account **not filtered out by omission** | functional | yes | `:197` renders `/accounts` with no filter and the disabled row appears; header *"disabled last, and never hidden"* in `index.ex` |
| FR-029 the procedure (three acts, does / does not) **on the screen** | functional | yes | `:448`; `what it does not do` ×3 in `index.ex` |
| FR-029 the *revoke* says it **does not remove access** | functional | yes | `:867`, `:1492`, `:448` |

**Derived phase**: **`sro.not_accepted_deliverable`** — due to **incomplete evaluation**, not to
wrong behavior: **the five points that D06 refused are closed with executed evidence**
(four NO → yes; one without evidence → yes with a caveat), the prototype exists and the four decisions
are recorded. What prevents acceptance today are **three clauses of the FRs without a test**
(missing vocabulary refuses; note-absence sentence; `temporary_source_not_recorded`), **the
transaction invariant not measured** (no injected-failure test), **QA's item-by-item check
not found**, and `rule01` open until the retroactive backlog. The review gap weighs
according to the reading the role chooses (see header).
**Task phase**: `sro.non_successfully_performed_scrum_development_task` — and **there is no intended
task** to link it to (no issue, no `tasks.md`): the phase belongs to the work, and the work has no
record of intention.
**What closes it**: four tests (missing knowledge base → `{:error, :vocabulario_nao_declarado}`; *"no
note"* on the row; *"not recorded"* on the old credential; injected failure in the episode's `Repo.insert` →
`users.disabled_at` stays null), the item-by-item §3 check with capture, and the
inheritance line in the 030 `sprint-backlog.md`. None of them is design: it is proof.
**Destination**: it enters sprint 030 as inheritance, a **new intended task** (never reopen #853),
linked to a user story that the 045 still needs to declare — "whoever administers disables and re-enables
accounts, and the record says who, when and why" has no `US` in the spec.

---

### H3 — Declaring a team inside another is ONE act, in one transaction {#h3--declarar-equipe-dentro-de-outra-é-um-ato-numa-transação}

**Produced by**: PR [#857](https://github.com/The-Band-Solution/theband/pull/857), merged
2026-09-11T14:52Z into `development` · **no issue** (`closingIssuesReferences: []`)
**Materializes**: 055/US3 — Team inside a team (P2), FR-008; and the invariant found on
2026-09-10 (the team was left **created and loose** when `compose_teams/4` failed after
`declare_structural_team/4`).
**Executed evidence**: `mix test test/the_band/ontology/seon/eo/team_composition_test.exs
test/the_band_web/live/subequipe_test.exs` (run together with those of H2) → **72 passed, EXIT=0**
(2026-09-14). One compilation warning at `subequipe_test.exs:81` (the `live/2` form pointed out by
the `Phoenix.LiveViewTest` documentation) — a warning, not a failure.

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| the two steps (create the team, compose it into the parent) happen **in one transaction** | non-functional | yes | `commands.ex:374` `declare_subteam/4`: `Repo.transaction(fn -> with {:ok, filha} <- declare_structural_team(...), {:ok, _} <- compose_teams(...) do filha else {:error, motivo} -> Repo.rollback(motivo) end end)`; `teams_live/show.ex:201-222` the `criar_subequipe` handler calls **only** `EO.declare_subteam/4` — the invariant lives in the domain, not in the caller |
| a test that **injects the failure of the second step** and proves that the first does not remain | non-functional | yes | `team_composition_test.exs:106` *"se a composição falha, a equipe NÃO fica criada e solta"*: parent with a nonexistent `id` (the `organization_id` is valid, so the first step passes and the second hits the `whole_team_id` FK); compares `length(EO.list_teams)` before/after and refutes the name `"Squad Órfã"`. **Run: passes** |
| the failure is a **refusal**, not a crash | functional | yes | `:91` *"a falha é RECUSA, e não queda"* — `{:error, motivo}` with `is_binary(motivo)`; before the `foreign_key_constraint/2` it raised `Ecto.ConstraintError` |
| the eight unhappy paths refuse and **none raises** | functional | yes | `:146-:210` — iterated table + `:210` *"NENHUM dos oito caminhos levanta"*; `:185` nonexistent author, `:192` nonexistent organization, `:199` parent with no organization |
| the size limit arrives **interpolated**, not as `%{count}` | functional | yes | `:172` |
| the sub-team **inherits the organization** of the parent; the screen names the created team | functional | yes | `:72`; `subequipe_test.exs:48`, `:155` |
| through the screen, the refusal **creates nothing** and the happy path continues in the same view | functional | yes | `subequipe_test.exs:104` (table of refusals), `:119` *"a recusa NÃO cria nada"*, `:132` |
| the name is trimmed, and a duplicate under the same normalization is refused | functional | yes | `subequipe_test.exs:60`; `team_composition_test.exs:251` *"a mesma composição duas vezes é recusada"* |
| without scope, it does not declare | functional | yes | `subequipe_test.exs:193` |

**Derived phase**: **`sro.accepted_deliverable`** — all criteria conform, with evidence
executed in this session. The request's two questions have a direct answer: **yes**, there is a
`Repo.transaction` covering the two steps (and `Repo.rollback` in the `else`); **yes**, there is a test that
injects the failure of the second step and proves that the first does not remain, and it passes.
**Task phase**: `sro.successfully_performed_scrum_development_task` — no intended task
recorded (no issue); the phase belongs to the work.
**Conditions outside the criteria** (see header): review never requested and not recorded;
`rule01` closes with the inheritance line in the 030 `sprint-backlog.md`.

---

### H2 — FR-003 of the 055 gets a screen: linking a person to a team, with the verdict before the button {#h2--fr-003-da-055-ganha-tela-vincular-pessoa-a-equipe-com-o-veredito-antes-do-botão}

**Produced by**: PR [#863](https://github.com/The-Band-Solution/theband/pull/863), merged
2026-09-12T19:25Z into `development` · **no issue** (`closingIssuesReferences: []`). The user story
055/US2 ([#703](https://github.com/The-Band-Solution/theband/issues/703)) was **closed on
2026-09-02**, ten days before FR-003 had a screen.
**Materializes**: 055/US2 — *The person joins, leaves, and what they did is still there* (P1), through FR-003
(MUST clause + amendment of 2026-09-06: *"linking from scratch still exists for whoever the source
does not show"*), scenarios AC1 and AC5. AC2–AC4 (departure, mistake, new period) belong to FR-004/006
and are not the object of this deliverable.
**Prototype**: `specs/055-equipes-declaradas/prototipo/` — `PROMPT.md` (§3 is *"QA's yardstick"*),
`README.md`, `team-declared-link.html`; artifact
`https://claude.ai/code/artifact/9645056b-9f3d-4a8a-88bf-81c09fac15d8`. The three files entered
**in #863 itself**, together with the code; PR [#915](https://github.com/The-Band-Solution/theband/pull/915)
(opened 2026-09-13, branch `design/055-vinculo-declarado-prototipo`) brings **the same three
files with content identical** to that of `development` (`git diff --stat origin/development
origin/design/055-vinculo-declarado-prototipo -- specs/055-equipes-declaradas/prototipo/` empty) —
it is a republication of something already merged, not a new prototype.
**What the record says about the approval**: the `README.md` — in both copies — declares
**`Aprovação: aguardando a pessoa mantenedora — três perguntas abertas, duas delas mudam o que a
tela desenha`** ("Approval: awaiting the maintainer — three open questions, two of which change what the
screen draws") (P1 recorded × derived source; P3 collection over a declared team membership). None of the
three has *Decided*. `vinculo_possivel.ex` states in its `@moduledoc` *"prototype approved on
2026-09-11"*. **The two statements cannot both be true**; I record it as it is.
**Record of the prototype in the backlog**: `grep -rl team-declared-link docs/` **empty** — no item
in `docs/backlog/` cites the artifact or the `PROMPT.md`.
**Divergence from the request for this evaluation**: the request says *"role and date optional"*; FR-003
says *"with role and start date"* and decision 3 of the prototype fixes **role required, date
optional**. I evaluate against the spec and the prototype.
**Executed evidence**: `mix test test/the_band/ontology/seon/eo/vinculo_possivel_test.exs
test/the_band_web/live/vincular_pessoa_test.exs test/the_band/ontology/seon/eo/team_membership_test.exs`
(together with those of H3) → **72 passed, EXIT=0** (2026-09-14).

| Criterion | Type | Conforms | Evidence |
|---|---|---|---|
| FR-003 — whoever administers links a person to a team, **with a role** | functional | yes | `vincular_pessoa_test.exs:234` *"declarar cria o vínculo, com papel e sem data"*; `:205` role required; `:265` without a role refuses |
| FR-003 — **with a start date** (optional; empty stays **null**, never today) | functional | yes | `:218`, `:253` keeps `~D[2026-01-15]`; `team_membership_test.exs:43` *"data em branco fica NULA"*; `commands.ex` change 2 of the README applied |
| FR-003 — the team membership **keeps who declared it** | functional | **not measured** | `declare_team_membership/5` writes `declared_by_user_id: actor_id` (`commands.ex:69+28`, reading); `team_membership.ex:147` validates the author/instant pair. **No test asserts `declared_by_user_id == ator`** — `:234` asserts only `papel_declarado?` (role not null) |
| FR-003 amendment — linking **from scratch** exists for whoever the source does not show | functional | yes | verdict 6: `vinculo_possivel_test.exs:135`, `vincular_pessoa_test.exs:183` *"é o caso da FR-003"* |
| AC1 — the team membership takes effect from the date, with whoever declared it | functional | partial | date: yes (`:253`); author: **not measured** (row above) |
| AC5 — already linked and in force → **refused with the reason** | functional | yes | verdict 2: `vinculo_possivel_test.exs:75`, `vincular_pessoa_test.exs:129` *"RECUSA inerte, e oferece declarar o papel"* (amended FR-007 / FR-014) |
| the **six verdicts** in the domain, in the right order, in two queries | functional | yes | `vinculo_possivel_test.exs:70-:135` (1–6), `:142` order (member **and** vanished → refusal), `:152` eight results = two queries, `:164` an empty list does not go to the database |
| the six verdicts **on the screen, before the button** (§3.5) | functional | **partial** | the screen tests 1 (`:119`), 2 (`:129`), 3 (`:157`), 6 (`:183`). **Verdicts 4 (left) and 5 (mistake) without a rendering test** — the texts `a new link` and `the mistake stays` exist in `show.ex` (1 occurrence each), but there is no assertion exercising them |
| §3.1 — section **`Link a person to this team`** between *Roles* and *Members*, closed at rest | screen | yes | `:71`, `:84`; `show.ex` 1 occurrence of the title |
| §3.1 item 2 — label `N of M collected people are linkable here`, N and M from the query | screen | **no** | `linkable here`: **0 occurrences** in `show.ex`. The measures that the README requires *before the code* (`structure.people_linkable_to_team.count`, `structure.memberships_declared_from_zero.count`, `structure.people_without_any_team.count`) **do not exist** in `priv/knowledge_base/` (grep empty) — principle IV |
| §3.2 — scope written, **does not create a person**, an empty search is not an error | screen | yes | `:93`, `:107`; `No collected person matches` in `show.ex` |
| §3.3 — form: chosen person, `choose a role…`, `member since` empty (`empty = start unknown`), `Declare the link`, *what this creates* / *What it does not do* | screen | yes | `:205`, `:218`, `:225`; texts present in `show.ex` (`step 2`, `choose a role`, `empty = start unknown`, `Declare the link`, `what this creates`, `What it does not do`) |
| §3.4 — member list with the **corrected `link` column** (`no source shows this link`, `declared in the same act`, order `person · role · link · since · squads`) | screen | **no** | `no source shows this link`: 0; `declared in the same act`: 0 in `show.ex`. The test's `describe "a seção (§3.4)"` refers to the new section, not to the member list. **Items 19–21 of the yardstick not implemented** |
| §3.7 — refuses a **start date in the future** | functional | **no** | `declare_team_membership/5` (`commands.ex:69-115`) **does not have** `nao_esta_no_futuro/1`; the check exists only for the departure (`:161`) |
| §3.7 — a person from another organization → `not found`, never "no permission" | functional | no evidence | `not found` has 3 occurrences in `show.ex`, none asserted in the H2 tests |
| domain refusal **in the screen's language** (the product speaks English) | functional | **no** | `commands.ex` returns `{:error, "esta pessoa já tem vínculo vigente nesta equipe, com início desconhecido"}`; the `declarar_vinculo` handler (`show.ex:596`) does `{:error, motivo} when is_binary(motivo) -> put_flash(socket, :error, motivo)` — **it prints the raw domain string**. The test `:265` itself asserts the word **`"papel"`** in the HTML. It is change 4 that the README listed as required, and it did not happen |
| the screen **does not raise** on a team membership in force with a null `started_at` (87 of 90 in the database) | functional | yes | `vinculo_possivel_test.exs:75`; `commands.ex:40` separate `%TeamMembership{started_at: nil}` clause |

**Derived phase**: **`sro.not_accepted_deliverable`** — four criteria **non-conforming due to
behavior or absence** (§3.1 item 2 and undeclared measures; §3.4 `link` column; §3.7 future
date; refusal in Portuguese printed raw), two **without evidence** (author of the team membership not asserted;
`not found` for another organization), two **partial** (verdicts 4 and 5 without a screen test; AC1 on the
author). And, before any criterion: **the prototype that is the yardstick declares its own approval
as pending**, with two open questions that change the design — the screen was implemented over
a yardstick that the record says is not closed, and no backlog item records artifact and
prompt.
**Task phase**: `sro.non_successfully_performed_scrum_development_task` — no intended
task recorded.
**What closes it, and the order**: (1) the maintainer answers P1, P2 and P3, Design marks
*Decided* and republishes **at the same address** — if P1 is A, `eo.team_membership` gains `origin` and
the three measures get YAML before the §3.1/§3.4 yardstick can be met; (2) the backlog item
cites artifact, `PROMPT.md` and `README.md`; (3) §3.4 and §3.7 implemented; (4) the domain refusals
go through the catalog (`dgettext`) before the flash; (5) tests: `declared_by_user_id`, verdicts 4 and
5 on the screen, `not found` from another organization, future date refused. **Only then** QA's
item-by-item check.
**Destination**: it enters sprint 030 as inheritance, a **new intended task** linked to 055/US2 — and
issue #703, closed on 2026-09-02 with FR-003 without a screen, **is not reopened**; the record that the
US was closed before it was whole remains.

---

### Summary {#resumo_2}

| | Count |
|---|---:|
| Deliverables evaluated | 3 |
| Accepted | **1** — H3 |
| Not accepted | **2** — H1 (incomplete evaluation: 4 clauses without a test, QA item-by-item missing), H2 (4 non-conforming, yardstick not approved) |
| Tasks successfully performed | 1 (no intended task recorded) |
| Tasks not successfully performed | 2 (same) |

| Deliverable | PR | Proposed phase | Dominant cause |
|---|---|---|---|
| H1 — D06 re-evaluated (disabled account) | #853 | `sro.not_accepted_deliverable` | **the 5 points of the original refusal are closed with evidence**; there remain 3 clauses of FR-025/027 without a test, the transaction without an injected-failure test, and QA's check not found |
| H2 — FR-003 with a screen (link a person) | #863 | `sro.not_accepted_deliverable` | yardstick (§3.4, §3.7, §3.1 item 2) not met; domain refusal in Portuguese on the screen; prototype with approval **pending** in its own README; measures not declared |
| H3 — sub-team in one transaction | #857 | `sro.accepted_deliverable` | `Repo.transaction` + injected-failure test that passes; 8 unhappy paths without exception |

**What the three have in common, and is not about the criteria**: review never requested and not recorded;
no issue closed; no item in a sprint backlog (`rule01`) — the retroactive record of 030
exists to close the third; the first two are residue that cannot be recovered on a merged PR,
and the exception decision still belongs to the role.

### Criteria changed during the sprint {#critérios-alterados-durante-o-sprint_1}

| Criterion | User story | Changed on | What changed | Why |
|---|---|---|---|---|
| FR-025 to FR-029 (045) | no US of the 045 carries them | 2026-09-10, in #853 | **added** to the spec, formalizing the criteria of `docs/backlog/conta-desativada.md` (2026-09-09) and the prototype's decisions | D06's refusal asked for exactly this; the origin predates the code, the normative text does not |
| FR-003 (055) | US2 | 2026-09-06 (amendment) | linking from scratch is left for whoever the source does not show; the observed one is born without a role | predates #863; evaluated in the amended version |

### Criteria without evidence {#critérios-sem-evidência_1}

| Criterion | Deliverable | What is missing |
|---|---|---|
| with no declared vocabulary, disabling refuses | H1 | test with the knowledge base missing → `{:error, :vocabulario_nao_declarado}` |
| an omitted note writes the absence sentence | H1 | assertion of *"no note"* on the row |
| `temporary_source_not_recorded` stated as such | H1 | assertion on the credential that predates the column |
| `disabled_at` and the episode in the same transaction | H1 | a test that injects a failure into the episode's `Repo.insert` and proves `disabled_at` null |
| roster, **measures** and history do not change | H1 | a computed measure of the person compared before/after (roster, link, scopes and password already are) |
| QA's item-by-item check of §3 with capture | H1, H2 | QA's record |
| the team membership keeps who declared it | H2 | assertion `declared_by_user_id == ator.id` |
| verdicts 4 and 5 on the screen | H2 | rendering test |
| another organization → `not found` | H2 | test |
| does not authenticate by token | H1 | the token (spec 061) — **not evaluable**, and does not count as conforming |

### Not measured, and why {#não-medido-e-por-quê}

- `mix gates` and the full suite: not run here by instruction; CI run 34779226200 over
  `0ccf02b` is `success` and is the evidence for the gates.
- Capture of the real screen (`/accounts`, `/teams/:id?tab=structure`): not done — the evaluation used
  rendering in tests and presence of texts; the capture next to the yardstick is what QA delivers.

---

# Part C — what cuts across both parts {#parte-c--o-que-atravessa-as-duas-partes}

## #860, which was not evaluated {#o-860-que-não-foi-avaliado}

PR [#860](https://github.com/The-Band-Solution/theband/pull/860) (2026-09-12) delivered the
*Flow per person* tab — US10–US12 of the extension `spec-graficos-por-membro.md` (FR-085 to FR-112). The
060's `tasks.md` declared them **without a task**, "dependent on US9 and on a prototype that does not
exist yet"; the prototype was approved on 2026-09-08 and the screen came in outside the plan. The requirements are
being transcribed from the prototype **now**, in PR #913. **Not classifiable by criteria in this
record**: the US exist in the extension, but were not in any backlog — by the axiom
`sro.rule01`, it is scope that came in without going through planning. Recorded, neither accepted nor
refused; the evaluation is its own, after #913.

## What happens to the issues, after the confirmation {#o-que-acontece-com-as-issues-depois-da-confirmação}

**There are no issues.** The 060 has no epic, user story or task on GitHub; #853, #857 and #863 did not
close any issue. **Proposed**, and nothing executed until the confirmation: retroactive creation
of the 060's issues (6 US + 29 tasks) and of the three inherited ones, like the 052 in sprint 026 — each one
saying that it was born after the work, closed in the same act when the phase is `accepted`, open
with a destination when it is not. The retroactive creation **does not fix** what the gap cost:
`flow.wip.count` undercounted the sprint while it was running.

## Destination of the user stories and of the deliverables {#destino-das-user-stories-e-dos-entregáveis}

| Deliverable | Proposed phase | Destination |
|---|---|---|
| 060/US1 (D1) | not accepted — test missing | **next sprint, first**: `abas_da_equipe_test`, `estrutura_membros_test`, `estrutura_permissao_test`; FR-004 "composed of K" |
| 060/US2 (D4) | not accepted — AC2 not measured | **decision by the role** at confirmation |
| 060/US3 (D2) | not accepted — SC-013 not measured | **time it** at confirmation |
| 060/US4 (D3) | **accepted** | done; locate the AC5 assertion or record the gap |
| 060/US5 (D5) | not accepted — SC-005/FR-081 not measured | **measure** with two teams + *Roles* section |
| 060/US9 (D6) | not accepted — defect | **new task via Design**: the *Squads at a glance* card conforming to the prototype; SC-009; FR-064 |
| 045 · D06 redone (H1) | not accepted — 4 clauses without a test | **new task**: the four tests, the §3 check with capture, and the US that the 045 needs to declare |
| 055 · FR-003 with a screen (H2) | not accepted — yardstick pending, §3 broken | **mandatory order** (see H2): decisions P1–P3 → republication → measures → §3.4/§3.7 → refusals through the catalog → tests → QA |
| 055 · sub-team in one transaction (H3) | **accepted** | done |
| #860 · *Flow per person* tab | not evaluated | its own record after #913 |

## The review, and the decision this record does not take {#a-revisão-e-a-decisão-que-este-registro-não-toma}

Ten PRs make up the sprint (#816–#821, #853, #857, #860, #863). **None has a recorded
review**; #853, #857, #860 and #863 **did not even request one**. The skill says that a review never requested
prevents acceptance; v0.7.0 and v0.8.0 treated the same gap as a release exception decided
by the role. Both readings are written down; **the choice belongs to the person allocated to the role**, and it applies
to both parts of this record.
