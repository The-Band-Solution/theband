defmodule TheBandWeb.PeopleLive.OrganizationAccountTest do
  @moduledoc """
  Declarar a conta da organização na tela de pessoas — feature 076, T026 (R14; A20).

  A administração declara e revoga pela página da pessoa, e vê a lista em `/people`. A conta de
  membro não vê o controle nem a lista, e o evento forjado por ela é recusado **sem mudar nada**.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, membro} =
      Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    leds = pessoa(tenant, "LEDS Conta Compartilhada")
    %{conn: conn, tenant: tenant, admin: admin, membro: membro, leds: leds}
  end

  test "a administração declara e revoga pela tela, e a lista diz quem e quando", ctx do
    {:ok, view, html} = live(log_in(ctx.conn, ctx.admin), ~p"/people/#{ctx.leds.id}")
    assert html =~ "Organisation account"

    view |> element("button", "Show whether this is the organisation") |> render_click()

    html =
      view
      |> form("#declarar-conta-da-organizacao", %{"reason" => "shared bot-like user"})
      |> render_submit()

    assert html =~ "Declared as the organisation&#39;s account"
    assert html =~ "shared bot-like user"
    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new([ctx.leds.id])

    {:ok, _lista, lista} = live(log_in(ctx.conn, ctx.admin), ~p"/people")
    assert lista =~ ~s(id="contas-da-organizacao")
    assert lista =~ "shared bot-like user"
    assert lista =~ (ctx.admin.name || ctx.admin.email)

    view |> element("button", "revoke") |> render_click()
    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new()
  end

  test "a conta de membro não vê o controle nem a lista", ctx do
    {:ok, _view, html} = live(log_in(ctx.conn, ctx.membro), ~p"/people/#{ctx.leds.id}")
    refute html =~ ~s(id="organization-account")

    {:ok, _lista, lista} = live(log_in(ctx.conn, ctx.membro), ~p"/people")
    # A página carregou a lista de pessoas antes do refute.
    assert lista =~ "LEDS Conta Compartilhada"
    refute lista =~ ~s(id="contas-da-organizacao")
  end

  test "o evento forjado por conta de membro é recusado, e nada muda", ctx do
    {:ok, d} =
      Tenants.declare_organization_account(
        ctx.tenant,
        ctx.leds.id,
        "declared by admin",
        ctx.admin
      )

    outra = pessoa(ctx.tenant, "Outra Pessoa")
    {:ok, view, _html} = live(log_in(ctx.conn, ctx.membro), ~p"/people/#{outra.id}")

    render_hook(view, "declarar_conta_da_organizacao", %{"reason" => "forjado"})
    render_hook(view, "revogar_conta_da_organizacao", %{"id" => d.id})
    html = render_hook(view, "ver_conta_da_organizacao", %{})

    assert html =~ "Only organisation administrators can do that."
    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new([ctx.leds.id])
    refute html =~ "declared by admin"
  end
end
