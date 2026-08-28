defmodule TheBandWeb.ProfileTest do
  @moduledoc """
  /profile — feature 045, US3 (FR-012).

  A violação que carrega o arquivo: o HTML do perfil NUNCA contém hash nem
  senha — nem da própria conta.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  @senha "senha-bem-comprida-123"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "eu-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, member} = Tenants.set_password(tenant, member.id, @senha)

    %{conn: log_in(conn, member), tenant: tenant, admin: admin, member: member}
  end

  test "mostra escopos com origem e o estado do elo; nada de hash no HTML", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/profile")

    assert html =~ "person"
    assert html =~ "Ninguém declarou quem esta conta é"
    assert html =~ "Concessão é ato de quem administra"

    refute html =~ ctx.member.password_hash
    refute html =~ @senha
  end

  test "edita o próprio nome", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/profile")

    html = render_submit(view, "nome", %{"name" => "Nome Novo"})
    assert html =~ "Nome atualizado."
    assert html =~ "Nome Novo"
  end

  test "trocar senha: atual errada recusa; certa troca e exige a nova na entrada", ctx do
    conn =
      post(ctx.conn, ~p"/profile/password", %{
        "current" => "atual-errada-e-longa",
        "password" => "novissima-comprida-1"
      })

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "atual não confere"
    assert {:ok, _} = Tenants.authenticate(ctx.member.email, @senha)

    conn =
      post(ctx.conn, ~p"/profile/password", %{
        "current" => @senha,
        "password" => "novissima-comprida-1"
      })

    assert redirected_to(conn) == ~p"/profile"
    assert {:ok, _} = Tenants.authenticate(ctx.member.email, "novissima-comprida-1")
    assert {:error, :invalid_credentials} = Tenants.authenticate(ctx.member.email, @senha)
  end
end
