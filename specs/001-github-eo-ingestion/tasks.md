# Tasks: Coleta de pessoas e equipes do GitHub para a Enterprise Ontology

**Feature**: 001-github-eo-ingestion | **Branch**: `feature/001-github-eo-ingestion` | **Data**: 2026-08-09

**Entrada**: [spec.md](spec.md) · [plan.md](plan.md) · [data-model.md](data-model.md) ·
[contracts/](contracts/) · [research.md](research.md) · [quickstart.md](quickstart.md)

**Convenção**: `- [ ] TID [P?] [US?] descrição com caminho`. `[P]` = paralelizável
(arquivo distinto, sem dependência pendente). Cada tarefa cita o requisito (FR/SC)
ou o contrato que a justifica.

---

## Phase 1 — Setup

Bootstrap do projeto. Nada existe hoje além de `docs/`, `priv/knowledge_base/`,
`scripts/` e `specs/`.

- [ ] T001 Gerar o projeto Phoenix com `mix phx.new . --app the_band --module TheBand --database postgres --no-mailer`, preservando `priv/knowledge_base/`, `scripts/`, `specs/`, `docs/`, `AGENTS.md` e `README.md` — plan.md, Structure Decision
- [ ] T002 Fixar as versões exatas de R1 e R2/R3 em `mix.exs`: `phoenix ~> 1.8`, `ecto_sql ~> 3.14`, `oban ~> 2.23`, `req ~> 0.7.2`, `yaml_elixir ~> 2.12`, `cloak_ecto ~> 1.3`, `mox` (test) — research.md R1–R3
- [ ] T003 [P] Criar `compose.yaml` com PostgreSQL 16, volume nomeado e porta 5432 — research.md R1
- [ ] T004 [P] Criar `.env.example` com `THE_BAND_MASTER_KEY` sem valor e instrução de geração — FR-005, AGENTS.md §14
- [ ] T005 [P] Configurar `.formatter.exs` e `.credo.exs` (Credo estrito) — constituição VII
- [ ] T006 [P] Criar `.github/workflows/ci.yml` rodando os oito quality gates com serviço PostgreSQL — constituição VII, quickstart.md
- [ ] T007 Configurar `config/runtime.exs` lendo `THE_BAND_MASTER_KEY` e `DATABASE_URL` do ambiente — FR-005
- [ ] T008 [P] Adicionar `alias` de `mix setup` cobrindo `deps.get`, `ecto.setup` e `assets.setup` — AGENTS.md §4

**Checkpoint**: `mix compile` limpo, `docker compose up -d` sobe o Postgres, `mix ecto.create` funciona.

---

## Phase 2 — Foundational

Bloqueia todas as user stories. Nada de US1/US2/US3 começa antes disto.

### Base de conhecimento

- [ ] T009 Implementar `lib/the_band/ontology/yaml_loader.ex` lendo `priv/knowledge_base/` com `yaml_elixir` — research.md R2, R4
- [ ] T010 Implementar `lib/the_band/ontology/yaml_validator.ex` validando manifesto, schemas, referências, ciclos e proveniência — constituição IV
- [ ] T011 Implementar `lib/the_band/ontology/knowledge_base.ex` carregando no boot para ETS `read_concurrency: true`, uma tabela por tipo de artefato; **falha de carga é falha de boot** — research.md R4
- [ ] T012 [P] Criar `lib/mix/tasks/knowledge.validate.ex` expondo o validador como Mix task — constituição VII
- [ ] T013 [P] Criar `lib/mix/tasks/knowledge.graph.ex` verificando direção de dependência entre ontologias e ciclos — constituição I, VII

### Segurança da credencial

- [ ] T014 Implementar `lib/the_band/vault.ex` com `Cloak.Vault`, AES-GCM 256 e chaves rotuladas para rotação — research.md R3, FR-005, FR-005b
- [ ] T015 Implementar `lib/the_band/encrypted/binary.ex` como `Ecto.Type` cifrado — FR-005
- [ ] T016 Fazer `lib/the_band/application.ex` recusar o boot quando `THE_BAND_MASTER_KEY` estiver ausente, antes de qualquer supervisor — **FR-005a**
- [ ] T017 [P] Criar `mix the_band.rotate_key` recifrando as credenciais existentes — FR-005b

### Tenant, usuário e proveniência

