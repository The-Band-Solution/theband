# Tasks: Autenticação e papel de acesso

**Feature**: 045-autenticacao-e-acesso | **Branch**: `045-autenticacao-e-acesso`
**Input**: [spec.md](spec.md) · [plan.md](plan.md) · [research.md](research.md) · [contracts/](contracts/)

## Phase 1 — Setup

- [ ] T001 Abrir branch e registrar baseline dos gates
  - **Pronta quando**: nada além do repositório; working tree limpa; PR da 046 mergeado
  - **Descrição**: branch `feature/<US1>-autenticacao-e-acesso` a partir de `main`;
    `mix gates > /tmp/gates-base.log 2>&1; echo "EXIT=$?" >> /tmp/gates-base.log` —
    o veredito gravado NO log (L60, forma do sprint 022), e a run termina antes de
    qualquer edição (lição do baseline contaminado do sprint 022)
  - **Feita quando**: branch existe; log do baseline contém `EXIT=0`
  - **Teste**: `grep EXIT= /tmp/gates-base.log` devolve 0

- [ ] T002 Dependência bcrypt_elixir com justificativa
  - **Pronta quando**: T001 concluída
  - **Descrição**: adicionar `bcrypt_elixir` ao `mix.exs` com versão fixada; a
    justificativa vive em research R1 (padrão phx.gen.auth, custo por tentativa é
    proteção) e o plan a referencia — exigência do AGENTS §3
  - **Feita quando**: `mix deps.get` resolve; compilação limpa
  - **Teste**: `mix compile --warnings-as-errors` com a dep presente; `Bcrypt.verify_pass/2` disponível em iex -S mix run -e

## Phase 2 — Foundational

- [ ] T003 Migrações: credencial na conta e tabela de concessões
  - **Pronta quando**: T001 concluída; data-model.md aprovado (está)
  - **Descrição**: migração 1 — colunas de `users` do data-model (password_hash,
    password_set_at, must_change_password, session_token, logged_in_at,
    failed_attempts, last_failed_at); migração 2 — `access_scope_grants` com índice
    parcial de vigência + **seed**: concessão organization por organização observada
    para cada conta admin, com comentário do porquê (research R9). Nenhuma senha
    semeada (FR-014)
  - **Feita quando**: ida e volta limpas; contas admin do banco dev têm N concessões
    (N = organizações do tenant); nenhuma linha com senha
  - **Teste**: `mix ecto.migrate && mix ecto.rollback --step 2 && mix ecto.migrate`;
    SQL no dev: `SELECT count(*) FROM access_scope_grants` == admins × orgs

- [ ] T004 Autenticação de domínio conforme contrato
  - **Pronta quando**: contrato `contracts/auth.md` escrito (está); T002 e T003 concluídas
  - **Descrição**: `lib/the_band/tenants/auth.ex` — `authenticate/2` (e-mail ou GitHub
    username via elo vigente, hash dummy p/ tempo constante, espera crescente R4),
    `set_password/3`, `change_password/4` (gira session_token), `reset_password/3`
    (temporária devolvida uma vez, must_change_password). Fachada `Tenants` delega.
    Se a implementação desmentir o contrato, corrigir no mesmo commit com a razão
  - **Feita quando**: todos os caminhos de recusa devolvem `:invalid_credentials`
    indistinto; sucesso zera tentativas e carrega tenant; temporária nunca logada
  - **Teste**: `test/the_band/tenants/auth_test.exs` — as violações: username ambíguo
    entre 2 tenants não entra; elo revogado não entra; conta sem senha não entra;
    5ª tentativa errada devolve `{:throttled, _}`; troca de senha muda session_token

- [ ] T005 Escopos de domínio conforme contrato
  - **Pronta quando**: contrato `contracts/access-scopes.md` escrito (está); T003 concluída
  - **Descrição**: `lib/the_band/tenants/access.ex` + `access/scope_grant.ex` —
    `scopes/2` (piso + derivados pela cadeia declarada R5/R6 + concessões, cada um com
    origem), `pode_ver/3` (ramos na ordem do contrato, delega liderança à
    `EO.Visibility`, motivo nomeado), `grant/5`, `revoke/5`, `operacional?/2`.
    **Retirar o ramo "admin vê tudo" do Visibility** (FR-022) no mesmo commit,
    atualizando `visibilidade_test` (L71: teste do requisito antigo muda junto)
  - **Feita quando**: união correta nas quatro origens; derivado some quando o fato
    fecha; admin sem concessão não vê painel; motivo distinto por ramo de recusa
  - **Teste**: `test/the_band/tenants/access_test.exs` — violações primeiro: vazamento
    entre tenants; grant sem alvo recusado; revoke por não-admin recusado; derivado
    não aparece após `ended_at`/`unlinked_at`; admin puro recebe `{:nao, :fora_dos_escopos}`

