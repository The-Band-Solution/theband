defmodule TheBandWeb.OrigensRecusaTest do
  @moduledoc """
  Feature 054, FR-008 — a recusa de origem é registrada nomeando quem tentou.

  **Este teste não prova código nosso, e é de propósito.** O registro da recusa
  já vem do `Phoenix.Socket.Transport`, e escrever o nosso por cima seria padrão
  sem problema — o antipadrão que o princípio VIII descreve (decisão 3 do
  `plan.md`).

  O que ele faz é transformar uma dependência tácita em dependência provada: o
  FR-008 está atendido por comportamento de biblioteca, e este é o teste que
  avisa no dia em que a biblioteca deixar de nomear a origem. Sem ele, a recusa
  viraria a mesma coisa que a feature existe para evitar — algo acontecendo sem
  que ninguém veja.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Phoenix.Socket.Transport
  alias Plug.Conn
  alias Plug.Test, as: PlugTest

  @aceitas ["https://theband.dev", "https://theband.5.189.161.85.sslip.io"]

  defp tentar(origem) do
    :get
    |> PlugTest.conn("/live/websocket")
    |> Conn.put_req_header("origin", origem)
    |> Transport.check_origin(
      __MODULE__,
      TheBandWeb.Endpoint,
      check_origin: @aceitas
    )
  end

  describe "origem fora da lista" do
    test "é recusada com 403 e o registro NOMEIA a origem" do
      origem = "https://origem-que-ninguem-declarou.example"

      registro =
        capture_log(fn ->
          conn = tentar(origem)

          assert conn.halted, "a conexão deveria ter sido interrompida"
          assert conn.status == 403
        end)

      # A asserção que vale é esta: não basta recusar, tem que dizer QUEM.
      # Removê-la faz o teste passar com um 403 mudo, que é metade do FR-008.
      assert registro =~ origem
    end
  end

  describe "origem declarada" do
    for origem <- @aceitas do
      test "#{origem} passa sem interromper" do
        conn = tentar(unquote(origem))

        refute conn.halted
        assert conn.status == nil
      end
    end
  end

  describe "a limitação que o contrato declara" do
    test "requisição SEM cabeçalho de origem não é checada" do
      # Verificado em research.md R3: a primeira cláusula do transporte devolve
      # a conexão intacta quando não há origem. Está aqui para que ninguém leia
      # os testes acima e conclua "só quem está na lista conecta" — é falso, e
      # contra cliente programático a defesa é a sessão, não a origem.
      conn =
        :get
        |> PlugTest.conn("/live/websocket")
        |> Transport.check_origin(
          __MODULE__,
          TheBandWeb.Endpoint,
          check_origin: @aceitas
        )

      refute conn.halted
    end
  end
end
