defmodule TheBand.NetworkAnalysis.Algorithms.NetworkDistancesTest do
  @moduledoc """
  Distância média, diâmetro e eficiência da rede, e as dos aleatórios — feature 076, T041 (US6;
  FR-037, FR-038, FR-041; A6 da revisão 2; `contracts/algoritmos.md`, `Paths.network/2` e
  `SmallWorld.random_battery/2`). Tolerância 1e-9.

  - caminho de 4: distância média 5/3, diâmetro 3, eficiência 13/18 (contas ao lado);
  - desconexa: a média é sobre os pares que se alcançam, com a fração deles; a eficiência conta o
    par sem caminho como 0 (a definição), sobre **todos** os pares;
  - sem par que se alcance: as três ausentes com `no_edge_in_window`;
  - nos aleatórios, as mesmas medidas, pela mesma regra, com `reachable_share` dos dois lados.

  **Defeito a injetar**: a média simples das médias por componente (a referência, `:139-149`); o
  caso desconexo reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Paths
  alias TheBand.NetworkAnalysis.Algorithms.Projection
  alias TheBand.NetworkAnalysis.Algorithms.SmallWorld

  defp adj(pares),
    do:
      pares
      |> Enum.map(fn {u, v} -> %{source: u, target: v, weight: 1} end)
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

  defp rede(pares) do
    a = adj(pares)
    a |> Paths.all_pairs() |> Paths.network(map_size(a))
  end

  test "caminho de 4: 5/3, 3 e 13/18" do
    r = rede([{"a", "b"}, {"b", "c"}, {"c", "d"}])

    # Pares: três a 1 passo, dois a 2, um a 3 → (3 + 4 + 3)/6 = 5/3; eficiência
    # (3 + 2·½ + ⅓)/6 = 13/18.
    {:ok, media} = r.average
    assert_in_delta media, 5 / 3, 1.0e-9
    assert r.diameter == {:ok, 3}
    {:ok, ef} = r.efficiency
    assert_in_delta ef, 13 / 18, 1.0e-9
    assert r.reachable_share == 1.0
    assert r.lengths == [{1, 3}, {2, 2}, {3, 1}]
  end

  test "desconexa: média sobre os pares que se alcançam, com a fração; eficiência sobre todos" do
    # Um caminho a — b — c (pares 1, 1, 2) e um par d — e (1): 4 dos 10 pares se alcançam.
    r = rede([{"a", "b"}, {"b", "c"}, {"d", "e"}])

    # A média dos pares que se alcançam: (1 + 1 + 2 + 1)/4 = 5/4. A média das médias por
    # componente daria (4/3 + 1)/2 = 7/6.
    {:ok, media} = r.average
    assert_in_delta media, 5 / 4, 1.0e-9
    assert_in_delta r.reachable_share, 4 / 10, 1.0e-9
    assert r.diameter == {:ok, 2}
    {:ok, ef} = r.efficiency
    assert_in_delta ef, (1 + 1 + 0.5 + 1) / 10, 1.0e-9
  end

  test "sem par que se alcance, as três ausentes com o motivo, nunca 0" do
    r = Paths.network(%{}, 0)

    assert r.average == {:ausente, :no_edge_in_window}
    assert r.diameter == {:ausente, :no_edge_in_window}
    assert r.efficiency == {:ausente, :no_edge_in_window}
    assert r.reachable_share == nil
  end

  test "os aleatórios medem pela mesma regra, com a fração de pares que se alcançam" do
    b =
      SmallWorld.random_battery(adj([{"a", "b"}, {"b", "c"}, {"d", "e"}, {"e", "f"}]), %{
        random_graphs: 100,
        seed: 42
      })

    assert {:ok, %{value: l, graphs_defined: 100}} = b.average_distance
    assert {:ok, %{graphs_defined: 100}} = b.diameter
    assert {:ok, %{value: ef, graphs_defined: 100}} = b.global_efficiency
    assert l >= 1 and ef > 0 and ef < 1
    # 6 pessoas e 4 ligações: nenhum aleatório liga todos, e a fração diz isso.
    assert b.reachable_share < 1
  end
end
