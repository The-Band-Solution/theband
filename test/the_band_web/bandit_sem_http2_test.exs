defmodule TheBandWeb.BanditSemHttp2Test do
  @moduledoc """
  O servidor da aplicação não fala HTTP/2 — EEF-CVE-2026-105659 (HIGH, `bandit` 1.12.5, sem versão
  consertada em 2026-10-15). O defeito está no HTTP/2 do Bandit: o prazo de envio bloqueado se
  reinicia a cada WINDOW_UPDATE, e um cliente lento prende processos de stream sem fim.

  A mitigação é `http_2_options: [enabled: false]`, no endpoint (`config/config.exs`). Este teste
  não confere a linha da configuração, e sim **o comportamento**: sobe um Bandit com as opções de
  HTTP do endpoint, abre um socket e fala HTTP/2 com conhecimento prévio (o preâmbulo
  `PRI * HTTP/2.0` seguido de um quadro SETTINGS vazio). Com HTTP/2 ligado, o servidor responde
  com o próprio SETTINGS. Desligado, ele não responde como HTTP/2.

  É a guarda da exceção desta advisory na auditoria de dependências (`mix.exs`): se o HTTP/2
  voltar a ser ligado, a premissa da exceção cai, e este teste reprova.
  """
  use ExUnit.Case, async: true

  # O preâmbulo do cliente HTTP/2 (RFC 9113 §3.4) e um quadro SETTINGS vazio: comprimento 0,
  # tipo 0x4, sem flags, stream 0.
  @preambulo "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
  @settings_vazio <<0::24, 0x4, 0, 0::32>>

  defmodule Ok do
    @moduledoc false
    def init(opcoes), do: opcoes
    def call(conn, _opcoes), do: Plug.Conn.send_resp(conn, 200, "ok")
  end

  defp opcoes_http do
    Application.fetch_env!(:the_band, TheBandWeb.Endpoint) |> Keyword.fetch!(:http)
  end

  defp resposta_ao_preambulo(http_2_options) do
    {:ok, servidor} =
      Bandit.start_link(
        plug: Ok,
        ip: :loopback,
        port: 0,
        http_2_options: http_2_options,
        startup_log: false
      )

    {:ok, {_ip, porta}} = ThousandIsland.listener_info(servidor)
    {:ok, socket} = :gen_tcp.connect(~c"localhost", porta, [:binary, active: false])
    :ok = :gen_tcp.send(socket, @preambulo <> @settings_vazio)

    resposta =
      case :gen_tcp.recv(socket, 0, 2_000) do
        {:ok, bytes} -> bytes
        {:error, motivo} -> {:sem_resposta, motivo}
      end

    :gen_tcp.close(socket)
    Supervisor.stop(servidor)
    resposta
  end

  # Um quadro HTTP/2 de SETTINGS vindo do servidor: 9 bytes de cabeçalho, tipo 0x4 no quarto byte.
  defp settings_do_servidor?(<<_comprimento::24, 0x4, _resto::binary>>), do: true
  defp settings_do_servidor?(_), do: false

  test "a configuração do endpoint desliga o HTTP/2" do
    assert opcoes_http()[:http_2_options][:enabled] == false
  end

  test "falar HTTP/2 com o servidor configurado como o endpoint não recebe resposta HTTP/2" do
    resposta = resposta_ao_preambulo(opcoes_http()[:http_2_options])
    refute settings_do_servidor?(resposta), "o servidor respondeu como HTTP/2"
  end

  test "o controle: com o HTTP/2 ligado, o mesmo preâmbulo recebe o SETTINGS do servidor" do
    # Sem este controle, um teste que nunca recebesse resposta passaria pelo motivo errado.
    assert settings_do_servidor?(resposta_ao_preambulo(enabled: true))
  end
end
