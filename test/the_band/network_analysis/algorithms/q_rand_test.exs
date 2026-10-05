defmodule TheBand.NetworkAnalysis.Algorithms.QRandTest do
  @moduledoc """
  A modularidade dos aleatórios, com peso — feature 076, T036 (A5 da revisão 2; R7, R8;
  `contracts/algoritmos.md`, `SmallWorld.random_battery/2`).

  - com todos os pesos 1, o Q_rand é o mesmo de qualquer outro peso uniforme: o peso não muda nada
    quando não há o que concentrar;
  - com pesos concentrados, o Q_rand com peso é **maior** que o do mesmo sorteio sem peso;
  - mesma semente, mesmo Q_rand; outra semente, outro;
  - todo aleatório entra: `graphs_defined` é o número de grafos.

  **Defeito a injetar**: não passar os pesos aos aleatórios (todo par com peso 1); o caso dos
  pesos concentrados reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Projection
  alias TheBand.NetworkAnalysis.Algorithms.SmallWorld

  @params %{random_graphs: 100, seed: 42}

  # Uma rede de 12 pessoas e 20 ligações, com os pesos dados por `peso.(i)`.
  defp rede(peso) do
    ids = for i <- 1..12, do: "p#{String.pad_leading(Integer.to_string(i), 2, "0")}"
    pares = for u <- ids, v <- ids, u < v, do: {u, v}

    pares
    |> Enum.take_every(3)
    |> Enum.take(20)
    |> Enum.with_index()
    |> Enum.map(fn {{u, v}, i} -> %{source: u, target: v, weight: peso.(i)} end)
    |> Projection.undirected()
    |> Map.fetch!(:adjacency)
  end

  test "todo aleatório entra, e a média diz quantos" do
    %{graphs: 100, modularity: {:ok, %{value: q, graphs_defined: 100}}} =
      SmallWorld.random_battery(rede(fn _ -> 1 end), @params)

    assert q > 0
  end

  test "com todos os pesos 1, o Q_rand é o de qualquer peso uniforme" do
    {:ok, um} = SmallWorld.random_battery(rede(fn _ -> 1 end), @params).modularity
    {:ok, cinco} = SmallWorld.random_battery(rede(fn _ -> 5 end), @params).modularity

    assert_in_delta um.value, cinco.value, 1.0e-12
  end

  test "com pesos concentrados, o Q_rand com peso é maior que o sem peso, no mesmo sorteio" do
    # Duas ligações com quase todo o peso: cada aleatório as recebe em lugares sorteados, e o
    # guloso as isola em comunidades próprias.
    concentrado = rede(fn i -> if i < 2, do: 200, else: 1 end)
    {:ok, com_peso} = SmallWorld.random_battery(concentrado, @params).modularity
    {:ok, sem_peso} = SmallWorld.random_battery(rede(fn _ -> 1 end), @params).modularity

    assert com_peso.value > sem_peso.value + 0.05
  end

  test "mesma semente, mesmo Q_rand; outra semente, outro" do
    a = rede(fn i -> rem(i, 4) + 1 end)

    assert SmallWorld.random_battery(a, @params) == SmallWorld.random_battery(a, @params)

    refute SmallWorld.random_battery(a, @params) ==
             SmallWorld.random_battery(a, %{@params | seed: 7})
  end
end
