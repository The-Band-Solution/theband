defmodule TheBandWeb.PapelAbaAbertaTest do
  @moduledoc """
  A tela aberta de quem perdeu a marca de administrador sai da área admin — spec 072, T009
  (FR-008, R4).

  O papel fica congelado no `mount`. O rebaixamento avisa, depois do `commit`, no tópico da conta,
  e a reconferência relê a conta: numa área admin, a aba vai para `/people` com a frase de hoje
  (Q3). Fora dela, a aba continua, porque a pessoa continua podendo estar ali.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, outra} =
      Tenants.create_user(tenant, %{
        "email" => "outra-#{System.unique_integer([:positive])}@x.io",
        "role" => "admin",
        "password" => "senha-forte-de-teste-123"
      })

    %{conn: log_in(conn, outra), tenant: tenant, admin: admin, outra: outra}
  end

  test "a aba de /accounts do rebaixado vai para /people, e o clique seguinte não executa", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.outra.id, ctx.admin)

    {path, flash} = assert_redirect(view)
    assert path == "/people"
    assert flash["error"] == "Only organisation administrators can do that."

    catch_exit(render_click(view, "reset", %{"id" => ctx.admin.id}))
  end

  test "a aba fora da área admin continua: o rebaixado ainda pode estar ali", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/people")

    {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.outra.id, ctx.admin)

    assert render_change(view, "buscar", %{"q" => "", "tabela" => "people"}) =~ "people"
  end

  test "promover não derruba ninguém", ctx do
    {:ok, membro} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "m-#{System.unique_integer([:positive])}@x.io",
        "role" => "member",
        "password" => "senha-forte-de-teste-123"
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")
    {:ok, _} = Tenants.promote_user(ctx.tenant, membro.id, ctx.admin)

    assert render(view) =~ membro.email
  end
end