- [ ] T018 Migração + schema de `tenants` em `lib/the_band/tenants/` — FR-001
- [ ] T019 Migração + schema de `users` com `role` enum `{admin, member}` e autenticação de sessão — Assumptions da spec
- [ ] T020 [P] Implementar `lib/the_band/provenance/application_reference.ex` resolvendo `source_system + source_instance + external_id` — FR-012, constituição III
- [ ] T021 [P] Implementar `lib/the_band_web/plugs/require_tenant.ex` e `require_admin.ex` — FR-027, contrato de telas

### Ontologia EO — o esquema derivado

- [ ] T022 Migração das seis tabelas derivadas (`eo_organizations`, `eo_people`, `eo_teams`, `eo_sectors`, `eo_organizational_roles`, `eo_team_memberships`) conferida contra `derive_information_model.py --ontology eo` — ADR 0004, data-model.md
- [ ] T023 Migração de `eo_team_membership_evidence` com as colunas de D-1/D-2 e o `unique_index` de idempotência — data-model.md, regra `github.team_membership_evidence`
- [ ] T024 Acrescentar as colunas obrigatórias (`tenant_id`, `internal_id`, `record_version`, quádrupla de proveniência) e o `unique_index` em toda tabela alimentada por fonte externa — **FR-012, FR-014, SC-003**
- [ ] T025 [P] Schemas Ecto privados em `lib/the_band/ontology/seon/eo/schemas/` — contrato ontology-eo.md
- [ ] T026 Comandos `upsert_organization_from_source/2`, `upsert_person_from_source/2`, `upsert_team_from_source/2` em `commands/`, exigindo a proveniência completa — contrato ontology-eo.md
- [ ] T027 `record_team_membership_evidence/2` e `mark_evidence_no_longer_observed/2` em `commands/` — FR-019, edge case de remoção
- [ ] T028 Constraints em `constraints/`: papel de plataforma não vira papel organizacional; membership exige papel; equipe do GitHub é organizacional; automação não é pessoa; identidade não se unifica — **FR-019 a FR-023, FR-025**
- [ ] T029 Módulo raiz `lib/the_band/ontology/seon/eo/eo.ex` com **apenas** `defdelegate` — ADR 0003, research.md R9
- [ ] T030 [P] Teste de idempotência: duas chamadas idênticas de `upsert_person_from_source/2` não alteram `record_version` — **SC-003**
- [ ] T031 [P] Teste de isolamento: dois tenants povoados, nenhum lê o outro — **SC-008**

**Checkpoint**: `mix ecto.migrate` aplica tudo, boot falha sem chave mestra, testes de fundação passam.

---

## Phase 3 — US1 (P1): conectar ferramenta com credencial protegida

**Meta**: a organização passa a ter registro auditável de quais ferramentas e
contas de serviço estão em uso.

**Teste independente**: cadastrar organização, conectar o GitHub com credencial
real, ver a conexão confirmada; recarregar e confirmar que a chave não é legível.

- [ ] T032 [US1] Migração + schema de `connected_tools` com `tool_type` enum, `instance_url`, `status` e campos de atenção — FR-002, FR-003, FR-009
- [ ] T033 [US1] Migração + schema de `tool_credentials` com `secret` cifrado, `last_four`, `active`, `validated_at` e histórico de falha — FR-004, FR-005, FR-007
- [ ] T034 [US1] Derivar `@derive {Inspect, except: [:secret]}` e redigir o campo em toda telemetria — **FR-008**
- [ ] T035 [US1] Implementar `TheBand.Integrations.GitHub.Client` sobre Req, com `verify_credential/2` checando acesso **e** escopo `read:org` — FR-006, quickstart V1
- [ ] T036 [US1] Comando `connect_tool/2` que valida antes de gravar e **não grava nada** quando a validação falha — FR-006, cenário 2 da US1
- [ ] T037 [US1] Marcar `connected_tools` como `needs_attention` com data e motivo quando a credencial falha, sem afetar as demais — FR-009, cenário 5 da US1
- [ ] T038 [US1] LiveView `/ferramentas` em `lib/the_band_web/live/source_live/` — listar, conectar, exibir `••••` + `last_four`, aceitar segunda credencial — contrato liveview-screens.md
- [ ] T039 [P] [US1] Teste de contrato do cliente GitHub com Mox **só na borda HTTP** — contrato github-connector.md
- [ ] T040 [P] [US1] Teste provando que a credencial não aparece em HTML, log nem estado do socket — **SC-005**

