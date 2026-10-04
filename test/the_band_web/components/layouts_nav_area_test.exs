defmodule TheBandWeb.LayoutsNavAreaTest do
  @moduledoc """
  O item **Network analysis** no menu principal — feature 076, T018 (FR-001; US1, cen. 1).

  `nav_area/1` marca a área para todo caminho sob `/network-analysis`, e o item aparece para
  toda conta do tenant, com `aria-current` quando a página é da área.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TheBandWeb.Layouts

  test "todo caminho da área resolve para :network_analysis" do
    id = Ecto.UUID.generate()

    for caminho <- [
          "/network-analysis",
          "/network-analysis/#{id}",
          "/network-analysis/#{id}/graph",
          "/network-analysis/#{id}/people/#{Ecto.UUID.generate()}"
        ] do
      assert Layouts.nav_area(caminho) == :network_analysis, caminho
    end

    # O prefixo não engole rota vizinha.
    assert Layouts.nav_area("/network-analysisx") == nil
    assert Layouts.nav_area("/organizations") == :organization
  end

  describe "o item no menu" do
    setup do
      {tenant, admin} = tenant_with_admin()

      {:ok, member} =
        TheBand.Tenants.create_user(tenant, %{
          "email" => "member-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      %{admin: admin, member: member}
    end

    test "toda conta vê Network analysis, fora da área sem marca", %{conn: conn} = ctx do
      for user <- [ctx.admin, ctx.member] do
        {:ok, _view, html} = conn |> log_in(user) |> live(~p"/people")
        [item] = item(html)

        assert LazyHTML.text(item) =~ "Network analysis"
        refute "true" in LazyHTML.attribute(item, "aria-current")
      end
    end

    test "dentro da área, o item leva aria-current", %{conn: conn, member: member} do
      {:ok, _view, html} = conn |> log_in(member) |> live(~p"/network-analysis")
      [item] = item(html)

      assert LazyHTML.attribute(item, "aria-current") == ["true"]
    end
  end

  defp item(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s(header a[href="/network-analysis"]))
    |> Enum.to_list()
  end
end
