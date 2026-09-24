defmodule TheBandWeb.Api.OrganizacaoSuspensaTest do
  @moduledoc """
  **Achado N5, 2026-09-24 — o token de organização suspensa continuava autenticando.**

  O H3 (2026-09-09) fez as três portas de sessão lerem `tenant.status`. A porta do token, que
  nasceu depois, na 061, conferia a conta dona e não conferia a organização. Medido pelo papel
  Security: `200` antes de suspender, e o **mesmo** token seguia com `200` depois.

  ## As três afirmações deste arquivo

  - **suspensa, recusa** — com a guarda de que o mesmo token respondia antes;
  - **o corpo é o mesmo das outras recusas** (SC-003), e o motivo próprio vai ao log (SC-004);
  - **reativada, volta a responder** — prova que o estado é lido a cada chamada, sem cache.
    Sem isto, um conserto que recusasse para sempre depois de um erro também passaria.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Repo
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "n5"}, admin)

    c = fn valor ->
      conn
      |> recycle()
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")
    end

    %{tenant: tenant, valor: valor, c: c}
  end

  defp mudar_status(tenant, status) do
    {:ok, t} = tenant |> Tenants.Tenant.changeset(%{"status" => status}) |> Repo.update()
    # A GUARDA DO CENÁRIO: um `status` que não gravou faria o teste passar pelo motivo errado.
    assert t.status == status
    t
  end

  defp sem_request_id(corpo),
    do: String.replace(corpo, ~r/"request_id":"[^"]+"/, ~s("request_id":"X"))

  test "o token de organização suspensa é recusado, e volta a valer ao reativar", ctx do
    assert ctx.c.(ctx.valor) |> get(~p"/api/v1/teams") |> Map.fetch!(:status) == 200, """
    O token não respondia nem ANTES da suspensão — o `401` abaixo não provaria nada.
    """

    tenant = mudar_status(ctx.tenant, "suspended")

    {conn, log} = with_log(fn -> ctx.c.(ctx.valor) |> get(~p"/api/v1/teams") end)

    assert conn.status == 401, """
    Organização suspensa, e o token dela respondeu #{conn.status}. É o achado N5: a porta do
    token não lia `tenant.status`, enquanto as três portas de sessão liam.
    """

    assert log =~ "motivo=organizacao_suspensa"

    inexistente = "tb_api_deadbeefcafe_" <> String.duplicate("x", 43)
    outro = ctx.c.(inexistente) |> get(~p"/api/v1/teams")

    assert sem_request_id(conn.resp_body) == sem_request_id(outro.resp_body), """
    A recusa por organização suspensa tem corpo diferente da recusa por token inexistente.
    Distinguir confirmaria, a quem tem o token, que ele é válido e a organização existe.
    """

    mudar_status(tenant, "active")

    assert ctx.c.(ctx.valor) |> get(~p"/api/v1/teams") |> Map.fetch!(:status) == 200, """
    Reativada, e o token continua recusado. O estado precisa ser lido a cada chamada.
    """
  end
end
