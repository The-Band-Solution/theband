defmodule TheBandWeb.CotaCompartilhadaTest do
  @moduledoc """
  A tela de ferramentas mostra o dono de cada token e avisa quando duas ferramentas
  dividem a cota — ADR 0007, decisão 1.

  A cota de 5 000 requisições por hora é do usuário do GitHub, não do token. Quem cadastra
  duas ferramentas com tokens do mesmo usuário precisa ver isso onde os tokens estão, e não
  descobrir pelo 403 no meio da coleta.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  @aviso "shares the 5,000 requests/hour quota"

  defp ferramenta(tenant, org) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: org
      })
      |> Repo.insert()

    tool
  end

  defp credencial(tenant, tool, secret, dono) do
    {:ok, credential} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "principal",
        secret: secret,
        last_four: ToolCredential.last_four(secret),
        validated_at: DateTime.utc_now(:second),
        owner_login: dono
      })
      |> Repo.insert()

    credential
  end

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    %{conn: log_in(conn, user), tenant: tenant}
  end

  test "duas ferramentas com o mesmo dono: aviso em cada uma, nomeando a outra", ctx do
    acme = ferramenta(ctx.tenant, "acme")
    labs = ferramenta(ctx.tenant, "acme-labs")
    credencial(ctx.tenant, acme, "ghp_a_0001", "octocat")
    credencial(ctx.tenant, labs, "ghp_b_0002", "octocat")

    {:ok, live, html} = live(ctx.conn, ~p"/tools")

    assert html =~ @aviso,
           "dois tokens do mesmo usuário dividem o saldo, e a tela é onde isso se vê antes do 403"

    assert has_element?(live, "#cota-compartilhada-#{acme.id}-octocat", "acme-labs"),
           "o aviso da acme nomeia a acme-labs: é com ela que a cota é dividida"

    assert has_element?(live, "#cota-compartilhada-#{labs.id}-octocat", "acme"),
           "o aviso da acme-labs nomeia a acme: o aviso é em cada uma, não só na primeira"

    assert html =~ "owner: octocat",
           "o dono aparece ao lado do token mascarado — é o dado que explica o aviso"
  end

  test "donos diferentes: o dono aparece ao lado do token, e não há aviso", ctx do
    acme = ferramenta(ctx.tenant, "acme")
    labs = ferramenta(ctx.tenant, "acme-labs")
    credencial(ctx.tenant, acme, "ghp_a_0001", "octocat")
    credencial(ctx.tenant, labs, "ghp_b_0002", "hubot")

    {:ok, _live, html} = live(ctx.conn, ~p"/tools")

    refute html =~ @aviso,
           "usuários diferentes têm saldos diferentes; avisar aqui seria alarme falso"

    assert html =~ "owner: octocat"
    assert html =~ "owner: hubot"
  end

  test "dono ainda desconhecido: a tela diz que não sabe, em vez de inventar", ctx do
    acme = ferramenta(ctx.tenant, "acme")
    credencial(ctx.tenant, acme, "ghp_a_0001", nil)

    {:ok, _live, html} = live(ctx.conn, ~p"/tools")

    assert html =~ "owner unknown until the next sync",
           "credencial anterior à decisão não tem dono gravado; a coleta seguinte descobre"

    refute html =~ @aviso
  end
end