**Checkpoint**: US1 entrega valor sozinha — a tela de ferramentas funciona sem que US2 exista.

---

## Phase 4 — US2 (P2): conhecer pessoas e equipes

**Meta**: o sistema deixa de estar vazio e passa a conhecer o quadro de pessoas.

**Teste independente**: disparar a sincronização e conferir que as quantidades
batem com o GitHub; rodar de novo e confirmar que os números não mudam.

### Conector declarativo

- [ ] T041 [P] [US2] Queries GraphQL em `priv/connectors/github/queries/`: `organization.graphql`, `organization_members.graphql`, `teams.graphql`, `team_members.graphql` — **todas pedindo `rateLimit { cost remaining resetAt }`** — contrato github-connector.md
- [ ] T042 [P] [US2] Definições declarativas em `priv/connectors/github/definitions/` para as quatro entidades, com paginação, checkpoint, retry e rate limit — AGENTS.md §10
- [ ] T043 [US2] Runtime do conector: carrega definição, valida, executa via Req, controla cursor — contrato github-connector.md
- [ ] T044 [US2] Tratamento de rate limit: pausa quando `remaining < cost * 2`, reagenda via Oban até `resetAt`, **nunca `Process.sleep`** — **FR-016, SC-009**, research.md R6

### Persistência da coleta

- [ ] T045 [US2] Migração + schema de `syncs` com relatório de FR-028 e índice único parcial sobre `connected_tool_id` onde `status = 'running'` — **FR-018, FR-028**
- [ ] T046 [US2] Migração + schema de `sync_checkpoints` por `(sync_id, entity_type)` com cursor opaco — FR-015, research.md R5
- [ ] T047 [US2] Migração + schema de `raw_payloads` guardando `payload` jsonb, `mapping_id` e `mapping_version` — **FR-011, FR-017**

### Transformação semântica

- [ ] T048 [US2] `lib/the_band/semantic_integration/mapper.ex` aplicando os mapeamentos YAML de `mappings/github/eo/` ao payload bruto — **FR-013**, constituição IV
- [ ] T049 [US2] Aplicar a regra `github.team_membership_evidence`: materializa pessoa e equipe, **não** materializa papel nem membership — FR-019, FR-024
- [ ] T050 [US2] Classificar conta de automação em `eo_people.account_type` a partir do tipo da conta — **FR-022**

### Orquestração

- [ ] T051 [US2] Worker Oban `SyncOrganization` com `unique`, `tenant_id` nos args **validado** antes de executar — FR-018, constituição V
- [ ] T052 [US2] Workers de página por entidade, gravando o checkpoint **depois** de processar a página — **SC-006**, research.md R5
- [ ] T053 [US2] Marcar evidência ausente com `no_longer_observed_at` ao fim da coleta, sem apagar — edge case, Assumptions
- [ ] T054 [US2] Interrupção controlada quando a credencial é revogada no meio: progresso preservado, ferramenta marcada — edge case
- [ ] T055 [US2] Relatório final: coletados, criados, atualizados, ignorados com motivo, e vínculos pendentes de papel — **FR-028, SC-010**
- [ ] T056 [US2] LiveView `/sincronizacoes` com progresso ao vivo, estado de pausa por rate limit e bloqueio da segunda execução — contrato liveview-screens.md
- [ ] T057 [P] [US2] Teste de integração de idempotência: segunda sincronização cria 0 e atualiza 0 — **SC-003**
- [ ] T058 [P] [US2] Teste de integração de retomada: no máximo uma reconsulta por página — **SC-006**
- [ ] T059 [P] [US2] Teste de integração de rate limit com resposta simulada de janela esgotada — **SC-009**
- [ ] T060a [US2] Implementar `TheBand.SemanticIntegration.reprocess_mappings/2` lendo `raw_payloads` e reaplicando os mapeamentos pelo módulo ontológico, sem tocar na origem — **FR-017**, [contracts/reprocessing.md](contracts/reprocessing.md)
- [ ] T060b [US2] Worker Oban `TheBand.Jobs.ReprocessMappings` na fila `:transformation`, com `tenant_id` validado, publicando `{:reprocess_finished, report}` — contrato de reprocessamento
- [ ] T060c [US2] Botão "Reprocessar mapeamentos" em `/sincronizacoes` com o relatório do resultado — princípio VI, contrato de telas
- [ ] T060 [P] [US2] Teste de reprocessamento com mapeamento corrigido, sem nenhuma chamada ao GitHub — **SC-007**

