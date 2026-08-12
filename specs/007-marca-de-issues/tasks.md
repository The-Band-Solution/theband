# Tarefas — Feature 007: a marca de trabalho no repositório

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/repository-work-mark.md](contracts/repository-work-mark.md) · **Quickstart**:
[quickstart.md](quickstart.md)

**Sete tarefas, três fases.** O conjunto é pequeno porque a feature é pequena: uma coluna, uma
consulta e cerca de 15 linhas de markup. A pessoa mantenedora já recusou uma spec inflada para
isto — 22 requisitos para um símbolo —, e vinte tarefas repetiriam o erro numa terceira fase.

Ordem: F1 → F2 → F3, e é dependência.

**MVP**: F1 e F3. Com as duas, a marca distingue "tem trabalho" de "não tem" — que é o pedido
literal. F2 acrescenta o terceiro estado, e sem ela a marca mostraria "vazio" onde o certo é "não
se sabe".

---

## Fase F1 — A consulta agrupada

Vem primeiro porque **paga sozinha**: a tela fica mais rápida antes de a marca existir, e se a
feature parar aqui o ganho permanece.

- [ ] T001 Contar issues por repositório numa consulta
  - **Pronta quando**: o contrato em `contracts/repository-work-mark.md` declara
    `count_collected_by_repository/2`
  - **Descrição**: acrescentar a função em `lib/the_band/work_items/queries.ex`, com o
    `defdelegate` em `lib/the_band/work_items.ex`. Agrupa por `observed_repository_id` e conta
    **só issues vigentes** — `no_longer_observed_at` nulo (FR-010, contrato). Devolve mapa;
    **repositório sem nenhuma issue não aparece nele**, e quem chama usa `Map.get(mapa, id, 0)` —
    o zero significa "nenhuma issue vigente", nunca "não sei". Lista de ids vazia devolve `%{}`
    sem consultar
  - **Feita quando**: uma chamada devolve a contagem dos 135 repositórios; repositório sem issue
    está ausente do mapa em vez de aparecer com zero
  - **Teste**: `test/the_band/work_items/count_by_repository_test.exs` — assere que o repositório
    sem issue **não** é chave do mapa, e que issue marcada como não mais observada **não** é
    contada

- [ ] T002 Trocar as 135 consultas por uma
  - **Pronta quando**: T001 concluída
  - **Descrição**: em `lib/the_band_web/live/work_item_live/index.ex`, `por_repositorio/2` passa a
    chamar `count_collected_by_repository/2` uma vez, em vez de `count_collected/2` por
    repositório. **A coluna de contagem passa a exibir issues vigentes**, e isso muda o
    significado dela: hoje conta todas. A mudança está declarada em R3 da pesquisa, e existe
    porque coluna e marca discordarem é o que FR-010 proíbe
  - **Feita quando**: desenhar a tela faz **uma** consulta de contagem, e não 135; os números
    exibidos são os mesmos, porque no dado real nenhuma issue está marcada como ausente
  - **Teste**: V4 do [quickstart](quickstart.md) — contar as consultas de agregação no log de uma
    renderização; **1**, não 135

---

## Fase F2 — A coluna de evento

Vem antes da tela porque a marca sem ela mostraria `0` para vazio **e** para desconhecido — o
defeito que a feature existe para não ter.

- [ ] T003 Registrar quando as issues foram coletadas
  - **Pronta quando**: T002 concluída; `data-model.md` descreve a coluna
  - **Descrição**: migração acrescentando `issues_collected_at` (`utc_datetime`, **anulável**) a
    `observed_repositories`, mais o campo no schema e em `CMPO.list_observed/2`. `nil` significa
    "nunca passou por coleta de issues", e é a única coisa que a plataforma hoje não sabe — os
    quatro candidatos que **não** servem estão em R4. **Nenhuma coluna é removida**, nenhum índice
    novo: a consulta filtra por `observed_repository_id`, que já é indexado
  - **Feita quando**: `list_observed/2` devolve `issues_collected_at`; os 135 repositórios
    existentes têm `nil`, porque nenhuma coleta anterior a registrou
  - **Teste**: round trip — `mix ecto.migrate`, `mix ecto.rollback --step 1`, `mix ecto.migrate`,
    sem erro nas três

- [ ] T004 Gravar a data no fim da fase de issues
  - **Pronta quando**: T003 concluída
  - **Descrição**: `CMPO.mark_issues_collected/3`, chamada em
    `lib/the_band/ingestion/github_work_items.ex` **no mesmo ponto** que grava o checkpoint da
    fase. Dois pontos diferentes é como a data fica gravada para uns repositórios e não para
    outros — e aí a marca **mente sobre coleta**, que é pior que não saber. Repositório excluído
    ou inacessível **não** recebe a data, porque não foi consultado: a ausência dela é a
    informação (FR-005, contrato)
  - **Feita quando**: depois de uma coleta, todo repositório coletado tem a data e nenhum
    excluído ou inacessível tem; a data e o checkpoint da fase andam juntos
  - **Teste**: teste de ingestão conferindo que o repositório coletado tem `issues_collected_at`
    e o inacessível **não** — a asserção que importa é a segunda

