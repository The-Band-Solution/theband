# Tarefas — Feature 024: as caixas de tempo, e as issues dentro delas

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md)
**Contrato**: [contracts/caixas-de-tempo.md](contracts/caixas-de-tempo.md) · **Modelo**: [data-model.md](data-model.md)

Onze tarefas em cinco fases. Cada uma tem teste, e nenhum deles é `mix test` sozinho.

**A fase 0 já foi feita**, em 2026-08-15, contra a API real — e ela achou o que muda a ordem das
fases: **`sro.sprint` não tem critério de identidade declarado**, nem herdado de ancestral. A
feature 022 encontrou o dela pronto; aqui ele precisa ser escrito antes da migração.

```
F1  o critério na base      ← princípio I: a tabela nasce do critério, não o contrário
F2  a caixa de tempo        ← a primeira tabela SRO do repositório
F3  as issues dentro dela   ← onde a sobreposição medida vira dado
F4  coletar                 ← fase nova, por quadro, fora da janela da 020
F5  o que ficou fora        ← 150 dos 677 itens do DevOps
```

---

## F1 — o critério de identidade *(bloqueia tudo)*

**Meta**: `sro.sprint` passa a dizer o que o identifica.

**Teste independente**: `mix knowledge.validate` aceita a base, e a regra aparece no grafo.

### T001 Declarar a identidade do sprint

- **Pronta quando**: nada além do repositório. É a primeira, e o `research.md` R1 fixou a forma.
- **Descrição**: acrescentar `identity_criterion` a `sro.sprint` em
  `priv/knowledge_base/ontology/continuum/sro/modules/scrum_process.yaml`, com os componentes
  `tenant_id`, `source_system`, `source_instance`, `source_external_id`.
  **É Application Reference, e não hash de atributos** — a iteração tem identificador próprio na
  origem, e nome, data e duração são editáveis: um hash sobre eles trocaria a identidade a cada
  correção, duplicando a caixa. A proveniência é `project_decision`, e não `thesis`: a tese
  descreve o conceito sem dizer como identificá-lo numa ferramenta.
- **Feita quando**: a base valida com um artefato a mais; `sro.sprint` tem `identity_criterion`
  com os quatro componentes; a proveniência **não** diz `thesis`.
- **Teste**: `mix knowledge.validate` e `mix knowledge.graph` — e a asserção que importa é que o
  validador Python e o de Elixir **concordam**, que é o gate 13.

---

## F2 — a caixa de tempo *(US1, P1)*

**Meta**: existir onde registrar uma iteração.

**Teste independente**: gravar a mesma iteração duas vezes produz uma linha.

### T002 Criar a tabela das caixas de tempo

- **Pronta quando**: T001 concluída — sem o critério na base, a tabela não tem de onde nascer.
- **Descrição**: migração criando `sro_sprints` com as colunas do `data-model.md`, e índice único
  em `(tenant_id, internal_id)`. **`duration_days` é da iteração, nunca a do campo**: medido em
  2026-08-15, `Sprint 10` tem 3 dias num campo de 14. `ended_on` é derivado de início mais
  duração menos um, e não vem da origem.
- **Feita quando**: a tabela existe com as colunas do modelo; o `down` a remove; `board_title` e
  `completed` aceitam nulo.
- **Teste**: `mix ecto.migrate` e `mix ecto.rollback` numa ida e volta limpa, sem aviso de nome
  truncado.

### T003 [US1] Gravar a caixa de tempo

- **Pronta quando**: T002 concluída; contrato seção 1.
- **Descrição**: `record_sprint/2` em `lib/the_band/ontology/continuum/sro/commands.ex`,
  devolvendo `:outcome`. **Aqui `:updated` existe**, ao contrário de `record_activity/2` da 022:
  uma caixa de tempo muda — renomeia-se `Sprint 38`, corrige-se a data, a iteração passa de em
  curso a concluída.
- **Feita quando**: gravar duas vezes o mesmo `source_external_id` devolve `:created` e depois
  `:unchanged`, com uma linha; renomear a iteração na origem devolve `:updated` e **não** cria
  linha nova.
