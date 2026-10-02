defmodule TheBandWeb.Plugs.Borda do
  @moduledoc """
  Os cabeçalhos de segurança na borda do endpoint, antes do roteador — spec 070, T038 (A8), e
  issue #1135.

  Depende de: nenhuma ontologia.

  As pipelines `:browser` e `:plataforma` já põem a CSP e os demais cabeçalhos. Este plug os põe
  **antes do roteador** porque há páginas que nascem de exceção:

  - a recusa de CSRF de `protect_from_forgery`, que levanta dentro da pipeline;
  - o caminho que não existe, que levanta no próprio roteador.

  Nos dois casos o endpoint desenha a página a partir da conexão de quando ela entrou no roteador.
  Medido em 2026-10-02: a página saía só com `content-type`, `cache-control` padrão e
  `x-request-id`, sem CSP.

  - `/platform` leva também `Cache-Control: no-store`, como a pipeline dele;
  - `/api` e `/mcp` ficam de fora: respondem JSON, e a interface do Swagger, sob `/api`, tem a CSP
    própria, com nonce (`router.ex`).

  O valor da CSP é o de `TheBandWeb.Router.csp/0`, o mesmo das pipelines. Uma cópia aqui
  divergiria no dia em que alguém apertasse uma e esquecesse a outra.
  """
  @behaviour Plug

  alias TheBandWeb.Plataforma.OperatorScope

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: ["platform" | _]} = conn, _opts),
    do: conn |> cabecalhos() |> OperatorScope.no_store([])

  def call(%Plug.Conn{path_info: [primeiro | _]} = conn, _opts) when primeiro in ["api", "mcp"],
    do: conn

  def call(conn, _opts), do: cabecalhos(conn)

  defp cabecalhos(conn),
    do:
      Phoenix.Controller.put_secure_browser_headers(conn, %{
        "content-security-policy" => TheBandWeb.Router.csp()
      })
end
