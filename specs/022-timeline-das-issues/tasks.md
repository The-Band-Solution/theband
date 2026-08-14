# Tarefas — Feature 022: a timeline da issue

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md)
**Contrato**: [contracts/atividade-executada.md](contracts/atividade-executada.md) · **Modelo**: [data-model.md](data-model.md)

Treze tarefas em quatro fases. Cada uma tem teste, e nenhum deles é `mix test` sozinho.

**A fase 0 já foi feita**, em 2026-08-14, contra a API real — e o que ela achou mudou o escopo:
`ProjectV2ItemStatusChangedEvent` **está** na timeline da issue, com estado anterior, novo e
autor. A dependência da [#181](https://github.com/The-Band-Solution/theband/issues/181) caiu.

```
F1  a atividade executada  ← a forma que commits e implantações vão herdar
F2  coletar a timeline      ← dentro da janela da feature 020
F3  a tela que mostra e recusa ← o teto: sem ela, o dado existe e ninguém alcança
F4  as máximas             ← a detecção que o YAML já declara
```

---

## F1 — a atividade executada *(US1, P1)*

**Meta**: existir onde registrar uma ocorrência de atividade.

**Teste independente**: gravar o mesmo evento duas vezes produz uma linha.

### T001 Criar a tabela da atividade executada

- **Pronta quando**: o contrato existe; o `data-model.md` declara as colunas e o que a tabela
  deliberadamente não tem.
- **Descrição**: migração criando `spo_performed_project_activities`, com o prefixo do módulo
  ontológico como `cmpo_` e `eo_` já usam. `activity_type` é **texto** e não enum — o conjunto é
  do mundo, e um enum faria a coleta falhar ao achar um tipo novo. A ligação é `subject_type` +
  `subject_id`, e **não** `collected_issue_id`: um commit não tem issue — R1.
- **Feita quando**: a tabela existe com as colunas do modelo; o `down` a remove; `organization_id`,
  `project_id`, `performer_id`, `concept_id` e `source_external_id` aceitam nulo.
- **Teste**: `mix ecto.migrate` e `mix ecto.rollback` numa ida e volta limpa.

### T002 Impedir a ocorrência duplicada

- **Pronta quando**: T001 concluída.
- **Descrição**: índice único em `(tenant_id, internal_id)`, onde `internal_id` é o hash do
  critério de identidade da ontologia — **com representação canônica para os componentes
  ausentes**, que a ontologia exige explicitamente para o resultado ser determinístico.
- **Feita quando**: dois eventos com o mesmo critério colidem; dois com `performer_id` nulo e
  instantes diferentes não colidem.
- **Teste**: `test/the_band/ontology/seon/spo/atividade_test.exs` — o caso do executor nulo é o
  que importa: sem representação canônica, dois nulos gerariam hashes diferentes.

### T003 [P] Gravar a ocorrência

- **Pronta quando**: T002 concluída; contrato seção 1.
- **Descrição**: `record_activity/2`, devolvendo `:outcome` no campo virtual que `Person`,
  `CollectedIssue` e `ObservedRepository` já usam. **`:updated` não existe aqui**: uma ocorrência
  não muda — ela aconteceu.
- **Feita quando**: gravar duas vezes devolve `:created` e depois `:unchanged`, com uma linha; o
  evento sem executor grava `performer_id` nulo e `performer_login` preenchido.
- **Teste**: no mesmo arquivo — a asserção é a **contagem** depois da segunda gravação.

### T004 [P] Ler as atividades de uma entidade

- **Pronta quando**: T003 concluída.
- **Descrição**: `list_activities/3` em ordem **crescente** de `occurred_at` — é a sequência do
  que aconteceu, e inverter faria a tela contar a história de trás para frente. E
  `count_activity_types/1`, que alimenta a FR-010.
- **Feita quando**: a lista sai em ordem cronológica; a contagem inclui os tipos de conceito nulo.
- **Teste**: no mesmo arquivo — a contagem por tipo **inclui** os sem conceito, e é isso que o
  teste afirma: são eles que dizem o que a rede ainda não nomeia.

---

## F2 — coletar a timeline *(US1, P1)*

**Meta**: os eventos chegam, e nenhum é descartado.

**Teste independente**: origem devolve cinco eventos, dois sem conceito; cinco linhas são
gravadas.

### T005 [US1] Pedir a timeline junto da issue

- **Pronta quando**: T003 concluída. A fase 0 **já confirmou** que `timelineItems` vem na mesma
  consulta e aceita `itemTypes:`.
- **Descrição**: `priv/connectors/github/queries/issues.graphql` ganha `timelineItems`, com os
  tipos medidos em 2026-08-14: `ProjectV2ItemStatusChangedEvent`, `AssignedEvent`,
  `UnassignedEvent`, `ClosedEvent`, `ReopenedEvent`, `LabeledEvent`, `SubIssueAddedEvent`,
  `ParentIssueAddedEvent`, `IssueTypeAddedEvent`, `AddedToProjectV2Event`,
  `CrossReferencedEvent`. **`IssueComment` fica de fora** — é a
  [#318](https://github.com/The-Band-Solution/theband/issues/318).
- **Feita quando**: a consulta devolve os eventos; o máximo medido numa issue é 18, e a
  paginação de 100 cobre com folga.
- **Teste**: `test/the_band/ingestion/timeline_test.exs` — a borda simulada devolve um payload
  capturado da origem real, e a asserção é que a variável de tipos chegou.

### T006 [US1] Registrar cada evento como atividade

- **Pronta quando**: T005 e T003 concluídas.
- **Descrição**: cada nó da timeline vira uma chamada a `record_activity/2`, com
  `subject_type: "issue"`. O tipo é gravado **como a origem o nomeia** — FR-005. O conceito vai
  nulo quando a rede não o nomeia, e nulo aqui é **informação**, não falta de dado.
- **Feita quando**: cinco eventos recebidos produzem cinco linhas; dois deles com `concept_id`
  nulo e `activity_type` com o nome do GitHub.
- **Teste**: no mesmo arquivo — **a asserção é a soma**: classificados mais sem conceito igual ao
  total recebido. É a SC-003, e "os eventos apareceram" passaria igual com o descarte.

### T007 [US1] Não pedir timeline do que não foi percorrido

- **Pronta quando**: T005 concluída.
- **Descrição**: a timeline entra na janela da feature 020 — repositório pulado não a tem
  pedida, e issue cuja atualização não mudou também não. FR-011, FR-012.
- **Feita quando**: a segunda coleta sem atividade na origem faz zero pedidos de timeline.
- **Teste**: no mesmo arquivo — a borda simulada **reprova o teste** se `timelineItems` for
  pedido para o repositório parado. "Não trouxe eventos" não prova que não pediu.

### T008 [P] [US1] Ligar o executor à pessoa conhecida

- **Pronta quando**: T006 concluída.
- **Descrição**: o `login` do autor é resolvido para `person_id` pelo mapa que a coleta já monta
  — o mesmo `ctx.pessoas` de `gravar_issue/3`. **Login não resolvido grava `performer_login` e
  `performer_id` nulo**, e não cria pessoa: criar sem proveniência é o que a plataforma recusa.
- **Feita quando**: evento de pessoa conhecida tem `person_id`; evento de
  `github-project-automation` tem `performer_id` nulo e o login preenchido.
- **Teste**: no mesmo arquivo — o caso do robô é o que importa, e ele é **160 das 357**
  movimentações medidas.

---

## F3 — a tela que mostra, e a que recusa *(US2, P1)*

**Meta**: quem lê vê a sequência, e quem procura cycle time descobre o que falta.

**Teste independente**: uma issue sem movimentação não mostra cycle time, e a tela diz por quê.

### T009 [US2] Mostrar a sequência na página da issue

- **Pronta quando**: T006 concluída.
- **Descrição**: `work_item_live/show.ex` ganha o bloco da timeline, em ordem cronológica, com
  autor e instante — FR-014. Evento sem executor humano **é exibido dizendo isso**, e não
  omitido: 160 das 357 movimentações são de robô, e escondê-las daria uma história falsa.
- **Feita quando**: os eventos aparecem em ordem; o de automação diz que não houve executor
  humano; o de tipo sem conceito aparece com o nome da origem.
- **Teste**: `test/the_band_web/live/timeline_test.exs` — e um `refute` de que o evento de robô
  sumiu da tela.

### T010 [US2] Recusar o cycle time, e dizer o que falta

- **Pronta quando**: T009 concluída.
- **Descrição**: `cycle_time/2` devolve `{:error, :no_start_signal}` quando não há movimentação
  que a regra reconheça como início. A tela diz **qual decisão falta** — e a medida a tornou
  concreta: o quadro tem `Backlog`, `Ready`, `In review` e `Done`, e **nenhum se chama "Em
  andamento"** — FR-008.
- **Feita quando**: a tela não mostra cycle time e nomeia o que falta; **e não mostra lead time
  no lugar** — FR-009.
- **Teste**: no mesmo arquivo — `refute html =~ "lead time"` no bloco de cycle time. São medidas
  diferentes, e trocá-las em silêncio faz a organização decidir sobre outra pergunta.

### T011 [US2] Listar os estados e tipos observados

- **Pronta quando**: T004 e T006 concluídas.
- **Descrição**: a tela mostra os tipos de evento e os **estados de quadro** observados, com a
  frequência de cada um — FR-010. É o que permite alguém declarar qual movimentação marca o
  começo, e a medida mostra por que isso não é óbvio: `Ready` significa pronto para pegar, ou já
  pego?
- **Feita quando**: a lista traz tipo, conceito quando houver, e contagem; os estados aparecem
  com a frequência.
- **Teste**: no mesmo arquivo — a lista inclui um tipo de conceito nulo, e isso é afirmado.

---

## F4 — as máximas *(a detecção que o YAML declara)*

**Meta**: os quatro antipadrões passam a ser detectados — e a fase 0 tornou isso possível nesta
feature.

### T012 Detectar os quatro antipadrões

- **Pronta quando**: T006 e T010 concluídas; `process_antipatterns.yaml` está na base — e está,
  desde 2026-08-14.
- **Descrição**: a detecção lê as regras da base de conhecimento, **nunca de lista fixa no
  código** — princípio IV, e é o mesmo desenho das regras de mapeamento. `enforcement: detection`
  significa relatar e nunca recusar.
  **Movimentação de automação não conta como início**: um cartão que o robô moveu para `Done` ao
  fechar a issue não diz que alguém trabalhou nela — R2.
- **Feita quando**: os quatro casos do YAML são detectados sobre dado montado; a detecção não
  grava nada em `spo_performed_project_activities` — ela lê.
- **Teste**: `test/the_band/mapping/antipadroes_test.exs` — um caso por máxima, **mais um que
  afirma que zero detectados com zero movimentação coletada é dito como "não olhei"**, e não como
  "processo saudável". É o limite escrito no próprio YAML, e a L57.

### T013 Sinalizar o antipadrão estrutural do quadro

- **Pronta quando**: T011 concluída — a tela já mostra os estados observados por quadro.
- **Descrição**: quando nenhum estado do quadro significa "em andamento", a plataforma sinaliza
  `process.ap05` e diz a **consequência**: o cycle time é impossível para **toda** issue daquele
  quadro — FR-010b. E sinaliza `process.ap06` quando dois estados parecem duplicar significado,
  **sem decidir** que duplicam: mostra e alguém confirma, como na alocação de papel.
  Medido em 2026-08-14: o quadro da `The-Band-Solution` não tem estado de andamento; o da
  `leds-conectafapes` tem `In Progress`, e também tem `To Do` **e** `Todo`.
- **Feita quando**: o quadro sem estado de andamento é sinalizado, com a consequência escrita; o
  quadro que tem estado de andamento **não** é sinalizado.
- **Teste**: `test/the_band/mapping/antipadroes_test.exs` — e o caso que importa é o **negativo**:
  um quadro com `In Progress` não sinaliza. Aviso que aparece sempre treina quem lê a ignorá-lo,
  e é justamente o aviso que importa quando aparece.

---

## Dependências

```
T001 ─► T002 ─┬─► T003 ─┬─► T004 ──────────────┐
              │         ├─► T005 ─► T006 ─┬─► T008
              │         │         └─► T007 │
              │         │                  ├─► T009 ─► T010 ─► T012
              │         │                  └─► T011 ◄─────────┘
                                                  └─► T013
```

**Em paralelo**: T003 com T004; T007 com T008 depois de T006.

## Escopo mínimo entregável

**F1 mais F2** — a atividade existe e é coletada. Sem a F3, porém, o dado não tem consumidor
visível, e é a **L21**: componente sem tela não é entrega.

**F1 a F3 é o entregável honesto.** A F4 pode ir para o sprint seguinte, e vira dívida declarada
se ficar de fora — mas ela é barata, porque a regra já está no YAML e a fase 0 destravou a
movimentação.

## Validação de formato

Treze tarefas, todas com título curto e as quatro seções. Nenhum `Feita quando` repete o título, e
nenhum `Teste` é `mix test` sozinho.

**Quatro tarefas provam uma ausência, uma soma ou uma igualdade** — T002, T006, T007 e T010. É
onde uma feature de coleta escorrega: o caminho feliz passa igual quando o dado é descartado.
