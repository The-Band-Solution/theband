defmodule TheBand.NetworkAnalysis.Algorithms.Communities do
  @moduledoc """
  As comunidades pelo guloso de Clauset, Newman e Moore (2004), com peso — feature 076, T035
  (FR-027 a FR-029; research.md R6; `contracts/algoritmos.md`, `Algorithms.Communities`;
  `network.analysis.parameters.communities`).

  ## O método, como a base o declara

  - começa com uma comunidade por pessoa; o índice inicial é a **posição na ordem do id**;
  - a cada passo junta o par **adjacente** de maior ΔQ = 2(e_ij − a_i·a_j), com peso e resolução 1;
  - **desempate pelo par de menor índice** `(i, j)`, lexicográfico. A comunidade juntada fica com
    o menor índice, que é sempre o do seu membro de menor id;
  - para quando o maior ΔQ é ≤ 0;
  - numera por **tamanho decrescente**, empate pelo menor índice.

  ## Por que inteiros

  Os pesos são contagens. Com W o peso total e S_i a força da comunidade i, ΔQ·2W² = 2W·w_ij −
  S_i·S_j, e a comparação é feita nesse inteiro: dois pares de mesmo ΔQ empatam **de verdade**, e
  o desempate declarado decide — nunca o arredondamento de um ponto flutuante nem a ordem de um
  mapa. A modularidade é a soma dos numeradores inteiros, dividida uma vez (FR-052).

  A fila dos pares é um `:gb_sets` de `{−escore, i, j}`: o menor elemento é o de maior ΔQ e, no
  empate, o de menor `(i, j)`. Cada junção só refaz os pares das duas comunidades juntadas.

  Puro: sem `Repo`, relógio, `Logger` nem `:digraph`. Depende de: nenhuma ontologia.
  """

  @type id :: term()
  @type adjacency :: %{id() => %{id() => pos_integer()}}

  @doc """
  A partição gulosa e a modularidade dela. `partition` vai de cada pessoa ao número da
  comunidade, 1 a maior. A adjacência precisa ter ao menos uma aresta: sem aresta não há
  comunidade, e quem chama diz a ausência.
  """
  @spec greedy(adjacency()) :: %{partition: %{id() => pos_integer()}, modularity: float()}
  def greedy(adjacencia) when map_size(adjacencia) > 0 do
    ids = adjacencia |> Map.keys() |> Enum.sort()
    indice = ids |> Enum.with_index(1) |> Map.new()
    por_indice = List.to_tuple(ids)
    w2 = peso_duplo(adjacencia)

    entre =
      Map.new(adjacencia, fn {u, vizinhos} ->
        {indice[u], Map.new(vizinhos, fn {v, w} -> {indice[v], w} end)}
      end)

    forca = Map.new(entre, fn {i, vizinhos} -> {i, vizinhos |> Map.values() |> Enum.sum()} end)
    membros = Map.new(entre, fn {i, _} -> {i, [i]} end)

    fila =
      for {i, vizinhos} <- entre, {j, w} <- vizinhos, i < j, reduce: :gb_sets.empty() do
        acc -> :gb_sets.add({-escore(w2, w, forca[i], forca[j]), i, j}, acc)
      end

    grupos = juntar(%{entre: entre, forca: forca, membros: membros, fila: fila, w2: w2})

    particao =
      grupos
      |> Enum.sort_by(fn {i, m} -> {-length(m), i} end)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {{_i, m}, n} -> Enum.map(m, &{elem(por_indice, &1 - 1), n}) end)
      |> Map.new()

    %{partition: particao, modularity: modularity(adjacencia, particao)}
  end

  # 2W: a soma das forças, que conta cada aresta nas duas pontas.
  defp peso_duplo(adjacencia),
    do: adjacencia |> Enum.flat_map(fn {_u, v} -> Map.values(v) end) |> Enum.sum()

  # ΔQ · 2W², em inteiro: 2W·w_ij − S_i·S_j (com 2W = w2).
  defp escore(w2, w, s_i, s_j), do: w2 * w - s_i * s_j

  defp juntar(%{fila: fila} = estado) do
    if :gb_sets.is_empty(fila) do
      estado.membros
    else
      {{menos_escore, i, j}, _} = :gb_sets.take_smallest(fila)
      if -menos_escore > 0, do: estado |> juntar_par(i, j) |> juntar(), else: estado.membros
    end
  end

  # Junta j em i (i < j): i fica com o menor índice. Só os pares de i e de j mudam de escore.
  defp juntar_par(%{entre: entre, forca: forca, w2: w2} = estado, i, j) do
    vi = Map.fetch!(entre, i)
    vj = Map.fetch!(entre, j)

    fila =
      Enum.reduce(vi, estado.fila, fn {x, w}, f -> tirar(f, w2, w, forca, i, x) end)

    fila = Enum.reduce(vj, fila, fn {x, w}, f -> tirar(f, w2, w, forca, j, x) end)

    novos =
      vi
      |> Map.merge(vj, fn _x, a, b -> a + b end)
      |> Map.drop([i, j])

    forca = forca |> Map.put(i, forca[i] + forca[j]) |> Map.delete(j)

    entre =
      Enum.reduce(novos, Map.drop(entre, [j]), fn {x, w}, acc ->
        Map.update!(acc, x, &(&1 |> Map.delete(j) |> Map.put(i, w)))
      end)
      |> Map.put(i, novos)

    fila =
      Enum.reduce(novos, fila, fn {x, w}, f ->
        :gb_sets.add({-escore(w2, w, forca[i], forca[x]), min(i, x), max(i, x)}, f)
      end)

    membros =
      estado.membros
      |> Map.put(i, estado.membros[i] ++ estado.membros[j])
      |> Map.delete(j)

    %{estado | entre: entre, forca: forca, fila: fila, membros: membros}
  end

  defp tirar(fila, w2, w, forca, a, b),
    do: :gb_sets.delete_any({-escore(w2, w, forca[a], forca[b]), min(a, b), max(a, b)}, fila)

  @doc """
  A modularidade de Newman (2004), com peso, de uma partição: Q = Σ_c (L_c/W − (S_c/2W)²), com
  L_c o peso dentro de c e S_c a força de c. Calculada como Σ_c (4W·L_c − S_c²) / (4W²), em
  inteiros até a divisão.
  """
  @spec modularity(adjacency(), %{id() => term()}) :: float()
  def modularity(adjacencia, particao) when map_size(adjacencia) > 0 do
    w2 = peso_duplo(adjacencia)

    {dentro2, forca} =
      for {u, vizinhos} <- adjacencia, {v, w} <- vizinhos, reduce: {%{}, %{}} do
        {d, s} ->
          c = Map.fetch!(particao, u)
          s = Map.update(s, c, w, &(&1 + w))
          if Map.fetch!(particao, v) == c, do: {Map.update(d, c, w, &(&1 + w)), s}, else: {d, s}
      end

    # dentro2 conta cada aresta interna duas vezes (2·L_c); w2 é 2W: 4W·L_c = w2·dentro2.
    numerador =
      forca
      |> Enum.map(fn {c, s} -> w2 * Map.get(dentro2, c, 0) - s * s end)
      |> Enum.sum()

    numerador / (w2 * w2)
  end

  @doc "Quantas pessoas da própria comunidade cada pessoa tem como vizinha (sem peso)."
  @spec internal_degree(adjacency(), %{id() => term()}) :: %{id() => non_neg_integer()}
  def internal_degree(adjacencia, particao) do
    Map.new(adjacencia, fn {u, vizinhos} ->
      c = Map.fetch!(particao, u)
      {u, Enum.count(vizinhos, fn {v, _w} -> Map.fetch!(particao, v) == c end)}
    end)
  end

  @doc """
  As comunidades da partição, na ordem dos números: membros ordenados, as ligações (pares sem
  direção) dentro e as que saem para outra comunidade.
  """
  @spec summary(adjacency(), %{id() => pos_integer()}) :: [
          %{
            index: pos_integer(),
            members: [id()],
            internal_edges: non_neg_integer(),
            outside_edges: non_neg_integer()
          }
        ]
  def summary(adjacencia, particao) do
    pares =
      for {u, vizinhos} <- adjacencia, {v, _w} <- vizinhos, u < v, do: {particao[u], particao[v]}

    particao
    |> Enum.group_by(fn {_id, c} -> c end, fn {id, _c} -> id end)
    |> Enum.sort()
    |> Enum.map(fn {c, membros} ->
      %{
        index: c,
        members: Enum.sort(membros),
        internal_edges: Enum.count(pares, &(&1 == {c, c})),
        outside_edges: Enum.count(pares, fn {a, b} -> a != b and (a == c or b == c) end)
      }
    end)
  end
end
