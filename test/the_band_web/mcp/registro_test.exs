defmodule TheBandWeb.MCP.RegistroTest do
  @moduledoc """
  O registro de leitura do MCP, no ponto do veredito — feature 062, T021 e T022, achados R1, R2
  e A7 da revisão independente.

  O cenário é o que a revisão propôs, pela rota real. Um token com alcance faz, na mesma
  execução:

  - `team_roster` sobre X;
  - `team_open_work` sobre Y;
  - `team_roster` sobre Z, de outro tenant, que é recusado;
  - um `tools/list` e uma notificação.

  **O que tem de sobrar**: exatamente duas linhas em `api_access_reads`, com a ferramenta e a
  equipe; nenhuma linha com `route` começando por `/mcp`; e um evento de recusa com a equipe Z e o
  mesmo `request_id` que a resposta levou no cabeçalho.

  A guarda contra o teste vazio: `assert length(linhas) > 0` antes das refutações. Sem ela,
  "nenhuma linha de /mcp" passaria com o registro desligado.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants

  @meta %{
    "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities" => %{},
    "io.modelcontextprotocol/clientInfo" => %{"name" => "teste", "version" => "0"}
  }

  setup %{conn: conn} do
    {a, admin_a} = tenant_with_admin()
    {b, _admin_b} = tenant_with_admin()
    {:ok, token, valor} = Tenants.create_api_token(a, admin_a, %{label: "mcp"}, admin_a)

    %{
      conn: conn,
      a: a,
      valor: valor,
      publico: token.public_id,
      x: equipe(a, "X"),
      y: equipe(a, "Y"),
      z: equipe(b, "Z")
    }
  end

  defp pedido(conn, valor, metodo, params, id \\ :com_id) do
    corpo =
      %{"jsonrpc" => "2.0", "method" => metodo, "params" => Map.put(params, "_meta", @meta)}
      |> then(fn c ->
        if id == :com_id, do: Map.put(c, "id", System.unique_integer([:positive])), else: c
      end)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> valor)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", "2026-07-28")
    |> put_req_header("mcp-method", metodo)
    |> then(fn c -> if n = params["name"], do: put_req_header(c, "mcp-name", n), else: c end)
    |> post("/mcp", Jason.encode!(corpo))
  end

  defp ferramenta(ctx, nome, equipe),
    do:
      pedido(ctx.conn, ctx.valor, "tools/call", %{
        "name" => nome,
        "arguments" => %{"team_id" => equipe.id}
      })

  defp linhas(tenant) do
    Repo.all(
      from r in "api_access_reads",
        where: r.tenant_id == type(^tenant.id, :binary_id),
        select: %{
          route: r.route,
          target_id: type(r.target_id, :binary_id),
          token: r.token_public_id
        }
    )
  end

  test "duas leituras concedidas, duas linhas; a recusa e o protocolo, nenhuma", ctx do
    {{respostas, recusa}, log} =
      with_log(fn ->
        roster_x = ferramenta(ctx, "team_roster", ctx.x)
        aberto_y = ferramenta(ctx, "team_open_work", ctx.y)
        recusa = ferramenta(ctx, "team_roster", ctx.z)
        lista = pedido(ctx.conn, ctx.valor, "tools/list", %{})

        aviso =
          pedido(ctx.conn, ctx.valor, "notifications/cancelled", %{"requestId" => 1}, :sem_id)

        {[roster_x, aberto_y, recusa, lista, aviso], recusa}
      end)

    # A notificação é recusada pelo plug de métodos (N3): `notifications/cancelled` saiu da
    # lista. As outras quatro respondem.
    assert respostas |> Enum.take(4) |> Enum.all?(&(&1.status == 200)),
           inspect(Enum.map(respostas, & &1.status))

    assert List.last(respostas).status == 404

    linhas = linhas(ctx.a)

    # A GUARDA: sem ela, as refutações abaixo passariam com o registro desligado.
    assert linhas != [], "nenhuma leitura foi registrada: o registro está desligado"

    assert Enum.sort_by(linhas, & &1.route) == [
             %{route: "mcp:team_open_work", target_id: ctx.y.id, token: ctx.publico},
             %{route: "mcp:team_roster", target_id: ctx.x.id, token: ctx.publico}
           ]

    refute Enum.any?(linhas, &String.starts_with?(&1.route, "/mcp")),
           "o ApiReadLog gravou o /mcp: a marca :delegado não chegou"

    refute Enum.any?(linhas, &(&1.target_id == ctx.z.id)),
           "a recusa foi gravada como leitura (A7)"

    # A recusa deixa um evento, com a equipe e o mesmo request_id da resposta (R8).
    [request_id] = get_resp_header(recusa, "x-request-id")

    assert log =~ "acesso: equipe recusada"
    assert log =~ ~s(alvo_team_id="#{ctx.z.id}")

    [linha_da_recusa] =
      log |> String.split("\n") |> Enum.filter(&(&1 =~ "equipe recusada"))

    assert linha_da_recusa =~ request_id,
           "o evento de recusa saiu sem o request_id da resposta: a correlação se perdeu (R8)"
  end

  test "o valor do token não aparece na linha do registro", ctx do
    ferramenta(ctx, "team_roster", ctx.x)

    [_, _, _, segredo] = String.split(ctx.valor, "_", parts: 4)
    linhas = linhas(ctx.a)

    # A GUARDA: sem linha, o `for` abaixo não afirmaria nada. Foi o que a injeção de defeito
    # mostrou: sem a gravação da leitura, este teste continuava verde.
    assert [_ | _] = linhas, "nenhuma leitura foi registrada, e o teste não mediria nada"

    for linha <- linhas do
      refute inspect(linha) =~ segredo
      assert linha.token == ctx.publico
    end
  end

  defp equipe(tenant, nome) do
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
        name: nome,
        slug: "#{String.downcase(nome)}-#{System.unique_integer([:positive])}",
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