- **Teste**: `test/the_band/ontology/continuum/sro/sprint_test.exs` — o caso do renomear é o que
  importa: com hash de atributos ele criaria uma caixa órfã ao lado.

### T004 [P] [US1] Fronteira do módulo SRO

- **Pronta quando**: T003 concluída.
- **Descrição**: `lib/the_band/ontology/continuum/sro.ex` com `defdelegate` apenas — ADR 0003.
  **É a primeira fronteira SRO do repositório**, e o moduledoc precisa dizer o que ela não expõe
  e por quê, como fazem `CMPO` e `EO`.
- **Feita quando**: nenhum módulo fora de `SRO` alcança `Schemas.*` nem chama `Repo` sobre
  `sro_*`; o módulo contém só delegações.
- **Teste**: `mix credo --strict` limpo, e uma busca por `Repo` sobre `sro_` fora do módulo não
  encontra nada.

---

## F3 — as issues dentro da caixa *(US2, P1)*

**Meta**: a sobreposição medida vira dado, em vez de ser achatada.

**Teste independente**: uma issue em duas caixas produz dois vínculos.

### T005 [US2] Criar a associação issue e caixa

- **Pronta quando**: T002 concluída.
- **Descrição**: migração criando `sro_sprint_issues` com `no_longer_observed_at` e único em
  `(tenant_id, sprint_id, collected_issue_id)`. **Muitos-para-muitos porque a medida obrigou**:
  no DevOps, `527 + 203 = 730` vínculos sobre 677 itens. Uma coluna `sprint_id` em
  `collected_issues` teria de escolher uma das duas, e o Produtos Internos inverte a proporção.
- **Feita quando**: a tabela existe; a mesma issue aceita vínculo com dois sprints diferentes; o
  mesmo par não duplica.
- **Teste**: `mix ecto.migrate` e rollback, mais a inserção do par repetido levantando a violação
  de unicidade.

### T006 [US2] Associar a issue à caixa

- **Pronta quando**: T005 concluída; contrato seção 2.
- **Descrição**: `place_issue_in_sprint/3`, idempotente. E
  `mark_issues_no_longer_in_sprint/4`, **escopada ao sprint** e nunca ao tenant — marcar por
  tenant atingiria caixas que a execução nunca olhou, que é a **L19**.
- **Feita quando**: associar duas vezes o mesmo par produz um vínculo; a issue que saiu tem
  `no_longer_observed_at` preenchido e a **linha continua existindo**.
- **Teste**: no mesmo arquivo de teste da F3 — a asserção é que a **contagem de linhas não cai**
  quando uma issue sai do sprint. Apagar passaria numa asserção sobre "não está mais vinculada".

### T007 [P] [US2] Ler as issues de uma caixa

- **Pronta quando**: T006 concluída.
- **Descrição**: `list_sprints/2` e `list_sprint_issues/2` na fronteira. Só vínculos vigentes
  contam na listagem; o encerrado continua no banco.
- **Feita quando**: a listagem traz as issues vigentes com número e título; a issue com vínculo
  encerrado **não** aparece.
- **Teste**: no mesmo arquivo — e o caso afirmado é o do vínculo encerrado ausente da lista **com
  a linha ainda no banco**.

---

## F4 — coletar *(US1 e US2, P1)*

**Meta**: as caixas e os vínculos chegam da origem, sem gastar cota onde não há o que buscar.

**Teste independente**: um quadro sem campo de iteração não tem itens consultados.

### T008 [US1] Pedir os campos de iteração dos quadros

- **Pronta quando**: T003 concluída. A fase 0 **já confirmou** a forma da consulta e o custo:
  1 ponto para 26 quadros.
- **Descrição**: consulta nova em `priv/connectors/github/queries/project_iterations.graphql`,
  pedindo `projectsV2` com `fields` e, dentro de `ProjectV2IterationField`, `iterations` e
  `completedIterations`. **Os dois conjuntos entram** — `completed` distingue.
