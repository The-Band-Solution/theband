# Tarefas — Feature 021: os papéis, e quem os desempenha

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md)
**Contrato**: [contracts/papeis-e-alocacao.md](contracts/papeis-e-alocacao.md) · **Modelo**: [data-model.md](data-model.md)

Treze tarefas em quatro fases. Cada uma tem teste, e nenhum deles é `mix test` sozinho.

**As três histórias são P1 e vão juntas.** Catálogo sem alocação não promove nada; alocação sem
tela é dado que ninguém alcança. É a **L21**, e é por isso que não há MVP menor que as três.

```
F1  o alicerce      ← schema, migração e índice: uma tabela existe sem módulo
F2  o catálogo (US1) ← cadastrar, renomear, recusar remover em uso
F3  a alocação (US2) ← alocar, encerrar, e a evidência apontando para o vínculo
F4  a distinção (US3)← a tela mostra as duas coisas, e diz qual é qual
```

---

## F1 — o alicerce

### T001 Dar módulo ao vínculo que já existe

- **Pronta quando**: o contrato em [contracts/papeis-e-alocacao.md](contracts/papeis-e-alocacao.md)
  está escrito; a decisão do R1 registra que a tabela existe sem schema.
- **Descrição**: `lib/the_band/ontology/seon/eo/schemas/team_membership.ex`, mapeando
  `eo_team_memberships` — `person_id`, `team_id`, `organizational_role_id`, `started_at`,
  `ended_at`, `internal_id`, `record_version`. Mesmo formato dos vizinhos do diretório.
  **Nenhuma migração aqui**: a tabela existe desde 2026-08-09.
- **Feita quando**: o schema carrega uma linha inserida por SQL cru; `organizational_role_id`
  continua obrigatório no changeset.
- **Teste**: `test/the_band/ontology/seon/eo/vinculo_schema_test.exs` — changeset sem papel é
  inválido, e a mensagem nomeia o campo.

### T002 Registrar quem declarou o vínculo

- **Pronta quando**: T001 concluída.
- **Descrição**: migração acrescentando `declared_by_user_id` a `eo_team_memberships`,
  referenciando `users`, **anulável** — FR-011, data-model. Nulo é permitido de propósito:
  proibir obrigaria a inventar um usuário-sistema, e autor falso mente mais que autor ausente.
- **Feita quando**: a coluna existe e aceita nulo; o `down` da migração a remove.
- **Teste**: `mix ecto.migrate` e `mix ecto.rollback` numa ida e volta limpa, e o schema lê a
  coluna depois.

### T003 Impedir a alocação repetida, sem proibir o histórico

- **Pronta quando**: T002 concluída.
- **Descrição**: índice **parcial** único em
  `(tenant_id, person_id, team_id, organizational_role_id) WHERE ended_at IS NULL` —
  data-model, R5. Único simples proibiria quem saiu e voltou, e apagar a linha antiga para
  permitir a nova seria apagar dado.
- **Feita quando**: inserir a mesma combinação vigente duas vezes falha; inserir a segunda com
  `ended_at` preenchido na primeira **passa**.
- **Teste**: `test/the_band/ontology/seon/eo/alocacao_test.exs` — o caso do histórico é o que
  importa: mesma pessoa, mesmo papel, mesma equipe, períodos distintos, **duas linhas**.

---

## F2 — o catálogo *(US1, P1)*

**Meta**: a organização declara quais papéis reconhece.

**Teste independente**: cadastrar `developer`, e conferir que a contagem de vínculos continua
zero — cadastrar papel não promove nada sozinho.

### T004 [US1] Cadastrar papel organizacional

- **Pronta quando**: o contrato existe, seção 1.
- **Descrição**: `create_role/2` e `list_roles/2` em
  `lib/the_band/ontology/seon/eo/commands.ex` e `queries.ex`, com `defdelegate` na fachada. O
  índice único por `(tenant_id, code)` já existe — FR-001, FR-002.
- **Feita quando**: dois papéis com o mesmo código no mesmo tenant são recusados, e a mensagem
  diz que o código já existe; o mesmo código em outro tenant é aceito.
