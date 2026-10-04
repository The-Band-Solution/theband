defmodule TheBand.NetworkAnalysis.Algorithms.Projection do
  @moduledoc """
  A projeção sem direção, os componentes e os graus — feature 076, T012 (FR-010, FR-019, FR-033;
  `contracts/algoritmos.md`, `Algorithms.Projection`;
  `network.analysis.parameters.undirected_projection` e `.connectivity`).

  - **peso** de {u, v} = w(u → v) + w(v → u). A referência usava `to_undirected()`, que guarda o
    peso de UM sentido, conforme a ordem de inserção; a soma não depende de ordem e não descarta
    observação;
  - **componentes fracos** (direção ignorada), por tamanho decrescente e, no empate, pelo menor id;
  - **grau** em pessoas distintas: o par recíproco conta uma vez no total.

  Puro: sem `Repo`, relógio, `Logger` nem `:digraph`. Toda lista de saída é ordenada. Depende de:
  nenhuma ontologia.
  """

  @type id :: String.t()
  @type edge :: %{source: id(), target: id(), weight: pos_integer()}
  @type adjacency :: %{id() => %{id() => pos_integer()}}

  @doc """
  A projeção sem direção das arestas dirigidas. Laço (`source == target`) não entra: a
  classificação já o excluiu, e um laço aqui seria bug de quem chama.
  """
  @spec undirected([edge()]) :: %{nodes: [id()], adjacency: adjacency(), edges: non_neg_integer()}
  def undirected(arestas) do
    adjacencia =
      Enum.reduce(arestas, %{}, fn %{source: u, target: v, weight: w}, acc when u != v ->
        acc
        |> Map.update(u, %{v => w}, &Map.update(&1, v, w, fn atual -> atual + w end))
        |> Map.update(v, %{u => w}, &Map.update(&1, u, w, fn atual -> atual + w end))
      end)

    pares = adjacencia |> Enum.map(fn {_u, vizinhos} -> map_size(vizinhos) end) |> Enum.sum()

    %{nodes: adjacencia |> Map.keys() |> Enum.sort(), adjacency: adjacencia, edges: div(pares, 2)}
  end

  @doc "Os componentes fracos, por tamanho decrescente e menor id; cada um com os ids ordenados."
  @spec components(adjacency()) :: [[id()]]
  def components(adjacencia) do
    adjacencia
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce({MapSet.new(), []}, fn inicio, {vistos, grupos} ->
      if MapSet.member?(vistos, inicio) do
        {vistos, grupos}
      else
        grupo = alcancaveis(adjacencia, [inicio], MapSet.new([inicio]))
        {MapSet.union(vistos, grupo), [Enum.sort(grupo) | grupos]}
      end
    end)
    |> elem(1)
    |> Enum.sort_by(fn [menor | _] = g -> {-length(g), menor} end)
  end

  defp alcancaveis(_adjacencia, [], vistos), do: vistos

  defp alcancaveis(adjacencia, [u | fila], vistos) do
    novos =
      adjacencia |> Map.get(u, %{}) |> Map.keys() |> Enum.reject(&MapSet.member?(vistos, &1))

    alcancaveis(adjacencia, fila ++ novos, Enum.into(novos, vistos))
  end

  @doc """
  Os graus de cada pessoa com aresta: pessoas distintas em cada sentido (`out_people`,
  `in_people`), no total sem direção (`degree`, o par recíproco uma vez) e o peso por sentido.
  """
  @spec degrees([edge()]) :: %{
          id() => %{
            out_people: non_neg_integer(),
            in_people: non_neg_integer(),
            degree: non_neg_integer(),
            out_weight: non_neg_integer(),
            in_weight: non_neg_integer()
          }
        }
  def degrees(arestas) do
    vazio = %{saida: MapSet.new(), entrada: MapSet.new(), out_weight: 0, in_weight: 0}

    arestas
    |> Enum.reject(&(&1.source == &1.target))
    |> Enum.reduce(%{}, fn %{source: u, target: v, weight: w}, acc ->
      acc
      |> Map.update(u, vazio, & &1)
      |> Map.update(v, vazio, & &1)
      |> update_in([u], &%{&1 | saida: MapSet.put(&1.saida, v), out_weight: &1.out_weight + w})
      |> update_in([v], &%{&1 | entrada: MapSet.put(&1.entrada, u), in_weight: &1.in_weight + w})
    end)
    |> Map.new(fn {id, g} ->
      {id,
       %{
         out_people: MapSet.size(g.saida),
         in_people: MapSet.size(g.entrada),
         degree: g.saida |> MapSet.union(g.entrada) |> MapSet.size(),
         out_weight: g.out_weight,
         in_weight: g.in_weight
       }}
    end)
  end
end
