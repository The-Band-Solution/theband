# Tarefas — Feature 006: detalhe da issue e decomposição navegável

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/issue-detail.md](contracts/issue-detail.md)

**Estado**: as 19 tarefas estão **feitas**, e este documento foi escrito depois da execução.
A dívida de processo está declarada no [plano](plan.md#ordem-e-a-dívida-de-processo). O que
ele registra com valor é o que cada tarefa entregou e **como isso foi provado** — inclusive as
duas que um teste reprovou antes de aceitar.

Ordem: F1 (campos) → F2 (leituras) → F3 (axioma) → F4 (telas). É dependência, não preferência:
sem coluna não há o que ler, e sem leitura não há o que a tela mostre.

---

## Fase F1 — Os campos na origem e no banco

- [X] T001 Pedir os campos novos à origem
  - **Pronta quando**: a consulta de issues da feature 004 existe
  - **Descrição**: acrescentar a `priv/connectors/github/queries/issues.graphql` os subcampos
    `bodyText`, `stateReason`, `updatedAt`, `closedAt`, `author { login }`,
    `assignees(first: 10)`, `labels(first: 20)`, `milestone { title }`,
    `projectItems(first: 10)`, `comments { totalCount }` e `reactions { totalCount }`. Todos
    no **mesmo nó** que já era buscado: nenhuma requisição adicional (FR-034). `bodyText` e
    **não** `body` — o segundo traz markdown cru, e a tela renderizaria marcação da origem
  - **Feita quando**: a consulta devolve autor, motivo do fechamento e rótulos para a issue
    `#1` do repositório `theband`
  - **Teste**: `gh api graphql -f query="$(cat priv/connectors/github/queries/issues.graphql)"`
    com `owner` e `name`, conferindo que `author.login` e `stateReason` vêm preenchidos

- [X] T002 Criar as colunas do detalhe
  - **Pronta quando**: T001 feita
  - **Descrição**: migração `20260811180000_add_issue_details.exs` com as nove colunas de
    `data-model.md`. `body` é `text`; `project_titles` é `text[]` com `default: []`;
    `comment_count` e `reaction_count` são `integer not null default 0` — porque zero é zero,
    e é diferente de ausente. `author_person_id` referencia `eo_people` com
    `on_delete: :nilify_all`. **Nenhuma coluna é removida**
  - **Feita quando**: `body` aceita nulo e o `nil` é distinguível de `""`; o índice
    `(tenant_id, author_person_id)` existe
  - **Teste**: round trip — `mix ecto.migrate`, `mix ecto.rollback --step 1`,
    `mix ecto.migrate`, sem erro nas três

- [X] T003 Criar as tabelas de designado e rótulo
  - **Pronta quando**: T002 feita
  - **Descrição**: migração `20260811180100_create_issue_assignees_and_labels.exs`.
    `issue_assignees` com `login` obrigatório e `person_id` **anulável**; `issue_labels` com
    `name` obrigatório e `color` anulável. Únicos em `(collected_issue_id, login)` e
    `(collected_issue_id, name)`, e um índice `(tenant_id, name)` nos rótulos. Tabela e não
    coluna: designado e rótulo são zero-ou-muitos
  - **Feita quando**: inserir o mesmo login duas vezes na mesma issue é recusado pelo índice
  - **Teste**: round trip das duas migrações, e o teste de idempotência de T007

- [X] T004 Aceitar os campos novos no schema
  - **Pronta quando**: T002 e T003 feitas
  - **Descrição**: acrescentar os nove campos a
    `lib/the_band/work_items/schemas/collected_issue.ex` e criar
    `issue_assignee.ex` e `issue_label.ex`. O moduledoc de cada um registra por que é tabela e
    por que `person_id` nulo é **declaração**, não falha
  - **Feita quando**: `mix compile --warnings-as-errors` passa e o changeset aceita os nove
  - **Teste**: `mix test test/the_band/work_items/detail_test.exs -o "traz os campos"`

- [X] T005 Resolver autor e designados em lote
  - **Pronta quando**: T004 feita
  - **Descrição**: `EO.person_ids_by_login/1` devolve o mapa login → id numa consulta, e
    `github_work_items.ex` o carrega **uma vez por coleta**. Uma consulta por login seriam
    4463 idas ao banco só para resolver autor. Login sem pessoa coletada **não** cria pessoa:
    o vínculo fica ausente (FR-004)
  - **Feita quando**: uma coleta com 4463 issues faz **uma** consulta de resolução de pessoa
  - **Teste**: a coleta contra o dado real, conferindo `author_person_id` preenchido onde a
    pessoa existe e nulo onde não

- [X] T006 Gravar os campos na coleta
  - **Pronta quando**: T005 feita
  - **Descrição**: em `gravar_issue/3`, repassar os nove campos e chamar
    `replace_assignees/3` e `replace_labels/3`. O título do quadro entra como **referência**:
    `titulos_de_quadro/1` extrai só o título, porque a coleta de quadros como entidade ficou
    fora da feature 004
  - **Feita quando**: depois de sincronizar, `body`, `author_login` e os rótulos estão
    preenchidos no banco
  - **Teste**: V1 do [quickstart](quickstart.md) — o contraste entre antes e depois da coleta

- [X] T007 Substituir designados e rótulos de forma idempotente
  - **Pronta quando**: T003 feita, e o contrato declara a semântica
  - **Descrição**: `replace_assignees/3` e `replace_labels/3` em
    `work_items/commands.ex`. Apagam o que a origem não traz mais — **contra** a regra geral
    "ausência marca, nunca apaga", com a razão e o critério de reversão em R3 da pesquisa. O
    rótulo é preservado e **não** promovido: `bug` não faz a issue um defeito
  - **Feita quando**: chamar duas vezes com o mesmo dado deixa uma linha; chamar com lista
    menor remove a que saiu
  - **Teste**: `mix test test/the_band/work_items/detail_test.exs -o "não duplica"` e
    `-o "remove o que a origem não traz"`

---

## Fase F2 — As leituras, e a separação na API

- [X] T008 Buscar a issue com tudo o que se sabe dela
  - **Pronta quando**: F1 feita, e `contracts/issue-detail.md` declara a assinatura
  - **Descrição**: `fetch_issue/2` em `work_items/queries.ex` — a issue, a promoção
    **vigente**, designados, rótulos e a classificação. Issue de outro tenant devolve
    `{:error, :not_found}`, **nunca** `:unauthorized`: dizer "sem permissão" confirmaria que o
    recurso existe (FR-032)
  - **Feita quando**: o mapa traz os 25 campos do contrato, e o tenant errado devolve
    `:not_found`
  - **Teste**: `-o "issue de outro tenant devolve não encontrada"`, que também **recusa** a
    palavra "permissão"

- [X] T009 Separar composição de atendimento na API
  - **Pronta quando**: T008 feita
  - **Descrição**: `list_composition/2` filtra as partes promovidas a épico ou user story
    atômica; `list_attendance/2` filtra as promovidas a tarefa. **Nenhuma função devolve as
    duas juntas**, e o contrato declara a ausência de `count_children/2` com o motivo. A
    separação tem de estar na API: deixá-la só na tela permitiria a soma em qualquer consumidor
    futuro
  - **Feita quando**: no épico do cenário, 9 e 30; e nenhuma função da fronteira devolve 39
  - **Teste**: `-o "as duas relações têm contagens próprias"`, com os três `refute`

- [X] T010 Listar as partes que a plataforma não promoveu
  - **Pronta quando**: T009 feita
  - **Descrição**: `list_unpromoted_parts/2`. Sem ela, composição + atendimento é menor que o
    que a origem declara e quem lê conclui que a plataforma perdeu vínculos — ela não perdeu:
    falta regra de mapeamento, que é a feature 005
  - **Feita quando**: uma issue sem partes tem as três listas vazias, e isso distingue "sem
    partes" de "partes perdidas"
  - **Teste**: `-o "terceira lista"`

- [X] T011 Achar o pai, e deixar `nil` ser resposta
  - **Pronta quando**: T008 feita
  - **Descrição**: `fetch_parent/2` devolve o pai vigente com o conceito dele, ou `nil`.
    Para tarefa é a user story que ela atende; para user story dentro de épico é o épico — é a
    mesma relação vista de baixo. `nil` é resposta, não erro
  - **Feita quando**: a issue sem pai devolve `nil` e a tela não quebra
  - **Teste**: `-o "issue sem pai devolve nil"`

- [X] T012 Ler o histórico de promoção em ordem
  - **Pronta quando**: T008 feita
  - **Descrição**: `promotion_history/2` em ordem crescente de `inserted_at`, marcando a
    **última** como vigente. Microssegundo importa: duas promoções do mesmo segundo tornariam
    "a vigente" dependente do plano de execução, e é a L20
  - **Feita quando**: duas promoções produzem duas linhas, e só a segunda é vigente
  - **Teste**: `-o "cada decisão é uma linha"`

- [X] T013 Mostrar os vínculos recusados na issue
  - **Pronta quando**: T008 feita
  - **Descrição**: `list_refused_for/2` devolve as recusas que envolvem a issue como pai **ou**
    como parte, com motivo e caminho do ciclo. Aparece nas duas issues envolvidas: a recusa é
    do vínculo, e quem abre qualquer uma das duas precisa saber
  - **Feita quando**: as 4 recusas do dado real aparecem no detalhe das issues envolvidas
  - **Teste**: a seção "Vínculos recusados" renderizada com o `cycle_path`

---

## Fase F3 — O axioma como função pura

- [X] T014 Verificar `sro.rule07` em função pura
  - **Pronta quando**: T011 feita
  - **Descrição**: `TheBand.WorkItems.Axioms.rule07/2` recebe o conceito da issue e o do pai e
    devolve `:ok` ou `{:violation, forma}`. Duas formas **separadas**: `task_parent_is_epic` e
    `task_without_parent` — não são caso uma da outra, e pedem ações diferentes. Issue que não
    é tarefa não viola nada. E **nada é despromovido**: o inválido é o vínculo (FR-024)
  - **Feita quando**: as quatro combinações da tabela devolvem o esperado, inclusive
    `rule07(nil, nil) == :ok`
  - **Teste**: `-o "tarefa cujo pai é épico viola"`

- [X] T015 Alimentar o axioma com o grafo em lote
  - **Pronta quando**: T014 feita
  - **Descrição**: `rule07_violations/2` traz as tarefas com o conceito do pai ao lado — um
    `left_join`, que é o que torna "sem pai" um **valor** em vez de ausência de linha — e
    aplica a função pura em memória. Uma consulta por issue seriam 4463 idas ao banco para
    desenhar uma tela; é o mesmo desenho de `list_links/1`
  - **Feita quando**: no dado real, 41 tarefas com pai épico e 3 sem pai
  - **Teste**: V5 e V6 do [quickstart](quickstart.md), conferidos por SQL contra a origem

- [X] T016 Provar que os dois caminhos concordam
  - **Pronta quando**: T015 feita
  - **Descrição**: teste que compara o conjunto de violações da consulta em lote com o de
    verificar issue por issue. Existe porque é a lição de `classification/2` na segunda forma:
    duas implementações do mesmo axioma fariam a tela do repositório avisar o que o detalhe
    nega
  - **Feita quando**: os dois conjuntos são iguais
  - **Teste**: `-o "concorda com a verificação de uma issue só"`. **Este teste já foi
    corrigido uma vez**: a primeira versão usava `for issue <- ..., pai = fetch_parent(...)`,
    e em comprehension uma expressão que não é gerador vale como filtro pelo seu valor — então
    `pai = nil` descartava justamente a tarefa sem pai, e o teste concordava por não olhar

---

## Fase F4 — As duas telas

- [X] T017 Centralizar a tradução dos conceitos
  - **Pronta quando**: F2 feita
  - **Descrição**: `TheBandWeb.ConceptLabel` com `conceitos/0`, `rotulo/1`, `motivo/1` e
    `recusa/1`. Três telas exibem os mesmos conceitos, e com a lista copiada `sro.epic` viraria
    "épico" numa e "epic" na outra. Identificador sem tradução é devolvido **como está**, nunca
    vazio nem inferido — inferir seria a semelhança de nome que o princípio I proíbe, escondida
    na apresentação
  - **Feita quando**: `/trabalho` deixa de ter a lista própria e passa a usar o módulo
  - **Teste**: a suíte de `/trabalho` continua verde depois da troca

- [X] T018 Tela de detalhe da issue
  - **Pronta quando**: F2, F3 e T017 feitas
  - **Descrição**: `lib/the_band_web/live/work_item_live/show.ex` em
    `/trabalho/issues/:id`. Composição e atendimento em **seções separadas**, cada uma com o
    identificador da relação à vista (FR-015). Corpo renderizado como texto com
    `whitespace-pre-wrap`; `nil` e `""` com mensagens diferentes. Promoção com regra e versão,
    divergência, histórico. Aviso do axioma **antes** de tudo, porque muda como se lê o resto.
    Autor e designados pelo nome quando a pessoa foi coletada, pelo login quando não
  - **Feita quando**: no épico do cenário a tela mostra 9 e 30, e **39 não aparece em lugar
    nenhum**
  - **Teste**: `mix test test/the_band_web/live/issue_detail_test.exs`, e em particular o
    `refute html =~ ">39<"`. **Este `refute` reprovou a primeira versão**: eu exibia "partes
    declaradas: 39" no painel lateral, que é exatamente a leitura somada que o SC-004 proíbe.
    No lugar entrou o que a soma escondia — quantas partes a origem declara e a plataforma
    **não tem**

- [X] T019 Tela do repositório com as issues dele
  - **Pronta quando**: T017 feita
  - **Descrição**: `lib/the_band_web/live/repository_live/show.ex` em
    `/trabalho/repositorios/:id`. Contagem por conceito que **soma o total**, com o desvio
    visível quando não fecha; paginação com ordem estável; os avisos do axioma em duas listas
    separadas; e três vazios diferentes — coletado e vazio, excluído da observação, inacessível
    —, porque "não olhamos" não é o mesmo que "não há". `CMPO.list_observed/2` passa a expor
    `description`, `external_created_at` e `collected_at`, que FR-031 pede
  - **Feita quando**: o total do cabeçalho bate com a listagem, e repositório excluído mostra
    as issues com a explicação
  - **Teste**: `-o "contagem do cabeçalho soma"`, `-o "paginação é estável"`,
    `-o "avisos do axioma aparecem no repositório"`

- [X] T020 Tornar os títulos navegáveis
  - **Pronta quando**: T018 e T019 feitas
  - **Descrição**: em `/trabalho`, o nome do repositório e o número e título da issue passam a
    abrir o detalhe **na plataforma** — não a origem. O que interessa ao clicar é o que foi
    coletado; o link para a origem está dentro de cada tela. A divergência do cartão também
    leva à issue, e para isso `list_divergences/2` passou a devolver o `id`
  - **Feita quando**: os três links existem em `/trabalho` e levam às telas certas
  - **Teste**: `-o "o título da issue na listagem leva ao detalhe"` e
    `-o "o nome do repositório leva às issues dele"`

---

## Dependências

```text
T001 → T002 → T003 → T004 → T005 → T006
                              T007 ─┘
F1 → T008 → T009 → T010
       ├──→ T011 → T014 → T015 → T016
       ├──→ T012
       └──→ T013
F2 + F3 → T017 → T018, T019 → T020
```

## Cobertura

| Requisitos | Tarefas |
|---|---|
| FR-001 a FR-007 (coleta) | T001, T002, T003, T004, T005, T006, T007 |
| FR-008 a FR-014 (detalhe) | T008, T012, T018 |
| FR-015 a FR-021 (decomposição) | T009, T010, T011, T018 |
| FR-022 a FR-025 (axioma e recusa) | T013, T014, T015, T016, T018, T019 |
| FR-026 a FR-031 (repositório) | T019, T020 |
| FR-032 a FR-034 (transversais) | T001, T008, T019 |

**34 de 34 requisitos com tarefa.** SC-001 a SC-013 verificados por V1 a V12 do
[quickstart](quickstart.md).

## Fora do escopo, e ficou de fora

| Item | Destino |
|---|---|
| comentários e timeline | product backlog; entidade própria |
| pull requests da issue | product backlog; é CMPO |
| histórico de mudança de estado | exigiria timeline |
| quadro como entidade | feature 004 F4, não implementada |
| markdown renderizado | recusado em R1, com o motivo |
