defmodule TheBandWeb.MCP.LimiteTest do
  @moduledoc """
  O limite é um só por token, e `/mcp` gasta o mesmo que `/api/v1` — feature 062, T024, FR-026.

  A Q4 da spec decidia *"o limite é o da 061"*. Isso só é verdade se as duas portas contarem no
  **mesmo** contador: dois limites dariam ao mesmo token o dobro da vazão, e duas respostas para
  *"por que recusou"*.

  **Como o teste chega ao limite**: o contador vive numa tabela ETS, em fatias de dez segundos
  (`ApiRateLimit`), e o limite vem da base de conhecimento (120 por minuto). Em vez de fazer 120
  requisições, o teste põe o token a **duas** do limite, pela mesma chave que o plug usa, e é o
  mesmo recurso de `test/the_band_web/api/registro_e_limite_test.exs`.

  **A guarda**: um segundo token, na mesma execução, **não** é recusado. Sem ela, o teste
  passaria com um limite global, que recusaria todo mundo.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Tenants

  @meta %{
    "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities" => %{},
    "io.modelcontextprotocol/clientInfo" => %{"name" => "teste", "version" => "0"}
  }

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, token, valor} = Tenants.create_api_token(tenant, admin, %{label: "limite"}, admin)
    {:ok, _outro, outro_valor} = Tenants.create_api_token(tenant, admin, %{label: "outro"}, admin)

    {:ok, regra} = KnowledgeBase.rule("api.access.thresholds")

    %{"requests_per_minute" => limite, "window_seconds" => janela} =
      regra["rules"]["rate_limit"]["values"]

    %{conn: conn, token: token, valor: valor, outro: outro_valor, limite: limite, janela: janela}
  end

  # Põe o token a `faltam` chamadas do limite, na fatia corrente — a mesma chave do plug.
  defp encostar_no_limite(ctx, faltam) do
    largura = max(div(ctx.janela, 6), 1)
    atual = div(System.system_time(:second), largura)
    :ets.insert(:api_rate_limit, {{ctx.token.public_id, atual}, ctx.limite - faltam})
  end

  defp api(conn, valor) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> valor)
    |> put_req_header("accept", "application/json")
    |> get(~p"/api/v1/teams")
  end

  defp mcp(conn, valor) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> valor)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", "2026-07-28")
    |> put_req_header("mcp-method", "tools/list")
    |> post(
      "/mcp",
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/list",
        "params" => %{"_meta" => @meta}
      })
    )
  end

  test "as duas portas gastam um limite só, e a recusa sai em qualquer delas", ctx do
    encostar_no_limite(ctx, 2)

    assert api(ctx.conn, ctx.valor).status == 200, "a primeira das duas que restam, pela API"
    assert mcp(ctx.conn, ctx.valor).status == 200, "a segunda, pelo MCP"

    # O limite acabou, e ele é um só: as duas portas recusam.
    recusa_mcp = mcp(ctx.conn, ctx.valor)

    assert recusa_mcp.status == 429,
           "o MCP não gastou o mesmo limite da API: #{recusa_mcp.status}"

    assert api(ctx.conn, ctx.valor).status == 429

    # A recusa é a do formato único, na camada HTTP, e diz o limite e a janela.
    corpo = Jason.decode!(recusa_mcp.resp_body)
    assert corpo["error"]["code"] == "too_many_requests", recusa_mcp.resp_body
    assert [_] = get_resp_header(recusa_mcp, "retry-after")
  end

  test "a guarda: outro token, na mesma execução, não é recusado", ctx do
    encostar_no_limite(ctx, 0)

    assert mcp(ctx.conn, ctx.valor).status == 429

    assert mcp(ctx.conn, ctx.outro).status == 200,
           "o limite recusou outro token: é global, e não por token"
  end
end
