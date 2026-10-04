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

## `Algorithms.Betweenness`

```elixir
@spec brandes(adjacency) :: %{id => measure}
```

Sem peso, sem direção, normalizada por (n−1)(n−2)/2 sobre pares não ordenados; n < 3 →
`{:ausente, :network_too_small}` para todos (D4).

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

## `Algorithms.Communities`

```elixir
@spec greedy(adjacency) :: %{partition: %{id => pos_integer}, modularity: float}
@spec modularity(adjacency, partition) :: float
@spec internal_degree(adjacency, partition) :: %{id => non_neg_integer}
```

Clauset–Newman–Moore com peso, resolução 1, desempate pelo par de menor índice, numeração por
tamanho decrescente (FR-027). O mesmo dado dá a mesma partição.

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

## `Algorithms.Layout`

```elixir
@spec fruchterman_reingold([node_id], adjacency, %{seed: integer, iterations: pos_integer}) ::
        %{node_id => {float, float}}        # em [40, 960]², uma casa
```

Usado no cálculo (rede inteira) e na leitura (grafo da visão com alcance parcial). Mesma entrada,
mesma saída.

## `Algorithms.Position`

```elixir
@spec percentiles(%{id => number}) :: %{id => float}                     # posto médio
@spec role(%{degree: float, betweenness: float}, rule :: map) :: %{code, label, sentence, cut}
```

Chamado só por `View`/`Reader`, nunca gravado (R17). Abaixo de `min_people`, `{:ausente,
:network_too_small}` para todos (FR-046).

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
