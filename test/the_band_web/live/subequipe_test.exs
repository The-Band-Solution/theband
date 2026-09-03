defmodule TheBandWeb.SubequipeTest do
  @moduledoc """
  Feature 055, US3 — a estrutura na tela da equipe, e a subequipe.

  **A subequipe herda a organização da mãe**, e não há seletor. Oferecer um faria
  a autoridade subir: quem tem escopo nesta equipe declara DENTRO dela, e não em
  qualquer lugar da organização.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    {:ok, mae} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, org: org, mae: mae}
  end

  describe "declarar uma equipe dentro desta" do
    test "a subequipe nasce e aparece em 'Contains'", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      html = render_submit(view, "criar_subequipe", %{"name" => "Dados"})

      assert html =~ "Dados"
      assert [%{name: "Dados"}] = EO.team_parts(ctx.tenant, ctx.mae.id)
    end

    test "ela HERDA a organização da mãe", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")
      render_submit(view, "criar_subequipe", %{"name" => "Dados"})

      [%{team_id: filha_id}] = EO.team_parts(ctx.tenant, ctx.mae.id)
      {:ok, filha} = EO.fetch_team(ctx.tenant, filha_id)

      assert filha.organization_id == ctx.org.id
    end

    test "a outra direção aparece na tela da filha", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")
      render_submit(view, "criar_subequipe", %{"name" => "Dados"})
      [%{team_id: filha_id}] = EO.team_parts(ctx.tenant, ctx.mae.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{filha_id}")

      # A de cima diz o que contém; a de baixo diz de quem faz parte.
      assert html =~ "Part of"
      assert html =~ "Plataforma"
    end
  end

  describe "descompor não apaga a equipe" do
    test "a filha sai da estrutura e continua existindo", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")
      render_submit(view, "criar_subequipe", %{"name" => "Dados"})
      [%{team_id: filha_id}] = EO.team_parts(ctx.tenant, ctx.mae.id)

      antes = EO.count_teams(ctx.tenant)
      render_click(view, "descompor", %{"part_id" => filha_id})

      assert EO.team_parts(ctx.tenant, ctx.mae.id) == []
      assert EO.count_teams(ctx.tenant) == antes
    end
  end

  describe "sem escopo, não declara" do
    test "quem não alcança a organização é recusado", ctx do
      {:ok, outra} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "sem-escopo-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      {:ok, view, _} = build_conn() |> log_in(outra) |> live(~p"/teams/#{ctx.mae.id}")

      html = render_submit(view, "criar_subequipe", %{"name" => "Pela porta dos fundos"})

      assert html =~ "no scope"
      assert EO.team_parts(ctx.tenant, ctx.mae.id) == []
    end
  end
end