## Phase 3 — US1: Entrar com e-mail ou usuário do GitHub, e sair (P1) 🎯 MVP

- [ ] T006 [US1] Tela de login do protótipo e sessão real
  - **Pronta quando**: T004 concluída
  - **Descrição**: refazer `session_live/new.ex` (split marketing + formulário,
    protótipo do canvas — axioma, três compromissos, tagline) e
    `session_controller.ex`: `create` recebe identificador+senha →
    `Tenants.authenticate/2`; grava `user_id` + `session_token` na sessão;
    `must_change_password` redireciona à definição de senha antes de qualquer tela
    (FR-013); `delete` continua. Mensagem única "Credenciais inválidas." (FR-002)
  - **Feita quando**: tela não lista conta nenhuma; recusa idêntica p/ senha errada,
    e-mail inexistente, username revogado/ambíguo e conta sem senha; login por
    username com elo vigente entra
  - **Teste**: `test/the_band_web/live/login_test.exs` — cenários 1–8 da US1, com a
    violação de vazamento por mensagem (respostas byte-idênticas nos 4 casos de recusa)

- [ ] T007 [US1] Sessão validada por token e expiração
  - **Pronta quando**: T006 concluída
  - **Descrição**: hook `current_scope` passa a validar `session_token` da sessão
    contra a conta e `logged_in_at` + 7 dias (research R2); divergência → redirect a
    /sign-in preservando destino (FR-005). Helper de teste `log_in/2` ganha o token
    (research R10) — documentar no helper por que ele continua sendo atalho legítimo
  - **Feita quando**: sessão com token antigo cai na próxima ação; destino preservado
    no redirect; suíte inteira segue passando com o helper ajustado
  - **Teste**: `login_test.exs` — troca de senha derruba a outra sessão (FR-015);
    acesso sem sessão a /people redireciona com `redirect_to`

- [ ] T008 [US1] Contas: criar e reiniciar senha (admin)
  - **Pronta quando**: T004 concluída
  - **Descrição**: LiveView `/accounts` (live_session require_admin) — listar contas
    do tenant, criar conta (e-mail, nome), reiniciar senha exibindo a temporária UMA
    vez (FR-013); entrada em Settings › Vocabulário? NÃO — Settings › **Contas** é
    seção própria da gestão (Vocabulário é da organização); item visível só a admin
  - **Feita quando**: temporária aparece uma única vez e não reaparece em render
    seguinte; conta criada sem senha até o primeiro reset/definição; member não
    alcança a tela
  - **Teste**: `test/the_band_web/live/accounts_test.exs` — member recusado na rota;
    temporária ausente do HTML após navegação; criação registra tenant certo

## Phase 4 — US2: Escopos de acesso acumulativos (P2)

- [ ] T009 [US2] Tela de concessões com derivados declarados
  - **Pronta quando**: T005 concluída
  - **Descrição**: LiveView `/access-scopes` (require_admin), protótipo aprovado:
    formulário Grant a scope (team/project/organization + alvo obrigatório, recusa
    nomeada sem alvo), tabela por conta com TODOS os escopos vigentes — derivados com
    hachura e origem ("vínculo pessoa-equipe", "equipe→projeto declarado"), concedidos
    com quem/quando e Revoke; piso person como nota, não linha. Entrada em Settings ›
    Vocabulário (slot previsto na 046)
  - **Feita quando**: derivado sem botão de revogar; concessão sem alvo recusada com
    motivo; revogação marca e a linha some da vigência (não do histórico)
  - **Teste**: `test/the_band_web/live/access_scopes_test.exs` — grant sem alvo mostra
    a frase; derivado exibe hachura/origem e não exibe Revoke; member não alcança

