# Tarefas — Feature 017: a tabela que busca, ordena e pagina

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md)

## F1 — a consulta

### T001 Buscar e ordenar no banco, com o total
- **Pronta quando**: o contrato existe em `contracts/tabela.md`.
- **Descrição**: `list_issues/2` ganha `search:` e `order_by:`; e `count_collected/2` passa a
  aceitar o mesmo `search:`, para que o total case com a lista. A ordem escolhida **antecede** o
  desempate que já existe — `observed_repository_id, number, id` —, que é o que impede página
  sobreposta. Ordenar por coluna derivada usa a junção lateral da feature 013. FR-001, FR-004,
  FR-005.
- **Feita quando**: buscar por texto que só existe na última página o encontra; ordenar por
  conceito funciona; e o total reflete a busca.
- **Teste**: `test/the_band/work_items/busca_e_ordem_test.exs` — o caso que importa é o da última
  página, que é onde "buscar em memória" seria pego.

## F2 — o componente

### T002 O componente de tabela
- **Pronta quando**: T001 feita.
- **Descrição**: em `core_components.ex`. Recebe as colunas — rótulo, se ordena, e o campo —, o
  escopo da busca e a paginação. Cabeçalho clicável com direção visível **sem depender de cor**;
  coluna não ordenável não parece clicável. FR-006, FR-007, FR-011, FR-013.
- **Feita quando**: uma tela declara colunas e ganha as três coisas; e em 360 px ordenar continua
  possível.
- **Teste**: `test/the_band_web/live/tabela_test.exs`.

### T003 A lista de trabalho usa o componente
- **Pronta quando**: T002 feita.
- **Descrição**: `/work` passa a usar, com busca em título e repositório. Estado na URL. FR-002,
  FR-010.
- **Feita quando**: recarregar com busca e ordem devolve a mesma tela; e o endereço é
  compartilhável.
- **Teste**: o teste segue o `push_patch` e confere os parâmetros.

## F3 — as outras listas

### T004 As demais tabelas
- **Pronta quando**: T003 feita.
- **Descrição**: `/people`, `/teams`, `/work/repositories/:id` e as de administração. **Cada uma
  declara o próprio escopo de busca** — e a tela diz onde procura. FR-002.
- **Feita quando**: as tabelas usam o componente; e `/teams`, com 12 linhas, **não** exibe
  paginação. FR-009.
- **Teste**: percorre as telas, como o da migalha faz.

## F4 — a prova

### T005 [P] A medida, e o que não pode piorar
- **Pronta quando**: T003 feita.
- **Descrição**: medir `/work` com busca e ordem ativas, e ordenar por conceito derivado. Comparar
  com o antes: 120 ms e 14,2 ms. FR-012, SC-003, SC-004.
- **Feita quando**: a tabela antes/depois está na review, e nenhum número piorou.
- **Teste**: mede linhas lidas e tempo, com guarda de que a medida não é zero — L50.

### T006 [P] A ordem não se repete entre páginas
- **Pronta quando**: T003 feita.
- **Descrição**: percorrer todas as páginas de uma ordem e conferir que **nenhuma linha aparece
  duas vezes**, e que nenhuma some. FR-005, SC-005.
- **Feita quando**: a união das páginas é igual ao total, sem repetição.
- **Teste**: o conjunto de ids de todas as páginas tem tamanho igual ao total.
