defmodule TheBandWeb.Plataforma.CabecalhosTest do
  @moduledoc """
  Os cabeçalhos de toda resposta de `/platform` — spec 070, T038 (A8; cenário 8 de
  `seguranca-autenticacao.md`). A área do operador está na mesma origem do domínio, e é a CSP que
  impede um script dessa origem de usar o cookie do operador: `http_only` impede a leitura, não o
  uso.
  """
  use TheBandWeb.ConnCase, async: true

  import TheBand.OperadorFixtures

  defp rotas do
    for r <- TheBandWeb.Router.__routes__(), String.starts_with?(r.path, "/platform") do
      metodo = if r.verb == :*, do: :get, else: r.verb
      {metodo, String.replace(r.path, [":slug", "*caminho"], "x")}
    end
  end

  defp confere_cabecalhos(conn, rotulo) do
    [csp] = get_resp_header(conn, "content-security-policy")
    [script_src] = Regex.run(~r/script-src [^;]*/, csp)

    assert script_src == "script-src 'self'", rotulo

    # `style-src` leva `unsafe-inline`, concessão declarada do LiveView (`router.ex`); `script-src`, nunca.
    refute script_src =~ "unsafe-inline", rotulo
    assert csp =~ "frame-ancestors 'none'", rotulo
    assert get_resp_header(conn, "cache-control") == ["no-store"], rotulo
  end

  test "toda rota de /platform, anônima, responde com CSP estrita e no-store" do
    assert length(rotas()) >= 13

    for {metodo, caminho} <- rotas() do
      conn = dispatch(build_conn(), TheBandWeb.Endpoint, metodo, caminho, %{})
      confere_cabecalhos(conn, "#{metodo} #{caminho}")
    end
  end

  test "toda rota de /platform, com o operador, responde com CSP estrita e no-store" do
    {op, _} = operador_pronto()

    for {metodo, caminho} <- rotas() do
      conn =
        build_conn()
        |> log_in_operador(op)
        |> then(&dispatch(&1, TheBandWeb.Endpoint, metodo, caminho, %{}))

      confere_cabecalhos(conn, "#{metodo} #{caminho}")
    end
  end

  # A recusa de CSRF levanta, e a página de erro sai da conexão de antes da pipeline. Os cabeçalhos
  # vêm de `TheBandWeb.Plataforma.Borda`, no endpoint; sem ela, saíam sem CSP (medido em T038).
  test "o POST sem token de CSRF é recusado com 403, e com os cabeçalhos" do
    for caminho <- ["/platform/session", "/platform/organizations/x/suspension", "/platform/x"] do
      {403, cabecalhos, _corpo} =
        assert_error_sent(403, fn ->
          build_conn()
          |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
          |> post(caminho, %{})
        end)

      conn = %{build_conn() | resp_headers: cabecalhos}
      confere_cabecalhos(conn, "POST #{caminho} sem CSRF")
    end
  end
end
