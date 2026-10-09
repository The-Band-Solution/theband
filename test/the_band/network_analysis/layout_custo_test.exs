defmodule TheBand.NetworkAnalysis.LayoutCustoTest do
  @moduledoc """
  O custo do layout recalculado na leitura, com alcance parcial — feature 076, T034 (R9; R7 da
  segurança: *"o plano mede e escreve o número"*).

  Mede `Algorithms.Layout.fruchterman_reingold/3` com os parâmetros da base sobre grafos de 50 e
  de 300 nós (300 é o teto de pessoas, R5: nenhuma visão passa dele), 3 arestas por nó, sorteadas
  com semente fixa. O número medido está em `research.md` R9, com a máquina e a data.

  O teto do teste é **folgado** e vem da medida dos dois lados (L53): a mediana de 5 corridas
  medida aqui, vezes a folga, para não reprovar numa máquina de CI mais lenta, e ainda assim
  reprovar se o custo multiplicar.

  **Defeito a injetar**: 500 iterações em vez das da base; o teto reprova.
  """
  use ExUnit.Case, async: false

  alias TheBand.NetworkAnalysis.Algorithms.Layout
  alias TheBand.NetworkAnalysis.Algorithms.Projection
  alias TheBand.NetworkAnalysis.Algorithms.Random
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase

  # Medido em 2026-10-04 (research.md R9): mediana de 50 nós 13 ms; de 300 nós 463 ms.
  # Teto ≈ 6× a medida: a folga de uma máquina de CI mais lenta e da suíte rodando em paralelo,
  # e ainda abaixo do que 500 iterações custam (linear nas iterações: 10×; com o defeito
  # injetado, aqui, 168 ms e 6 044 ms).
  @teto_ms %{50 => 80, 300 => 3_000}

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    %{layout: Map.take(Parameters.fetch!().layout, [:seed, :iterations])}
  end

  defp grafo(n) do
    {pares, _} = Random.gnm(Random.new(76), n, 3 * n)
    ids = for i <- 1..n, do: "p-#{String.pad_leading(Integer.to_string(i), 4, "0")}"
    t = List.to_tuple(ids)

    pares
    |> Enum.map(fn {u, v} -> %{source: elem(t, u - 1), target: elem(t, v - 1), weight: 1} end)
    |> Projection.undirected()
  end

  defp mediana_ms(n, params) do
    %{nodes: nos, adjacency: adj} = grafo(n)

    tempos =
      for _ <- 1..5 do
        {us, pos} = :timer.tc(fn -> Layout.fruchterman_reingold(nos, adj, params) end)
        assert map_size(pos) == n
        div(us, 1000)
      end

    tempos |> Enum.sort() |> Enum.at(2)
  end

  for n <- [50, 300] do
    test "o layout de #{n} nós da visão fica abaixo do teto medido", %{layout: params} do
      ms = mediana_ms(unquote(n), params)
      assert ms <= @teto_ms[unquote(n)], "#{ms} ms passa do teto de #{@teto_ms[unquote(n)]} ms"
    end
  end
end
