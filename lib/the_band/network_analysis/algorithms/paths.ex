defmodule TheBand.NetworkAnalysis.Algorithms.Paths do
  @moduledoc """
  As distâncias em passos e o que se deriva delas — feature 076, T038 e T041 (FR-035, FR-037,
  FR-038; research.md R6; `contracts/algoritmos.md`, `Algorithms.Paths`;
  `network.analysis.parameters`, `closeness` e `distances`).

  Busca em largura a partir de cada pessoa, sobre a projeção sem direção, **sem peso**: a
  distância é em passos (`undirected_projection.values.distance: hops`).

  - **proximidade** de Wasserman e Faust: ((r − 1)/(n − 1)) · ((r − 1)/D(u)), com r as pessoas que
    u alcança contando u, n as pessoas da rede inteira e D(u) a soma das distâncias. **Nunca** se
    converte 1/proximidade em distância: a distância média da pessoa é D(u)/(r − 1), à parte, com
    quantas ela alcança (a referência fazia a conversão, `dashboard_team_graph.py:318`);
  - **distância média da rede**: a média sobre os pares que se alcançam, com a fração deles sobre
    todos os pares (`reachable_share`); **diâmetro**, a maior delas; **eficiência global** de
    Latora e Marchiori, Σ 1/d sobre **todos** os pares, dividido pelo número de pares — o 0 do par
    sem caminho é a definição (1/∞), e não valor de reserva.

  Toda soma percorre os comprimentos em ordem crescente, para que o mesmo dado dê o mesmo número.

  Puro: sem `Repo`, relógio, `Logger` nem `:digraph`. Depende de: nenhuma ontologia.
  """

  @type id :: term()
  @type adjacency :: %{id() => %{id() => pos_integer()}}
  @type distances :: %{id() => %{id() => pos_integer()}}
  @type measure :: {:ok, number()} | {:ausente, atom()}

  @doc "As distâncias em passos de cada pessoa até cada outra que ela alcança (sem ela mesma)."
  @spec all_pairs(adjacency()) :: distances()
  def all_pairs(adjacencia) do
    Map.new(adjacencia, fn {u, _} -> {u, bfs(adjacencia, u)} end)
  end

  defp bfs(adjacencia, inicio) do
    bfs(adjacencia, [inicio], 1, %{inicio => 0})
    |> Map.delete(inicio)
  end

  defp bfs(_adjacencia, [], _d, vistos), do: vistos

  defp bfs(adjacencia, fronteira, d, vistos) do
    {proxima, vistos} =
      Enum.reduce(fronteira, {[], vistos}, fn u, acc ->
        adjacencia
        |> Map.get(u, %{})
        |> Map.keys()
        |> Enum.reduce(acc, fn v, {prox, vis} ->
          if Map.has_key?(vis, v), do: {prox, vis}, else: {[v | prox], Map.put(vis, v, d)}
        end)
      end)

    bfs(adjacencia, proxima, d + 1, vistos)
  end

  @doc """
  A proximidade de cada pessoa (Wasserman–Faust), com `n` as pessoas da rede inteira. Pessoa que
  não alcança ninguém não tem proximidade: `{:ausente, :no_reachable_person}`.
  """
  @spec closeness(distances(), pos_integer()) :: %{id() => measure()}
  def closeness(distancias, n) do
    Map.new(distancias, fn {u, ate} ->
      case soma_e_alcance(ate) do
        {_soma, 0} -> {u, {:ausente, :no_reachable_person}}
        {soma, r1} -> {u, {:ok, r1 / (n - 1) * (r1 / soma)}}
      end
    end)
  end

  @doc "A distância média de cada pessoa até quem ela alcança, e quantas alcança."
  @spec person_distance(distances()) :: %{
          id() =>
            {:ok, %{mean: float(), reaches: pos_integer()}} | {:ausente, :no_reachable_person}
        }
  def person_distance(distancias) do
    Map.new(distancias, fn {u, ate} ->
      case soma_e_alcance(ate) do
        {_soma, 0} -> {u, {:ausente, :no_reachable_person}}
        {soma, r1} -> {u, {:ok, %{mean: soma / r1, reaches: r1}}}
      end
    end)
  end

  defp soma_e_alcance(ate), do: {ate |> Map.values() |> Enum.sum(), map_size(ate)}

  @doc """
  As medidas da rede: distância média sobre os pares que se alcançam, a fração desses pares,
  o diâmetro, a eficiência global e a distribuição dos comprimentos (`lengths`, comprimento →
  pares). `n` são as pessoas da rede inteira. Sem par que se alcance, as três medidas são
  `{:ausente, :no_edge_in_window}` e a fração é `nil`.
  """
  @spec network(distances(), non_neg_integer()) :: %{
          average: measure(),
          reachable_share: float() | nil,
          diameter: measure(),
          efficiency: measure(),
          lengths: [{pos_integer(), pos_integer()}]
        }
  def network(distancias, n) do
    # Cada par não ordenado aparece duas vezes (u → v e v → u): conta-se uma, a de u < v.
    comprimentos =
      for {u, ate} <- distancias, {v, d} <- ate, u < v, reduce: %{} do
        acc -> Map.update(acc, d, 1, &(&1 + 1))
      end
      |> Enum.sort()

    pares = div(n * (n - 1), 2)
    alcancados = comprimentos |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    if alcancados == 0 do
      %{
        average: {:ausente, :no_edge_in_window},
        reachable_share: nil,
        diameter: {:ausente, :no_edge_in_window},
        efficiency: {:ausente, :no_edge_in_window},
        lengths: []
      }
    else
      soma = comprimentos |> Enum.map(fn {d, c} -> d * c end) |> Enum.sum()
      inversos = comprimentos |> Enum.map(fn {d, c} -> c / d end) |> Enum.sum()

      %{
        average: {:ok, soma / alcancados},
        reachable_share: alcancados / pares,
        diameter: {:ok, comprimentos |> List.last() |> elem(0)},
        efficiency: {:ok, inversos / pares},
        lengths: comprimentos
      }
    end
  end
end
