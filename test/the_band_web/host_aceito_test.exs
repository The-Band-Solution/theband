defmodule TheBandWeb.HostAceitoTest do
  @moduledoc """
  O host da conexão fica na lista aceita — EEF-CVE-2026-105660 (MEDIUM, `bandit` 1.12.5): um
  pedido HTTP/1 em forma absoluta (`GET http://outro/x HTTP/1.1`) deixa o cliente escolher
  `conn.host`. É a guarda da exceção desta advisory na auditoria (`mix.exs`).

  Três camadas, cada uma vista reprovando com o defeito injetado:

  1. o plug `TheBandWeb.Plugs.HostAceito` recusa host fora da lista e deixa passar o aceito;
  2. o **endpoint inteiro**, servido por um Bandit de verdade, recusa o pedido em forma absoluta
     com outro host, mesmo com o cabeçalho `Host` certo. É o caminho exato da advisory;
  3. o `force_ssl` de produção tem o host fixo, porque roda antes do plug.
  """
  use ExUnit.Case, async: false
  import Plug.Test

  alias TheBandWeb.Origens
  alias TheBandWeb.Plugs.HostAceito

  describe "o plug" do
    test "host fora da lista: 400, e nada mais roda" do
      conn = conn(:get, "http://evil.example/version") |> HostAceito.call([])
      assert conn.halted
      assert conn.status == 400
    end

    test "o controle: host da lista passa intacto" do
      conn = conn(:get, "http://localhost/version") |> HostAceito.call([])
      refute conn.halted
      assert conn.status == nil
    end
  end

  describe "o endpoint, por um Bandit de verdade" do
    defp responder(pedido) do
      {:ok, servidor} =
        Bandit.start_link(plug: TheBandWeb.Endpoint, ip: :loopback, port: 0, startup_log: false)

      {:ok, {_ip, porta}} = ThousandIsland.listener_info(servidor)
      {:ok, socket} = :gen_tcp.connect(~c"localhost", porta, [:binary, active: false])
      :ok = :gen_tcp.send(socket, pedido)
      {:ok, resposta} = :gen_tcp.recv(socket, 0, 5_000)
      :gen_tcp.close(socket)
      Supervisor.stop(servidor)
      resposta
    end

    test "o pedido em forma absoluta com outro host é recusado, mesmo com o Host certo" do
      resposta =
        responder("GET http://evil.example/version HTTP/1.1\r\nHost: localhost\r\n\r\n")

      assert resposta =~ ~r/^HTTP\/1\.1 400/
    end

    test "o controle: o mesmo pedido em forma de origem é servido" do
      resposta = responder("GET /version HTTP/1.1\r\nHost: localhost\r\n\r\n")
      assert resposta =~ ~r/^HTTP\/1\.1 200/
    end
  end

  test "o force_ssl de produção redireciona para o host configurado, e não para o da conexão" do
    prod = Config.Reader.read!("config/prod.exs", env: :prod)
    force_ssl = prod[:the_band][TheBandWeb.Endpoint][:force_ssl]

    assert force_ssl[:host] == {TheBandWeb.Endpoint, :host, []}
  end

  describe "Origens.hosts/2, da mesma fonte do check_origin" do
    test "o principal e os extras, sem esquema nem porta" do
      assert Origens.hosts("app.theband.dev", "https://x.theband.dev:8443, y.theband.dev") ==
               ["app.theband.dev", "x.theband.dev", "y.theband.dev"]
    end

    test "sem extras, só o principal: a ausência restringe" do
      assert Origens.hosts("app.theband.dev", nil) == ["app.theband.dev"]
    end
  end
end
