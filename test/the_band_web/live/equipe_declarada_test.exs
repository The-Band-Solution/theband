defmodule TheBandWeb.EquipeDeclaradaTest do
  @moduledoc """
  Feature 055, US1 — a tela cria a equipe e diz de onde ela veio.

  **A distinção observada × declarada não pode ser carregada só por cor** (FR-002).
  Por isso as asserções procuram a PALAVRA, e não a classe: um teste que
  aceitasse `badge-info` passaria numa tela em que a única diferença é o tom do
  azul — que é exatamente o que o requisito proíbe.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")

    {:ok, membro} =
      TheBand.Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, membro: membro, org: org}
  end

  describe "declarar a equipe (FR-001)" do
    test "a equipe declarada aparece na lista", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams")

      html =
        render_submit(view, "declarar_equipe", %{
          "name" => "Plataforma",
          "organization_id" => ctx.org.id
        })

      assert html =~ "Plataforma"
    end

    test "a lista diz que ela foi DECLARADA, em palavra e não em cor (FR-002)", ctx do
      {:ok, equipe} = EO.declare_structural_team(ctx.tenant, ctx.org.id, "Dados", ctx.admin.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams")

      assert html =~ equipe.name

      # NÃO basta a palavra aparecer: a coluna de origem já mostra o valor cru
      # `declared`, e uma asserção sobre a palavra solta passa mesmo sem a marca.
      # Descoberto por injeção — removi o crachá e o teste continuou verde (L90).
      #
      # A asserção precisa provar a MARCA: crachá com a palavra dentro.
      assert html =~ ~r/badge[^>]*>\s*declared\s*</
    end

    test "nome repetido na mesma organização é recusado com a razão", ctx do
      {:ok, _} = EO.declare_structural_team(ctx.tenant, ctx.org.id, "Plataforma", ctx.admin.id)

      {:ok, view, _} = live(ctx.conn, ~p"/teams")

      html =
        render_submit(view, "declarar_equipe", %{
          "name" => "Plataforma",
          "organization_id" => ctx.org.id
        })

      # A recusa nomeia o que aconteceu, e não a restrição do banco (L94).
      assert html =~ "já existe uma equipe declarada com este nome"
    end
  end

  describe "só quem administra declara (FR-011)" do
    test "quem não administra não vê o formulário", ctx do
      {:ok, _view, html} = build_conn() |> log_in(ctx.membro) |> live(~p"/teams")

      refute html =~ "Declare a team"
    end

    test "e a recusa vale mesmo se o evento chegar sem passar pela tela", ctx do
      # Esconder o botão é aparência. A conferência vive no evento, e este caso é
      # o que prova: o LiveView recebe o evento direto, sem o formulário existir.
      {:ok, view, _} = build_conn() |> log_in(ctx.membro) |> live(~p"/teams")

      html =
        render_submit(view, "declarar_equipe", %{
          "name" => "Pela porta dos fundos",
          "organization_id" => ctx.org.id
        })

      assert html =~ "Only an administrator"
      assert EO.count_teams(ctx.tenant) == 0
    end
  end
end
