defmodule TheBandWeb.MCP.MetodosTest do
  @moduledoc """
  A lista fechada de métodos JSON-RPC — feature 062, T016, R2 e R4.

  Estes testes exercitam o plug sozinho, com o corpo já decodificado, como o `Plug.Parsers` o
  entrega. A mesma lista é conferida de novo pela rota `/mcp`, com token, quando ela existir
  (T007): lá se prova que o plug está **na** pipeline, e aqui se prova o que ele decide.

  **A guarda contra a recusa vazia** é a mesma em todos: os métodos permitidos **passam**, sem
  resposta enviada. Um plug que recusasse tudo passaria em todos os `refute`.
  """
  use ExUnit.Case, async: true

  import Plug.Test

  alias TheBandWeb.Plugs.McpMetodos

  defp post(corpo) do
    :post
    |> conn("/mcp", "")
    |> Map.put(:body_params, corpo)
    |> McpMetodos.call([])
  end

  defp erro(conn), do: conn.resp_body |> Jason.decode!() |> Map.fetch!("error")

  test "os quatro métodos permitidos passam, sem resposta enviada" do
    for metodo <- McpMetodos.permitidos() do
      conn = post(%{"jsonrpc" => "2.0", "id" => 1, "method" => metodo})

      refute conn.halted, "#{metodo} foi recusado, e é um dos quatro"
      assert conn.state == :unset
    end
  end

  test "subscriptions/listen é recusado, e não abre stream" do
    conn = post(%{"jsonrpc" => "2.0", "id" => 7, "method" => "subscriptions/listen"})

    assert conn.halted
    assert conn.status == 404

    refute Plug.Conn.get_resp_header(conn, "content-type")
           |> Enum.any?(&(&1 =~ "text/event-stream"))

    assert %{"code" => -32_601} = erro(conn)
    assert Jason.decode!(conn.resp_body)["id"] == 7
  end

  test "resources, prompts, logging e o aperto de mão antigo ficam de fora" do
    # `initialize`, `notifications/initialized` e `ping` não existem na revisão 2026-07-28, e a
    # primeira versão desta lista os deixava passar.
    for metodo <-
          ~w(resources/list resources/read prompts/list prompts/get logging/setLevel
             initialize notifications/initialized ping) do
      conn = post(%{"jsonrpc" => "2.0", "id" => 1, "method" => metodo})

      assert conn.halted, "#{metodo} chegou à biblioteca"
      assert %{"code" => -32_601} = erro(conn)
    end
  end

  test "tools/call que pede stream é recusado à vista, e não descartado em silêncio" do
    for chave <- ~w(progressToken io.modelcontextprotocol/logLevel) do
      conn =
        post(%{
          "jsonrpc" => "2.0",
          "id" => 3,
          "method" => "tools/call",
          "params" => %{"name" => "team_roster", "_meta" => %{chave => "x"}}
        })

      assert conn.halted, "o pedido de stream por #{chave} chegou à biblioteca"
      assert %{"code" => -32_602, "message" => mensagem} = erro(conn)
      assert mensagem =~ "not offered"
    end

    # A guarda: o mesmo tools/call, sem pedir stream, passa.
    refute post(%{
             "jsonrpc" => "2.0",
             "id" => 3,
             "method" => "tools/call",
             "params" => %{"name" => "team_roster", "_meta" => %{}}
           }).halted
  end

  test "lote e pedido sem método são inválidos" do
    assert %{"code" => -32_600} = post(%{"_json" => [%{"method" => "ping"}]}) |> erro()
    assert %{"code" => -32_600} = post(%{"jsonrpc" => "2.0", "id" => 1}) |> erro()
  end

  test "só olha POST: GET passa adiante, para o 405 do T007" do
    conn = :get |> conn("/mcp") |> McpMetodos.call([])
    refute conn.halted
  end
end