- **Teste**: `test/the_band/ontology/seon/eo/papeis_test.exs` — o caso de outro tenant é o que
  prova o escopo, e não o de duplicata.

### T005 [P] [US1] Renomear sem trocar o código

- **Pronta quando**: T004 concluída.
- **Descrição**: `rename_role/3` — muda `name`, **nunca** `code`. É por ele que os vínculos
  referenciam o papel, e trocá-lo seria trocar a identidade — FR-004, contrato seção 1.
- **Feita quando**: depois de renomear, o código é o mesmo e os vínculos continuam apontando.
- **Teste**: no mesmo arquivo — renomear e afirmar `code` inalterado; a asserção é sobre o que
  **não** mudou.

### T006 [US1] Recusar remover papel em uso

- **Pronta quando**: T004 e T001 concluídas — sem o schema do vínculo não há o que contar.
- **Descrição**: `delete_role/2` devolve `{:error, {:in_use, quantos}}` quando há vínculo
  apontando — FR-005, contrato seção 1. O número vai na resposta, e não só no log: quem lê a
  recusa precisa saber o tamanho do que a impede.
- **Feita quando**: papel sem vínculo é removido; papel com dois vínculos devolve `{:in_use, 2}`
  e **continua existindo**.
- **Teste**: no mesmo arquivo — depois da recusa, `list_roles/2` ainda o traz.

### T007 [P] [US1] Sugerir os papéis da ontologia, sem cadastrá-los

- **Pronta quando**: T004 concluída.
- **Descrição**: `suggested_roles/0` lê os quatro papéis da SRO pela API da base de conhecimento,
  **nunca por caminho de arquivo** — FR-003, princípio IX. Devolve lista e não escreve.
- **Feita quando**: quatro sugestões voltam, com código e nome; nenhuma linha é gravada.
- **Teste**: no mesmo arquivo — chamar `suggested_roles/0` e afirmar que `count_roles/1`
  continua **zero**. É a SC-004, e a asserção é a ausência de escrita.

### T008 [US1] Tela do catálogo de papéis

- **Pronta quando**: T004 a T007 concluídas.
- **Descrição**: LiveView em `lib/the_band_web/live/roles_live/index.ex`, rota restrita a
  administrador como `/tools` já é — FR-017. Usa o componente `data_table`. Quando não há papel,
  a tela diz **quantas evidências esperam por um** — FR-013.
- **Feita quando**: com zero papéis, a tela mostra as quatro sugestões e o número de evidências
  pendentes; cadastrar pela tela cria um; renomear pela tela preserva o código.
- **Teste**: `test/the_band_web/live/papeis_test.exs` — o estado vazio afirma o número de
  evidências, e um `refute` garante que nenhuma sugestão foi gravada ao abrir a tela.

---

## F3 — a alocação *(US2, P1)*

**Meta**: evidência vira vínculo, com papel e período.

**Teste independente**: alocar uma pessoa e conferir que o número de evidências **não muda**.

### T009 [US2] Alocar pessoa a papel numa equipe

- **Pronta quando**: T003 e T004 concluídas; contrato seção 3 escrito.
- **Descrição**: `allocate/2` em `commands.ex`. `started_at` **ausente grava nulo**, e nunca a
  data de hoje: inventar afirmaria que a alocação começou agora, e o que se sabe é que ninguém
  disse quando — FR-007, contrato. `ended_at` anterior a `started_at` devolve
  `{:error, :period_inverted}`. Quando vem `evidence_id`, a evidência passa a apontar para o
  vínculo — FR-009.
- **Feita quando**: dois papéis diferentes na mesma equipe são aceitos; o mesmo papel vigente
  duas vezes devolve `{:error, :already_allocated}`; a evidência informada aponta para o vínculo.
- **Teste**: `test/the_band/ontology/seon/eo/alocacao_test.exs` — o caso de **dois papéis
  aceitos** é o que prova a FR-006a, e ele falharia com um índice único simples.

### T010 [US2] Encerrar sem apagar

- **Pronta quando**: T009 concluída.
- **Descrição**: `end_allocation/3` grava `ended_at` — FR-010. Encerrar de novo devolve
  `{:error, :already_ended}` e **não reescreve** a data da primeira: a segunda tentativa é
  engano de quem opera, e sobrescrever perderia quando de fato terminou.
