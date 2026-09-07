# Tasks: A tela da equipe — PR 1, os membros (US1–US5 e as duas abas)

**Input**: `plan.md`, `research.md`, `data-model.md`, `spec.md` (2026-09-07), `prototipo/`.

**Testes**: cada tarefa carrega o seu, no campo `Teste`. Nenhuma tarefa está feita sem a asserção
nomeada verde **e** sem ter sido lida (princípio XI).

**Convenções**: `[P]` = paralelizável; `[USn]` = a user story; **FR/SC** citados na descrição;
**Protótipo** cita o trecho de `prototipo/team-dashboard-structure.html` que a tarefa reproduz. A
interface fala inglês.

**Ordem**: fatias verticais. A primeira tarefa que chega à tela é a **T010**; antes dela só o que a
tela precisa para decidir quem vê botão.

---

## Fase 0 — Contratos e base de conhecimento (princípios IV e VI)

- [ ] **T001 [P]** Escrever os contratos antes da primeira função pública
  - `contracts/estrutura-da-equipe.md`: assinatura, retornos de sucesso e de erro, e o que **não**
    expõe, de `EO.list_team_roster/3`, `count_team_roster/3`, `team_roster_totals/2`,
    `role_holder_counts/3`, `declare_role/6`, `change_role/5`, `record_team_departure/5`
    (emendada), `record_team_membership_mistake/5` (emendada), `end_allocation/4`.
  - `contracts/gerir-estrutura.md`: `EO.declare_structure_grant/4`, `revoke_structure_grant/4`,
    `structure_grants_by_role/1`, `Tenants.pode_gerir_estrutura/3` com os seis motivos.
  - Declarar que **nenhuma** devolve `Ecto.Query` e que **nenhuma** apaga linha (SC-012).
  - **Teste**: revisão de leitura contra `data-model.md` §2 e §4; nenhuma função pública é escrita
    adiante sem constar aqui.

- [ ] **T002** Declarar as duas concessões na base — `data-model.md` §3.1
  - Criar `priv/knowledge_base/ontology/seon/eo/modules/role_grants.yaml`; acrescentar
    `role_grants` a `modules:` em `eo/ontology.yaml`. FR-080; SC-015; princípio IV.
  - **Feita quando**: `mix knowledge.validate` e `mix knowledge.graph` verdes, **lidos do log**; o
    grafo não ganha aresta nova.
  - **Teste**: novo `test/the_band/ontology/role_grants_yaml_test.exs` — o módulo carrega com
    exatamente os dois conceitos e `scope` como `enum [team, organization]`.

- [ ] **T003 [P]** Emendar a regra da evidência para a v3 — `data-model.md` §3.2
  - FR-026, FR-027; a ADR 0008 item 4 ganha a linha apontando para esta versão (T025).
  - **Teste**: `mix knowledge.validate` com `EXIT=0` lido; o comportamento é provado na T014.

---

## Fase 1 — A concessão *gerir estrutura da equipe* e o veredito (FR-006, FR-080–082)

- [ ] **T004** A tabela e o schema da concessão de gestão
  - Migração `eo_role_structure_management_grants` como em `data-model.md` §2, com o índice
    parcial; schema `schemas/role_structure_management_grant.ex` espelhando
    `role_visibility_grant.ex:32-70`. `change` reversível.
  - **Feita quando**: a segunda concessão vigente para o mesmo (papel, alcance) é recusada pelo
    **banco**; revogar preenche `revoked_at` e a linha continua; migrar e reverter volta ao início.
  - **Teste**: `test/the_band/ontology/seon/eo/concessao_de_gestao_test.exs`.

