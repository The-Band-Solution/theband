defmodule TheBand.NetworkAnalysis.Algorithms.PathsTest do
  @moduledoc """
  As distâncias de cada pessoa e a proximidade — feature 076, T038 (FR-035; R6;
  `contracts/algoritmos.md`, `Algorithms.Paths`; medidas `network.closeness.ratio` e
  `network.person_distance.mean`). Tolerância 1e-9 (R6).

  - estrela de 6: o centro tem proximidade 1,0 e distância média 1; cada folha, proximidade
    5/9 = (5/5)·(5/9) e distância média 9/5;
  - rede desconexa: a proximidade usa r(u) e o n da rede **inteira** (Wasserman–Faust), e a
    distância média é sobre quem a pessoa alcança — nunca 1/proximidade.

  **Defeito a injetar**: devolver 1/proximidade como distância média (a referência, `:318`); o
  caso desconexo reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Paths
  alias TheBand.NetworkAnalysis.Algorithms.Projection

  defp adj(pares),
    do:
      pares
      |> Enum.map(fn {u, v} -> %{source: u, target: v, weight: 1} end)
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

  test "estrela de 6: o centro tem proximidade 1 e distância média 1" do
    d = Paths.all_pairs(adj(for f <- ~w(b c d e f), do: {"a", f}))
    prox = Paths.closeness(d, 6)
    dist = Paths.person_distance(d)

    {:ok, centro} = prox["a"]
    assert_in_delta centro, 1.0, 1.0e-9
    assert {:ok, %{mean: m, reaches: 5}} = dist["a"]
    assert_in_delta m, 1.0, 1.0e-9

    # A folha: D = 1 + 4·2 = 9, r − 1 = 5 → (5/5)·(5/9); distância média 9/5.
    {:ok, folha} = prox["b"]
    assert_in_delta folha, 5 / 9, 1.0e-9
    assert {:ok, %{mean: mf, reaches: 5}} = dist["b"]
    assert_in_delta mf, 9 / 5, 1.0e-9
  end

  test "desconexa: proximidade com r(u) e o n da rede inteira; distância sobre quem alcança" do
    # Um caminho a — b — c e um par d — e: n = 5.
    d = Paths.all_pairs(adj([{"a", "b"}, {"b", "c"}, {"d", "e"}]))
    prox = Paths.closeness(d, 5)
    dist = Paths.person_distance(d)

    # a alcança b (1) e c (2): r − 1 = 2, D = 3 → (2/4)·(2/3) = 1/3; distância média 3/2.
    {:ok, pa} = prox["a"]
    assert_in_delta pa, 1 / 3, 1.0e-9
    assert {:ok, %{mean: ma, reaches: 2}} = dist["a"]
    assert_in_delta ma, 1.5, 1.0e-9

    # d alcança só e: r − 1 = 1, D = 1 → (1/4)·(1/1) = 1/4; distância média 1, e não 4.
    {:ok, pd} = prox["d"]
    assert_in_delta pd, 0.25, 1.0e-9
    assert {:ok, %{mean: md, reaches: 1}} = dist["d"]
    assert_in_delta md, 1.0, 1.0e-9
  end

  test "as distâncias são em passos, sem peso" do
    pesado =
      [%{source: "a", target: "b", weight: 50}, %{source: "b", target: "c", weight: 1}]
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

    assert Paths.all_pairs(pesado)["a"] == %{"b" => 1, "c" => 2}
  end
end
