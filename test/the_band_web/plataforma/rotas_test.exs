defmodule TheBandWeb.Plataforma.RotasTest do
  @moduledoc """
  A área do operador no roteador — spec 070, T036 (FR-009, FR-011; I4 de `seguranca.md`; C13 de
  `seguranca-totp.md`).
  """
  use TheBandWeb.ConnCase, async: true

  import TheBand.OperadorFixtures

  alias TheBandWeb.Plataforma.OperatorScope

  @rotas_de_operador [
    {:get, "/platform/organizations"},
    {:get, "/platform/organizations/qualquer"},
    {:post, "/platform/organizations/qualquer/suspension"},
    {:post, "/platform/organizations/qualquer/reactivation"},
    {:delete, "/platform/session"}
  ]

  for {metodo, caminho} <- @rotas_de_operador do
    @metodo metodo
    @caminho caminho

    test "#{metodo} #{caminho} anônimo dá 404, sem redirecionar", %{conn: conn} do
      conn = dispatch(conn, TheBandWeb.Endpoint, @metodo, @caminho, %{})
      assert conn.status == 404
      assert get_resp_header(conn, "location") == []
    end
  end

  test "um admin de organização com sessão válida recebe o mesmo 404 do anônimo", %{conn: conn} do
    {_tenant, admin} = tenant_with_admin()

    anonimo = get(build_conn(), ~p"/platform/organizations")
    como_admin = conn |> log_in(admin) |> get(~p"/platform/organizations")

    assert como_admin.status == 404
    assert get_resp_header(como_admin, "location") == []
    assert como_admin.assigns[:current_user] == nil
    assert sem_csrf(como_admin.resp_body) == sem_csrf(anonimo.resp_body)
  end

  test "nenhuma rota de /platform passa por CurrentScope" do
    rotas =
      for r <- TheBandWeb.Router.__routes__(), String.starts_with?(r.path, "/platform"), do: r

    # As do contrato, mais o curinga duas vezes (com e sem caminho).
    assert length(rotas) >= 13

    for rota <- rotas do
      metodo = if rota.verb == :*, do: "GET", else: rota.verb |> to_string() |> String.upcase()
      caminho = String.replace(rota.path, [":slug", "*caminho"], "x")

      %{pipe_through: pipes} = Phoenix.Router.route_info(TheBandWeb.Router, metodo, caminho, "")
      assert List.first(pipes) == :plataforma, rota.path
      refute :browser in pipes, rota.path
      refute :require_user in pipes, rota.path
    end
  end

  test "C13: o operador da sessão é atribuído sem o segredo TOTP, e o log leva só operator_id",
       %{conn: conn} do
    {op, _} = operador_pronto()

    conn =
      conn
      |> log_in_operador(op)
      |> Map.put(:secret_key_base, TheBandWeb.Endpoint.config(:secret_key_base))
      |> OperatorScope.call([])

    assert conn.assigns.current_operator.id == op.id
    assert conn.assigns.current_operator.totp_secret == nil
    assert conn.assigns.current_operator_session.operator_id == op.id
    refute Map.has_key?(conn.assigns, :current_user)
    refute Map.has_key?(conn.assigns, :current_tenant)

    metadados = Logger.metadata()
    assert metadados[:operator_id] == op.id
    refute Keyword.has_key?(metadados, :user_id)
    refute Keyword.has_key?(metadados, :tenant_id)
  end

  test "com o cookie do operador, require_operator deixa passar", %{conn: conn} do
    {op, _} = operador_pronto()

    conn =
      conn
      |> log_in_operador(op)
      |> Map.put(:secret_key_base, TheBandWeb.Endpoint.config(:secret_key_base))
      |> OperatorScope.call([])
      |> OperatorScope.require_operator([])

    refute conn.halted
  end

  defp sem_csrf(corpo), do: String.replace(corpo, ~r/name="csrf-token" content="[^"]*"/, "")
end
