defmodule TheBandWeb.SegredoForaDoLogDoJoinTest do
  @moduledoc """
  A guarda do achado A1 da avaliação de 2026-10-27
  (`docs/seguranca/2026-10-27-avisos-bandit-jose-plug-crypto-ex-mcp.md`), issue #1439.

  `plug_crypto` 2.2.0 (EEF-CVE-2026-105963): argumento de tipo errado em `Plug.Crypto.verify/4`
  vira `FunctionClauseError` com os argumentos reais no frame, e o primeiro argumento é o
  `secret_key_base`. Aqui o caminho é anônimo: qualquer cliente abre o socket do LiveView e manda
  `phx_join` com `"session"` que não é texto, e o canal repassa o valor sem checar o tipo.

  O teste fala com o canal do LiveView do mesmo jeito que o socket falaria, captura o log do
  processo que morre e exige que a chave não esteja nele. A chave é a de `config/test.exs`,
  pública por desenho.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.ChannelTest

  @endpoint TheBandWeb.Endpoint

  # Lista e mapa: o JSON entrega os dois, e a guarda da cabeça só aceita texto.
  @sessoes_de_tipo_errado [["x"], %{"x" => "y"}]

  for sessao <- @sessoes_de_tipo_errado do
    test "phx_join com session #{inspect(sessao)} não escreve o secret_key_base no log" do
      segredo = @endpoint.config(:secret_key_base)
      assert is_binary(segredo) and byte_size(segredo) >= 64

      log =
        capture_log(fn ->
          Process.flag(:trap_exit, true)
          socket = socket(Phoenix.LiveView.Socket, nil, %{})

          resultado =
            subscribe_and_join(socket, Phoenix.LiveView.Channel, "lv:segredo", %{
              "session" => unquote(Macro.escape(sessao)),
              "static" => nil,
              "url" => "http://localhost:4002/"
            })

          send(self(), {:resultado_do_join, resultado})

          # O canal morre fora do processo do teste; o log só existe depois que ele termina.
          Process.sleep(50)
        end)

      # A guarda do cenário: o join tem de ter chegado à verificação do token e sido recusado.
      # Com o defeito, o canal morre (e o log traz a chave); consertado, a recusa é limpa e não
      # loga nada. Um join aceito diria que o pedido nunca chegou ao `Plug.Crypto`.
      assert_received {:resultado_do_join, resultado}
      refute match?({:ok, _, _}, resultado), "o join foi aceito: o teste não mediu nada"

      refute log =~ segredo, """
      O secret_key_base apareceu no log de um phx_join anônimo com session de tipo errado.
      Com ele se forjam cookie de sessão e tokens do LiveView. O `plug_crypto` instalado é o
      #{Application.spec(:plug_crypto, :vsn)}; o conserto é o 2.2.1 (EEF-CVE-2026-105963).
      """
    end
  end
end
