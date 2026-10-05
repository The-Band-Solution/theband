defmodule TheBandWeb.Origem do
  @moduledoc """
  A origem de uma requisição — spec 077, contrato §3 (FR-005, FR-006).

  Depende de: nenhuma ontologia.

  ## Nunca o lado do cabeçalho que o cliente escreve (seguranca.md, L4)

  `Plug.RewriteOn` com `:x_forwarded_for` lê o valor mais à **esquerda**, e não confere quem
  mandou (`deps/plug/lib/plug/rewrite_on.ex:133-137`): com um proxy que acrescenta, é o valor que
  o cliente escreveu, e quem ataca escolheria a própria origem. Aqui, em `:proxy`:

  1. o cabeçalho só é lido se o **socket** pertence à lista de proxies;
  2. as linhas do cabeçalho são juntadas **na ordem** e separadas por vírgula;
  3. a origem é o valor **mais à direita que não é proxy confiável** — o que o último proxy
     confiável viu; com um salto, o último valor;
  4. valor que não é endereço estrito, ou cabeçalho vazio, faz valer o socket.

  Nenhum outro cabeçalho (`Forwarded`, `X-Real-IP`, `CF-Connecting-IP`) é lido.
  """

  alias TheBand.Origem

  @doc "A origem da requisição, no estado da configuração (`config :the_band, :origem`)."
  @spec de(Plug.Conn.t()) :: Origem.t()
  def de(%Plug.Conn{} = conn) do
    case Application.get_env(:the_band, :origem, %{estado: :nao_declarada}) do
      %{estado: :proxy, cabecalho: cabecalho, proxies: proxies} ->
        Origem.de_endereco(pelo_proxy(conn, cabecalho, proxies), :proxy)

      %{estado: estado} when estado in [:socket, :nao_declarada] ->
        Origem.de_endereco(conn.remote_ip, estado)
    end
  end

  defp pelo_proxy(conn, cabecalho, proxies) do
    if confiavel?(conn.remote_ip, proxies),
      do: mais_a_direita(conn, cabecalho, proxies),
      else: conn.remote_ip
  end

  defp mais_a_direita(conn, cabecalho, proxies) do
    valores =
      conn
      |> Plug.Conn.get_req_header(cabecalho)
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.reverse()

    Enum.reduce_while(valores, conn.remote_ip, fn valor, _ ->
      case Origem.analisar_estrito(valor) do
        {:ok, ip} -> if confiavel?(ip, proxies), do: {:cont, conn.remote_ip}, else: {:halt, ip}
        :error -> {:halt, conn.remote_ip}
      end
    end)
  end

  defp confiavel?(ip, proxies), do: Enum.any?(proxies, &Origem.pertence?(ip, &1))
end