- [ ] T010 [US2] O veredito único nas telas de pessoa
  - **Pronta quando**: T005 concluída
  - **Descrição**: `people_live/show` (e onde mais `EO.Visibility.pode_ver/3` é
    chamado — grep) passam a chamar `Tenants.Access.pode_ver/3`; a recusa exibe o
    motivo novo em serifada (padrão da tela de recusa do protótipo). Lista de pessoas
    filtra pela união (SC-003)
  - **Feita quando**: os quatro motivos de recusa aparecem cada um na sua condição;
    conta piso vê só o próprio painel; team/project/organization ampliam exatamente
    o alcance do contrato
  - **Teste**: nos testes de visibilidade existentes + novos casos em
    `access_test.exs`/tela: admin sem concessão recusado com motivo; líder declarado
    (regra #369) CONTINUA vendo (FR-018 — a violação testada é a regressão)

- [ ] T011 [US2] Operacionais restritas e filtradas (FR-023)
  - **Pronta quando**: T005 concluída
  - **Descrição**: hook `require_operacao` (admin OU organization vigente) nas rotas
    /syncs, /tools, /ai, /profiles; telas filtram ferramentas/syncs por
    `organization_login ∈ organizações concedidas` quando não-admin (research R8);
    menu Settings › Operação muda a condição no ponto único previsto pela 046; recusa
    por URL direta nomeia o motivo
  - **Feita quando**: member puro nem vê as entradas e URL direta recusa; organization
    vê só o que pertence às suas organizações; admin segue vendo tudo do tenant
  - **Teste**: `test/the_band_web/live/gating_operacional_test.exs` — a violação:
    organization de org A não vê ferramenta da org B; member direto por URL recusado
    com motivo; layouts_nav_test ganha o caso organization (L71)

## Phase 5 — US3: Configurar o próprio perfil (P3)

- [ ] T012 [US3] Tela de perfil
  - **Pronta quando**: T004 e T005 concluídas
  - **Descrição**: LiveView `/profile` conforme protótipo: identidade (nome editável,
    e-mail leitura), troca de senha com confirmação da atual (FR-012), escopos
    vigentes com origem (piso/derivado hachura/concedido — `Access.scopes/2`), estado
    do elo com proveniência; frases de "quem concede é quem administra". Item no menu
    da conta (junto de Sign out)
  - **Feita quando**: troca com atual errada recusa e mantém a vigente; com certa, a
    próxima entrada exige a nova; escopos exibidos batem com `scopes/2`; nada de
    edição de papel/elo na tela
  - **Teste**: `test/the_band_web/live/profile_test.exs` — cenários 1–4 da US3 + a
    violação: o HTML do perfil nunca contém hash nem senha

## Phase 6 — Polish

- [ ] T013 Verificação contra a origem e evidências
  - **Pronta quando**: T006–T012 concluídas; banco dev migrado
  - **Descrição**: no dev — admins com concessão organization por organização (SQL ×
    tela /access-scopes); login real por e-mail e por username (screenshot); derivado
    project aparecendo para as equipes ligadas via `spo_project_teams` (3 vínculos
    medidos no research R6); screenshots 1280px das telas novas
  - **Feita quando**: números tela × SQL batem; evidências anexadas ao PR
  - **Teste**: a própria verificação, com SQL e screenshots registrados

- [ ] T014 Gates verdes e fechamento
  - **Pronta quando**: T013 concluída
  - **Descrição**: `mix gates > log 2>&1; echo "EXIT=$?" >> log` (forma completa da
    L60); atualizar protótipo/canvas se a implementação divergiu do desenho; PR no
    padrão da constituição 1.6.0 (issues com resumo na frente)
  - **Feita quando**: 13 gates verdes com EXIT gravado no log; PR aberto com revisor
    the-band, projeto e iteration
  - **Teste**: `grep EXIT= <log>` devolve 0; PR aberto no padrão

## Dependencies

```text
T001 → T002 → T004 → T006 → T007
     → T003 → T004        → T008
            → T005 → T009 · T010 · T011
T004 + T005 → T012
T006–T012 → T013 → T014
```

- US1 (T006–T008) é o MVP; exige Foundational completo (T002–T005).
- T009, T010, T011 paralelizáveis entre si depois de T005.
- US3 (T012) depende dos dois contratos implementados.

## Parallel Execution Examples

- Depois de T003: **T004 e T005 em paralelo** (módulos distintos, contratos próprios).
- Depois de T005: **T009 [P] · T010 [P] · T011 [P]** (telas/arquivos distintos).

## Implementation Strategy

Foundational primeiro (migrações + dois módulos de domínio com contratos — é onde
mora a segurança); US1 fecha a porta e é demonstrável sozinha; US2 gradua o acesso e
faz o FR-023; US3 fecha o ciclo da conta. Violação antes do caminho feliz em todo
teste de segurança (L03).