**Checkpoint**: sincronização completa, idempotente e retomável, com tela de acompanhamento.

---

## Phase 5 — US3 (P3): rastrear de onde veio cada informação

**Meta**: provar que a feature funciona sem ler código nem teste.

**Teste independente**: abrir a tela e conferir que cada pessoa e cada equipe
exibe origem, identificador externo e data de coleta, e que os números batem.

- [ ] T061 [US3] `list_people/2` e `count_people/2` em `queries/`, aceitando **exatamente as mesmas** `opts` — contrato ontology-eo.md
- [ ] T062 [US3] `list_teams/2`, `count_teams/2` e `list_team_members/3` em `queries/` — FR-026
- [ ] T063 [US3] `count_evidence_pending_role/2` — **FR-021, SC-010**
- [ ] T064 [US3] LiveView `/pessoas` exibindo nome, tipo de conta, origem, identificador externo e data de coleta — **FR-026, SC-004**
- [ ] T065 [US3] LiveView `/equipes` com integrantes, nível de acesso rotulado como **acesso na plataforma**, pendentes de papel e vínculos históricos — FR-019, FR-020
- [ ] T066 [P] [US3] Estados vazios explicados por causa: "nenhuma sincronização executada" ≠ "organização sem equipes" — edge case
- [ ] T067 [P] [US3] Teste provando que `count_*` e `list_*` concordam sob todo filtro — contrato ontology-eo.md
- [ ] T068 [P] [US3] Teste de interface com dois tenants: nenhum caminho mostra dado do outro; id trocado na URL devolve 404 — **SC-008**

**Checkpoint**: fatia vertical fechada — banco, escopo de tenant, domínio, coleta e tela.

---

## Phase 6 — Polish

- [ ] T069 [P] Telemetria com os campos de AGENTS.md §15, com o segredo redigido
- [ ] T070 [P] Atualizar `README.md` com o caminho de execução do quickstart
- [ ] T071 Rodar os oito quality gates verdes — constituição VII
- [ ] T072 Executar V1 a V8 do [quickstart.md](quickstart.md) e registrar a evidência de cada um
- [ ] T073 Abrir o PR com a tabela de mapeamentos semânticos, declarando a revisão independente como **pendente** — constituição VII

---

## Dependências

```text
Phase 1 (Setup)
   └→ Phase 2 (Foundational) ── bloqueia tudo
         ├→ Phase 3 US1 (P1)  ── independente, entrega valor sozinha
         │     └→ Phase 4 US2 (P2) ── precisa de ferramenta conectada
         │           └→ Phase 5 US3 (P3) ── precisa de dado coletado
         └→ Phase 6 (Polish)
```

US2 depende de US1 por dado (sem ferramenta conectada não há o que coletar), não
por código. US3 depende de US2 pela mesma razão. As três permanecem testáveis de
forma independente com dado semeado.

## Paralelismo

| Fase | Tarefas `[P]` | Por que são seguras |
|---|---|---|
| 1 | T003, T004, T005, T006, T008 | arquivos distintos, sem dependência entre si |
| 2 | T012, T013, T017, T020, T021, T025, T030, T031 | módulos e testes separados |
| 3 | T039, T040 | testes, arquivos próprios |
| 4 | T041, T042 (artefatos declarativos) · T057–T060 (testes) | YAML/GraphQL e testes não colidem |
| 5 | T066, T067, T068 | testes e componentes distintos |
| 6 | T069, T070 | documentação e telemetria |

## Estratégia de entrega

**MVP** = Phase 1 + Phase 2 + Phase 3 (US1). Entrega o registro auditável de
ferramentas e credenciais, com tela funcionando, e prova o caminho de segurança
(SC-005) — que é onde mora o maior risco da feature.

Incremento 2 = Phase 4 (US2): o sistema passa a conhecer o quadro de pessoas.
Incremento 3 = Phase 5 (US3): a proveniência fica visível na tela.

**Total**: 73 tarefas — 8 setup, 23 fundação, 9 US1, 20 US2, 8 US3, 5 polish.
