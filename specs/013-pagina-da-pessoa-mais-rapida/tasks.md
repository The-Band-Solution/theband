# Tarefas — Feature 013: a página da pessoa que não varre tudo

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md)
**Branch**: `019-a-pagina-da-pessoa-que-nao-varre-tudo` · **Uma migração**, só índice

Dez tarefas em quatro fases. Cada uma tem teste, e nenhuma delas é `mix test` sozinho.

**Ordem que é dependência**: F1 fixa o que não pode mudar · F2 muda · F3 prova que não mudou ·
F4 mede.

**A F3 é a fase que ninguém pula.** Otimização que muda a resposta não é otimização — é defeito com
tempo melhor, e este seria silencioso: a tela continuaria abrindo.

---

## F1 — fixar o comportamento antes de tocar nele

### T001 Contar os empates que existem hoje

- **Pronta quando**: nada além do repositório e do banco de desenvolvimento.
- **Descrição**: consulta que conta quantas issues têm **duas ou mais** promoções com o **mesmo**
  `inserted_at` — `inserted_at` é `utc_datetime`, de segundo inteiro, e o `DISTINCT ON` de hoje não
  tem desempate. O número entra na pesquisa, seção D4. **Se for zero, o desempate entra assim
  mesmo**: ele é barato, e a ausência dele é silenciosa.
- **Feita quando**: o número está medido e registrado em `research.md`; e está escrito se ele é zero
  ou não.
- **Teste**: a própria consulta SQL, com a saída colada na pesquisa — é medida, não asserção.

### T002 Fixar a vigência e o desempate em teste

- **Pronta quando**: o contrato existe em `contracts/promocao-vigente.md`; T001 medida.
- **Descrição**: `test/the_band/work_items/promocao_vigente_test.exs`, **escrito contra o
  comportamento atual** — a promoção vigente é a mais recente, issue sem promoção aparece sem
  conceito, e o escopo é por tenant. Mais o caso que hoje **falha**: duas promoções no mesmo segundo
  devem devolver sempre a mesma, e a de `id` maior. FR-003, FR-004, FR-006, FR-007.
- **Feita quando**: os casos de vigência passam **antes** da reescrita; e o caso do empate falha,
  documentando o defeito que a F2 corrige.
- **Teste**: o próprio arquivo. O caso do empate entra com `@tag :pending` até a F2, e a etiqueta sai
  no mesmo commit que a corrige — nunca antes.

### T003 [P] Registrar o retrato de cada tela afetada

- **Pronta quando**: o servidor sobe localmente.
- **Descrição**: para `/people/:id` (três pessoas: a mais lenta, a mais rápida e uma do meio),
  `/work`, `/work/issues/:id` e `/work/repositories/:id`, gravar o HTML da tabela renderizada em
  `specs/013-pagina-da-pessoa-mais-rapida/retratos/`. **É o "antes" da FR-008**, e sem ele a prova de
  conteúdo idêntico vira memória.
- **Feita quando**: existe um arquivo por tela, com issues, conceitos, contagens e ordem; e o
  procedimento para regravá-los está no `quickstart.md`.
- **Teste**: regravar duas vezes seguidas produz arquivos **idênticos** — se não produzir, a tela já
  é não determinística hoje, e isso é achado, não ruído.

---

## F2 — a mudança

### T004 Resolver a promoção vigente por issue exibida

- **Pronta quando**: T002 feita — os casos de vigência precisam estar passando **antes**.
- **Descrição**: reescrever `promocoes_vigentes/1` em `lib/the_band/work_items/queries.ex` para
  `left_lateral_join` com `parent_as/1` e `limit: 1`, ordenando por `inserted_at DESC, id DESC`
  (FR-004). São **14** pontos de chamada no arquivo, em duas formas:
  - `join(:left|:inner, [i], p in subquery(vigentes(tenant)), on: …)` — 8 pontos, ganham binding
    nomeado;
  - `left_join: p in subquery(promocoes_vigentes(tenant_id))` dentro de `from` — 6 pontos.
  **Uma exceção declarada**: `current_promotions/2` recebe a lista de ids e não decora linha nenhuma
  — ali a correção é **restringir a subconsulta aos ids recebidos**, não `LATERAL`. FR-001.
- **Feita quando**: nenhuma consulta do módulo produz varredura sequencial de `issue_promotions`; o
  caso do empate de T002 passa e a etiqueta `:pending` sai; e `mix gates` fica verde.
- **Teste**: `test/the_band/work_items/promocao_vigente_test.exs` — o caso do empate, mais um teste
  que executa `EXPLAIN` da consulta da pessoa e **falha se o plano contiver `Seq Scan` sobre
  `issue_promotions`** (FR-010).

### T005 Indexar a designação pela pessoa

- **Pronta quando**: nada além do repositório.
- **Descrição**: migração criando índice em `issue_assignees (person_id, no_longer_observed_at)`.
  Os dois índices existentes são por `collected_issue_id` e respondem "quem é designado desta
  issue"; **nenhum responde a pergunta inversa**, que é a da página da pessoa. Medido: varredura de
  4 232 linhas descartando 3 882. FR-002.
