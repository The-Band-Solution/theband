defmodule TheBandWeb.Plataforma.Borda do
  @moduledoc """
  Os cabeçalhos de `/platform` na borda do endpoint — spec 070, T038 (A8).

  Depende de: nenhuma ontologia.

  A pipeline `:plataforma` já põe a CSP e o `no-store`. Este plug os põe **antes do roteador**,
  porque a recusa de CSRF de `protect_from_forgery` levanta, e o endpoint desenha o `403` a partir da
  conexão de quando ela entrou no roteador. Medido em T038: sem este plug, a página saía só com
  `content-type`, `cache-control` padrão e `x-request-id`, sem CSP e sem `no-store`.

  O valor da CSP é o de `TheBandWeb.Router.csp/0`, o mesmo de `:browser`: uma cópia aqui divergiria
  no dia em que alguém apertasse uma e esquecesse a outra.
  """
  @behaviour Plug

  alias TheBandWeb.Plataforma.OperatorScope

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: ["platform" | _]} = conn, _opts) do
    conn
    |> Phoenix.Controller.put_secure_browser_headers(%{
      "content-security-policy" => TheBandWeb.Router.csp()
    })
    |> OperatorScope.no_store([])
  end

  def call(conn, _opts), do: conn
end