- [ ] **T005** `EO.StructureGrants` — declarar, revogar, listar e alcançar
  - `structure_grants.ex` espelhando `visibility.ex`: `declare_grant/4`, `revoke_grant/4` (marca),
    `grants_by_role/1`, `alcance(tenant, person_id, team_id)` →
    `{:ok, :gestor_da_equipe | :gestor_da_organizacao} | {:nao, :vinculo_encerrado | :sem_concessao}`.
    `defdelegate`s em `eo.ex`. FR-080, FR-082.
  - **Feita quando**: papel chamado "Tech Lead" **sem** concessão não alcança ninguém; `team`
    alcança só a equipe do vínculo vigente; `organization` alcança outra equipe da mesma
    organização e **não** de outra; vínculo encerrado devolve `:vinculo_encerrado`.
  - **Teste**: um `describe` por linha acima, no molde de `visibilidade_test.exs:131-303`; **dois
    tenants**.

- [ ] **T006** `pode_gerir_estrutura/3` substitui `pode_declarar_estrutura/4`
  - Criar em `access.ex`; **remover** `pode_declarar_estrutura/4` e o delegate em `tenants.ex:26`;
    trocar os dois chamadores (`show.ex:98`, `:129`). Apagar `declarar_estrutura_test.exs` e
    escrever `gerir_estrutura_test.exs`. FR-006, FR-082; plano D6. Registrar no PR o que muda para
    quem age hoje por escopo `organization` de conta, com a medida no banco de desenvolvimento.
  - **Feita quando**: `grep -rn pode_declarar_estrutura lib test` devolve zero.
  - **Teste**: os seis motivos, um teste cada; o "escopo organization de conta NÃO gere" prova a
    substituição.

- [ ] **T007** `/roles` concede e revoga *manages team structure*
  - Coluna *manages* ao lado de *sees*, mesmo formulário, eventos `conceder_gestao`/`revogar_gestao`,
    só admin; `load/1` ganha `structure_grants_by_role` (uma consulta, nunca por linha). FR-081.
  - **Teste**: `papel_declarado_test.exs` — novo `describe`, espelhando `:235-285`.

**Checkpoint**: a concessão existe, é declarável, e o veredito responde com motivo. `/teams/:id`
ainda não mudou.

---

## Fase 2 — US1: as duas abas e a lista por vínculo (P1) — primeira fatia com tela

- [ ] **T008** A saída declarada e a data da declaração no esquema — `data-model.md` §1
  - Migração com `declared_at`, `ended_by_user_id`, `end_declared_at`, os dois CHECKs e o backfill;
    `down` explícito. Schema: os três campos no `cast` e a validação "autor e instante andam
    juntos". FR-021, FR-022, FR-010.
  - **Feita quando**: gravar `ended_by_user_id` sem `end_declared_at` é recusado pelo **banco**.
  - **Teste**: `saida_declarada_test.exs` — o teste da **violação** via `Repo.update_all`.

- [ ] **T009 [P]** As consultas do roster — `data-model.md` §4.1–4.2
  - `list_team_roster/3` em **duas** consultas (pessoas distintas; vínculos das pessoas da página),
    `count_team_roster/3`, `team_roster_totals/2`. FR-008 a FR-012. Nenhuma consulta por linha.
  - **Feita quando**: pessoa com vínculo direto **e** em subequipe vem **uma** vez com dois
    vínculos; encerrado pela coleta lê `{:coleta, quando}`; com autor lê `{:declarado, …}`;
    invalidado tem `situacao: :equivoco`; parte com composição **encerrada** não entra; busca por
    login acha; tenant B não vê nada de A.
  - **Teste**: `roster_test.exs`, com `ContadorDeConsultas` provando que 1 e 11 pessoas custam o
    **mesmo** número de consultas.

- [ ] **T010 [US1]** As duas abas de `/teams/:id`, com a aba na URL
  - `handle_params/3` lê `params["tab"]` (inválida → Dashboard **e** flash); `load/1` vira
    `carregar_cabecalho/1` + `carregar_dashboard/1` | `carregar_estrutura/1`; `caminho/3` passa
    `tab:` no `extra`. `<nav role="tablist">` com dois `<.link patch>`. Cabeçalho FR-004. Saem do
    Dashboard as seis seções de estrutura. Os eventos de escrita só existem quando a aba é
    `structure`. FR-001 a FR-004; SC-007; plano D1, D2.
  - **Teste**: novo `abas_da_equipe_test.exs` (cinco casos, abrindo a URL direta e `assert_patched`);
    **migrar** os testes que só mudam de aba (`research.md` R9).

