# Implementation Plan: o rótulo como campo do item de trabalho

**Branch**: `065-rotulos-no-item` · **Spec**: [spec.md](spec.md) · **Data**: 2026-09-13

**Protótipo aprovado**: <https://claude.ai/code/artifact/e52ca895-fa21-40b2-bbbc-bab0b4a711b0>

**Decisões**: [research.md](research.md) · **Modelo**: [data-model.md](data-model.md) · **Validação**: [quickstart.md](quickstart.md)

---

## Summary

Os rótulos já são coletados e param no detalhe de um item. Este plano os leva à **listagem** e
à **tela de divergências**, com a origem visível, e acrescenta a segunda via: o prefixo de
área do título — que a base de conhecimento já separou, para recusá-lo como tipo.

**Nenhuma migração. Nenhuma coluna nova. Nenhum dado recoletado.** Tudo o que a feature
precisa já está guardado; o que falta é ler.

O plano também incorpora uma medição que **reduz** o que o pedido sugeria: a identificação por
organização + repositório + número **já está correta no armazenamento**, e o defeito é de
leitura — ver [R1](research.md#r1--a-identidade-da-issue-já-está-correta-o-defeito-é-de-leitura).

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir ~> 1.17 · Phoenix 1.8.9 · LiveView |
| **Persistência** | PostgreSQL 16, multitenant — toda consulta recebe `%Tenant{}` (princípio V) |
| **Dado existente** | `issue_labels`: 1 733 vínculos, 138 nomes, com cor e data de saída |
| **Segunda origem** | prefixo do título: 1 519 issues em 8 prefixos declarados |
| **Onde a lista vive** | `priv/knowledge_base/rules/github_issue_pattern_catalog.yaml`, seção `not_type_patterns` |
| **O que verifica** | `mix gates` — o veredito é o código de saída |

**Nenhum NEEDS CLARIFICATION.** As três dúvidas que restavam foram respondidas por medição,
não por suposição: onde está o defeito de identidade (R1), quais consultas recebem o campo
(R2), e se a lista de prefixos se duplica (R3 — não, e a razão é que duas listas divergem em
silêncio).

## Constitution Check

| princípio | como este plano o satisfaz |
|---|---|
| **III — proveniência** | é o coração da feature: o rótulo do campo e o do título **não** se parecem, porque não têm a mesma força. Um alguém clicou; o outro é convenção de escrita |
| **V — multitenant** | as consultas alteradas já recebem `%Tenant{}` e continuam recebendo; a junção nova herda o mesmo recorte |
| **VIII — desenho que o problema justifica** | registro abaixo |
| **X — responsabilidade única** | a lista de prefixos vive **num lugar só**, junto da recusa de onde vem |
| **XI — sinal nunca silenciado** | ausência de rótulo é **escrita**, nunca célula vazia — vazio se confunde com "ainda não carregou" |

### Registro das decisões de desenho (princípio VIII)

**1. Junção lateral agregada, em vez de carregamento associado**

- *Que problema resolve*: uma listagem de 100 itens com carregamento por linha faz 101
  consultas.
- *Existe agora?* **Sim** — a listagem de itens é paginada e já serve centenas.
- *O que piora*: a consulta fica mais difícil de ler que um `preload`, e quem a editar depois
  precisa entender por que ela é assim. Mitigado por comentário no ponto, com o número.

**2. Derivar o prefixo na leitura, e não guardá-lo**

- *Que problema resolve*: 1 519 issues carregam caracterização que ninguém consulta.
- *Existe agora?* **Sim, e crescendo** — `[Devops]` era 340 em agosto, 369 hoje.
- *O que piora*: o custo de derivar é pago em toda leitura. E o título vira entrada de uma
  regra, o que significa que renomear uma issue pode mudar seus rótulos — comportamento que
  precisa estar escrito, ou parece defeito.

**3. Mostrar o nome qualificado do repositório ao lado do número**

- *Que problema resolve*: `#2` sem repositório é ambíguo — 5 033 issues em apenas 2 699
  números distintos.
- *Existe agora?* **Sim, medido.** A tela de hoje mostra números que colidem.
- *O que piora*: uma junção a mais na listagem, e uma coluna a mais numa tabela já larga. O
  nome qualificado é longo (`leds-conectafapes/conectafapes-project`) e vai precisar de
  truncamento com o valor inteiro no `title`.

**Nenhum padrão novo.** A junção lateral agregada já é o padrão do arquivo — `vigente_da_issue/1`
faz exatamente isso para a promoção. Usá-la aqui é usá-la dentro do problema que a motivou.

## Project Structure

```
specs/065-rotulos-no-item/
├── spec.md              ← 15 FR, 8 SC (+ os da identificação, ver abaixo)
├── plan.md              ← este documento
├── research.md          ← R1..R6
├── data-model.md        ← o rótulo, suas duas origens, e a identidade do item
├── quickstart.md        ← o que deve passar E o que deve falhar
└── checklists/requirements.md

lib/the_band/
├── work_items/queries.ex          ← `list_issues`, `list_divergences` + a junção agregada
└── ontology/…                     ← a leitura da lista de prefixos declarada

lib/the_band_web/live/work_item_live/
├── index.ex / .html.heex          ← a coluna de rótulos e o repositório ao lado do número
└── (tela de divergências)         ← rótulo e conceito lado a lado

priv/knowledge_base/rules/github_issue_pattern_catalog.yaml   ← NÃO muda; é lido
```

## Requisitos que este plano acrescenta à spec

A medição da identidade (R1) produziu requisitos que a spec não tinha. Ficam registrados aqui
e entram na spec antes das tarefas:

- **FR-016**: Um item de trabalho MUST ser identificável na tela sem ambiguidade. O número
  sozinho MUST NOT ser usado como identificação visível, porque ele se repete entre
  repositórios.
- **FR-017**: A identificação visível MUST nomear o repositório, e o nome MUST trazer a
  organização junto.
- **SC-009**: Duas issues de repositórios diferentes com o mesmo número são distinguíveis na
  listagem, sem abrir nenhuma das duas.

## Ordem de execução

A ordem é por **dependência real**, e a primeira tarefa é a que as outras duas reusam.

| # | o quê | FR | por quê nesta posição |
|---|---|---|---|
| **1** | a junção agregada com os rótulos do campo, em `list_issues` | 001, 002, 012, 013 | é o mecanismo que as duas seguintes reusam; e entrega valor sozinha — a listagem passa a mostrar o que o time escreveu |
| **2** | o prefixo do título como segunda origem | 002, 003, 004, 005, 006 | depende de 1 para ter onde aparecer, e da leitura da lista declarada |
| **3** | o repositório ao lado do número | 016, 017 | independente das duas acima; podia vir primeiro, e vem depois porque é ambiguidade de leitura, não ausência de informação |
| **4** | rótulo e conceito lado a lado nas divergências | 014 | reusa 1 e 2; é a tela que mais ganha, e a que menos gente abre |

## Complexity Tracking

| o que se acrescenta | custo assumido | por que se aceita |
|---|---|---|
| junção lateral agregada em duas consultas | consulta mais difícil de ler que um `preload` | é o que mantém a listagem em consulta única — L38 |
| derivação do prefixo na leitura | custo pago a cada leitura; título vira entrada de regra | evita coluna, migração e recarga de 5 033 linhas, e torna a lista editável sem recoletar |
| junção até o nome do repositório | mais uma junção e uma coluna larga | sem ela, `#2` é ambíguo, e a ambiguidade já existe hoje |

**Recusado por não ter problema que o justifique**: uma coluna de arranjo desnormalizada em
`collected_issues` no molde de `project_titles` — duplicaria o que `issue_labels` já guarda
com mais informação, e criaria duas verdades que divergem na primeira coleta que falhar no
meio.

## O que este plano NÃO resolve

- **As cinco consultas de hierarquia** — pai, partes, histórico. Fora do protótipo aprovado, e
  rótulo ao lado de uma árvore lê como ruído.
- **Interpretar o conteúdo do rótulo.** `prioridade:alta` continua texto.
- **A busca por número** em `changes.ex:690` continua como está. É busca, não identidade, e
  devolver todos os `#42` é o que uma busca deve fazer.
- **Editar rótulos pela plataforma.** O rótulo é observado.
