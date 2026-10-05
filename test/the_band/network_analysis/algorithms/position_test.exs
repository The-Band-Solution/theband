defmodule TheBand.NetworkAnalysis.Algorithms.PositionTest do
  @moduledoc """
  Percentil e papel, derivados na leitura — feature 076, T045 (US8, cen. 1 e 2; FR-044 a FR-046;
  `contracts/algoritmos.md`, `Algorithms.Position`; regra `network.position_role` da base real).

  - percentil 90 de grau e 85 de intermediação dá `central_position`, com o rótulo e a frase da
    base, os dois percentis e o corte;
  - 40% empatados em zero dão percentil 20 (posto médio);
  - abaixo de 10 pessoas, todos ausentes com `network_too_small_for_roles`;
  - ordem de cortes diferente da implementada levanta.

  O caso de que a leitura gravada **não** tem papel nem percentil está em
  `commands_comunidades_test.exs` (o defeito a injetar é gravar o papel em `Commands`).
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Position
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    %{regra: Parameters.fetch!().position}
  end

  test "percentil 90 e 85 dá central_position, com a frase da base e o corte", %{regra: r} do
    papel = Position.role(%{degree: 90.0, betweenness: 85.0}, r)

    assert papel.code == "central_position"
    assert papel.label == "Central position"
    assert papel.sentence =~ "in this network and window"
    assert papel.degree_percentile == 90.0
    assert papel.betweenness_percentile == 85.0
    assert papel.cut =~ "degree > 80 and betweenness > 80"
  end

  test "os cortes na ordem da base", %{regra: r} do
    assert Position.role(%{degree: 85.0, betweenness: 10.0}, r).code == "many_direct_links"
    assert Position.role(%{degree: 10.0, betweenness: 85.0}, r).code == "on_many_paths"
    assert Position.role(%{degree: 60.0, betweenness: 60.0}, r).code == "above_median_in_both"
    assert Position.role(%{degree: 10.0, betweenness: 10.0}, r).code == "few_links_few_paths"
    assert Position.role(%{degree: 60.0, betweenness: 30.0}, r).code == "mixed_position"
  end

  test "40% empatados em zero dão percentil 20" do
    valores = Map.new(1..10, fn i -> {i, if(i <= 4, do: 0, else: i)} end)
    p = Position.percentiles(valores)

    for i <- 1..4, do: assert(p[i] == 20.0)
    # O maior: 9 menores e ele mesmo pela metade → 95.
    assert p[10] == 95.0
  end

  test "abaixo do mínimo, ninguém tem papel", %{regra: r} do
    pessoas = Map.new(1..9, &{&1, %{degree: &1, betweenness: {:ok, &1 / 10}}})

    assert Position.roles(pessoas, r) |> Map.values() |> Enum.uniq() ==
             [{:ausente, :network_too_small_for_roles}]
  end

  test "com o mínimo, todos têm papel pelos percentis da rede inteira", %{regra: r} do
    pessoas = Map.new(1..20, &{&1, %{degree: &1, betweenness: {:ok, &1 / 100}}})
    papeis = Position.roles(pessoas, r)

    assert {:ok, %{code: "central_position"}} = papeis[20]
    assert {:ok, %{code: "few_links_few_paths"}} = papeis[1]
  end

  test "ordem de cortes diferente da implementada levanta", %{regra: r} do
    assert_raise RuntimeError, ~r/cuts.order/, fn ->
      Position.role(%{degree: 1.0, betweenness: 1.0}, %{r | order: Enum.reverse(r.order)})
    end
  end
end
