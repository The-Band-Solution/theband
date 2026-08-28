defmodule TheBandWeb.AccountsTest do
  @moduledoc """
  /accounts — feature 045, US1 (FR-013).

  A asserção que mais importa: a senha temporária aparece UMA vez e não
  reaparece — nem em render seguinte, nem no HTML de outra ação.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "alvo-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: conn, tenant: tenant, admin: admin, member: member}
  end

  test "member não alcança a tela", ctx do
    assert {:error, {:redirect, %{to: "/people"}}} =
             ctx.conn |> log_in(ctx.member) |> live(~p"/accounts")
  end

  test "a temporária aparece uma vez e some na ação seguinte", ctx do
    {:ok, view, _html} = ctx.conn |> log_in(ctx.admin) |> live(~p"/accounts")

    html = render_click(view, "reset", %{"id" => ctx.member.id})

    [temporaria] = Regex.run(~r/font-mono text-lg">([a-z2-7]+)</, html, capture: :all_but_first)
    assert String.length(temporaria) >= 12

    # A ação seguinte apaga a temporária da tela — ela não reaparece.
    html_depois = render_click(view, "reset", %{"id" => ctx.member.id})
    refute html_depois =~ temporaria

    # E a conta ficou com troca obrigatória pendente.
    assert html_depois =~ "temporária pendente"
  end

  test "criar conta: nasce sem senha, e a tela diz que a entrada recusa", ctx do
    {:ok, view, _} = ctx.conn |> log_in(ctx.admin) |> live(~p"/accounts")

    email = "nova-#{System.unique_integer([:positive])}@example.test"
    html = render_submit(view, "criar", %{"email" => email, "name" => "Nova"})

    assert html =~ email
    assert html =~ "sem senha — a entrada recusa"
  end
end
