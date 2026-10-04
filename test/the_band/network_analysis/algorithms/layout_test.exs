defmodule TheBand.NetworkAnalysis.Algorithms.LayoutTest do
  @moduledoc """
  As posições no servidor, com semente — feature 076, T031 (FR-022, FR-052; R9).

  - o mesmo grafo dá as mesmas posições em duas chamadas, mesmo com o `:rand` do processo mexido
    entre elas, e com os ids em outra ordem;
  - todas em [40, 960]², com uma casa;
  - 0, 1 e nós no mesmo ponto não quebram; nó isolado também recebe posição;
  - a semente muda o desenho (o sorteio é dela, e não do relógio).

  Acima do teto, o layout ausente é do cálculo: `commands_test.exs`, A16.

  **Defeito a injetar**: semear por `:rand.seed/1` com o tempo; a igualdade reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Layout
  alias TheBand.NetworkAnalysis.Algorithms.Projection

  @params %{seed: 42, iterations: 50}

  defp rede do
    [{"a", "b", 3}, {"b", "c", 1}, {"c", "a", 2}, {"c", "d", 1}, {"d", "e", 5}, {"e", "f", 1}]
    |> Enum.map(fn {u, v, w} -> %{source: u, target: v, weight: w} end)
    |> Projection.undirected()
  end

  test "o mesmo grafo dá as mesmas posições, com o :rand do processo mexido entre as chamadas" do
    %{nodes: nos, adjacency: adj} = rede()
    primeira = Layout.fruchterman_reingold(nos, adj, @params)

    :rand.seed(:exsss, System.os_time())
    _ = :rand.uniform()

    assert Layout.fruchterman_reingold(Enum.reverse(nos), adj, @params) == primeira
    assert map_size(primeira) == 6
  end

  test "todas as posições em [40, 960]², com uma casa, e espalhadas" do
    %{nodes: nos, adjacency: adj} = rede()
    pos = Layout.fruchterman_reingold(nos ++ ["isolado"], adj, @params)

    assert map_size(pos) == 7

    for {_id, {x, y}} <- pos, v <- [x, y] do
      assert is_float(v)
      assert v >= 40.0 and v <= 960.0
      assert Float.round(v, 1) == v
    end

    # A reescala usa a caixa inteira em pelo menos um eixo.
    extremos = pos |> Map.values() |> Enum.flat_map(fn {x, y} -> [x, y] end)
    assert Enum.min(extremos) == 40.0 or Enum.max(extremos) == 960.0
    assert pos |> Map.values() |> Enum.uniq() |> length() == 7
  end

  test "0 e 1 nó" do
    assert Layout.fruchterman_reingold([], %{}, @params) == %{}
    assert Layout.fruchterman_reingold(["a"], %{}, @params) == %{"a" => {500.0, 500.0}}
  end

  test "a semente decide o sorteio" do
    %{nodes: nos, adjacency: adj} = rede()

    refute Layout.fruchterman_reingold(nos, adj, @params) ==
             Layout.fruchterman_reingold(nos, adj, %{@params | seed: 7})
  end

  test "a ligação pesada aproxima mais que a leve" do
    adj = %{"a" => %{"b" => 20}, "b" => %{"a" => 20, "c" => 1}, "c" => %{"b" => 1}}
    pos = Layout.fruchterman_reingold(~w(a b c), adj, @params)

    dist = fn u, v ->
      :math.sqrt(
        :math.pow(elem(pos[u], 0) - elem(pos[v], 0), 2) +
          :math.pow(elem(pos[u], 1) - elem(pos[v], 1), 2)
      )
    end

    assert dist.("a", "b") < dist.("b", "c")
  end
end
