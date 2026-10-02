defmodule TheBandWeb.CabecalhosDasPaginasDeErroTest do
  @moduledoc """
  As páginas de erro do domínio levam a CSP e os cabeçalhos de segurança — issue #1135.

  A recusa de CSRF levanta dentro da pipeline, e o caminho que não existe levanta no roteador. Nos
  dois casos o endpoint desenha a página a partir da conexão de antes da pipeline. Medido em
  2026-10-02: o 403 saía só com `content-type`, `cache-control` e `x-request-id`.
  """
  use TheBandWeb.ConnCase, async: true

  @csp "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " <>
         "img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:; " <>
         "base-uri 'self'; form-action 'self'; frame-ancestors 'none'"

  # Os cabeçalhos de segurança de uma página normal de `:browser`, com os valores. A página de erro
  # tem de levar os mesmos.
  defp de_uma_pagina_normal do
    conn = get(build_conn(), ~p"/sign-in")
    seguranca(conn.resp_headers)
  end

  defp seguranca(cabecalhos) do
    cabecalhos
    |> Enum.filter(fn {nome, _} ->
      nome in ~w(content-security-policy referrer-policy x-content-type-options
                 x-permitted-cross-domain-policies x-frame-options)
    end)
    |> Enum.sort()
  end

  defp confere(cabecalhos, rotulo) do
    esperados = de_uma_pagina_normal()
    assert {"content-security-policy", @csp} in esperados, "a medição não mediu"
    assert seguranca(cabecalhos) == esperados, rotulo
  end

  test "o 403 de CSRF numa rota de :browser" do
    {403, cabecalhos, _} =
      assert_error_sent(403, fn ->
        build_conn()
        |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
        |> post(~p"/session", %{"identifier" => "x", "password" => "y"})
      end)

    confere(cabecalhos, "POST /session sem CSRF")
  end

  test "o 404 de um caminho que não existe" do
    conn = get(build_conn(), "/nao-existe-mesmo")
    assert conn.status == 404
    confere(conn.resp_headers, "GET /nao-existe-mesmo")
  end

  test "a API e a MCP não ganham a CSP das telas, que é de HTML" do
    conn = get(build_conn(), "/api/v1/people")
    assert get_resp_header(conn, "content-security-policy") == []
  end
end