- **Feita quando**: os 15 campos medidos aparecem; `Quarter` **não** é filtrado; a duração
  registrada é a de cada iteração.
- **Teste**: `test/the_band/ingestion/sprints_test.exs` — a borda simulada devolve um payload
  capturado da origem real, e a asserção é que `Sprint 10` foi gravado com **3 dias**, e não 14.

### T009 [US2] Pedir os itens e os valores de iteração

- **Pronta quando**: T008 e T006 concluídas.
- **Descrição**: paginar `items` de 100 em 100 e ler `ProjectV2ItemFieldIterationValue`, com o
  nome do campo de origem. Item que não é issue — rascunho do Projects — **não vira issue
  inventada**.
- **Feita quando**: sobre o payload do DevOps, 527 vínculos saem do campo `Sprint` e 203 do
  `Quarter`; a soma é **maior** que os 677 itens do quadro.
- **Teste**: no mesmo arquivo — **a asserção é a soma ser maior que o total de itens**. Se der
  677 ou menos, alguma issue perdeu uma das duas caixas, que é o defeito que o modelo existe para
  impedir.

### T010 [US1] Não consultar quadro sem iteração

- **Pronta quando**: T009 concluída.
- **Descrição**: a coleta pula a consulta de itens para quadro sem campo de iteração — 15 dos 26
  medidos são assim. A fase é **por quadro**, e não entra na janela da feature 020: caixa de
  tempo não pertence a repositório, e quadro não tem `pushedAt`.
- **Feita quando**: quadro sem campo de iteração não produz consulta de itens, e isso **não** é
  erro nem aparece como falha na execução.
- **Teste**: no mesmo arquivo — a borda simulada **reprova** se `items` for pedido para quadro
  sem iteração. "Não trouxe caixas" não prova que não pediu.

---

## F5 — o que ficou fora da caixa *(US3, P2)*

**Meta**: a plataforma sabe dizer o que o quadro usa e o que ficou de fora — e distingue as duas
ausências.

### T011 [US3] Contar as issues fora de qualquer caixa

- **Pronta quando**: T009 concluída.
- **Descrição**: `count_issues_outside_any_sprint/2`, devolvendo
  `{:error, :board_has_no_iteration_field}` para quadro que não usa caixas — FR-009 e FR-010.
  Medido: **150 dos 677 itens do DevOps** estão fora de qualquer sprint.
- **Feita quando**: sobre o quadro DevOps a função devolve 150; sobre um quadro sem campo de
  iteração devolve o erro, e **nunca** `{:ok, 0}`.
- **Teste**: no arquivo de teste da fronteira SRO — e o caso que importa é o **segundo**:
  `{:ok, 0}` e `{:error, :board_has_no_iteration_field}` produzem o mesmo zero na tela e afirmam
  coisas opostas. É a L57.

---

## Dependências

```
T001 ─► T002 ─┬─► T003 ─┬─► T004
              │         ├─► T008 ─► T009 ─┬─► T010
              │         │                 └─► T011
              └─► T005 ─► T006 ─► T007
                            └──────► T009
```

**Em paralelo**: T004 com T005; T007 com T008 depois de T006.

## Escopo mínimo entregável

**T001 a T009.** É a fatia que responde "quais sprints existem e o que está em cada um" — o
pedido literal. A T010 é economia de cota e a T011 é a lacuna, e as duas entregam valor sozinhas
depois.

## Validação de formato

Onze tarefas, todas com título curto e as quatro seções. Nenhum `Feita quando` repete o título, e
nenhum `Teste` é `mix test` sozinho.

**As três asserções que carregam a feature**, e nenhuma delas é "o dado apareceu":

| Tarefa | O que ela afirma |
|---|---|
| T009 | a soma dos vínculos é **maior** que o total de itens — a sobreposição não foi achatada |
| T010 | a borda **reprova** se o item for pedido onde não há iteração — pedir é diferente de trazer vazio |
| T011 | `{:error, :board_has_no_iteration_field}` **não** é `{:ok, 0}` |
