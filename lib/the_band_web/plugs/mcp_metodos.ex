defmodule TheBandWeb.Plugs.McpMetodos do
  @moduledoc """
  A lista fechada de métodos JSON-RPC que chegam à biblioteca do protocolo — feature 062, T016,
  achados R2 e R4 da revisão independente.

  É a FR-023 aplicada ao **protocolo**, e não só às ferramentas. Só quatro métodos passam:

  | Método | Por quê |
  |---|---|
  | `server/discover` | a descoberta do servidor na revisão 2026-07-28, que substitui o `initialize` |
  | `tools/list` | a lista fechada das quatro ferramentas |
  | `tools/call` | chamar uma delas |
  | `notifications/cancelled` | o cliente desistir de uma chamada em curso |

  **Corrigido em 2026-09-25, no T021.** A primeira lista trazia `initialize`,
  `notifications/initialized` e `ping`, que **não** existem na revisão 2026-07-28: a tabela
  `@modern_methods` da `ex_mcp` 1.5.0 (`protocol/methods.ex:29`) não os tem, e a biblioteca os
  recusava com `404` depois do plug. E a lista **recusava `server/discover`**, que é como um
  cliente moderno descobre o servidor: nenhum cliente real conseguiria começar. A lista agora é
  o que o modo moderno usa, e é também menor.

  ## O que fica de fora, e por quê

  - **`subscriptions/listen`**, que a `ex_mcp` liga por padrão. O stream dura até uma hora,
    conta uma vez no limite do token, não tem teto de concorrência e **continua aberto depois
    da revogação**. Tudo o mais (`resources/*`, `prompts/*`, `logging/*`) não tem uso nesta
    fatia, e método sem uso é superfície sem dono;
  - **o pedido de stream num `tools/call`** (`_meta.progressToken` ou
    `io.modelcontextprotocol/logLevel`). A biblioteca abriria `text/event-stream`, e o registro
    de leitura gravaria a abertura **antes** de existir veredito (R2). Recusado à vista, com
    erro de parâmetro, e não descartado em silêncio: tirar o campo mudaria o pedido do cliente
    sem avisar;
  - **o lote** (um array JSON). A biblioteca também o recusa, e aqui ele não chega a ela.

  ## A forma da recusa

  A mesma da `ex_mcp` para método inexistente: HTTP `404` e o erro JSON-RPC `-32601`, com o
  `id` do pedido. Um cliente MCP trata as duas do mesmo jeito, e não precisa saber qual camada
  recusou.

  Só olha `POST`. `GET` e `DELETE` em `/mcp` são outro assunto, e recebem `405` no T007.
  """

  import Plug.Conn

  @behaviour Plug

  @permitidos ~w(server/discover tools/list tools/call notifications/cancelled)
  @chaves_de_stream ~w(progressToken io.modelcontextprotocol/logLevel)

  @doc "Os quatro métodos que chegam à biblioteca."
  @spec permitidos() :: [String.t()]
  def permitidos, do: @permitidos

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "POST"} = conn, _opts), do: avaliar(conn, conn.body_params)
  def call(conn, _opts), do: conn

  defp avaliar(conn, %{"_json" => lista}) when is_list(lista),
    do: recusar(conn, 400, nil, -32_600, "Batch requests are not accepted")

  defp avaliar(conn, %{"method" => metodo} = pedido) when metodo in @permitidos do
    if pede_stream?(pedido) do
      recusar(
        conn,
        400,
        pedido["id"],
        -32_602,
        "Streaming responses are not offered: remove _meta.progressToken and " <>
          "_meta.io.modelcontextprotocol/logLevel"
      )
    else
      conn
    end
  end

  defp avaliar(conn, %{"method" => metodo} = pedido) when is_binary(metodo),
    do: recusar(conn, 404, pedido["id"], -32_601, "Method not found")

  defp avaliar(conn, pedido),
    do: recusar(conn, 400, pedido["id"], -32_600, "Invalid Request: method is required")

  defp pede_stream?(%{"params" => %{"_meta" => meta}}) when is_map(meta),
    do: Enum.any?(@chaves_de_stream, &Map.has_key?(meta, &1))

  defp pede_stream?(_pedido), do: false

  defp recusar(conn, status, id, codigo, mensagem) do
    corpo = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{"code" => codigo, "message" => mensagem}
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(corpo))
    |> halt()
  end
end