- **Feita quando**: a contagem de vínculos é a mesma antes e depois de encerrar; a data da
  primeira permanece depois da segunda tentativa.
- **Teste**: no mesmo arquivo — a asserção é a **contagem**, e não a existência da linha: "o
  vínculo existe" passaria mesmo se outro tivesse sido apagado.

### T011 [US2] Provar que a coleta não apaga a declaração

- **Pronta quando**: T009 concluída.
- **Descrição**: nenhum código de produção — é o teste da garantia central da feature.
  `mark_evidence_no_longer_observed/3` toca **apenas** a evidência, e o vínculo permanece
  vigente — FR-014, R3. Se a implementação divergir, o conserto é aqui.
- **Feita quando**: depois de a coleta marcar a evidência, o vínculo continua com `ended_at`
  nulo, e a contagem de `eo_team_memberships` é idêntica.
- **Teste**: `test/the_band/ontology/seon/eo/coleta_nao_apaga_declaracao_test.exs` — contar
  antes e depois, e afirmar a igualdade. Uma coleta apagando declaração humana é o pior
  resultado possível desta feature.

---

## F4 — a distinção *(US3, P1)*

**Meta**: quem lê a página distingue o que a origem mostrou do que alguém afirmou.

**Teste independente**: numa pessoa com evidência e alocação, as duas aparecem com origem
visível.

### T012 [US3] Mostrar papel declarado ao lado da participação observada

- **Pronta quando**: T009 concluída.
- **Descrição**: `lib/the_band_web/live/people_live/show.ex` ganha o bloco de papéis, separado
  do de participação. O de papéis diz **declarado por quem e quando**; o de participação
  continua dizendo **observado**, com o nível rotulado como acesso — FR-012, FR-015.
  Equipe derivada é dita como derivada.
- **Feita quando**: pessoa sem alocação mostra "papel pendente"; pessoa alocada mostra papel,
  período e autor; os dois blocos são distinguíveis **lendo**, sem adivinhar.
- **Teste**: `test/the_band_web/live/papel_declarado_test.exs` — e o caso decisivo é
  `refute html =~ "MAINTAINER"` dentro do bloco de papéis. É a SC-006, e ela afirma uma
  **ausência**.

### T013 [US3] Dizer que a participação acabou, sem encerrar o papel

- **Pronta quando**: T011 e T012 concluídas.
- **Descrição**: quando a evidência está marcada como não mais observada e o vínculo continua
  vigente, a tela mostra os dois e diz que a participação não aparece mais na origem — FR-014.
  **Não** encerra, não esconde, não avisa como erro: é estado, e quem lê decide.
- **Feita quando**: a tela mostra o papel vigente e a frase sobre a evidência, ao mesmo tempo.
- **Teste**: no mesmo arquivo — marcar a evidência e afirmar que o papel **continua** na tela,
  junto da frase. Um teste que só afirmasse a frase não pegaria o papel tendo sumido.

---

## Dependências

```
T001 ─► T002 ─► T003 ─┬─► T009 ─► T010
                      │      └──► T011 ─► T013
T004 ─┬─► T005        │              ▲
      ├─► T006 ◄──T001│              │
      ├─► T007        └─► T012 ──────┘
      └─► T008
```

**Em paralelo**: T005, T006 e T007 depois de T004; T012 e T010 depois de T009.

## Escopo mínimo entregável

**As três histórias juntas.** Não há MVP menor: catálogo sem alocação não promove nada, e
alocação sem tela é dado que ninguém alcança — L21.

O que **pode** ser adiado sem quebrar nada: a T013, que é o caso da evidência marcada. Ela é
rara hoje e vira dívida declarada se ficar de fora.

## Validação de formato

Treze tarefas. Todas com título curto sem comando nem caminho, e as quatro seções. Nenhum
`Feita quando` repete o título, e nenhum `Teste` é `mix test` sozinho.

**Cinco tarefas têm teste que afirma uma ausência ou uma igualdade** — T005, T007, T010, T011 e
T012. É onde uma feature de cadastro escorrega sem ninguém ver: o caminho feliz passa igual nos
dois casos.
