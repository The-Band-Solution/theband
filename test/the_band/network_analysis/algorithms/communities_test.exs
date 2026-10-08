defmodule TheBand.NetworkAnalysis.Algorithms.CommunitiesTest do
  @moduledoc """
  As comunidades pelo guloso com peso — feature 076, T035 (FR-027; R6; `contracts/algoritmos.md`,
  `Algorithms.Communities`).

  - dois triângulos ligados por uma aresta dão duas comunidades, e Q = 5/14 (conta ao lado);
  - o empate perfeito (um anel, todos os pares com o mesmo ΔQ) dá a mesma partição em dez
    execuções, com as arestas na ordem invertida, e com ids que mudam a ordem do mapa mas não a
    ordem dos ids;
  - a numeração é por tamanho, e o grau interno conta pessoas.

  **Defeito a injetar**: desempatar pela ordem do mapa (o primeiro par de maior ΔQ que a
  iteração do mapa encontra); o caso do anel com ids de outra ordem de mapa reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Communities
  alias TheBand.NetworkAnalysis.Algorithms.Projection

  defp adj(arestas),
    do:
      arestas
      |> Enum.map(fn {u, v, w} -> %{source: u, target: v, weight: w} end)
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

  defp sem_peso(pares), do: Enum.map(pares, fn {u, v} -> {u, v, 1} end)

  defp dois_triangulos,
    do:
      sem_peso([
        {"a", "b"},
        {"b", "c"},
        {"a", "c"},
        {"d", "e"},
        {"e", "f"},
        {"d", "f"},
        {"c", "d"}
      ])

  # Dois triângulos {a, b, c} e {d, e, f}, ligados por c — d.

  test "dois triângulos ligados por uma aresta dão duas comunidades, e Q = 5/14" do
    %{partition: p, modularity: q} = Communities.greedy(adj(dois_triangulos()))

    assert p["a"] == p["b"] and p["b"] == p["c"]
    assert p["d"] == p["e"] and p["e"] == p["f"]
    refute p["a"] == p["d"]

    # W = 7; cada triângulo tem L = 3 e S = 2 + 2 + 3 = 7: Q = 2·(3/7 − (7/14)²) = 6/7 − 1/2.
    assert_in_delta q, 5 / 14, 1.0e-9
  end

  test "a numeração é por tamanho decrescente, empate pelo menor índice" do
    # Um quadrado completo {a, b, c, d} e um triângulo {e, f, g}, ligados por d — e.
    arestas =
      sem_peso(
        for(u <- ~w(a b c d), v <- ~w(a b c d), u < v, do: {u, v}) ++
          [{"e", "f"}, {"f", "g"}, {"e", "g"}, {"d", "e"}]
      )

    %{partition: p} = Communities.greedy(adj(arestas))

    assert Enum.map(~w(a b c d), &p[&1]) == [1, 1, 1, 1]
    assert Enum.map(~w(e f g), &p[&1]) == [2, 2, 2]
  end

  test "o peso conta: a aresta pesada junta o que a leve não juntaria" do
    # O caminho a — b — c — d: sem peso, o meio fica junto; com b — c leve e as pontas pesadas,
    # as pontas ficam com o vizinho mais pesado.
    %{partition: p} = Communities.greedy(adj([{"a", "b", 10}, {"b", "c", 1}, {"c", "d", 10}]))

    assert p["a"] == p["b"]
    assert p["c"] == p["d"]
    refute p["b"] == p["c"]
  end

  defp anel(prefixo, n) do
    ids = for i <- 1..n, do: "#{prefixo}#{String.pad_leading(Integer.to_string(i), 2, "0")}"
    arestas = for {u, v} <- Enum.zip(ids, tl(ids) ++ [hd(ids)]), do: {u, v, 1}
    {ids, arestas}
  end

  # A partição como a lista dos grupos de posições na ordem dos ids: compara anéis de ids
  # diferentes sem depender dos nomes.
  defp por_posicao(ids, particao),
    do:
      ids
      |> Enum.with_index()
      |> Enum.group_by(fn {id, _} -> particao[id] end, &elem(&1, 1))
      |> Map.values()
      |> Enum.sort()

  test "o empate perfeito dá a mesma partição em dez execuções e com a entrada invertida" do
    {ids, arestas} = anel("p", 40)
    primeira = Communities.greedy(adj(arestas))

    assert map_size(primeira.partition) == 40
    assert primeira.partition |> Map.values() |> Enum.uniq() |> length() > 1

    for _ <- 1..10, do: assert(Communities.greedy(adj(arestas)) == primeira)
    assert Communities.greedy(adj(Enum.reverse(arestas))) == primeira

    # Os mesmos 40 nós em anel, com ids da mesma ordem mas de outro prefixo: com mais de 32
    # chaves, a ordem do mapa segue o hash, e não a do id. A partição, pela posição na ordem do
    # id, tem de ser a mesma.
    {outros, arestas_outras} = anel("zz-pessoa-", 40)
    segunda = Communities.greedy(adj(arestas_outras))

    assert por_posicao(outros, segunda.partition) == por_posicao(ids, primeira.partition)
    assert segunda.modularity == primeira.modularity
  end

  test "o grau interno conta as pessoas vizinhas da mesma comunidade" do
    a = adj(dois_triangulos())
    %{partition: p} = Communities.greedy(a)
    graus = Communities.internal_degree(a, p)

    assert graus == %{"a" => 2, "b" => 2, "c" => 2, "d" => 2, "e" => 2, "f" => 2}
  end

  test "o resumo diz membros, ligações dentro e as que saem" do
    a = adj(dois_triangulos())
    %{partition: p} = Communities.greedy(a)

    assert [
             %{index: 1, members: ~w(a b c), internal_edges: 3, outside_edges: 1},
             %{index: 2, members: ~w(d e f), internal_edges: 3, outside_edges: 1}
           ] = Communities.summary(a, p)
  end

  test "a modularidade de uma partição dada bate com a conta à mão" do
    a = adj(dois_triangulos())
    tudo_junto = Map.new(~w(a b c d e f), &{&1, 1})

    # Uma comunidade só: L = W = 7, S = 14 → 1 − 1 = 0.
    assert_in_delta Communities.modularity(a, tudo_junto), 0.0, 1.0e-12
  end
end
