defmodule TheBand.NetworkAnalysis.Algorithms.SmallWorld do
  @moduledoc """
  Os grafos aleatórios equivalentes e o que se compara com eles — feature 076, T036 (Q_rand),
  T041 (distâncias) e T043 (clustering e σ) (R7, R8; FR-038, FR-040 a FR-043;
  `contracts/algoritmos.md`, `Algorithms.SmallWorld`; `network.analysis.parameters`,
  `small_world` e `modularity_reading`; medida `network.small_world_sigma.score`).

  ## A sequência, declarada

  `random_graphs` grafos G(n, m) com as mesmas `n` pessoas e as mesmas `m` ligações sem direção
  da rede real, todos da **mesma** sequência do gerador (`Algorithms.Random.new(seed)`): o grafo i
  começa onde o i − 1 parou. Em cada um, depois dos pares, os **pesos reais** da projeção sem
  direção, em ordem crescente do par, são embaralhados por Fisher–Yates e dados aos pares na ordem
  em que foram sorteados (`small_world.values.sampling`).

  ## O que se mede em cada aleatório, pelas regras da rede real

  - a **modularidade** da partição que o mesmo guloso com peso encontra (Q_rand, R8);
  - o **clustering** médio, sem peso, com grau < 2 fora da média (`Algorithms.Clustering`);
  - a **distância média**, o **diâmetro** e a **eficiência**, pela mesma regra de pares que se
    alcançam (`Algorithms.Paths.network/2`, com as `n` pessoas, inclusive as que ficaram sem
    ligação no sorteio), e a fração de pares que se alcançam.

  **Todo aleatório gerado entra**, ligado ou não (FR-041): a média divide pelo número de grafos em
  que a medida está definida, e esse número volta junto. Descartar os desconexos escolheria os
  aleatórios a favor de uma resposta.

  ## σ (Humphries e Gurney, 2008)

  σ = (C / C_rand) / (L / L_rand). Ausente, com o motivo da base, abaixo do mínimo de pessoas, sem
  clustering ou distância na rede real, ou com C_rand zero ou indefinido. A ausência **não** diz
  que a rede não é mundo pequeno (FR-042).

  Puro: sem `Repo`, relógio, `Logger` nem processo. Depende de: nenhuma ontologia.
  """

  alias TheBand.NetworkAnalysis.Algorithms.Clustering
  alias TheBand.NetworkAnalysis.Algorithms.Communities
  alias TheBand.NetworkAnalysis.Algorithms.Paths
  alias TheBand.NetworkAnalysis.Algorithms.Random

  @type adjacency :: %{term() => %{term() => pos_integer()}}
  @type com_contagem ::
          {:ok, %{value: float(), graphs_defined: pos_integer()}} | {:ausente, atom()}
  @type medida :: {:ok, number()} | {:ausente, atom()}

  @doc """
  As medidas dos `random_graphs` aleatórios equivalentes à rede de `adjacencia`, com a semente
  dada. A rede precisa ter ao menos uma ligação: sem ela não há aleatório equivalente.
  """
  @spec random_battery(adjacency(), %{
          required(:random_graphs) => pos_integer(),
          required(:seed) => integer()
        }) :: %{
          graphs: pos_integer(),
          modularity: com_contagem(),
          clustering: com_contagem(),
          average_distance: com_contagem(),
          diameter: com_contagem(),
          global_efficiency: com_contagem(),
          reachable_share: float()
        }
  def random_battery(adjacencia, %{random_graphs: quantos, seed: semente})
      when map_size(adjacencia) > 0 do
    n = map_size(adjacencia)
    pesos = pesos_por_par(adjacencia)
    m = length(pesos)

    {medidas, _estado} =
      Enum.map_reduce(1..quantos, Random.new(semente), fn _i, estado ->
        {pares, estado} = Random.gnm(estado, n, m)
        {sorteados, estado} = Random.shuffle(estado, pesos)
        {medir(adjacencia_de(pares, sorteados), n), estado}
      end)

    # Cada aleatório tem as m ≥ 1 ligações da real: a modularidade, a distância e a eficiência
    # estão definidas em todos. O clustering pode não estar (nenhuma pessoa com dois vizinhos).
    %{
      graphs: quantos,
      modularity: media(medidas, :modularity, :no_edge_in_window),
      clustering: media(medidas, :clustering, :random_clustering_undefined),
      average_distance: media(medidas, :average_distance, :no_edge_in_window),
      diameter: media(medidas, :diameter, :no_edge_in_window),
      global_efficiency: media(medidas, :global_efficiency, :no_edge_in_window),
      reachable_share: Enum.sum(Enum.map(medidas, & &1.reachable_share)) / length(medidas)
    }
  end

  @doc """
  σ a partir das medidas da rede real (`clustering`, `average_distance`), das dos aleatórios
  (`random_battery/2`) e do número de pessoas. Devolve também as duas razões.
  """
  @spec sigma(
          %{
            required(:clustering) => medida(),
            required(:average_distance) => medida(),
            optional(atom()) => term()
          },
          %{
            required(:clustering) => com_contagem(),
            required(:average_distance) => com_contagem(),
            optional(atom()) => term()
          },
          non_neg_integer(),
          %{required(:min_people) => pos_integer(), optional(atom()) => term()}
        ) ::
          {:ok, %{value: float(), clustering_ratio: float(), distance_ratio: float()}}
          | {:ausente,
             :network_too_small
             | :no_edge_in_window
             | :clustering_undefined
             | :random_clustering_undefined}
  def sigma(_real, _aleatorios, n, %{min_people: minimo}) when n < minimo,
    do: {:ausente, :network_too_small}

  def sigma(%{average_distance: {:ausente, _}}, _aleatorios, _n, _p),
    do: {:ausente, :no_edge_in_window}

  def sigma(%{clustering: {:ausente, _}}, _aleatorios, _n, _p),
    do: {:ausente, :clustering_undefined}

  def sigma(_real, %{clustering: {:ausente, _}}, _n, _p),
    do: {:ausente, :random_clustering_undefined}

  def sigma(_real, %{clustering: {:ok, %{value: c_rand}}}, _n, _p) when c_rand == 0,
    do: {:ausente, :random_clustering_undefined}

  def sigma(_real, %{average_distance: {:ausente, _}}, _n, _p),
    do: {:ausente, :no_edge_in_window}

  def sigma(real, aleatorios, _n, _p) do
    {:ok, c} = real.clustering
    {:ok, l} = real.average_distance
    {:ok, %{value: c_rand}} = aleatorios.clustering
    {:ok, %{value: l_rand}} = aleatorios.average_distance

    razao_c = c / c_rand
    razao_l = l / l_rand
    {:ok, %{value: razao_c / razao_l, clustering_ratio: razao_c, distance_ratio: razao_l}}
  end

  # Os pesos de cada par sem direção, na ordem crescente do par (`weights_input`).
  defp pesos_por_par(adjacencia) do
    for {u, vizinhos} <- adjacencia, {v, w} <- vizinhos, u < v do
      {{u, v}, w}
    end
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
  end

  defp adjacencia_de(pares, pesos) do
    pares
    |> Enum.zip(pesos)
    |> Enum.reduce(%{}, fn {{u, v}, w}, acc ->
      acc
      |> Map.update(u, %{v => w}, &Map.put(&1, v, w))
      |> Map.update(v, %{u => w}, &Map.put(&1, u, w))
    end)
  end

  # `n` são as pessoas do sorteio: quem ficou sem ligação conta nos pares que não se alcançam.
  defp medir(adjacencia, n) do
    rede = adjacencia |> Paths.all_pairs() |> Paths.network(n)

    %{
      modularity: {:ok, Communities.greedy(adjacencia).modularity},
      clustering:
        case Clustering.average(adjacencia) do
          {:ok, %{value: c}} -> {:ok, c}
          ausente -> ausente
        end,
      average_distance: rede.average,
      diameter: rede.diameter,
      global_efficiency: rede.efficiency,
      reachable_share: rede.reachable_share
    }
  end

  # A média sobre os grafos em que a medida está definida, na ordem em que foram gerados. Sem
  # nenhum, o motivo da base para aquela medida.
  defp media(medidas, chave, motivo) do
    case for(m <- medidas, {:ok, v} <- [Map.fetch!(m, chave)], do: v) do
      [] ->
        {:ausente, motivo}

      valores ->
        {:ok, %{value: Enum.sum(valores) / length(valores), graphs_defined: length(valores)}}
    end
  end
end
