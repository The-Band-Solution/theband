# Tarefas — Feature 011: de quem cada issue é parte

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/issue-parent.md](contracts/issue-parent.md)
**Branch**: `015-de-quem-a-issue-e-parte` · **Nenhuma migração** — a feature só lê

Nove tarefas em três fases. Cada uma atende uma user story, e cada uma tem teste.

**Ordem que é dependência**: F1 decide e busca · F2 mostra · F3 cobre o que o dado ainda não tem.

**F1 sozinha não é entregável** — função sem consumidor visível não é funcionalidade entregue, é a
**L21**, e é por isso que as três fases estão no mesmo sprint.

---

## F1 — a decisão e a consulta

### T001 [US2] Nomear a relação do vínculo

- **Pronta quando**: o contrato existe em `contracts/issue-parent.md`, e ele já declara as cinco
  respostas e a precondição "há pai".
- **Descrição**: acrescentar `relacao/2` a `lib/the_band/work_items/axioms.ex`, pura, devolvendo
  `:atendimento | :composicao | :nao_nomeada | :pai_sem_conceito | {:violacao,
  :task_parent_is_epic}`. Quem decide atendimento contra composição é o **conceito da filha** —
  FR-004b —, que é como `list_composition/2` e `list_attendance/2` já decidem vistas do pai. A
  violação vem de `rule07/2`, **chamado**, nunca reimplementado (FR-006). **A cláusula do pai sem
  conceito vem primeiro**: `nil` aqui significa "o pai não foi promovido", e em `rule07/2` significa
  "não tem pai" — passar esse `nil` adiante faria a tela dizer *task without parent* sobre uma issue
  que tem pai. Expor por `defdelegate` em `lib/the_band/work_items.ex`, como `rule07/2` já é.
- **Feita quando**: filha tarefa com pai épico devolve `{:violacao, :task_parent_is_epic}`; filha
  defeito devolve `:nao_nomeada` para qualquer pai; pai com conceito `nil` devolve
  `:pai_sem_conceito` **sem** chamar o axioma; e nenhuma entrada devolve `:composicao` para filha
  promovida a defeito.
- **Teste**: `test/the_band/work_items/axioms_test.exs` — um caso por linha da tabela do contrato,
  mais o caso que separa os dois `nil`: `relacao("sro.intended_scrum_development_task", nil)` devolve
  `:pai_sem_conceito`, e **não** `{:violation, :task_without_parent}`.

### T002 [US1] Buscar os pais em lote

- **Pronta quando**: T001 feita — o mapa devolvido precisa carregar `derived_concept` para a decisão
  ser tomada em memória.
- **Descrição**: `list_parents/2` em `lib/the_band/work_items/queries.ex`, com `defdelegate` em
  `work_items.ex`. **Uma** consulta para a lista inteira de `child_issue_id`, agrupada por filha em
  memória. Cada pai traz `id`, `number`, `title`, `observed_repository_id`, `derived_concept` da
  promoção **vigente** (`promocoes_vigentes/1`, que já existe) e `no_longer_observed_at` **do
  vínculo**. `order_by: [asc: c.number, asc: c.id]` — o desempate por `id` não é enfeite: `number`
  repete entre repositórios, e 57 vínculos têm pai em outro. Lista vazia devolve `%{}` **sem
  consultar** (G7). **Não juntar a tabela de CMPO**: devolve o identificador do repositório, nunca o
  nome — ADR 0003.
- **Feita quando**: uma chamada com 50 identificadores faz **uma** consulta; o mapa não tem chave
  para issue sem pai; a lista de pais de uma filha com dois vem na mesma ordem em duas chamadas
  seguidas; e vínculo com `no_longer_observed_at` preenchido **vem**, marcado.
- **Teste**: `test/the_band/work_items/queries_test.exs` — conta as consultas com o mesmo
  `contar_consultas/1` de `test/the_band_web/live/person_detail_test.exs`, que anexa
  `[:the_band, :repo, :query]` por telemetria, e exige **uma**; monta uma filha com dois pais e
  compara duas chamadas; monta um vínculo ausente e exige que apareça; e chama com `[]` exigindo
  `%{}` e zero consultas.

---

## F2 — a coluna

### T003 [US1] Mostrar o pai na linha

