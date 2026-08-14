# Tarefas — Feature 020: coletar só o que mudou

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md)
**Contrato**: [contracts/coleta-incremental.md](contracts/coleta-incremental.md) · **Modelo**: [data-model.md](data-model.md)

Quatorze tarefas em seis fases. Cada uma tem teste, e nenhum deles é `mix test` sozinho.

**A ordem é dependência, e não preferência:**

```
F0  verificar a origem      ← bloqueia F4 e F5, e só ela precisa da chave mestra
F1  a contagem dizer verdade ← instrumento de medida da feature inteira
F2  escopar a marca          ← conserto por si, e pré-requisito de F3 e F4
F3  pular repositório parado  ← o corte grosso: 106 de 121
F4  trazer só o alterado      ← depende de F0
F5  a rede de segurança       ← a FR-012
```

**F1 e F2 valem sozinhas, com a coleta ainda completa.** É o que permite provar depois que o corte
não mudou o resultado — sem elas, "baixou 5%" e "perdeu 95%" produzem a mesma tela.

---

## F0 — verificar a origem

### T001 Conferir a janela contra a API real

- **Pronta quando**: nada além do repositório e da chave mestra, que é da pessoa mantenedora.
- **Descrição**: três consultas ao GraphQL do GitHub, numa sessão `iex -S mix`, com um repositório
  real. **(a)** `issues(filterBy: {since: <ontem>})` devolve menos que sem o filtro; **(b)** uma
  issue comentada e não editada aparece na janela; **(c)** remover uma sub-issue e reconsultar o
  **pai** — ele aparece na janela? As três estão em [research.md](research.md#o-que-fica-pendente-de-medida),
  e a terceira decide o desenho da FR-012. **Nenhuma linha de F4 ou F5 antes desta tarefa** — é a
  L23: verificação que não aconteceu lida como verificação que passou.
- **Feita quando**: as três respostas estão escritas em `research.md`, cada uma com a consulta que
  a produziu e a data; e o `contracts/coleta-incremental.md` foi corrigido onde divergir.
- **Teste**: o próprio `research.md` deixa de dizer "NÃO MEDIDO AQUI" nos R1, R2 e R3, e passa a
  citar a consulta. Quem revisar compara o texto com o que a API devolveu.

---

## F1 — a contagem dizer a verdade *(US1, P1)*

**Meta**: a tela de sincronização para de mostrar `0 / 0 / 0` para toda execução.

**Teste independente**: uma coleta com uma issue nova, uma alterada e uma inalterada faz a tela
dizer 1, 1 e 1.

### T002 [US1] Contar o que a escrita de issue fez

- **Pronta quando**: nada — o `Ingestion.tally/2` já distingue os três casos, e o upsert já
  devolve o resultado.
- **Descrição**: em `lib/the_band/ingestion/github_work_items.ex:408`, trocar
  `Ingestion.tally(:unchanged)` por `Ingestion.tally(resultado.outcome)`, no formato que
  `sync_github_eo.ex:406` já usa — FR-001, FR-004, research.md R6.
- **Feita quando**: uma coleta que grava issue nova soma em `records_created`; uma que altera soma
  em `records_updated`; e a que não muda nada soma só em `records_collected`.
- **Teste**: `test/the_band/ingestion/contagem_da_execucao_test.exs` — três coletas encenadas com
  a borda HTTP simulada, uma por caso, e a asserção é sobre as três colunas de `syncs`, não sobre
  o log.

### T003 [P] [US1] Contar o que a escrita de repositório fez

- **Pronta quando**: T002 concluída — o formato do resultado é o mesmo, e fazer as duas juntas
  esconderia qual delas quebrou.
- **Descrição**: o mesmo em `github_work_items.ex:121`, para `CMPO.observe_repository/3` — FR-004.
- **Feita quando**: repositório observado pela primeira vez soma em `records_created`; o já
  observado, não.
- **Teste**: no mesmo arquivo de T002, um caso que coleta a mesma organização duas vezes e afirma
  que a segunda tem `records_created` **zero** e `records_collected` igual à primeira.

### T004 [US1] Preservar a contagem na interrupção

- **Pronta quando**: T002 e T003 concluídas.
- **Descrição**: conferir que `Ingestion.finish/3` com `:interrupted` não zera as três colunas, e
  que a tela as exibe para execução interrompida — FR-003. É leitura e teste; se o código já
  estiver certo, a tarefa entrega o teste que o prova.
- **Feita quando**: uma execução interrompida no meio mostra o que já tinha sido feito, e nunca
  zero.
- **Teste**: no mesmo arquivo — coletar duas issues, interromper, e afirmar `records_created == 2`
  na linha de `syncs`.

---

## F2 — escopar a marca *(FR-012, pré-requisito de F3 e F4)*

**Meta**: "não apareceu" volta a significar algo em relação ao que foi olhado.

**Teste independente**: com a coleta ainda completa, os 52 vínculos marcados continuam 52.

### T005 [US2] Marcar pelo que foi percorrido

- **Pronta quando**: o contrato em [contracts/coleta-incremental.md](contracts/coleta-incremental.md#1-a-marca-de-vínculo-ausente-passa-a-receber-o-que-foi-olhado)
  está escrito, com a regra da lista vazia.
- **Descrição**: `mark_decomposition_links_no_longer_observed/3` em
  `lib/the_band/work_items/commands.ex` passa a receber `[Ecto.UUID.t()]` de pais percorridos, em
  lugar do `observed_repository_id`. **Lista vazia devolve `{:ok, 0}` e não marca nada.** Trocar a
  assinatura, e não acrescentar parâmetro opcional: o padrão obtido por esquecimento não pode ser
  o que marca 4261 vínculos falsos — research.md R3, FR-012.
- **Feita quando**: a função não conhece mais repositório; `lib/the_band/work_items.ex` delega com
  a assinatura nova; e nenhum chamador passa id de repositório.
- **Teste**: `test/the_band/ingestion/marca_escopada_test.exs` — cem pais no repositório, um
  percorrido e largado pela origem: **um** marcado. Os outros noventa e nove intactos, e a
  asserção é essa, não a primeira.

### T006 [US2] Passar os pais percorridos na coleta

- **Pronta quando**: T005 concluída.
- **Descrição**: `marcar_vinculos_ausentes/3` em `github_work_items.ex:349` acumula os ids das
  issues gravadas no repositório e os repassa. Com a coleta ainda completa, o conjunto é o mesmo
  de antes — e é isso que torna a mudança provável por regressão.
- **Feita quando**: numa coleta completa o número de marcados é **idêntico** ao de antes da
  mudança.
- **Teste**: `test/the_band/ingestion/github_work_items_test.exs` — o caso existente de vínculo
  largado continua marcando exatamente aquele, e o teste não muda. Um teste que precisa mudar aqui
  é sinal de que o comportamento mudou.

---

## F3 — pular repositório sem atividade *(US2, P1)*

**Meta**: 106 dos 121 repositórios deixam de ser consultados.

**Teste independente**: duas coletas seguidas sem atividade; a segunda não consulta issues de
repositório algum.

### T007 [US2] Decidir se o repositório é percorrido

- **Pronta quando**: o contrato da seção 3 está escrito, com a tabela dos quatro estados.
- **Descrição**: função que compara `cmpo_source_repositories.last_pushed_at` com
  `observed_repositories.issues_collected_at` e devolve `:sim` ou
  `{:nao, :sem_push_desde_a_revisao}` — FR-005, FR-006. **Data ausente responde `:sim`**: ausência
  de data não é ausência de mudança, e é a mesma regra da L47.
- **Feita quando**: os quatro estados da tabela do contrato têm resposta, e o motivo é átomo, não
  frase.
- **Teste**: `test/the_band/ingestion/pular_sem_atividade_test.exs` — um caso por linha da tabela,
  e o caso de `last_pushed_at` nulo afirma `:sim`.

### T008 [US2] Não consultar issues de repositório parado

- **Pronta quando**: T007 e T006 concluídas — sem o escopo da marca, pular marcaria tudo.
- **Descrição**: `coletar_issues/2` consulta T007 antes de paginar. Repositório pulado **não**
  chama `marcar_vinculos_ausentes/3`, e **não** grava `issues_collected_at` — FR-005, FR-008.
- **Feita quando**: a segunda coleta seguida faz zero consultas de issues; e nenhum vínculo é
  marcado nos pulados.
- **Teste**: no mesmo arquivo — a borda HTTP simulada **falha o teste** se for chamada para o
  repositório parado. Afirmar que "não trouxe issues" não prova que não pediu.

### T009 [US2] Gravar a revisão depois de percorrer

- **Pronta quando**: T008 concluída.
- **Descrição**: `issues_collected_at` passa a ser gravado **ao terminar o repositório**, nunca ao
  gravar issue — FR-010, data-model.md. Gravar antes faria a coleta interrompida congelar o
  repositório para sempre, porque o critério de pular olha justamente este campo.
- **Feita quando**: uma coleta interrompida no meio de um repositório deixa `issues_collected_at`
  como estava; e a seguinte o percorre inteiro.
- **Teste**: no mesmo arquivo — simular falha na segunda página e afirmar que o campo **não**
  mudou, e que a coleta seguinte pediu a primeira página de novo.

### T010 [P] [US2] Dizer quantos foram pulados, e por quê

- **Pronta quando**: T008 concluída.
- **Descrição**: o resultado da fase carrega a contagem por motivo, e o cartão de `/syncs` a exibe
  — FR-007. **Silêncio quando é zero**, pela mesma regra de "0 unreachable": a linha que aparece
  em toda execução treina quem lê a ignorá-la.
- **Feita quando**: uma execução com repositório pulado diz o número e o motivo; uma sem pular não
  mostra a linha.
- **Teste**: `test/the_band_web/live/sync_card_test.exs` — a tela mostra o texto quando há pulados,
  e o `refute` quando não há.

---

## F4 — trazer só a issue alterada *(US3, P2)*

**Meta**: dentro dos 15 repositórios com atividade, só as issues alteradas chegam.

**Teste independente**: repositório com 50 issues e uma alterada; a coleta traz uma.

### T011 [US3] Filtrar a consulta pela janela

- **Pronta quando**: **T001 concluída** — se `filterBy: {since:}` não filtrar como o schema diz,
  esta tarefa muda de forma.
- **Descrição**: `priv/connectors/github/queries/issues.graphql` ganha `$since` e
  `filterBy: {since: $since}`, e a ordenação passa de `CREATED_AT` para `UPDATED_AT` — contrato,
  seção 4. **`$since` nulo traz tudo**, que é o modo completo.
- **Feita quando**: com `$since` nulo, a consulta devolve o mesmo que antes; com data, devolve
  menos.
- **Teste**: `test/the_band/ingestion/janela_incremental_test.exs` — a borda simulada afirma que a
  variável `since` chegou com o valor esperado, e que ela é nula na coleta completa.

### T012 [US3] Aplicar a sobreposição da janela

- **Pronta quando**: T011 e T009 concluídas.
- **Descrição**: a coleta pede desde `issues_collected_at - 60s`, e a constante é nomeada e
  comentada — FR-011, contrato seção 5. O carimbo é da origem e a marca é da plataforma: os dois
  relógios não são o mesmo, e uma issue alterada no instante da revisão anterior cairia fora para
  sempre.
- **Feita quando**: a data enviada é anterior à gravada, pela sobreposição declarada.
- **Teste**: no mesmo arquivo — uma issue com `updatedAt` trinta segundos antes da última revisão
  **chega** na coleta seguinte.

---

## F5 — a rede de segurança *(FR-012)*

### T013 Coletar por inteiro de tempos em tempos

- **Pronta quando**: T012 concluída; e a resposta (c) de T001 está escrita — ela decide se esta
  fase é rede de segurança ou mecanismo principal.
- **Descrição**: `syncs.mode` com `check_constraint` — `"complete"` ou `"incremental"`, padrão
  `"complete"` —, e a decisão do modo no início da execução. A coleta completa continua disponível
  sob demanda na tela — FR-014, data-model.md.
- **Feita quando**: a coluna recusa valor fora dos dois; a tela diz qual foi o modo; e o botão de
  coleta completa existe.
- **Teste**: `test/the_band/ingestion/modo_da_coleta_test.exs` — gravar `"parcial"` levanta; e o
  round trip da migração (`mix ecto.migrate` e rollback) roda limpo.

### T014 Provar que completa e incremental convergem

- **Pronta quando**: T013 concluída.
- **Descrição**: o teste que fecha a feature. Uma sequência de coletas incrementais seguida de uma
  completa produz **o mesmo estado** que uma sequência só de completas — princípio III, e
  invariante 5 do data-model.
- **Feita quando**: as duas sequências produzem as mesmas issues vigentes, os mesmos vínculos
  marcados e as mesmas datas.
- **Teste**: `test/the_band/ingestion/convergencia_test.exs` — dois tenants, a mesma origem
  simulada, cadências diferentes, e a comparação é do estado inteiro, não de uma contagem.

---

## Dependências

```
T001 ──────────────────────────────► T011 ─► T012 ─► T013 ─► T014
                                                      ▲
T002 ─► T003 ─► T004                                  │
                                                      │
T005 ─► T006 ─► T007 ─► T008 ─► T009 ─────────────────┘
                          └────► T010
```

**Em paralelo**: T003 com T004 depois de T002; T010 com T009 depois de T008.

**T001 é a única que precisa da chave mestra**, e ela bloqueia só a F4 e a F5. As fases 1, 2 e 3
podem ser feitas inteiras sem a origem — e elas são 106 dos 121 repositórios de economia.

## Escopo mínimo entregável

**F1 e F2**, e elas não cortam nada: consertam a contagem e a marca. Entregues sozinhas, a
plataforma passa a dizer a verdade sobre o que cada coleta fez, e a marca de ausência fica correta
para o dia em que a coleta deixar de ser completa.

**F3 é o primeiro corte, e o maior** — 87,6% do trabalho, sem tocar na origem.

**F4 e F5 só depois da T001**, e a resposta dela pode mudar as duas.

## Validação de formato

Quatorze tarefas. Todas com título curto sem comando nem caminho, e as quatro seções —
`Pronta quando`, `Descrição`, `Feita quando`, `Teste`. Nenhum `Feita quando` repete o título, e
nenhum `Teste` é `mix test` sozinho.
