# Research — PR 1 da tela da equipe: o que existe, o que falta, e onde

**Data**: 2026-09-07 · **Árvore**: `feat/060-tela-da-equipe` sobre `feat/vinculo-observado`
(o código da ADR 0008 já está aqui: `commands.ex:632-769`, migração `20260906230000`).

Cada item diz **arquivo:linha**, o que faz hoje, e o que a PR 1 precisa. "Reusa" = sem mudança;
"Emenda" = função existente muda; "Falta" = não existe.

## R1 — A tela de hoje (`lib/the_band_web/live/teams_live/show.ex`, 2 092 linhas)

| Trecho | Linhas | O que é | Destino na PR 1 |
|---|---|---|---|
| `mount/3` | 40-59 | acha a equipe em `EO.list_teams/1`; 404 de outro tenant | reusa |
| `@tabelas` | 37 | `members` ordenável por `name, platform_access_level, observed_at, last_observed_at` | vira `[:name]` — as outras três são da evidência |
| `handle_params/3` | 61-66 | `Tabela.aplicar` + `load/1` | ganha a leitura de `?tab=` e o carregamento por aba |
| `associar_projeto` / `desassociar_projeto` | 73-88, 152-161 | escrita; autoriza por `%{role: "admin"}` no pattern | movem para a Estrutura; permissão vira `pode_gerir_estrutura/3` (FR-052) |
| `criar_subequipe` / `descompor` | 93-148 | `Tenants.pode_declarar_estrutura(…, :organization, org_id)` em `:98` e `:129` | mesma tela, aba Estrutura; veredito trocado (D6) |
| `promover` | 163-181 | `EO.promote_evidence/5` por **evidência**; **sem** permissão | reescrito: por vínculo, `EO.declare_role/6`, com veredito (FR-006, FR-014) |
| `escolhas_de/1`, `frase_do_resultado/2` | 187-251 | "N recorded · M skipped · K refused" | reusa a forma; as chaves passam a ser `membership_id` |
| `load/1` | 266-292 | `list_team_members` (evidência), `count_team_members`, `count_memberships_pending_role` | as duas primeiras saem; a terceira vai para o cabeçalho FR-004 |
| `data_ou_nil/1` | 296-304 | campo vazio = nulo, nunca hoje | reusa (FR-016, FR-023) |
| `carregar_promocao/1` | 310-331 | papéis da org, `team_parts`, `team_wholes`, `pending_evidence`, `membership_disagreements` | `pending_evidence` sai; o resto migra para `carregar_estrutura/1` |
| `carregar_linhas/2`, `carregar_detalhe/1` | 345-407 | a composta e o detalhe da 057 | Dashboard, intocado |
| `carregar_competencias/1` | 760-778 | `Profiles.*`; ids de membros via `list_team_members` **por evidência** | Dashboard, intocado; ver R12 |
| `carregar_projetos/1` | 783-794 | ligados + disponíveis | disponíveis só na Estrutura; ligados nas duas |
| `carregar_espera_por_revisao/1` | 860-955 | composição da medida; veredito `pode_ver_equipe` em `:904-905` | Dashboard, intocado |
| render — cabeçalho | 1099-1104 | "N members · M with no organisational role" (N = evidência) | FR-004: N vigentes (`team_size`), M sem papel, "composed of K", origem |
| — *Structure* (Part of / Contains) | 1191-1232 | | Estrutura, seção *Squads* |
| — `data_table id="members"` | 1234-1281 | evidência: nome, **access at the platform**, pending/assigned, observed at | **substituída** pelo roster (FR-008) |
| — discordância | 1294-1359 | as duas afirmações (055 FR-012) | Estrutura, markup mantido |
| — promoção em lote `#promover` | 1366-1447 | `papel[<evidence_id>]`, `started_at[<id>]` **com hoje** (`:1417`) | lote fica (FR-014), por vínculo, **sem** hoje (FR-016) |
| — alerta "papel pendente" | 1449-1461 | texto em pt+en misturado | sai; a legenda das marcas ocupa o lugar |
| — Projects | 1464-1493 | leitura e escrita juntas | leitura no Dashboard; escrita em *Where this team sits* |
| — antipadrões, espera, pipeline, skills | 1500-2088 | 058/029 | Dashboard, intocados |

