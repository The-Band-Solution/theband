defmodule TheBandWeb.Api.CaminhoInexistenteTest do
  @moduledoc """
  O caminho que não existe sob `/api/v1` responde no formato único — issue #943, FR-020.

  Medido na v0.9.1: `GET /api/v1/nao-existe` → `404 text/html`, a página do site. O controle é o
  `content-type` e o `error.code`, e não uma palavra no corpo: o corpo HTML do site também
  poderia conter "not found".
  """
  use TheBandWeb.ConnCase, async: true

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "943"}, admin)
    %{conn: conn, com_token: put_req_header(conn, "authorization", "Bearer " <> valor)}
  end

  defp erro(conn, status) do
    assert conn.status == status
    assert [tipo | _] = get_resp_header(conn, "content-type")
    assert tipo =~ "application/json", "veio #{tipo}: é a página do site, e não a API"
    Jason.decode!(conn.resp_body)["error"]
  end

  for {metodo, caminho} <- [
        {:get, "/api/v1/nao-existe"},
        {:post, "/api/v1/nao-existe"},
        {:get, "/api/v1/teams/1/nao-existe"},
        {:get, "/api/v1"}
      ] do
    test "#{metodo} #{caminho}, com token: 404 no formato único", ctx do
      conn = dispatch(ctx.com_token, @endpoint, unquote(metodo), unquote(caminho), nil)

      e = erro(conn, 404)

      assert e["code"] == "not_found"
      assert is_binary(e["request_id"]) and e["request_id"] != ""
    end
  end

  test "sem token, o caminho inexistente dá 401, como qualquer outro", %{conn: conn} do
    e = erro(get(conn, "/api/v1/nao-existe"), 401)
    assert e["code"] == "unauthorized"
  end

  test "as rotas que existem continuam as mesmas: GET 200, POST 405", ctx do
    assert ctx.com_token |> get("/api/v1/teams") |> Map.get(:status) == 200
    assert erro(post(ctx.com_token, "/api/v1/teams"), 405)["code"] == "method_not_allowed"
  end

  test "o curinga não aparece na descrição OpenAPI", %{conn: conn} do
    caminhos =
      conn |> get("/api/openapi") |> json_response(200) |> Map.fetch!("paths") |> Map.keys()

    refute Enum.any?(caminhos, &String.contains?(&1, "caminho")), inspect(caminhos)
    refute "/api/v1" in caminhos
    refute "/api/v1/" in caminhos
    assert "/api/v1/teams" in caminhos
  end
end