- **Pronta quando**: T002 feita.
- **Descrição**: coluna `part of` em `lib/the_band_web/live/repository_live/show.ex`. O `carregar/1`
  chama `WorkItems.list_parents(tenant, Enum.map(issues, & &1.id))` **depois** de `list_issues/2` —
  a lista das issues da página é a entrada. Cada pai é link para `~p"/work/issues/#{id}"` (FR-012),
  com `#número` monoespaçado e o título. **E o conceito do pai**, por
  `ConceptLabel.rotulo(pai.derived_concept)` — FR-003: reduzir a "US ou épico" erraria os **12**
  vínculos cujo pai é **defeito**, e é o que o pedido original dizia. Issue **sem** pai: texto dizendo
  que ela não é parte de nada (FR-002) — nunca `<td></td>`. **Ler o mapa com `Map.get(pais, i.id,
  [])`**: `list_parents/2` não cria chave para issue sem pai (G3), e `pais[i.id]` levantaria
  `KeyError` em 2 899 linhas — foi exatamente o defeito que o teste da feature 010 pegou.
  `data-label="part of"` na célula, para virar cartão em 360 px (FR-015).
- **Feita quando**: numa página com issues decompostas o HTML tem o número, o título **e o conceito**
  do pai; nenhum pai que é defeito aparece chamado de user story ou de épico; issue sem pai tem texto
  na célula; e o link do pai aponta para o detalhe dele.
- **Teste**: `test/the_band_web/live/repository_live/show_test.exs` — monta uma issue com pai user
  story, uma com pai **defeito** e uma sem pai, e assere o texto das três no HTML. **A ausência é
  asserida pelo texto**, não pela falta dele: `assert html =~ "not part of anything"`. Mais o caso do
  pai defeito: `assert html =~ "defect"` na célula, e `refute` os rótulos de user story e de épico
  nela. E o tenant: um repositório de **outro** tenant na mesma rota devolve não encontrado, e a
  mensagem não confirma existência — FR-016 e SC-011.

### T004 [US2] Dizer qual relação é

- **Pronta quando**: T001 e T003 feitas.
- **Descrição**: os cinco textos em `lib/the_band_web/concept_label.ex`, em inglês, conforme a tabela
  do contrato — `attends`, `composes`, o aviso citando `sro.rule07`, `part of — the ontology network
  does not name this relation`, e `part of — the parent has no concept`. A coluna chama
  `WorkItems.relacao/2` **somente quando há pai**: o R6 da pesquisa mediu que chamar o axioma com pai
  nulo encheria **2 091 das 2 899** células de aviso, afogando as **293** que são o caso
  interessante. O painel acima da tabela continua sendo onde `task_without_parent` é contado. Cada
  caso distinguível por **texto**, cor nunca sozinha (FR-014).
- **Feita quando**: tarefa sob user story e user story sob épico têm textos diferentes na mesma
  lista; tarefa sob épico traz o aviso nomeando `sro.rule07`; filha defeito diz que a ontologia não
  nomeia a relação; e nenhuma issue **sem** pai traz aviso de violação.
- **Teste**: no mesmo teste do LiveView — quatro issues na mesma lista, uma por relação, e as quatro
  frases asseridas. Mais um `refute`: numa lista com uma tarefa **sem** pai,
  `refute html =~ "violates sro.rule07"` na célula da coluna, com o painel ainda presente na tela.

### T005 [US3] Nomear o repositório do pai

- **Pronta quando**: T003 feita.
- **Descrição**: `CMPO.list_observed/2` virando mapa de `observed_repository_id` para nome, como
  `nomes_de_repositorio/1` faz em `people_live/show.ex`. **Uma** consulta, **incondicional** — um
  ramo condicional faria o número de consultas variar com o dado, e a constância do SC-008 deixaria
  de ser asserível. O nome aparece **só quando o repositório do pai difere** do da filha: são 57
  vínculos, e repetir o nome nas outras 1 609 linhas gastaria a atenção que os 57 precisam ter
  (FR-010, T4 do contrato).
- **Feita quando**: pai em outro repositório mostra o nome dele; pai no mesmo repositório **não**
  mostra; e o nome é resolvido por mapa, nunca por consulta na linha.
- **Teste**: no teste do LiveView — duas issues, uma com pai no mesmo repositório e uma com pai em
  outro; assere o nome na segunda e `refute` o nome do próprio repositório na primeira.

### T006 [US3] Dizer que há mais de um pai

- **Pronta quando**: T002 e T003 feitas.
- **Descrição**: quando a filha tem mais de um pai **vigente**, a célula lista todos e diz que há
  mais de um (FR-008). São **36** issues. **A contagem considera só o vigente**: uma filha com um pai
  vigente e um vínculo ausente é **um** pai mais um vínculo que acabou — não é caso de mais de um
  (G5 do contrato). A ordem é a que `list_parents/2` já garante, e é o que `fetch_parent/2` não
  garante: `limit: 1` sem `order_by` devolve pai arbitrário, e é a **L20**.
- **Feita quando**: uma issue com dois pais mostra os dois e diz que há mais de um; nenhum pai
  aparece como se fosse o único; e a mesma página renderizada duas vezes produz HTML idêntico na
  coluna.
