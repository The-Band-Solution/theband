defmodule TheBandWeb.NetworkAnalysisLive.ProfileTest do
  @moduledoc """
  A página do perfil — feature 076, T048 (US9, cen. 1 a 4; FR-048, FR-049; protótipo 3.6.4 e
  Tela 8).

  - Bia, designada em issues abertas por 3 pessoas e autora de issues designadas a 2, mostra
    *"opened issues assigned to 2 people"* e *"assigned on issues opened by 3 people"*, as duas
    listas com o peso e o total;
  - nenhum *"assigns to"* nem *"receives from"*;
  - a rede sem aresta para ela diz a ausência, e não zeros;
  - fora do alcance, *"not found"*.

  **Defeito a injetar**: o rótulo *"assigns to"*; o teste reprova.
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
    {outro, outro_admin} = tenant_with_admin()
    %{organization: org} = organizacao_com_repositorio(tenant)
    [bia, a1, a2, a3, r1, r2] = for n <- ~w(Bia A1 A2 A3 R1 R2), do: pessoa(tenant, "#{n} Perfil")

    designacao =
      for(a <- [a1, a2, a3], do: %{source: a.id, target: bia.id, weight: 2}) ++
        [%{source: bia.id, target: r1.id, weight: 4}, %{source: bia.id, target: r2.id, weight: 1}]

    entradas = fn
      "assignment", _, _ ->
        {:ok,
         %{
           edges: designacao,
           exclusions: %{"issues" => 11},
           people_without_edges: 0,
           source_computed_at: nil,
           provenance: %{}
         }}

      "review", _, _ ->
        {:ok,
         %{
           edges: [%{source: a1.id, target: a2.id, weight: 1}],
           exclusions: %{"pairs" => 1, "organization_account" => 0},
           people_without_edges: 0,
           source_computed_at: nil,
           provenance: %{}
         }}
    end

    {:ok, _, _} =
      Commands.compute(tenant, org, DateTime.utc_now(:second), Parameters.fetch!(), entradas)

    %{conn: conn, admin: admin, org: org, bia: bia, outro_admin: outro_admin, outro: outro}
  end

  defp abrir(conn, user, org, pessoa) do
    live(
      log_in(conn, user),
      "/network-analysis/#{org.id}/people/#{pessoa}?network=assignment&window=90"
    )
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)
  defp texto(html, sel), do: html |> q(sel) |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

  test "Bia: os rótulos de network.degree.count, as listas por peso e o total", ctx do
    {:ok, _view, html} = abrir(ctx.conn, ctx.admin, ctx.org, ctx.bia.id)
    designacao = texto(html, "#rede-assignment")

    assert designacao =~ "opened issues assigned to 2 people"
    assert designacao =~ "assigned on issues opened by 3 people"
    # O total da designação aberta soma uma vez por responsável: são designações (T053).
    assert texto(html, "#assignment-para") =~ "5 assignments"
    assert texto(html, "#assignment-para") =~ ~r/R1 Perfil 4 issues.*R2 Perfil 1 issue/
    assert texto(html, "#assignment-de") =~ "6 issues"
    refute html =~ ~r/assigns to/i
    refute html =~ ~r/receives from/i
  end

  test "a rede sem aresta para ela diz a ausência, e não zeros", ctx do
    {:ok, _view, html} = abrir(ctx.conn, ctx.admin, ctx.org, ctx.bia.id)

    assert texto(html, "#rede-review") =~ "no review with another person in this network"
    refute texto(html, "#rede-review") =~ ~r/\b0\b/
  end

  test "de outro tenant, not found", ctx do
    assert {:error, {:live_redirect, %{flash: %{"error" => "Not found."}}}} =
             abrir(ctx.conn, ctx.outro_admin, ctx.org, ctx.bia.id)
  end
end
