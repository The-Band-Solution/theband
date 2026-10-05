defmodule TheBandWeb.NetworkAnalysisLive.DistanceTest do
  @moduledoc """
  A primeira metade da página Distance and small world — feature 076, T042 (US6, cen. 1 a 3;
  FR-037, FR-038; protótipo 3.5.1, 3.5.2, 3.5.5).

  - rede com dois componentes: a página diz que há pares sem caminho, com a fração, e o diâmetro
    como *"the longest distance between people who reach each other"*;
  - cada medida com o valor médio dos aleatórios ao lado;
  - a nota de que só a eficiência conta o par sem caminho como zero; a distribuição dos
    comprimentos;
  - nenhum *"efficient"* nem *"slow"* na página.

  **Defeito a injetar**: escrever *"efficient"* acima de 0,7 (a referência, `:354`); o teste
  reprova.
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
    %{organization: org} = organizacao_com_repositorio(tenant)
    [a, b, c, d, e] = for n <- ~w(A B C D E), do: pessoa(tenant, "#{n} Distancia")

    # Dois componentes: o caminho a — b — c e o par d — e. A eficiência é 3,5/10 = 35%; um
    # triângulo a mais a tornaria alta, e a página não diria "efficient".
    arestas =
      for {u, v} <- [{a, b}, {b, c}, {d, e}], do: %{source: u.id, target: v.id, weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => 3},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(tenant, org, DateTime.utc_now(:second), Parameters.fetch!(), fn _, _, _ ->
        {:ok, entrada}
      end)

    %{conn: log_in(conn, admin), org: org, tenant: tenant}
  end

  defp abrir(ctx) do
    {:ok, _view, html} =
      live(ctx.conn, "/network-analysis/#{ctx.org.id}/distance?network=assignment&window=90")

    html
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)
  defp texto(html, sel), do: html |> q(sel) |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

  test "dois componentes: há pares sem caminho, com a fração, e o diâmetro entre quem se alcança",
       ctx do
    html = abrir(ctx)

    assert texto(html, "#conectividade") =~ "2 groups not linked to each other, of 3, 2 people"
    assert texto(html, "#pares-sem-caminho") =~ "40% of the pairs reach each other"
    assert texto(html, "#distancia-media") =~ ~r/1\.[23] steps/
    assert texto(html, "#diametro") =~ "the longest distance between people who reach each other"
    assert texto(html, "#eficiencia") =~ "35%"
    assert texto(html, "#eficiencia") =~ "count as zero here, and only here"
  end

  test "cada medida com o valor médio dos aleatórios ao lado, e a distribuição", ctx do
    html = abrir(ctx)

    for id <- ~w(distancia-media diametro eficiencia),
        do: assert(texto(html, "##{id}") =~ "Random networks:")

    assert texto(html, "#distancia-media") =~ "(average of 100)"
    assert texto(html, "#comprimentos") =~ "4 pairs of people who reach each other"
    assert texto(html, "#comprimentos [data-length='1']") =~ "3 pairs"
  end

  test "nenhuma faixa vira adjetivo", ctx do
    # Um K4: eficiência 100%, acima de qualquer faixa que a referência chamaria de "efficient".
    %{organization: org} = organizacao_com_repositorio(ctx.tenant)
    pessoas = for n <- ~w(K1 K2 K3 K4), do: pessoa(ctx.tenant, "#{n} Distancia")

    arestas =
      for u <- pessoas, v <- pessoas, u.id < v.id, do: %{source: u.id, target: v.id, weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => 6},
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

    html = abrir(%{ctx | org: org})

    # Mediu: a eficiência está na página, e é alta.
    assert texto(html, "#eficiencia") =~ "100%"
    refute html =~ ~r/\befficient\b/i
    refute html =~ ~r/\bslow\b/i
  end
end
