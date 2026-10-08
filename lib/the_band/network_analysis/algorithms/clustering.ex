defmodule TheBand.NetworkAnalysis.Algorithms.Clustering do
  @moduledoc """
  O coeficiente de clustering médio — feature 076, T043 (FR-039; research.md R6;
  `contracts/algoritmos.md`, `Algorithms.Clustering`; medida `network.clustering.ratio`;
  `network.analysis.parameters.clustering`).

  Na projeção sem direção, **sem peso**: para cada pessoa com ao menos `min_neighbours` vizinhos,
  a fração dos pares de vizinhos que são ligados entre si (Watts e Strogatz; o C^ws de Humphries
  e Gurney). A média é sobre essas pessoas; quem tem menos vizinhos fica **fora da média e é
  contado** (`excluded_degree_below_two`), e nunca entra como 0.

  Puro: sem `Repo`, relógio, `Logger` nem `:digraph`. Depende de: nenhuma ontologia.
  """

  @type adjacency :: %{term() => %{term() => pos_integer()}}

  @doc """
  O clustering médio e quantas pessoas ficaram fora dele. Sem ninguém com vizinhos bastantes,
  `{:ausente, :no_person_with_two_neighbours}`.
  """
  @spec average(adjacency(), pos_integer()) ::
          {:ok, %{value: float(), excluded_degree_below_two: non_neg_integer()}}
          | {:ausente, :no_person_with_two_neighbours}
  def average(adjacencia, minimo \\ 2) do
    {locais, fora} =
      adjacencia
      |> Enum.sort()
      |> Enum.reduce({[], 0}, fn {_u, vizinhos}, {locais, fora} ->
        k = map_size(vizinhos)

        if k < minimo,
          do: {locais, fora + 1},
          else: {[local(adjacencia, Map.keys(vizinhos), k) | locais], fora}
      end)

    case Enum.reverse(locais) do
      [] ->
        {:ausente, :no_person_with_two_neighbours}

      valores ->
        {:ok, %{value: Enum.sum(valores) / length(valores), excluded_degree_below_two: fora}}
    end
  end

  defp local(adjacencia, vizinhos, k) do
    ligados =
      for a <- vizinhos, b <- vizinhos, a < b, Map.has_key?(Map.fetch!(adjacencia, a), b), do: 1

    2 * length(ligados) / (k * (k - 1))
  end
end
