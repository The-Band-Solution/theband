defmodule TheBandWeb.MCP.ProtocoloTest do
  @moduledoc """
  O MCP servido de verdade, pela rota `/mcp`, com token — feature 062, T007.

  Estes testes passam pela pipeline inteira: `ApiAuth`, `ApiRateLimit`, `ApiReadLog`, a porta, o
  plug de métodos, a `ex_mcp` e o registro. São a metade do T016 que só se prova com a rota (o
  plug está **na** pipeline), e o `tools/list` idêntico entre tenants, que veio do T006.

  ## O que a revisão 2026-07-28 do protocolo exige de cada requisição

  Medido contra a `ex_mcp` 1.5.0 antes de escrever este arquivo, e não presumido:

  - o cabeçalho `mcp-protocol-version: 2026-07-28`;
  - o cabeçalho `mcp-method`, com o método JSON-RPC. Sem ele: `-32020`;
  - em `tools/call`, o cabeçalho `mcp-name`, com o nome da ferramenta. Sem ele: `-32020`;
  - o `_meta` com a versão e as capacidades do cliente.

  **A biblioteca devolve as ferramentas em ordem alfabética**, e não na do registro. Por isso a
  comparação é de conjunto.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBandWeb.MCP.Servidor

  @meta %{
    "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities" => %{},
    "io.modelcontextprotocol/clientInfo" => %{"name" => "teste", "version" => "0"}
  }

  setup %{conn: conn} do
    {a, admin_a} = tenant_with_admin()
    {b, admin_b} = tenant_with_admin()
    {:ok, _t, token_a} = Tenants.create_api_token(a, admin_a, %{label: "mcp"}, admin_a)
    {:ok, _t, token_b} = Tenants.create_api_token(b, admin_b, %{label: "mcp"}, admin_b)

    %{conn: conn, a: a, b: b, token_a: token_a, token_b: token_b, equipe_a: equipe(a)}
  end

  # Um pedido JSON-RPC com os cabeçalhos que a revisão 2026-07-28 exige.
  defp mcp(conn, token, metodo, params \\ %{}, extra \\ []) do
    corpo = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => metodo,
      "params" => Map.put(params, "_meta", @meta)
    }

    conn =
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", metodo)
      |> then(fn c ->
        if token, do: put_req_header(c, "authorization", "Bearer " <> token), else: c
      end)
      |> then(fn c ->
        if nome = params["name"], do: put_req_header(c, "mcp-name", nome), else: c
      end)

    conn = Enum.reduce(extra, conn, fn {k, v}, acc -> put_req_header(acc, k, v) end)

    post(conn, "/mcp", Jason.encode!(corpo))
  end

  defp chamar(conn, token, ferramenta, argumentos),
    do: mcp(conn, token, "tools/call", %{"name" => ferramenta, "arguments" => argumentos})

  describe "a porta" do
    test "sem token, recebe o 401 do formato único, e não chega à ferramenta", ctx do
      r = chamar(ctx.conn, nil, "team_roster", %{"team_id" => ctx.equipe_a.id})

      assert r.status == 401
      assert %{"error" => %{"code" => "unauthorized"}} = json_response(r, 401)
    end

    test "passa pelo limite do token: a resposta traz os cabeçalhos do ApiRateLimit", ctx do
      r = mcp(ctx.conn, ctx.token_a, "tools/list")

      assert r.status == 200
      assert [_] = get_resp_header(r, "x-ratelimit-limit"), "o ApiRateLimit não rodou em /mcp"
      assert [_] = get_resp_header(r, "x-ratelimit-remaining")
    end

    test "leva a marca que entrega o registro ao registro de ferramentas (T021)", ctx do
      r = mcp(ctx.conn, ctx.token_a, "tools/list")
      assert r.private[:api_read_log] == :delegado
    end

    test "GET e DELETE em /mcp recebem 405: com modern_only não há sessão", ctx do
      base = ctx.conn |> put_req_header("authorization", "Bearer " <> ctx.token_a)

      assert base
             |> recycle()
             |> put_req_header("authorization", "Bearer " <> ctx.token_a)
             |> get("/mcp")
             |> Map.fetch!(:status) == 405

      assert base
             |> recycle()
             |> put_req_header("authorization", "Bearer " <> ctx.token_a)
             |> delete("/mcp")
             |> Map.fetch!(:status) == 405
    end

    test "/mcp casa exato: subcaminho recebe o 404 do formato único (R10)", ctx do
      r =
        ctx.conn
        |> put_req_header("authorization", "Bearer " <> ctx.token_a)
        |> put_req_header("content-type", "application/json")
        |> post("/mcp/nada", Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"}))

      assert %{"error" => %{"code" => "not_found"}} = json_response(r, 404)
    end

    test "origem de navegador fora da lista recebe 403", ctx do
      r = mcp(ctx.conn, ctx.token_a, "tools/list", %{}, [{"origin", "https://outro.example"}])
      assert r.status == 403
    end

    test "o plug de métodos está NA pipeline: subscriptions/listen é recusado pela rota", ctx do
      r = mcp(ctx.conn, ctx.token_a, "subscriptions/listen")

      assert r.status == 404
      assert %{"error" => %{"code" => -32_601}} = Jason.decode!(r.resp_body)
      refute get_resp_header(r, "content-type") |> Enum.any?(&(&1 =~ "text/event-stream"))
    end
  end

  describe "server/discover" do
    test "o primeiro passo de um cliente moderno responde, e diz quem é o servidor", ctx do
      # Até 2026-09-25 o plug de métodos recusava este método, e nenhum cliente da revisão
      # 2026-07-28 conseguiria começar. A lista trazia o `initialize` antigo no lugar dele.
      r = mcp(ctx.conn, ctx.token_a, "server/discover")

      assert r.status == 200, r.resp_body
      corpo = Jason.decode!(r.resp_body)
      refute Map.has_key?(corpo, "error"), r.resp_body
      assert r.resp_body =~ "the-band"
    end
  end

  describe "tools/list" do
    test "devolve as quatro, com a descrição e o esquema do registro", ctx do
      tools =
        mcp(ctx.conn, ctx.token_a, "tools/list")
        |> json_response(200)
        |> get_in(["result", "tools"])

      assert tools |> Enum.map(& &1["name"]) |> MapSet.new() ==
               MapSet.new(~w(team_roster team_open_work team_review_wait team_stale_work))

      for t <- tools do
        assert t["description"] =~ "Does not answer"
        assert t["inputSchema"]["additionalProperties"] == false
        assert t["inputSchema"]["required"] == ["team_id"]
      end
    end

    test "é idêntico para dois tenants: a descrição é constante, e nunca dado (T006)", ctx do
      lista = fn token ->
        mcp(ctx.conn, token, "tools/list") |> json_response(200) |> get_in(["result", "tools"])
      end

      assert lista.(ctx.token_a) == lista.(ctx.token_b)
    end
  end

  describe "tools/call" do
    test "tenant_id enviado é recusado com erro de parâmetro, e não obedecido", ctx do
      r =
        chamar(ctx.conn, ctx.token_a, "team_roster", %{
          "team_id" => ctx.equipe_a.id,
          "tenant_id" => ctx.b.id
        })

      assert %{"error" => %{"code" => -32_602, "message" => "unexpected argument: tenant_id"}} =
               Jason.decode!(r.resp_body)
    end

    test "a recusa é resposta, com o mesmo objeto em structuredContent e em content", ctx do
      # O token de B, com a equipe de A: outro tenant.
      resultado =
        chamar(ctx.conn, ctx.token_b, "team_roster", %{"team_id" => ctx.equipe_a.id})
        |> json_response(200)
        |> Map.fetch!("result")

      assert %{"state" => "refused", "reason" => "fora_do_alcance", "value" => nil} =
               resultado["structuredContent"]

      refute resultado["isError"]
      [%{"type" => "text", "text" => texto}] = resultado["content"]
      assert Jason.decode!(texto) == resultado["structuredContent"]
    end

    test "cada token recebe o próprio tenant, em chamadas seguidas", ctx do
      # B não alcança a equipe de A: recusa.
      de_b = chamar(ctx.conn, ctx.token_b, "team_roster", %{"team_id" => ctx.equipe_a.id})

      assert get_in(Jason.decode!(de_b.resp_body), ["result", "structuredContent", "state"]) ==
               "refused"

      # A alcança: a ferramenta responde. O que importa aqui é que NÃO é a recusa de B.
      de_a = chamar(ctx.conn, ctx.token_a, "team_roster", %{"team_id" => ctx.equipe_a.id})

      refute get_in(Jason.decode!(de_a.resp_body), ["result", "structuredContent", "state"]) ==
               "refused"
    end
  end

  describe "o estado do handler (R7)" do
    test "leva só identificadores, e nunca o valor do token", ctx do
      {:ok, token, valor} =
        Tenants.create_api_token(ctx.a, admin(ctx.a), %{label: "r7"}, admin(ctx.a))

      conn = %Plug.Conn{
        assigns: %{current_tenant: ctx.a, current_user: admin(ctx.a), api_token: token}
      }

      estado = Servidor.estado(conn, %{})

      assert Map.keys(estado) |> Enum.sort() == [:request_id, :tenant, :token_public_id, :user]
      [_, _, _, segredo] = String.split(valor, "_", parts: 4)
      refute inspect(estado, limit: :infinity) =~ segredo
      refute inspect(estado, limit: :infinity) =~ valor
    end
  end

  defp admin(tenant) do
    tenant |> Tenants.list_users() |> Enum.find(&(&1.role == "admin"))
  end

  # A equipe organizacional EXIGE organização — há um `CHECK` no banco.
  defp equipe(tenant) do
    login = "org-#{String.slice(tenant.id, 0, 8)}"

    {:ok, _} =
      EO.upsert_organization_from_source(tenant, %{
        login: login,
        name: login,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: login,
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, t} =
      EO.upsert_team_from_source(tenant, %{
        name: "Equipe",
        slug: "equipe-#{System.unique_integer([:positive])}",
        type: "organizational_team",
        organization_external_id: login,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_#{System.unique_integer([:positive])}",
        collected_at: DateTime.utc_now(:second)
      })

    t
  end
end
