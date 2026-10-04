defmodule TheBand.NetworkAnalysis.Algorithms.BetweennessTest do
  @moduledoc """
  A intermediação por Brandes — feature 076, T030 (R6; SC-002, tolerância 1e-9).

  Valores à mão, com a conta ao lado:

  - **estrela de 6** (centro + 5 folhas): os 10 pares de folhas passam todos pelo centro;
    10 / ((6 − 1)(6 − 2)/2) = 10/10 = 1,0. Folhas: 0;
  - **caminho de 4** a–b–c–d: b está em a–c e a–d (2 pares); 2 / ((4 − 1)(4 − 2)/2) = 2/3;
  - **dois caminhos de mesmo tamanho** (quadrado a–b–c–d–a): cada um de b e d leva metade do par
    a–c; 0,5 / 3 = 1/6;
  - n < 3: ausente com `network_too_small`, e nunca 0.

  **Defeito a injetar**: não dividir por 2 (pares ordenados); a estrela dá 2,0 e reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Betweenness
  alias TheBand.NetworkAnalysis.Algorithms.Projection

  @tol 1.0e-9
  @params %{min_people: 3}

  defp rede(pares) do
    pares
    |> Enum.map(fn {u, v} -> %{source: u, target: v, weight: 1} end)
    |> Projection.undirected()
    |> Map.fetch!(:adjacency)
  end

  defp valor(resultado, id) do
    assert {:ok, v} = Map.fetch!(resultado, id)
    v
  end

  test "estrela de 6: o centro em todos os caminhos, as folhas em nenhum" do
    folhas = ~w(f1 f2 f3 f4 f5)
    r = Betweenness.brandes(rede(for f <- folhas, do: {"c", f}), @params)

    assert_in_delta valor(r, "c"), 1.0, @tol
    for f <- folhas, do: assert_in_delta(valor(r, f), 0.0, @tol)
  end

  test "caminho de 4: 2/3 nos dois do meio" do
    r = Betweenness.brandes(rede([{"a", "b"}, {"b", "c"}, {"c", "d"}]), @params)

    assert_in_delta valor(r, "b"), 2 / 3, @tol
    assert_in_delta valor(r, "c"), 2 / 3, @tol
    assert_in_delta valor(r, "a"), 0.0, @tol
    assert_in_delta valor(r, "d"), 0.0, @tol
  end

  test "dois caminhos mais curtos dividem o par" do
    r = Betweenness.brandes(rede([{"a", "b"}, {"b", "c"}, {"c", "d"}, {"d", "a"}]), @params)
    for id <- ~w(a b c d), do: assert_in_delta(valor(r, id), 1 / 6, @tol)
  end

  test "a direção e o peso não mudam a intermediação" do
    pesado =
      [%{source: "b", target: "a", weight: 9}, %{source: "c", target: "b", weight: 1}]
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

    assert_in_delta valor(Betweenness.brandes(pesado, @params), "b"), 1.0, @tol
  end

  test "n < 3: ausente para todos, com o motivo, e nunca 0" do
    assert Betweenness.brandes(rede([{"a", "b"}]), @params) == %{
             "a" => {:ausente, :network_too_small},
             "b" => {:ausente, :network_too_small}
           }
  end

  test "o mínimo vem de quem chama (a base), e não do código" do
    r = Betweenness.brandes(rede([{"a", "b"}, {"b", "c"}, {"c", "d"}]), %{min_people: 5})
    assert Enum.all?(r, fn {_, v} -> v == {:ausente, :network_too_small} end)
  end

  test "a mesma rede dá o mesmo número, independente da ordem das arestas" do
    pares = [{"a", "b"}, {"b", "c"}, {"c", "d"}, {"b", "d"}, {"d", "e"}]

    assert Betweenness.brandes(rede(pares), @params) ==
             Betweenness.brandes(rede(Enum.reverse(pares)), @params)
  end
end
