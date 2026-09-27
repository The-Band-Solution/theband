defmodule TheBandWeb.MCP.CustoTest do
  @moduledoc """
  O custo do `team_roster` contra o de `GET /api/v1/teams/:id/members` — feature 062, T028.

  *Duas portas para o mesmo dado com custos diferentes significam que uma tem consulta a mais*,
  e a que tem a mais faz trabalho que a outra provou desnecessário. As duas passam pela mesma
  pipeline (`ApiAuth`, `ApiRateLimit`), e as duas são medidas pela rota, com token: medir o
  MCP pela função e a API pela rota compararia coisas diferentes.

  E o custo é o mesmo com 1 e com 10 membros, nas duas: sem isso, uma consulta por linha
  passaria na igualdade se as duas portas a tivessem.

  A falha diz **o que** entrou a mais, pela assinatura de cada consulta.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.ContadorDeConsultas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @meta %{
    "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities" => %{},
    "io.modelcontextprotocol/clientInfo" => %{"name" => "custo", "version" => "0"}
  }

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "custo"}, admin)
    %{conn: conn, tenant: tenant, token: valor}
  end

  defp equipe_com(tenant, n) do
    u = System.unique_integer([:positive])
    org = organization_fixture(tenant, "org-#{u}")
    equipe = team_fixture(tenant, "T_#{u}", %{organization: org})

    for i <- 1..n do
      {:ok, p} =
        EO.upsert_person_from_source(tenant, %{
          login: "p#{i}-#{u}",
          name: "Pessoa #{i}",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "U_#{i}_#{u}",
          collected_at: DateTime.utc_now(:second)
        })

      {:ok, _} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: p.id,
          team_id: equipe.id,
          person_external_id: p.external_id,
          team_external_id: "T_#{u}",
          platform_access_level: "MEMBER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })
    end

    equipe
  end

  defp api(ctx, equipe) do
    ContadorDeConsultas.listar(fn ->
      r =
        ctx.conn
        |> recycle()
        |> put_req_header("authorization", "Bearer " <> ctx.token)
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/teams/#{equipe.id}/members")

      assert r.status == 200
      send(self(), {:linhas, length(json_response(r, 200)["data"])})
    end)
  end

  defp mcp(ctx, equipe) do
    corpo = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/call",
      "params" => %{
        "name" => "team_roster",
        "arguments" => %{"team_id" => equipe.id},
        "_meta" => @meta
      }
    }

    ContadorDeConsultas.listar(fn ->
      r =
        ctx.conn
        |> recycle()
        |> put_req_header("authorization", "Bearer " <> ctx.token)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json, text/event-stream")
        |> put_req_header("mcp-protocol-version", "2026-07-28")
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "team_roster")
        |> post("/mcp", Jason.encode!(corpo))

      assert r.status == 200, r.resp_body
      resultado = Jason.decode!(r.resp_body)["result"]["structuredContent"]
      assert resultado["state"] == "checked", inspect(resultado)
      send(self(), {:linhas, length(resultado["value"]["people"])})
    end)
  end

  defp linhas do
    assert_received {:linhas, n}
    n
  end

  defp diferenca(a, b) do
    (b -- a) |> Enum.frequencies() |> Enum.map_join(", ", fn {q, n} -> "#{q}×#{n}" end)
  end

  # A diferença MEDIDA em 2026-09-25, e nomeada, e não uma consulta a mais sem dono:
  #
  # - no lugar do `count(*)` da paginação da API, o MCP faz `team_roster_totals/3`, que conta o
  #   mesmo alcance separado em current, left e mistakes. Uma consulta por uma, e a do MCP diz
  #   mais: a API conta pessoas, e o MCP diz quantas saíram e quantas foram equívoco;
  # - e o MCP faz `team_parts/2`, que a API não faz, porque só ele devolve o bloco `composition`
  #   com o nome das partes, quem declarou e desde quando. O escopo já sabe os ids das partes, e
  #   não os nomes nem a declaração.
  #
  # Qualquer outra diferença reprova, e a mensagem diz qual.
  @so_no_mcp ["eo_team_compositions", "eo_team_memberships"]

  test "team_roster custa o mesmo que GET /teams/:id/members, menos a diferença nomeada", ctx do
    equipe = equipe_com(ctx.tenant, 10)

    na_api = api(ctx, equipe)
    assert linhas() == 10

    no_mcp = mcp(ctx, equipe)
    # A guarda da igualdade vazia: as duas trouxeram os dez, e não zero.
    assert linhas() == 10

    relato =
      "API #{length(na_api)}, MCP #{length(no_mcp)}. " <>
        "A mais no MCP: [#{diferenca(na_api, no_mcp)}]. " <>
        "A mais na API: [#{diferenca(no_mcp, na_api)}]"

    assert Enum.sort(no_mcp -- na_api) == @so_no_mcp, relato
    assert [contagem] = na_api -- no_mcp, relato
    assert contagem =~ "SELECT count(*)", relato
  end

  test "e o custo não cresce com os membros, em nenhuma das duas portas", ctx do
    uma = equipe_com(ctx.tenant, 1)
    dez = equipe_com(ctx.tenant, 10)

    for {porta, medir} <- [api: &api/2, mcp: &mcp/2] do
      com_um = medir.(ctx, uma)
      assert linhas() == 1
      com_dez = medir.(ctx, dez)
      assert linhas() == 10

      assert length(com_dez) == length(com_um),
             "#{porta}: 1 membro #{length(com_um)}, 10 membros #{length(com_dez)}. " <>
               "Entrou: [#{diferenca(com_um, com_dez)}]"
    end
  end
end