- [ ] **T011 [US1]** A seção *Members* por vínculo, a legenda, a discordância e *Where this team sits*
  - Componentes funcionais: legenda das quatro marcas; `data_table id="members"` com person (nome
    **e** login clicáveis) · role (`not declared` em destaque) · link (marca + autor/data, com a
    frase de FR-022 para o fim constatado) · since (`unknown` / `start → end` / `never`) · squads
    (chips + `direct`) · ações (só com `{:ok, _}`); linha encerrada e invalidada com o texto do
    protótipo; **nenhuma** ocorrência de `MAINTAINER`/"access at the platform" (FR-008, SC-004).
    Mover a discordância; *Where this team sits* em leitura. Datas com `%d %b %Y`. FR-008 a FR-013.
  - **Teste**: novo `estrutura_membros_test.exs` (marcas em **texto**, nunca por classe);
    `refute html =~ "MAINTAINER"`; reescrever `screens_test.exs:138-145`.

- [ ] **T012 [US1]** Quem não gere lê tudo e não vê ação — e o evento é recusado com motivo
  - `defp com_gestao(socket, fun)` re-pergunta o veredito em **todo** evento de escrita e traduz os
    três `:nao`; os cinco eventos existentes passam por ele — `promover` **hoje não confere nada**.
    Botões só renderizam com `{:ok, _}`. FR-006, FR-082; SC-011.
  - **Teste**: novo `estrutura_permissao_test.exs` — os três motivos por evento.

- [ ] **T013 [US1]** O teto de consultas das duas abas, medido
  - Medir o Dashboard e **baixar** `@teto_do_detalhe`; criar `@teto_da_estrutura` medido, com o
    teste de **constância** (1 × 11 pessoas; 1 × 3 subequipes). Sem folga.
  - **Teste**: o próprio arquivo, com os números lidos do log.

**Checkpoint US1**: quem administra vê cada pessoa uma vez, com origem, papel, início e subequipes;
quem não gere lê e não age.

---

## Fase 3 — US3: a pessoa saiu (P1)

- [ ] **T014 [US3]** A saída grava quem e quando, alcança os dois papéis, e a coleta não recria
  - `record_team_departure/5`: usar `actor_id`; `update_all` sobre **todos** os vigentes do par;
    recusar futuro; `{:error, …}` nomeado quando zero. `end_allocation/3` → `/4` com `actor_id`
    (oito arquivos de teste ajustados). Guarda: `existe_declaracao?/3` ganha `ended_by_user_id` e
    `observar_vinculo` passa a receber `retorno?`. FR-019, FR-021, FR-023, FR-026, FR-027; SC-002.
  - **Feita quando**: pessoa com dois papéis sai numa chamada; `count_team_members_at` para ontem é
    o mesmo antes e depois; depois da saída a coleta **não** recria e a discordância aparece;
    depois de ausência constatada **e** reobservação, nasce vínculo novo.
  - **Teste**: `saida_declarada_test.exs` + novo `describe` em `vinculo_observado_test.exs`.

