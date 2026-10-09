defmodule TheBandWeb.SaudeController do
  @moduledoc """
  `GET /health` — a fila anda? Issue #801, contrato em `docs/producao/saude-da-fila.md`.

  **Sem autenticação**, como `/version`: quem pergunta é quem opera, ou um monitor, antes de
  haver sessão. **E não diz mais do que o estado**: sem minutos, contagem, fila ou worker. Cada
  campo a mais seria superfície nova numa rota sem sessão, e o detalhe está no `/syncs` e no
  log. Texto puro, pelo mesmo motivo do `/version`: quem consome compara uma palavra.

  As palavras são de tela, em inglês.
  """
  use TheBandWeb, :controller

  alias TheBand.Saude

  def show(conn, _params) do
    case Saude.fila() do
      :ok ->
        conn |> put_resp_content_type("text/plain") |> send_resp(200, "ok")

      {:parada, _minutos} ->
        conn |> put_resp_content_type("text/plain") |> send_resp(503, "queue stalled")
    end
  end
end
