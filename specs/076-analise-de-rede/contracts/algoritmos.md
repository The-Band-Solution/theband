# Contrato — os algoritmos e a visão, puros

Módulos privados de `TheBand.NetworkAnalysis`, sem `Repo`, sem relógio, sem `Logger`, sem processo.
Cada um muda por uma razão (princípio X): a matemática, o sorteio, o desenho, ou a regra de acesso.
Referências e complexidades em [research.md R6](../research.md#r6--os-algoritmos-em-elixir-puro).

Convenções: `id` é o UUID de pessoa; toda lista de saída é ordenada; toda ausência é
`{:ausente, motivo}` com o motivo da base; nenhum valor de reserva.

## `Algorithms.Projection`

```elixir
@spec undirected([%{source: id, target: id, weight: pos_integer()}]) ::
        %{nodes: [id], adjacency: %{id => %{id => pos_integer()}}, edges: non_neg_integer()}
@spec components(%{id => %{id => pos_integer()}}) :: [[id]]   # fracos, por tamanho desc., depois menor id
@spec degrees([edge]) :: %{id => %{out_people: n, in_people: n, degree: n, out_weight: n, in_weight: n}}
```

Peso {u, v} = w(u→v) + w(v→u) (FR-010). O par recíproco conta uma vez no grau (FR-033).

## `Algorithms.Paths`

```elixir
@spec all_pairs(adjacency) :: %{id => %{id => pos_integer()}}            # distâncias em passos, BFS
@spec closeness(distances, n) :: %{id => measure}                         # Wasserman–Faust
@spec person_distance(distances) :: %{id => {:ok, %{mean: float, reaches: pos_integer}} | {:ausente, :no_reachable_person}}
@spec network(distances, n) :: %{average: measure, reachable_share: float | nil, diameter: measure, efficiency: measure}
```

Sem par que se alcance: as três medidas da rede `{:ausente, :no_edge_in_window}`. Na eficiência, o 0
de par inalcançável é **definição** (1/∞), e está dito na medida.

**Emenda de 2026-10-05 (T038, T041)**, no mesmo commit da implementação: `network/2` devolve
também `lengths`, a distribuição dos comprimentos (`[{passos, pares}]`, crescente; 3.5.2). Cada par
não ordenado conta uma vez. As distâncias são em passos, sem peso. `person_distance/1` devolve
`{:ok, %{mean, reaches}}`; `closeness/2` usa o `n` da rede inteira.

## `Algorithms.Betweenness`

```elixir
@spec brandes(adjacency, %{min_people: pos_integer}) :: %{id => {:ok, float} | {:ausente, :network_too_small}}
```

Sem peso, sem direção, normalizada por (n−1)(n−2)/2 sobre pares não ordenados; n < 3 →
`{:ausente, :network_too_small}` para todos (D4).

**Emenda de 2026-10-04 (T030)**, no mesmo commit da implementação: o mínimo vem da base
(`betweenness.values.min_people`, por `Parameters`), e não do código — a regra *"nenhum valor da
base no código"* vale também para ele. Abaixo de 3 a normalização não existe, e a ausência vale
qualquer que seja o valor da base. Gravado no nó como `"betweenness" => %{"value" => v}` ou
`%{"absent" => "network_too_small"}` ([data-model.md §1.2](../data-model.md)).

## `Algorithms.Eigenvector`

```elixir
@spec by_component(adjacency, components, %{tolerance_per_node: float, max_iterations: pos_integer}) ::
        %{id => {:ok, float} | {:ausente, :did_not_converge}}
```

Iteração sobre A + I com peso, por componente com ≥ 2 pessoas, partindo de 1, norma L2. Componente
que não converge: **todos** dele ausentes; nenhum outro afetado (FR-036).

## `Algorithms.Clustering`

```elixir
@spec average(adjacency) :: {:ok, %{value: float, excluded_degree_below_two: non_neg_integer}}
                            | {:ausente, :no_person_with_two_neighbours}
```

Sem peso. Grau < 2 fora da média e contado (D5).

**Emenda de 2026-10-05 (T043)**, no mesmo commit da implementação: `average/2` recebe o mínimo de
vizinhos da base (`clustering.values.min_neighbours`, padrão 2).

## `Algorithms.Communities`

```elixir
@spec greedy(adjacency) :: %{partition: %{id => pos_integer}, modularity: float}
@spec modularity(adjacency, partition) :: float
@spec internal_degree(adjacency, partition) :: %{id => non_neg_integer}
```

Clauset–Newman–Moore com peso, resolução 1, desempate pelo par de menor índice, numeração por
tamanho decrescente (FR-027). O mesmo dado dá a mesma partição.

**Emenda de 2026-10-05 (T035)**, no mesmo commit da implementação:

- a comparação do ΔQ é feita no **inteiro** ΔQ·2W² = 2W·w_ij − S_i·S_j (os pesos são contagens):
  dois pares de mesmo ΔQ empatam de verdade, e o desempate declarado decide, nunca o
  arredondamento. A modularidade soma os numeradores inteiros e divide uma vez;
- a comunidade juntada fica com o menor índice, que é sempre o do seu membro de menor id;
- `greedy/1` e `modularity/2` exigem ao menos uma aresta: sem aresta não há comunidade, e quem
  chama grava a ausência (`no_edge_in_window`);
- acrescentada `summary/2`, para a leitura gravar o que a tela mostra de cada comunidade:

```elixir
@spec summary(adjacency, partition) ::
        [%{index: pos_integer, members: [id], internal_edges: non_neg_integer, outside_edges: non_neg_integer}]
```

  `internal_edges` são os pares sem direção dentro da comunidade; `outside_edges`, os que saem
  para outra (protótipo 3.3.4, *"links inside · to other communities"*).

## `Algorithms.Random`

```elixir
@spec new(seed :: integer) :: state                      # :rand.seed_s(:exsss, seed); estado explícito
@spec gnm(state, n :: pos_integer, m :: non_neg_integer) :: {[{pos_integer, pos_integer}], state}
@spec shuffle(state, list) :: {list, state}              # Fisher–Yates
```

Nunca o dicionário do processo. Duas chamadas com o mesmo estado dão a mesma saída (SC-003).

## `Algorithms.SmallWorld`

```elixir
@spec random_battery(adjacency, %{random_graphs: pos_integer, seed: integer}) ::
        %{clustering: measure_with_count, average_distance: measure_with_count,
          diameter: measure, global_efficiency: measure, modularity: measure_with_count,
          reachable_share: float | nil}
@spec sigma(real :: %{clustering: measure, average_distance: measure}, random :: map, n, %{min_people: pos_integer}) ::
        {:ok, float} | {:ausente, :network_too_small | :random_clustering_undefined | :clustering_undefined | :no_edge_in_window}
```

Os 100 grafos G(n, m) na mesma sequência; os pesos reais sorteados para o Q_rand (R8). Toda média
divide pelo número de grafos em que a medida está definida, que é devolvido.

**Emenda de 2026-10-05 (T036)**, no mesmo commit da implementação: `random_battery/2` devolve
também `graphs` (quantos foram gerados), e cada medida com contagem é `{:ok, %{value, graphs_defined}}`
ou `{:ausente, motivo}`. Nesta tarefa ela calcula só `modularity`; `clustering`,
`average_distance`, `diameter`, `global_efficiency` e `reachable_share` entram com T041 e T043,
no mesmo laço e na mesma sequência — nenhuma delas consome o gerador, e o Q_rand não muda quando
elas entram. Os pesos de cada aleatório são os da projeção real em ordem crescente do par,
embaralhados por `Random.shuffle/2` depois dos pares do mesmo grafo, e dados aos pares na ordem
do sorteio. Exige ao menos uma ligação: sem ela, quem chama grava `no_edge_in_window`.

**Emenda de 2026-10-05 (T041, T043)**, no mesmo commit da implementação: `random_battery/2`
mede, no mesmo laço da modularidade, `clustering` (ausente em todos → `random_clustering_undefined`),
`average_distance`, `diameter` e `global_efficiency` (pela regra de pares que se alcançam, com as
`n` pessoas, inclusive as que ficaram sem ligação no sorteio) e a média de `reachable_share`.
**Todo aleatório entra**, ligado ou não. `sigma/4` devolve `{:ok, %{value, clustering_ratio,
distance_ratio}}`; a ordem das ausências é: abaixo do mínimo (`network_too_small`), sem distância
real (`no_edge_in_window`), sem clustering real (`clustering_undefined`), C_rand ausente ou zero
(`random_clustering_undefined`).

**Emenda de 2026-10-06 (T053)**, no mesmo commit da implementação: `random_battery/2` devolve
também `not_linked`, quantos aleatórios ficaram com algum par sem caminho (`reachable_share < 1`).
Neles, a distância média é a dos pares que se alcançam. A tela da Distance diz quantos e como
(PROMPT §3, 3.5.4), o que antes não dizia.

## `Algorithms.Layout`

```elixir
@spec fruchterman_reingold([node_id], adjacency, %{seed: integer, iterations: pos_integer}) ::
        %{node_id => {float, float}}        # em [40, 960]², uma casa
```

Usado no cálculo (rede inteira) e na leitura (grafo da visão com alcance parcial). Mesma entrada,
mesma saída.

**Emenda de 2026-10-04 (T031)**, no mesmo commit da implementação:

- `ids` é reordenado por id dentro da função: a ordem de quem chama não muda o desenho;
- 0 nós → `%{}`; 1 nó → o centro, `{500.0, 500.0}`; todos no mesmo ponto → o centro;
- as posições iniciais vêm de `Algorithms.Random.uniform/1` (acrescentada: `@spec uniform(state)
  :: {float, state}`, `:rand.uniform_real_s/1` com o estado explícito), x e depois y, em ordem
  crescente de id; o estado nasce de `Random.new(seed)`, à parte de `small_world`;
- passo como `networkx`: temperatura inicial 0,1, decrescida de 0,1/(iterações + 1) a cada
  iteração; deslocamento de cada nó calculado com as posições da iteração anterior (síncrono);
  distância mínima 0,01 (é piso numérico da força, como no `networkx`, e não valor de medida);
- reescala que preserva a proporção: centra na média e divide pelo maior |coordenada| dos dois
  eixos, para [40, 960]², uma casa.

## `Algorithms.Position`

```elixir
@spec percentiles(%{id => number}) :: %{id => float}                     # posto médio
@spec role(%{degree: float, betweenness: float}, rule :: map) :: %{code, label, sentence, cut}
```

Chamado só por `View`/`Reader`, nunca gravado (R17). Abaixo de `min_people`, `{:ausente,
:network_too_small}` para todos (FR-046).

**Emenda de 2026-10-05 (T045)**, no mesmo commit da implementação:

- o motivo da ausência é o da base, `network_too_small_for_roles`
  (`network.position_percentile.percentage`), e não `network_too_small`;
- acrescentadas `order/0` (a ordem dos cortes que o código implementa, conferida contra a de
  `network.position_role.cuts.order`: diferente, levanta) e `roles/2`:

```elixir
@spec roles(%{id => %{degree: number, betweenness: measure}}, rule) ::
        %{id => {:ok, role} | {:ausente, :network_too_small_for_roles}}
```

  que calcula os percentis sobre todas as pessoas e o papel de cada uma; abaixo do mínimo, ou com
  a intermediação ausente, todas ausentes;
- `role/2` devolve `%{code, label, sentence, degree_percentile, betweenness_percentile, cut}`, com o
  rótulo e a frase de `network.position_role.labels` e o corte escrito com os limiares da base.

## `AssignmentClassification` (T024; acrescentado em 2026-10-04, antes do código)

```elixir
@spec order() :: [String.t()]   # ~w(bot_or_app organization_account unlinked_person self_assignment)
@spec classify([WorkItems.assignment_pair()], %{id => String.t()}, MapSet.t()) ::
        [%{collected_issue_id: id, opened_at: DateTime.t(), destino: destino, unknown_type?: boolean()}]
@spec summarize([classificado], inicio :: DateTime.t()) ::
        %{edges: [%{source: id, target: id, weight: pos_integer()}],   # por (source, target)
          exclusions: %{String.t() => non_neg_integer()},
          account_type_unknown: non_neg_integer()}
```

`destino` é `{:aresta, autor, responsavel}`, um dos quatro motivos da base, ou `:no_assignee` (a
issue sem responsável vigente, que não é par). A ordem é a de `assignment.network.edge`;
`Parameters` confere a da base contra `order/0`, e levanta se divergirem. Cada lado do par diz os
fatos que tem (máquina, declarada da organização, sem pessoa, tipo nulo, pessoa), e a ordem
decide qual pesa: a conta que é máquina **e** declarada conta uma vez, como máquina.

`summarize/2` filtra pelo instante de abertura (`opened_at >= inicio`) e devolve em `exclusions`
os quatro motivos, `pairs`, `issues` e `issues_without_assignee`. O peso é o número de issues
distintas do par. Invariante: soma dos pesos + os quatro motivos = `pairs`. Nenhum login entra nem
sai (R9).

## `View.build/5`

```elixir
@spec build(reading, reach :: :todas | {:algumas, MapSet.t()}, granted :: :todas | {:algumas, MapSet.t()},
            viewer_person_id :: id | nil, params) :: view_without_names
```

As dez regras de [research.md R10](../research.md#r10--a-visão-recortada-fr-011-a-fr-016-r1r6-da-segurança).
O id de agregado é `"outside-<n>"`, sem relação com `person_id`. A mesma visão serve ao grafo
ponderado, ao de comunidades e à lista do telefone.

## O que estes módulos não fazem

Não leem banco nem base (recebem os parâmetros), não leem relógio, não registram log, não guardam
estado entre chamadas, não chamam `:digraph`, não criam átomo a partir de dado.
