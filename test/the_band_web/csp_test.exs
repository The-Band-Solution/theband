defmodule TheBandWeb.CspTest do
  @moduledoc """
  A CSP das telas de domínio é byte a byte a de antes de virar atributo de módulo — spec 070,
  T017 (A8). A área do operador vai usar a mesma, e a extração não pode mudar o valor.
  """
  use TheBandWeb.ConnCase, async: true

  # O valor literal de `router.ex` antes da extração, copiado à mão de propósito: se o atributo
  # mudar, este teste reprova, em vez de comparar o atributo com ele mesmo.
  @antes "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " <>
           "img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:; " <>
           "base-uri 'self'; form-action 'self'; frame-ancestors 'none'"

  test "o cabeçalho content-security-policy de /sign-in é o de antes", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")
    assert get_resp_header(conn, "content-security-policy") == [@antes]
  end
end
