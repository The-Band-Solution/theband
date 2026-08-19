defmodule TheBandWeb.ErrorHTMLTest do
  @moduledoc """
  O contrato mínimo das páginas de erro — issue #437.

  ## O que este arquivo era, e por que mudou

  Vinha do gerador do Phoenix e afirmava o texto plano: `"Not Found"` e
  `"Internal Server Error"`. A feature 040 trocou as páginas por conteúdo próprio, então as
  duas asserções passaram a descrever comportamento que a plataforma não tem mais.

  **E elas pegaram um defeito de verdade antes de serem atualizadas.** `render_to_string/4`
  chama a página **sem assigns** — sem `conn`. O código acessava `@conn.request_path`
  direto e levantava `KeyError`: a página de erro dava erro, que é exatamente o que o
  `@moduledoc` dela promete não fazer.

  Por isso este arquivo continua chamando **sem assigns**: é a única forma de garantir que a
  página sobrevive ao caso em que o endpoint não passou nada. As asserções de conteúdo ficam
  em `TheBandWeb.PaginasDeErroTest`.
  """
  use TheBandWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  alias TheBandWeb.ErrorHTML

  test "o 404 renderiza sem assigns, e não cita caminho que não recebeu" do
    html = render_to_string(ErrorHTML, "404", "html", [])

    assert html =~ "Nothing plays at this address"
    # Sem `conn` não há caminho: a página diz "this address" em vez de inventar um.
    assert html =~ "this address"
  end

  test "o 403 renderiza sem assigns" do
    html = render_to_string(ErrorHTML, "403", "html", [])

    assert html =~ "The stage door is closed"
  end

  test "o 500 renderiza sem assigns, e não inventa identificador" do
    html = render_to_string(ErrorHTML, "500", "html", [])

    assert html =~ "A string broke mid-song"
    # Sem `conn` não há `x-request-id`. Inventar um faria alguém procurar no log um
    # identificador que nunca existiu.
    refute html =~ "whoever investigates"
  end

  test "código sem página própria continua caindo no nome do status" do
    assert render_to_string(ErrorHTML, "502", "html", []) =~ "Bad Gateway"
  end
end