## R2 — Comandos da EO (`commands.ex`)

| Função | Linhas | Hoje | PR 1 |
|---|---|---|---|
| `declare_team_membership/5` | 62-91 | **`started_at` default `DateTime.utc_now()`** (`:70`) — contraria FR-016 | não é chamada pela tela; emenda anotada para a 055 |
| `record_team_departure/5` | 103-123 | `_actor_id` **ignorado** (`:110`); grava só `ended_at`; `vigente/3` = `Repo.one` | **Emenda**: grava `ended_by_user_id` e `end_declared_at`; `update_all` sobre os vigentes do par |
| `record_team_membership_mistake/5` | 148-174 | trio do equívoco; razão obrigatória; `Repo.one` | **Emenda**: `update_all` sobre o par (D4). Já vale para observado e declarado |
| `observar_vinculo/2` | 632-664 | cria o observado quando não há vigente nem declaração | **Emenda** só na guarda (R7) |
| `existe_declaracao?/3` | 683-691 | autor **ou** papel **ou** `invalidated_at` | cobre o equívoco ✅; **não cobre a saída declarada** — **falta** `ended_by_user_id` + a noção de retorno |
| `encerrar_vinculos_observados/3` | 749-769 | ausência na origem encerra o puramente observado | reusa; é a origem de "constatado pela coleta" (FR-022) |
| `create_role/4`, `hide_role/3`, `rename_role/4` | 1092-1230 | por organização; recusas nomeadas | **Reusa** (FR-030, FR-032, FR-033) |
| `allocate/2` | 1278-1345 | completa o observado vigente ou insere declaração | **Reusa** dentro de `declare_role/6` |
| `promote_evidence/5` | 1376-1403 | por evidência; `resolver_papel/3` materializa catálogo | fica para compat; `resolver_papel/3` é **reaproveitado** |
| `end_allocation/3` | 1451-1467 | `update_all` de `ended_at`; **sem autor** | **Emenda**: `end_allocation/4` com `actor_id` |
| **Falta** `declare_role/6` | — | — | resolve o papel, chama `allocate/2`, grava `declared_at` |
| **Falta** `change_role/5` | — | — | transação: `end_allocation/4` + `allocate/2` do novo (FR-017) |

## R3 — Consultas da EO (`queries.ex`)

| Função | Linhas | Hoje | PR 1 |
|---|---|---|---|
| `list_team_members/3`, `count_team_members/3` | 109-161 | **por evidência**; devolve `platform_access_level` | deixam de ser chamadas pela tela (FR-008) |
| `count_team_members_at/3`, `team_members_at/3`, `vigente_em/2` | 182-225, 323-341 | vigência `[started_at, ended_at)` sem invalidado | **Reusa** — prova SC-001 |
| `membership_disagreements/2` | 390-440 | veredito agregado por pessoa | **Reusa** (FR-013). Não devolve o autor da saída — não tocado nesta PR |
| `count_memberships_pending_role/2` | 838-853 | vigentes sem papel | **Reusa** no cabeçalho |
| `person_active_teams/2` | 1020-1033 | equipes vigentes da pessoa | reusa em `pode_gerir_estrutura/3` |
| `list_organization_roles/2` + `RoleCatalog.compose/1` | 1242-1259 | catálogo + declarados; `origem` tupla | **Reusa** na seção *Roles* e no seletor |
| `team_size/2` | 1280-1293 | pessoas distintas vigentes | **Reusa** no cabeçalho |
| `team_parts/2`, `team_wholes/2` | 1301-1339 | composições vigentes | reusa |
| `count_memberships_of_role/2` | 1390-1398 | conta **vínculos** — o número da recusa de ocultar | reusa na recusa; **não** serve para FR-029 |
| `fetch_membership/2` | 1401-1410 | por id, com tenant | reusa em `change_role/5` |
| **Falta** `list_team_roster/3`, `count_team_roster/3` | — | — | pessoas distintas com vínculo nesta equipe **ou** nas partes vigentes |
| **Falta** `team_roster_totals/2` | — | — | `%{vigentes, sairam, equivocos}` por **pessoa** (FR-012) |
| **Falta** `role_holder_counts/3` | — | — | pessoas distintas vigentes nesta equipe e na organização (FR-029) |

