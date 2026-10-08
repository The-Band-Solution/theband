defmodule TheBand.NetworkAnalysis.Algorithms.Eigenvector do
  @moduledoc """
  A centralidade de autovetor, por componente — feature 076, T039 (FR-036; research.md R6;
  `contracts/algoritmos.md`, `Algorithms.Eigenvector`; `network.analysis.parameters.eigenvector`;
  medida `network.eigenvector.score`).

  Iteração de potência sobre **A + I**, com peso (a soma dos dois sentidos), em cada componente
  com ao menos `min_component_size` pessoas, partindo de x = 1, normalizada em L2. Converge quando
  Σ|x − x_anterior| < n_c × `tolerance_per_node`, até `max_iterations`. O deslocamento pela
  identidade é o que faz a rede bipartida convergir: sobre A ela oscila.

  **Sem convergência, todos os do componente ficam ausentes** (`did_not_converge`); nenhum outro
  componente muda, e nenhum valor de reserva entra — nem 0,01, nem o grau.

  Valores de componentes diferentes não se comparam: cada componente tem a sua norma.

  Puro: sem `Repo`, relógio, `Logger` nem `:digraph`. Depende de: nenhuma ontologia.
  """

  @type id :: term()
  @type adjacency :: %{id() => %{id() => pos_integer()}}

  @doc "O autovetor de cada pessoa, componente por componente."
  @spec by_component(adjacency(), [[id()]], %{
          required(:tolerance_per_node) => float(),
          required(:max_iterations) => pos_integer(),
          optional(:min_component_size) => pos_integer()
        }) :: %{id() => {:ok, float()} | {:ausente, :did_not_converge | :component_too_small}}
  def by_component(adjacencia, componentes, params) do
    minimo = Map.get(params, :min_component_size, 2)

    componentes
    |> Enum.flat_map(fn membros ->
      membros = Enum.sort(membros)

      if length(membros) < minimo,
        do: Enum.map(membros, &{&1, {:ausente, :component_too_small}}),
        else: iterar(adjacencia, membros, params)
    end)
    |> Map.new()
  end

  defp iterar(adjacencia, membros, %{tolerance_per_node: tol, max_iterations: teto}) do
    inicial = Map.new(membros, &{&1, 1.0})
    limite = length(membros) * tol

    case passo(adjacencia, membros, inicial, limite, teto) do
      {:ok, x} -> Enum.map(membros, &{&1, {:ok, Map.fetch!(x, &1)}})
      :did_not_converge -> Enum.map(membros, &{&1, {:ausente, :did_not_converge}})
    end
  end

  defp passo(_adjacencia, _membros, _x, _limite, 0), do: :did_not_converge

  defp passo(adjacencia, membros, x, limite, restantes) do
    # (A + I)·x: cada pessoa fica com o próprio valor mais o dos vizinhos, pelo peso, somados na
    # ordem do id.
    y =
      Map.new(membros, fn u ->
        vizinhos = adjacencia |> Map.fetch!(u) |> Enum.sort()
        {u, Enum.reduce(vizinhos, Map.fetch!(x, u), fn {v, w}, s -> s + w * Map.fetch!(x, v) end)}
      end)

    norma = membros |> Enum.map(&(Map.fetch!(y, &1) ** 2)) |> Enum.sum() |> :math.sqrt()
    y = Map.new(y, fn {u, v} -> {u, v / norma} end)
    mudanca = membros |> Enum.map(&abs(Map.fetch!(y, &1) - Map.fetch!(x, &1))) |> Enum.sum()

    if mudanca < limite,
      do: {:ok, y},
      else: passo(adjacencia, membros, y, limite, restantes - 1)
  end
end