---

## Fase F3 — A marca na tela

- [ ] T005 Exibir a marca com três canais
  - **Pronta quando**: T002 concluída; T004 concluída para o terceiro estado
  - **Descrição**: markup na célula do repositório em
    `lib/the_band_web/live/work_item_live/index.ex`, com um helper privado para o texto.
    **Nenhum componente novo** — há um chamador só, e a tabela e o cartão do telefone são o mesmo
    HTML (R1). Três estados, três canais: forma preenchida/vazia/tracejada, texto
    `N issues`/`collected, no issues`/`not collected yet`, e rótulo acessível por extenso.
    **Cor não conta como canal** — WCAG 1.4.1, e é regra do design system. Os utilitários de
    forma são os mesmos de `<.evidence>`, e o padrão vem do `docs/design-system.md`
  - **Feita quando**: os três estados aparecem na lista; com a cor removida, continuam
    distinguíveis; cada marca é anunciada por leitor de tela
  - **Teste**: `test/the_band_web/live/work_mark_test.exs` — o teste que importa é o que **remove
    a cor** e ainda distingue os três, e o que exige textos **diferentes** para vazio e
    desconhecido

- [ ] T006 Dizer que houve trabalho e não há vigente
  - **Pronta quando**: T005 concluída
  - **Descrição**: quarto texto, que não é um quarto estado da marca: repositório cujas issues são
    **todas** não vigentes exibe `no current work`, e não `collected, no issues`. Houve trabalho e
    ele não está presente — são fatos diferentes, e o design system exige nomear a diferença
    (premissa da spec, caso de borda 1)
  - **Feita quando**: repositório com issues todas marcadas como ausentes exibe `no current work`;
    repositório que nunca teve issue exibe `collected, no issues`
  - **Teste**: o mesmo arquivo de T005 — marcar as issues de um repositório como não mais
    observadas e conferir que o texto muda

- [ ] T007 Manter todo repositório clicável
  - **Pronta quando**: T005 concluída
  - **Descrição**: conferir que os 135 repositórios continuam com link para
    `/work/repositories/:id`, **inclusive os 61 vazios** — a tela deles explica por que estão
    vazios, e é isso que alguém procura ao clicar num vazio (FR-007). O alvo de toque no telefone
    vem do design system e já existe; a tarefa é não quebrá-lo
  - **Feita quando**: toda linha da lista tem link, e a marca não substitui o link nem o cobre
  - **Teste**: o mesmo arquivo de T005 — contar os links da lista e exigir um por repositório,
    inclusive nos que a marca mostra como vazios

---

## Dependências

```text
T001 → T002 → T005 → T006, T007
        T003 → T004 ────┘
```

T003 e T004 podem ir em paralelo com T005 até o ponto em que o terceiro estado é exigido.

## Paralelismo

| Podem ir juntas | Por quê |
|---|---|
| T003 e T005 | migração e markup não se tocam; T005 só depende de T004 para o terceiro estado |
| T006 e T007 | textos e links, no mesmo arquivo mas em pontos diferentes |

## Cobertura

| Requisitos | Tarefas |
|---|---|
| FR-001 a FR-003 (a marca e os três canais) | T005 |
| FR-004 (não repetir a coluna `state`) | T005 |
| FR-005 (desconhecido ≠ zero) | T003, T004, T005 |
| FR-006 (tabela e cartão) | T005 |
| FR-007 a FR-009 (navegação e toque) | T007 |
| FR-010, FR-011 (um número, sem mais consultas) | T001, T002 |
| FR-012 (isolamento entre tenants) | T001 |
| FR-013 (escopo é `/work`) | T005 — e a ausência de tarefa para a tela de sincronização |

**13 de 13 requisitos com tarefa.** SC-001 a SC-009 verificados por V1 a V8 do
[quickstart](quickstart.md).

## Estratégia de entrega

**F1 primeiro, e ela é entregável sozinha**: 135 consultas viram 1, e a tela fica mais rápida sem
nenhuma mudança visível. Se a feature parar aqui, o ganho permanece.

**F1 + F3 é o MVP**: a marca com dois estados — tem e não tem — é o pedido literal.

**F2 fecha o terceiro estado.** Sem ela, 61 repositórios apareceriam como "coletado e vazio"
quando a plataforma não sabe se olhou. É o único ponto da feature onde omitir produz afirmação
falsa, e por isso F2 não é opcional para declarar a feature completa.

## Fora do escopo, e ficou de fora

| Item | Por quê |
|---|---|
| a marca dizer o estado de observação | a coluna `state` já diz — FR-004 |
| marca na tela de sincronização | lá o repositório é fase de execução — FR-013 |
| ordenar ou filtrar a lista | não foi pedido |
| componente `<.work_mark>` | um chamador só; o segundo justifica — R1 |
