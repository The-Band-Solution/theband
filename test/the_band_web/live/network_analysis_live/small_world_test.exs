defmodule TheBandWeb.NetworkAnalysisLive.SmallWorldTest do
  @moduledoc """
  A segunda metade da página Distance and small world — feature 076, T044 (US7, cen. 1 a 4;
  FR-040 a FR-043; protótipo 3.5.3, 3.5.4, com R21: 100 aleatórios, e não 50).

  - rede de 10 pessoas em dois grupos densos: a tabela real × aleatórios com as razões, σ com uma
    casa, *"meets the σ > 1 criterion"* e a frase do que o critério não prova; quantos aleatórios
    e a semente;
  - rede de 5 pessoas (abaixo do mínimo da base): σ ausente com o motivo, e **nenhuma** frase diz
    que não é mundo pequeno.

  **Defeito a injetar**: escrever *"is a small world"*; o teste reprova.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant}
  end

  defp rede(ctx, pares_de) do
    %{organization: org} = organizacao_com_repositorio(ctx.tenant)
    n = System.unique_integer([:positive])
    pessoas = for i <- 1..10, do: pessoa(ctx.tenant, "P#{i} Mundo#{n}")

    entrada = %{
      edges:
        for(
          {i, j} <- pares_de,
          do: %{source: Enum.at(pessoas, i).id, target: Enum.at(pessoas, j).id, weight: 1}
        ),
      exclusions: %{"issues" => 9},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(ctx.tenant, org, DateTime.utc_now(:second), Parameters.fetch!(), fn _,
                                                                                           _,
                                                                                           _ ->
        {:ok, entrada}
      end)

    {:ok, _view, html} =
      live(ctx.conn, "/network-analysis/#{org.id}/distance?network=assignment&window=90")

    html
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)
  defp texto(html, sel), do: html |> q(sel) |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

  # Dois K5 (0–4 e 5–9) ligados por 4 — 5.
  defp dois_k5,
    do: for(g <- [0, 5], i <- g..(g + 4), j <- g..(g + 4), i < j, do: {i, j}) ++ [{4, 5}]

  test "σ > 1: a tabela, σ com uma casa, o critério e o que ele não prova", ctx do
    html = rede(ctx, dois_k5())

    tabela = texto(html, "#tabela-mundo-pequeno")
    assert tabela =~ "Clustering"
    assert tabela =~ "(average of"
    assert tabela =~ "×"

    sigma = texto(html, "#sigma")
    assert sigma =~ ~r/σ = \d+\.\d\./
    assert sigma =~ "meets the σ > 1 criterion"
    assert texto(html, "#o-que-o-criterio-nao-prova") =~ "Telesford et al., 2011"
    assert texto(html, "#aleatorios") =~ "100 random networks"
    assert texto(html, "#aleatorios") =~ "Seed 42"
    refute html =~ ~r/is a small world/i
  end

  test "abaixo do mínimo, σ ausente com o motivo, e nada diz que não é mundo pequeno", ctx do
    html = rede(ctx, [{0, 1}, {1, 2}, {2, 0}, {2, 3}, {3, 4}])

    assert texto(html, "#sigma") =~ "fewer people than the minimum declared for σ"
    refute html =~ ~r/not a small world/i
    refute html =~ ~r/is a small world/i
    refute html =~ "does not meet"
  end
end
