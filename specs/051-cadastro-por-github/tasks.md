# Tasks: Contas — cadastrar pessoas e associar o GitHub

**Input**: specs/051-cadastro-por-github/ — spec.md, plan.md, research.md,
contracts/contas-e-elo.md, quickstart.md

**Tests**: cada tarefa carrega o seu; as violações primeiro (L03).

## Phase 1: Setup

- [ ] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch `051-cadastro-por-github` rebaseada na main pós-sprint-024
  - **Descrição**: `mix gates > /tmp/gates_051_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_051_baseline.log`, run TERMINADA antes de editar (L60 + baseline limpo)
  - **Feita quando**: log com `EXIT=0` na última linha, sem edição concorrente
  - **Teste**: `tail -1 /tmp/gates_051_baseline.log` = `EXIT=0`

## Phase 2: Foundational

- [ ] T002 O cadastro transacional com temporária, pela violação
  - **Pronta quando**: T001 concluída; `contracts/contas-e-elo.md` escrito (está)
  - **Descrição**: `Tenants.cadastrar_conta/3` conforme contrato — cria + temporária numa transação, `{:ok, {user, temporaria}}`; e-mail duplicado devolve changeset sem criar nada; rastro do actor como no reset. `create_user/2` intocada
  - **Feita quando**: duplicado não cria nem conta nem senha; sucesso devolve temporária que autentica com troca forçada
  - **Teste**: `test/the_band/tenants_cadastro_test.exs` — violação primeiro (duplicado: contagens inalteradas), depois o fluxo temporária→gate de troca

- [ ] T003 A leitura estreita do conflito
  - **Pronta quando**: T002 concluída
  - **Descrição**: `Tenants.user_of_person/2` — conta com elo vigente para a pessoa, ou nil; uma consulta filtrada por tenant. Chamada só no caminho do `:taken`
  - **Feita quando**: devolve a conta dona quando há elo vigente; nil sem elo; nil para pessoa de outro tenant
  - **Teste**: mesmo arquivo — os três casos, incluindo a violação entre tenants

## Phase 3: US1 — Cadastrar a pessoa: nome e e-mail (P1)

- [ ] T004 [US1] O cadastro na tela, com a temporária de uma vez
  - **Pronta quando**: T002 concluída
  - **Descrição**: `accounts_live` — o evento de criar passa a `cadastrar_conta/3`; a temporária aparece uma vez e some no evento seguinte (padrão do reset); frases novas em dgettext (gate da 047)
  - **Feita quando**: cadastro mostra a temporária; duplicado recusa com frase do catálogo; testes da 045 da tela INALTERADOS e verdes (L71)
  - **Teste**: `test/the_band_web/live/accounts_elo_test.exs` — cadastro feliz + duplicado; e `accounts_test.exs` da 045 sem diff

## Phase 4: US2 — Associar a conta do GitHub, na mesma área (P1)

- [ ] T005 [US2] A lista diz quem tem GitHub, numa consulta
  - **Pronta quando**: T004 concluída
  - **Descrição**: lista de contas com o elo vigente e o login observado via join único (L38); ausência nomeada na linha sem elo (FR-003)
  - **Feita quando**: linha com elo mostra o login; sem elo mostra a ausência; contagem de consultas da tela não cresce por linha
  - **Teste**: mesmo arquivo — as duas linhas, e o teto de consultas na forma L38

- [ ] T006 [US2] Associar com busca, e o conflito nomeado
  - **Pronta quando**: T005 concluída
  - **Descrição**: formulário por linha com busca `EO.list_people(q:, limit: 8)` disparada por evento; resultado com nome, login e organização; escolher chama `declare_person/4`; `:taken` recusa nomeando a conta dona via `user_of_person/2`; 0 resultados é ausência nomeada
  - **Feita quando**: associar funciona e a linha atualiza; pessoa já vinculada recusa COM o e-mail da dona; contagens inalteradas na recusa (SC-003)
  - **Teste**: mesmo arquivo — violação primeiro (conflito nomeado), depois o feliz, depois a busca vazia

- [ ] T007 [US2] Revogar na área, e o login acompanha
  - **Pronta quando**: T006 concluída
  - **Descrição**: revogação por linha com confirmação (`revoke_person/3`); depois dela a linha volta à ausência e o username não entra mais (recusa única da 045)
  - **Feita quando**: elo fechado preserva `person_declared_at` e ganha `person_revoked_at`; username recusa; e-mail segue entrando
  - **Teste**: mesmo arquivo — o ciclo completo associar→revogar→login, com as asserções de auditoria

## Phase 5: Polish

- [ ] T008 Gates verdes e PR no padrão
  - **Pronta quando**: T001–T007 concluídas
  - **Descrição**: `mix gates > /tmp/gates_051.log 2>&1; echo "EXIT=$?" >> /tmp/gates_051.log` (14, L60); quickstart §1–§5 com evidências (capturas da lista nos dois estados e da recusa nomeada); PR no padrão 1.6.0
  - **Feita quando**: EXIT=0; evidências olhadas (L73); PR aberto
  - **Teste**: `tail -1 /tmp/gates_051.log` = `EXIT=0`; seção Issues com resumo por tarefa

## Dependencies

```text
T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008
```

MVP = US1 (T004): cadastro com temporária já vale sozinho. Sem [P]: tudo converge
na mesma tela e no mesmo arquivo de teste.
