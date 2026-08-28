defmodule TheBandWeb.GatingOperacionalTest do
  @moduledoc """
  FR-023 — Syncs e Tools por administrador ou concessão organization, com recorte.

  A violação primeiro (L03): quem responde pela organização A não vê ferramenta
  da organização B — nem no menu, nem na tela, nem por URL.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [ferramenta: 2]

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org_a = organization_fixture(tenant, "org-a")
    _org_b = organization_fixture(tenant, "org-b")
    tool_a = ferramenta(tenant, "org-a")
    tool_b = ferramenta(tenant, "org-b")

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "op-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{
      conn: conn,
      tenant: tenant,
      admin: admin,
      member: member,
      org_a: org_a,
      tool_a: tool_a,
      tool_b: tool_b
    }
  end

  test "member puro: nem menu, nem tela — e a recusa nomeia o motivo", ctx do
    conn = log_in(ctx.conn, ctx.member)

    {:ok, _view, html} = live(conn, ~p"/people")
    refute html =~ "Operação"
    refute html =~ ~s(href="/syncs")

    assert {:error, {:redirect, %{to: "/people", flash: flash}}} = live(conn, ~p"/tools")
    assert flash["error"] =~ "organization"
  end

  test "organization alcança /ai — decisão da aceitação do sprint 023 (FR-023 como escrito)",
       ctx do
    {:ok, _} =
      Tenants.grant_scope(ctx.tenant, ctx.member.id, :organization, ctx.org_a.id, ctx.admin)

    conn = log_in(ctx.conn, ctx.member)
    assert {:ok, _view, html} = live(conn, ~p"/ai")
    # A chave é UMA do tenant — o recorte de organização não a divide, e a tela é a mesma.
    assert html =~ "provider"
  end

  test "member puro não alcança /ai", ctx do
    assert {:error, {:redirect, %{to: "/people"}}} =
             ctx.conn |> log_in(ctx.member) |> live(~p"/ai")
  end

  test "organization da org A vê a ferramenta da A e NÃO a da B", ctx do
    {:ok, _} =
      Tenants.grant_scope(ctx.tenant, ctx.member.id, :organization, ctx.org_a.id, ctx.admin)

    conn = log_in(ctx.conn, ctx.member)

    # O menu agora oferece Operação (FR-023 ampliou a condição da 046).
    {:ok, _view, html} = live(conn, ~p"/people")
    assert html =~ "Operação"

    {:ok, _view, html} = live(conn, ~p"/tools")
    assert html =~ "org-a"
    refute html =~ "org-b", "ferramenta de outra organização vazou para o recorte"

    {:ok, _view, html} = live(conn, ~p"/syncs")
    refute html =~ "org-b"
  end

  test "admin segue vendo o tenant inteiro", ctx do
    conn = log_in(ctx.conn, ctx.admin)

    {:ok, _view, html} = live(conn, ~p"/tools")
    assert html =~ "org-a"
    assert html =~ "org-b"
  end

  test "gestão continua só de administrador: organization não alcança contas", ctx do
    {:ok, _} =
      Tenants.grant_scope(ctx.tenant, ctx.member.id, :organization, ctx.org_a.id, ctx.admin)

    conn = log_in(ctx.conn, ctx.member)

    assert {:error, {:redirect, %{to: "/people"}}} = live(conn, ~p"/accounts")
    assert {:error, {:redirect, %{to: "/people"}}} = live(conn, ~p"/access-scopes")
  end
end
