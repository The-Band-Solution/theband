defmodule TheBandWeb.PainelDeCotaTest do
  @moduledoc """
  O painel de cota na tela de sincronização — ADR 0007, parte 5.

  Princípio IV pelo avesso: o que decide a coleta não pode ser invisível. A tela mostra, por
  identidade (usuário do GitHub dono do token), o que resta em cada balde, quando reabre e
  quantas requisições estão em voo — alimentada pelo gestor via PubSub.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ingestion.Cota
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    dono = "dona-#{System.unique_integer([:positive])}"
    tool = ferramenta(tenant, dono)
    %{conn: log_in(conn, user), tenant: tenant, tool: tool, dono: dono}
  end

  test "sem nenhuma requisição feita, o painel não aparece — não há o que mostrar", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/syncs")
    refute html =~ "API quota"
  end

  test "mostra o dono, o saldo de cada balde e quando reabre, e acompanha o gestor", ctx do
    chave = {"https://github.com", ctx.dono}
    {:ok, live, _html} = live(ctx.conn, ~p"/syncs")

    # O gestor observa uma resposta: publica, e a tela — assinante da identidade — recebe.
    :ok = Cota.pedir(chave, :core)
    reset = DateTime.add(DateTime.utc_now(), 1800, :second)
    Cota.observar(chave, :core, %{remaining: 4212, limit: 5000, reset: reset})

    html = render_ate(live, "4212 / 5000")

    assert html =~ "API quota"
    assert html =~ ctx.dono, "a linha é da IDENTIDADE (o dono do token), e não da ferramenta"
    assert html =~ "4212 / 5000", "o saldo é o que a última resposta disse"
    assert html =~ Calendar.strftime(reset, "%H:%M UTC"), "quando o balde reabre"
    assert html =~ "not read yet", "a GraphQL ainda não foi lida — e a tela diz isso, não zero"
  end

  test "a identidade sem dono descoberto é nomeada como tal, e não inventa um login", ctx do
    tool = ferramenta(ctx.tenant, nil, "acme-sem-dono")
    credencial = TheBand.Sources.active_credential(tool)
    chave = Cota.chave(tool, credencial)
    assert {_, {:credencial, _}} = chave

    {:ok, live, _html} = live(ctx.conn, ~p"/syncs")
    :ok = Cota.pedir(chave, :graphql)
    Cota.observar(chave, :graphql, %{remaining: 10, limit: 5000, cost: 1, reset: nil})

    html = render_ate(live, "10 / 5000")
    assert html =~ "credential not yet identified"
  end

  # A mensagem do PubSub chega ao LiveView de forma assíncrona: espera até a tela refletir.
  defp render_ate(live, trecho, tentativas \\ 50) do
    html = render(live)

    cond do
      html =~ trecho -> html
      tentativas == 0 -> html
      true -> Process.sleep(20) && render_ate(live, trecho, tentativas - 1)
    end
  end

  defp ferramenta(tenant, dono, login \\ "acme") do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: login
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "principal",
        secret: "ghp_painel",
        last_four: "inel",
        scopes: ["read:org"],
        owner_login: dono,
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    tool
  end
end