- [ ] **T015 [US3]** "Left the team…" na linha, com data obrigatória e a origem do fim dita
  - Formulário sob a linha, **sem** data pré-preenchida (FR-023), com a nota do protótipo ("ended,
    not deleted"). Evento sob `com_gestao`; data vazia → "A departure needs a date — the platform
    does not presume today." FR-019 a FR-023; SC-001, SC-013.
  - **Teste**: novo `saida_na_tela_test.exs` — SC-001 comparando `count_team_members_at`
    antes/depois; SC-013 no mesmo `live`.

---

## Fase 4 — US4: o vínculo que nunca foi (P1)

- [ ] **T016 [US4]** O equívoco alcança todos os vigentes do par
  - `update_all` com o trio; zero vigentes → erro nomeado; razão vazia continua recusada. FR-024,
    FR-025; plano D4.
  - **Teste**: "equívoco com dois papéis vigentes"; invalidado não conta em data anterior.

- [ ] **T017 [US4]** "Mistake…" na linha, com razão obrigatória e o texto que separa de "saiu"
  - Formulário sob a linha com a nota inteira do protótipo (inclusive "applies to declared and
    observed alike" e "the next collection does not re-create"). Razão vazia → "A mistake needs a
    written reason." FR-024 a FR-028; SC-002.
  - **Teste**: novo `equivoco_na_tela_test.exs` — cenários 1–5; SC-002 contando vínculos do par
    antes e depois da coleta simulada.

---

## Fase 5 — US2: declarar e alterar o papel (P1)

- [ ] **T018 [US2]** `declare_role/6` e `change_role/5`
  - `declare_role`: `fetch_team/2` → `resolver_papel/3` → `allocate/2` com autor, `started_at`
    (nulo fica nulo) e `declared_at`. `change_role`: transação — `end_allocation/4` em
    `desde || agora` + `declare_role/6`; `{:ok, %{encerrado, novo}}`. FR-015 a FR-018.
  - **Teste**: novo `declarar_e_alterar_papel_test.exs` — mesmo `id` ao declarar num observado;
    dois registros ao alterar; segundo papel aceito; papel de outra organização recusado.

- [ ] **T019 [US2]** "Declare role" / "Change role" na linha, e "＋ new role…" sem sair dela
  - Formulário sob a linha; `<select>` com os papéis da organização, "choose…" e "＋ new role…";
    "since" **sem** valor por padrão (hoje `:1417` pré-preenche com hoje: **remover**). FR-015 a
    FR-018, FR-034.
  - **Teste**: novo `declarar_papel_na_linha_test.exs`; o cenário 4 fica `@tag :pending` até T022.

- [ ] **T020 [US2]** O lote "Declare all roles", por vínculo, na Estrutura
  - `<details>` com o formulário de hoje reescrito por `membership_id`, data vazia, e as frases de
    resultado reusadas. FR-014, FR-015, FR-016.
  - **Teste**: `promocao_na_tela_test.exs` **reescrito** — os sete casos em `?tab=structure`; a data
    vem vazia; `refute "MAINTAINER"`.

---

## Fase 6 — US5: os papéis da organização, a partir da Estrutura (P1)

- [ ] **T021 [P] [US5]** `role_holder_counts/3` — quantas pessoas por papel, aqui e na organização
  - Uma consulta com `count(distinct person_id)` total e filtrado. FR-029.
  - **Teste**: `roster_test.exs` — `describe "contagem por papel"`.

- [ ] **T022 [US5]** A seção *Roles*: catálogo e criados, criar com código sugerido, renomear, ocultar
  - Cabeçalho, texto, colunas (role · code · origin · people here · in the organisation · grants ·
    ações), formulário "new role" com código sugerido do nome, recusas nomeadas
    (`:code_taken`, `{:in_use, n}`). Ao criar com `linha_de_retorno`, reabrir a linha (destrava
    T019 c4). FR-029 a FR-034; SC-005. **Rótulo do botão**: proposta *Hide* (pergunta aberta 1).
  - **Teste**: novo `papeis_na_estrutura_test.exs` — cenários 1–6; o 1 abre `/roles` depois e acha
    o papel (SC-005).

**Checkpoint US2–US5**: quem gere declara, altera, encerra, invalida e cria papéis sem sair de
`?tab=structure`.

---

## Fase 7 — Fechamento

- [ ] **T023** A escrita de projeto vive na Estrutura, sob o mesmo veredito
  - `associar_projeto`/`desassociar_projeto` perdem o pattern `%{role: "admin"}` e passam por
    `com_gestao`; o `<select>` e o `×` só em *Where this team sits*. FR-003, FR-052.
  - **Teste**: `equipe_competencias_test.exs` em `?tab=structure`; caso novo em
    `estrutura_permissao_test.exs`.

- [ ] **T024 [P]** Isolamento entre tenants nas consultas novas
  - Roster, totais, contagens por papel e alcance da concessão; `?tab=structure` de equipe de outro
    tenant → "Team not found". Princípio V; FR-005.

- [ ] **T025** Gates, quickstart e documentos
  - `mix gates > /tmp/gates.log 2>&1; echo EXIT=$?` e **ler** o log; `quickstart.md` com os
    cenários das cinco histórias e o passo "medir contas não-admin com escopo organization
    vigente"; nota na ADR 0008 apontando a regra v3; `docs/backlog/tela-da-equipe.md` com o que a
    PR 1 entregou; corpo do PR com a tabela por user story e a lacuna de revisão se houver.

---

## Dependências e ordem

```text
T001 ─┬─ T002 ── T004 ── T005 ─┬─ T006 ─┐
      │                        └─ T007  │
      ├─ T003 ─────────────────────┐    │
      └─ T008 ─┬─ T009 ────────────┼────┼── T010 ── T011 ─┬─ T012 ─┬─ T015  (precisa T014)
               ├─ T014 ◄───────────┘    │                 └─ T013  ├─ T017  (precisa T016)
               ├─ T016                  │                          ├─ T019 ── T020  (precisa T018)
               └─ T018                  │                          ├─ T022 ◄─ T021
                                        └────────────────────────── T023 ── T024 ── T025
```

- **Paralelizáveis**: T001 ∥ T003; T009 ∥ T014 ∥ T016 ∥ T018 (após T008); T021; T024.
- **Sequência crítica**: T001 → T002 → T004 → T005 → T006 → T010 → T011 → T012 → (T015 | T017 |
  T019) — a primeira tela só existe depois do veredito, porque decide quem vê botão no primeiro
  render.
- **US3, US4, US2, US5 são independentes** depois de T012.

## Rastreabilidade — FR/SC por tarefa

| FR/SC | Tarefas |
|---|---|
| FR-001, FR-002, FR-004, SC-007 | T010 |
| FR-003, FR-052 | T010, T023 |
| FR-005 | T010, T024 |
| FR-006, FR-080–082, SC-011 | T002, T004, T005, T006, T007, T012 |
| FR-007 | confirmado sem mudança (`pode_ver_equipe/3`) |
| FR-008 a FR-013, SC-004 | T009, T011 |
| FR-014 | T020 |
| FR-015 a FR-018 | T018, T019, T020 |
| FR-019 a FR-023, SC-001, SC-013 | T008, T014, T015 |
| FR-024, FR-025, FR-028 | T016, T017 |
| FR-026, FR-027, SC-002 | T003, T014, T017 |
| FR-029 a FR-034, SC-005 | T021, T022 |
| SC-012 (zero linhas removidas) | T014, T016, T018, T022 |
| SC-015 (YAML antes da tela) | T002, T003 |
| teto de consultas | T013 |
| FR-041 (cartão da subequipe e a porta, US7), FR-084 (gráfico pequeno no cartão, US9) | **sem tarefa** — US7 e US9 não estão planejadas em tarefas; os dois vieram da US6 pela decisão 11 de 2026-09-07 |

Esta tabela cobre o que a **PR 1** entrega (US1–US5, as duas abas e a concessão).
Requisitos de US6 a US9 só aparecem aqui quando a PR 1 os toca — FR-052 (a escrita
de projeto muda de aba) e FR-007 (confirmado sem mudança) são os casos. FR-041 e
FR-084 não são: ficam sem tarefa até US7 e US9 serem planejadas.

## Dependências externas desta PR

- **YAML**: `role_grants.yaml` (novo) + `eo/ontology.yaml`; `github_team_membership_evidence` v3.
- **Migrações**: `saida_declarada_com_autor`; `concessao_de_gestao_da_estrutura`.
- **Decisões pendentes** (não bloqueiam começar; bloqueiam fechar T017, T022, T014, T002): as seis
  perguntas abertas do `plan.md`.