## R4 — Quem vê, quem escreve (`access.ex`, `visibility.ex`)

- `pode_declarar_estrutura/4` (`access.ex:175-189`): admin **ou** escopo de **conta**. Chamadores:
  `show.ex:98,129`; delegate `tenants.ex:26`; teste `declarar_estrutura_test.exs`.
  **Substituída** (D6). Quem age por escopo perde a **escrita**; a leitura não muda.
- `pode_ver_equipe/3` (`access.ex:261-271`): admin; escopo `team`; escopo `organization`;
  **vínculo vigente**. São os quatro caminhos de FR-007 — **confirmado, sem emenda**.
- `EO.Visibility`: `pode_ver/3`, `grants_by_role/1`, `declare_grant/4`, `revoke_grant/4` (marca),
  `lidera_equipe_do_alvo?/3` — **é o molde** de `EO.StructureGrants.alcance/3`.
- `RoleVisibilityGrant` (`schemas/role_visibility_grant.ex:32-70`): campos e `unique_constraint`
  no índice parcial — **espelhar**.
- `/roles` (`roles_live/index.ex`): `conceder`/`revogar_concessao` (`:123-173`) só admin; coluna
  *sees* (`:439-483`). A PR 1 acrescenta a coluna *manages*. Rota em `live_session :admin`.

## R5 — Esquema do vínculo (`schemas/team_membership.ex`, migrações)

- Campos (`:52-79`): `organizational_role_id` **nulo = não declarado**; `started_at` nulo =
  desconhecido; `ended_at`; `declared_by_user_id`; trio `invalidated_*`. **Não há** `declared_at`,
  `ended_by_user_id` nem instante da saída.
- `validar_papel_da_declaracao/1` (`:115-122`): autor sem papel é recusado.
- Índices: `eo_team_memberships_vigente_index` (com papel, parcial); 
  `eo_team_memberships_observado_vigente_index` (sem papel, parcial). CHECK
  `eo_equivoco_do_vinculo_completo` — **modelo** para a CHECK da saída.

## R6 — "Declarado por X em D": de onde vem D

Não há coluna. `inserted_at` serve para o declarado do zero; para o observado completado o
instante é o `updated_at`, que o próximo `update` apaga. **Falta** `declared_at`; backfill
`= inserted_at where declared_by_user_id is not null`.

## R7 — A guarda da coleta e o retorno (FR-026, FR-027)

- `record_team_membership_evidence/2` (`:588-630`): a evidência existente é atualizada com
  `no_longer_observed_at: nil` (`:620-625`) — a informação de que **houve ausência** existe no
  registro carregado e se perde na escrita.
- Proposta: `observar_vinculo/3` recebe `retorno?` = `not is_nil(record.no_longer_observed_at)`.
  Sem retorno, qualquer declaração sobre o par bloqueia (autor, papel, equívoco, **saída
  declarada**); com retorno, nada bloqueia além do vigente. É a ADR 0008 item 5 estendida.
- **Alternativa** (não escolhida): comparar `ended_at` com `no_longer_observed_at` — mais fina,
  depende de duas tabelas concordarem em cadência. Pergunta aberta 3.

## R8 — Papéis: o que o seletor da linha precisa