- **Teste**: no teste do LiveView — monta dois pais para a mesma filha, assere os dois números e a
  frase do plural; depois renderiza duas vezes e compara as duas saídas com `assert`. Mais o caso
  misto: um pai vigente e um ausente **não** dispara a frase do plural.

---

## F3 — o que o dado ainda não tem

### T007 [US2] Marcar o vínculo ausente

- **Pronta quando**: T003 feita.
- **Descrição**: vínculo com `no_longer_observed_at` preenchido aparece **tracejado**, com a data, e
  o texto dizendo que houve vínculo e ele não está presente (FR-011). São **zero** hoje — o teste
  monta o caso. A gramática da evidência é normativa em `docs/design-system.md`: sólido é observado,
  hachurado é derivado, tracejado é ausente, **sempre com texto e rótulo de leitor de tela**, nunca
  só cor. As duas falhas típicas são **omitir** e **mostrar como atual**.
- **Feita quando**: o vínculo ausente aparece com a data; ele não aparece como atual; e a marca tem
  texto além da forma.
- **Teste**: no teste do LiveView — cria o vínculo, preenche `no_longer_observed_at`, e assere a data
  no HTML mais o texto da ausência. E um `refute` sobre a frase da relação em ordem, que não pode
  aparecer nessa linha.

### T008 [US2] Dizer pai sem conceito

- **Pronta quando**: T001 e T003 feitas.
- **Descrição**: pai que existe e não foi promovido aparece como **sem conceito**, e a linha não
  inventa um (FR-007). São **zero** hoje, porque toda issue está promovida; vai existir na primeira
  coleta que traga tipo novo. O caminho é `:pai_sem_conceito` de `relacao/2` — e o erro que esta
  tarefa impede é a tela dizer *task without parent* sobre uma issue que **tem** pai.
- **Feita quando**: o pai sem promoção aparece com número e título e com o texto de sem conceito; e
  nenhum conceito é atribuído a ele.
- **Teste**: no teste do LiveView — cria o pai sem `IssuePromotion`, e assere
  `part of — the parent has no concept`; mais `refute html =~ "no parent"` na célula dessa linha.

### T009 [US1] Medir o custo do render

- **Pronta quando**: T003, T004, T005 e T006 feitas — o custo só é medível com a coluna inteira.
- **Descrição**: teste que conta as consultas do render e verifica **duas** coisas, que é como a
  feature 010 estabeleceu (**L38**): a **diferença** contra a tela sem a coluna é exatamente
  **duas** — `list_parents/2` e `CMPO.list_observed/2`, uma por fronteira (FR-013) —, e a
  **constância**: uma página com 3 issues e uma com 50 fazem o **mesmo** número. "Um número que não
  cresce" não é asserção; o número medido é.
- **Feita quando**: a diferença medida é **duas por render**; a página de 3 e a de 50 medem igual; e o
  número está escrito no teste, não deduzido.
- **Teste**: `test/the_band_web/live/repository_live/show_test.exs` — `contar_consultas/1` por
  telemetria de `[:the_band, :repo, :query]`. **`live/2` faz dois renders**, então a diferença bruta
  vem **dobrada** e é dividida por dois antes de comparar com duas — é o que o teste da feature 010
  faz com `div(poucas - lista, 2)`, e esquecer isso mediria quatro e reprovaria sem defeito nenhum. A
  medida vale contra o baseline **medido**, nunca contra um número presumido: a 010 pagou por isso com
  um teste que esperava 8 numa tela que faz 24.

---

## Dependências

```text
T001 ──┬── T002 ── T003 ──┬── T004 ──┐
       │                  ├── T005 ──┼── T009
       │                  └── T006 ──┘
       ├── T008 (precisa de T003)
       └── T007 (precisa de T003)
```

**Paralelizáveis depois de T003**: T004, T005, T006, T007 e T008 tocam a mesma tela, então o paralelo
é de raciocínio, não de arquivo.

## Escopo mínimo

**US1 sozinha** — T002 e T003 — já entrega o pedido literal: a linha mostra de quem a issue é parte.
O que ela **não** entrega é a distinção entre as relações, e é aí que estão as 293 violações e os 33
vínculos que a ontologia não nomeia.

## Fora destas tarefas, e registrado

| Fora | Onde vai |
|---|---|
| dar `order_by` a `fetch_parent/2` | dívida vizinha, backlog — outra tela |
| mostrar os 33 vínculos de defeito **no detalhe do pai** | dívida vizinha, backlog — outra tela |
| corrigir as 293 violações na origem | a plataforma observa e avisa; corrigir é do time |
| escolher qual pai vale, entre os 36 | a plataforma não decide isso pelo time |
