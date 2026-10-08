defmodule TheBandWeb.OrigemTest do
  @moduledoc """
  A origem da requisição — spec 077, T005 (FR-005, FR-006; seguranca.md, L2, L4, L12; Q9–Q12,
  Q15, Q16). Só endereços de documentação.

  Síncrono: troca `config :the_band, :origem`, que é global.
  """
  use ExUnit.Case, async: false

  import Plug.Test, only: [conn: 2]

  alias TheBand.Origem.Configuracao
  alias TheBandWeb.Origem

  @proxy {10, 0, 1, 5}
  @cliente "198.51.100.9"
  @forjado "203.0.113.7"

  setup do
    antes = Application.get_env(:the_band, :origem)
    on_exit(fn -> Application.put_env(:the_band, :origem, antes) end)
    :ok
  end

  defp configurar(%{} = config), do: Application.put_env(:the_band, :origem, config)

  defp proxy_confiavel,
    do:
      configurar(
        Configuracao.ler!(%{
          "THE_BAND_ORIGEM" => "proxy",
          "THE_BAND_ORIGEM_CABECALHO" => "x-forwarded-for",
          "THE_BAND_ORIGEM_PROXIES" => "10.0.1.0/24"
        })
      )

  defp requisicao(socket, cabecalhos) do
    Enum.reduce(cabecalhos, %{conn(:post, "/session") | remote_ip: socket}, fn {k, v}, c ->
      %{c | req_headers: c.req_headers ++ [{k, v}]}
    end)
  end

  defp origem(socket, cabecalhos \\ []), do: Origem.de(requisicao(socket, cabecalhos)).chave

  test "Q9 — socket declarado: X-Forwarded-For é ignorado" do
    configurar(%{estado: :socket})
    assert origem({192, 0, 2, 44}, [{"x-forwarded-for", @cliente}]) == "192.0.2.44"
  end

  test "não declarado: conta pelo socket, e o estado vai na origem" do
    configurar(%{estado: :nao_declarada})
    o = Origem.de(requisicao(@proxy, [{"x-forwarded-for", @cliente}]))
    assert o.chave == "10.0.1.5"
    assert o.estado == :nao_declarada
  end

  test "Q10 — proxy ligado, socket fora da lista: o cabeçalho é ignorado" do
    proxy_confiavel()
    assert origem({192, 0, 2, 44}, [{"x-forwarded-for", @cliente}]) == "192.0.2.44"
  end

  test "Q11 — o mais à direita: o valor forjado à esquerda não muda a origem" do
    proxy_confiavel()
    assert origem(@proxy, [{"x-forwarded-for", "#{@forjado}, #{@cliente}"}]) == @cliente
  end

  test "Q11 — duas linhas do cabeçalho são juntadas na ordem" do
    proxy_confiavel()

    assert origem(@proxy, [{"x-forwarded-for", @forjado}, {"x-forwarded-for", @cliente}]) ==
             @cliente
  end

  test "o mais à direita que NÃO é proxy confiável: pula os proxies da lista" do
    proxy_confiavel()
    assert origem(@proxy, [{"x-forwarded-for", "#{@forjado}, #{@cliente}, 10.0.1.9"}]) == @cliente
  end

  test "Q12 — socket IPv4 mapeado em IPv6 casa a lista IPv4, e o cabeçalho é lido" do
    proxy_confiavel()
    mapeado = {0, 0, 0, 0, 0, 0xFFFF, 0x0A00, 0x0105}
    assert origem(mapeado, [{"x-forwarded-for", @cliente}]) == @cliente
  end

  test "Q15 — valor que não é endereço estrito, ou cabeçalho vazio, faz valer o socket" do
    proxy_confiavel()

    for valor <- ["", "#{@cliente},", "127.1", "fe80::1%eth0", "[2001:db8::1]:443"] do
      assert origem(@proxy, [{"x-forwarded-for", valor}]) == "10.0.1.5", inspect(valor)
    end

    assert origem(@proxy) == "10.0.1.5"
  end

  test "Q16 — nenhum outro cabeçalho é lido" do
    proxy_confiavel()

    for nome <- ["forwarded", "x-real-ip", "cf-connecting-ip", "true-client-ip"] do
      valor = if nome == "forwarded", do: "for=#{@cliente}", else: @cliente
      assert origem(@proxy, [{nome, valor}]) == "10.0.1.5", nome
    end
  end
end