- **Feita quando**: `mix ecto.migrate` e o rollback voltam limpos; e o plano da consulta da pessoa
  usa o índice em vez de varrer.
- **Teste**: a ida e volta da migração, mais a asserção de `EXPLAIN` no teste de T004 — **sem
  `Seq Scan` em `issue_assignees`**.

### T006 [P] Unificar a segunda definição de promoção vigente

- **Pronta quando**: T004 feita.
- **Descrição**: `lib/the_band/mapping/queries.ex` tem a **sua própria** `promocoes_vigentes/1`, com
  a mesma semântica e o mesmo defeito de desempate. Duas definições para a mesma decisão discordam
  no dia em que uma for corrigida — e hoje é esse dia. Avaliar reuso pela fronteira pública de
  WorkItems; **se a fronteira não permitir sem vazá-la, corrigir a segunda no mesmo desenho e
  registrar a duplicação como dívida** — nunca criar dependência que fure a ADR 0003.
- **Feita quando**: as duas definições ordenam com o mesmo desempate; e a decisão — reuso ou
  duplicação declarada — está escrita no `plan.md`.
- **Teste**: teste que pede a vigente pelos dois caminhos, para a mesma issue com empate, e exige
  **a mesma** resposta.

---

## F3 — provar que a resposta não mudou

### T007 Comparar cada tela com o retrato

- **Pronta quando**: T003, T004 e T005 feitas.
- **Descrição**: regravar os retratos e comparar com os de T003, arquivo a arquivo. **Diferença
  nenhuma é aceitável** — nem de ordem, nem de contagem, nem de conceito. FR-008.
- **Feita quando**: o `diff` de cada arquivo é vazio; e as diferenças que aparecerem estão
  explicadas e corrigidas, nunca aceitas como "provavelmente irrelevante".
- **Teste**: o `diff` colado no `sprint-review.md`. Vazio é evidência; "parece igual" não é.

### T008 [P] Fixar as contagens que o axioma produz

- **Pronta quando**: T004 feita.
- **Descrição**: as contagens de divergência e as violações da `sro.rule07` são derivadas da promoção
  vigente. Teste que compara os números **antes e depois** com o mesmo dado: 520 divergências, 293
  violações por tarefa sob épico. FR-008.
- **Feita quando**: os números batem exatamente; e o teste falha se qualquer um deles mudar.
- **Teste**: `test/the_band/work_items/` — asserção sobre os números medidos, não sobre "existe
  alguma divergência".

---

## F4 — medir

### T009 Medir as três telas, antes e depois

- **Pronta quando**: T007 feita.
- **Descrição**: cinco medidas por tela — `/people/:id` nas **oito** pessoas com mais trabalho,
  `/work` e `/people` —, pelo mesmo método dos dois lados: render HTTP inicial, com o servidor local
  e o mesmo banco. **A L38**: `live/2` faz dois renders, e medir sem saber disso atribui à consulta o
  que é do framework. SC-001, SC-001b, SC-004.
- **Feita quando**: a tabela antes/depois está no `sprint-review.md`; a pior página está **abaixo de
  200 ms**; e a razão entre a mais lenta e a mais rápida caiu de setenta para menos de três.
- **Teste**: a tabela com as cinco medidas por tela e a variação entre elas — constância junto da
  diferença, nunca só a diferença.

### T010 [P] Provar que o custo parou de crescer com o histórico

- **Pronta quando**: T004 feita.
- **Descrição**: teste que **dobra** o histórico de promoções de um cenário — sem apagar nada,
  acrescentando — e exige que o tempo da consulta da pessoa varie menos de 10%. SC-006, FR-010. É o
  teste que impede a regressão de voltar: sem ele, alguém reintroduz a varredura e ninguém percebe
  até a tela doer de novo.
- **Feita quando**: com o dobro do histórico, o tempo não dobra; e o teste falha se a varredura
  voltar.
- **Teste**: o próprio arquivo, medindo com o histórico simples e com o dobrado, no mesmo caso.

---

## Dependências

```text
T001 ── T002 ──┬── T004 ──┬── T006 [P]
               │          ├── T008 [P]
T003 [P] ──────┘          ├── T010 [P]
T005 ─────────────────────┘
                          └── T007 ── T009
```

## Estratégia

**MVP**: T002 + T004 + T005. A consulta para de varrer, e o índice responde a pergunta da pessoa.

**O que não entra**: reduzir, arquivar ou apagar o histórico de promoções — FR-005 e princípio III.
E nenhuma mudança de aparência: se algo na tela mudar, é defeito (FR-008).

## Cobertura dos requisitos

| Requisito | Tarefa |
|---|---|
| FR-001 | T004 |
| FR-002 | T005 |
| FR-003, FR-006, FR-007 | T002 |
| FR-004 | T001, T002, T004, T006 |
| FR-005 | T010 — dobra o histórico **acrescentando**, e a contagem final é conferida |
| FR-008 | T003, T007, T008 |
| FR-009 | T009 |
| FR-010 | T004, T010 |
| SC-001, SC-001b, SC-004 | T009 |
| SC-002, SC-002b | T004 |
| SC-003 | T005 |
| SC-005 | T007 |
| SC-006 | T010 |
| SC-007 | T010 |