- `valor_do_papel/1` e `papel_escolhido/1` (`show.ex:752-756`): `"catalogo:<conceito>"` /
  `"existente:<id>"` — **reusa**.
- `materialize_catalog_role/3` nasce dentro de `resolver_papel/3` — a tela nunca materializa antes.
- "＋ new role…" (FR-034): opção `value="novo"`; `phx-change` abre o formulário com
  `linha_de_retorno`; ao criar, `load` recarrega e reabre a linha com o papel selecionado.
- Código sugerido (FR-031): slug do nome, só sobrescreve enquanto não editado à mão.

## R9 — Testes existentes que mudam de lugar

| Arquivo | O que assertava | Mudança |
|---|---|---|
| `promocao_na_tela_test.exs` | `#promover` por evidência; "MAINTAINER"; data com hoje | **reescrito**: lote por vínculo em `?tab=structure`; `refute "MAINTAINER"`; data vazia |
| `duas_afirmacoes_test.exs` | as quatro cordas da discordância | abre `?tab=structure`; "without a declared role" → "not declared" |
| `subequipe_test.exs` | `criar_subequipe`/`descompor`; "no scope" | `?tab=structure`; a recusa nomeia *sem concessão* |
| `screens_test.exs:138-145` | **exige** "access at the platform" e "MAINTAINER" | inverte: `refute` na Estrutura (FR-008) |
| `tabela_em_todas_as_telas_test.exs:168` | ordenar `name` | `?tab=structure` |
| `equipe_competencias_test.exs:145-163` | `#associar-projeto` | `?tab=structure` |
| `equipe_composta_test.exs:212` | "Contains:" | `?tab=structure` |
| `clicar_leva_a_pagina_test.exs:86-100` | dois `href="/people/:id"` | `?tab=structure` |
| `teto_de_consultas_da_equipe_test.exs:92` | `@teto_do_detalhe 23` | baixa; nasce `@teto_da_estrutura` |
| `tenants/declarar_estrutura_test.exs` | escopo de conta declara estrutura | **substituído** por `gerir_estrutura_test.exs` |

## R10 — Componentes e convenções de tela

- `TheBandWeb.UI`: `evidence/1`, `absent/1`, `notice/1`. As marcas `left` e `mistake` **não
  existem** — nascem como classes locais com a razão escrita, ou dois `shape`s novos; decidir na
  T011 e registrar no commit.
- `TabelaLive.aplicar/3` e `query/4` com `extra` — carrega `tab:`.
- Datas: hoje imprime `DateTime` cru; o protótipo escreve "03 Mar 2026" →
  `Calendar.strftime(d, "%d %b %Y")`.
- Recusa de outro tenant: "not found", nunca "permission denied".

## R11 — Base de conhecimento: como um módulo novo entra

- `YamlLoader` carrega `**/*.yaml`; o validador exige que todo módulo **listado** em
  `ontology.yaml` tenha arquivo. Listar em `eo/ontology.yaml` `modules:` é o que o faz aparecer.
- Schema do módulo: exige `id, ontology, name, version, provenance`; conceito exige
  `id, name, definition(pt-BR), classification.ufo_category`.
- Modelo de "declaração adjacente": `spo/modules/activity_start_criterion.yaml`.

## R12 — Achados fora do escopo desta PR (anotados, não corrigidos)

1. `carregar_competencias/1` (`show.ex:766-770`) deriva os ids dos membros da **evidência** —
   o espírito da ADR 0008 alcança isto. PR 2.
2. `declare_team_membership/5` grava `started_at = agora` (`commands.ex:70`) — contraria 055
   FR-013c/060 FR-016. Sem chamador de tela; emenda para a 055.
3. `mount/3` carrega **todas** as equipes do tenant para achar uma (`show.ex:43`) —
   `fetch_team/2` existe. Fica para quando a tela for dividida (D1).
4. `membership_disagreements/2` não devolve quem declarou a saída; o protótipo mostra. PR 2.
