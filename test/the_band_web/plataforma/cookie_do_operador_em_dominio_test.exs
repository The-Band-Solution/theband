defmodule TheBandWeb.Plataforma.CookieDoOperadorEmDominioTest do
  @moduledoc """
  O cookie do operador não abre domínio — spec 070, T042 (US2, cenário 4; SC-003).

  `put_req_cookie` ignora o `Path=/platform` do cookie, e é o pior caso: o navegador não o mandaria
  para fora de `/platform`, mas quem o copiou manda. Nas três portas (tela, API e MCP), a resposta é
  a de quem não tem sessão, e nenhuma consulta toca uma tabela `platform_*`.
  """
  use TheBandWeb.ConnCase, async: true

  import TheBand.OperadorFixtures

  defp capturar(fun) do
    ref = make_ref()
    eu = self()
    id = {__MODULE__, ref}

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ -> if self() == eu, do: send(eu, {ref, sql}) end,
      nil
    )

    resultado = fun.()
    :telemetry.detach(id)
    {resultado, coletar(ref, [])}
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, sql} -> coletar(ref, [sql | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  setup %{conn: conn} do
    {op, _} = operador_pronto()
    b = tenant_fixture()
    equipe = team_fixture(b, "T_#{System.unique_integer([:positive])}")
    %{conn: log_in_operador(conn, op), equipe: equipe}
  end

  test "GET /people e GET /teams/:id de B: o redirecionamento a /sign-in", %{
    conn: conn,
    equipe: equipe
  } do
    for caminho <- [~p"/people", ~p"/teams/#{equipe.id}"] do
      {resposta, consultas} = capturar(fn -> get(conn, caminho) end)

      assert redirected_to(resposta) == ~p"/sign-in", caminho
      assert Enum.filter(consultas, &(&1 =~ ~s("platform_))) == [], caminho
    end
  end

  test "GET /api/v1/people e POST /mcp: 401", %{conn: conn} do
    for {metodo, caminho} <- [{:get, "/api/v1/people"}, {:post, "/mcp"}] do
      {resposta, consultas} =
        capturar(fn ->
          conn
          |> put_req_header("accept", "application/json")
          |> put_req_header("content-type", "application/json")
          |> dispatch(TheBandWeb.Endpoint, metodo, caminho, "{}")
        end)

      assert resposta.status == 401, caminho
      assert Enum.filter(consultas, &(&1 =~ ~s("platform_))) == [], caminho
    end
  end
end
