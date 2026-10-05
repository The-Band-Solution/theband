defmodule TheBand.Origem do
  @moduledoc """
  A origem de uma tentativa, normalizada — spec 077, contrato `contracts/limite-por-origem.md` §1.

  Depende de: nenhuma ontologia. Não conhece `Plug.Conn`: quem lê a conexão é
  `TheBandWeb.Origem`.

  ## A normalização vem antes de tudo (seguranca.md, L2)

  O Bandit escuta em `::` (`config/runtime.exs`), e um cliente IPv4 chega **mapeado** em IPv6
  (`::ffff:a.b.c.d`). Aplicada a regra do `/64` a esse formato, todo IPv4 da internet viraria uma
  origem só; e uma lista de proxies em IPv4 nunca casaria o socket. Por isso o desmapeamento é o
  primeiro passo, antes da lista e antes do prefixo.

  ## A chave conta; o prefixo é a única forma que vai para o log (L10)

  O IPv4 conta inteiro, o IPv6 pelo `/64` (uma pessoa controla o `/64` inteiro). O endereço é dado
  pessoal: no log vai só o prefixo truncado, `/24` ou `/48`. A struct **não** guarda o endereço
  inteiro em campo nenhum, para que não haja o que logar por engano.
  """

  import Bitwise

  @enforce_keys [:chave, :estado, :prefixo]
  defstruct [:chave, :estado, :prefixo]

  @type estado :: :socket | :proxy | :nao_declarada
  @type t :: %__MODULE__{chave: String.t(), estado: estado(), prefixo: String.t()}
  @type cidr :: {:inet.ip_address(), 0..128}

  # A origem fixa de um socket que não é endereço (`{:local, caminho}`, `:unspec`): nomeada, para
  # que conte num balde visível, e nunca `raise` dentro da entrada (L2).
  @sem_endereco "sem-endereco"

  @doc """
  A origem de um endereço, já normalizada, no estado da configuração.
  """
  @spec de_endereco(term(), estado()) :: t()
  def de_endereco(endereco, estado) when estado in [:socket, :proxy, :nao_declarada] do
    case normalizar(endereco) do
      :sem_endereco ->
        %__MODULE__{chave: @sem_endereco, estado: estado, prefixo: @sem_endereco}

      ip ->
        %__MODULE__{chave: chave(ip), estado: estado, prefixo: prefixo(ip)}
    end
  end

  @doc """
  Desmapeia o IPv4 mapeado em IPv6 (`::ffff:0:0/96`); o que não é tupla de endereço vira
  `:sem_endereco`.
  """
  @spec normalizar(term()) :: :inet.ip_address() | :sem_endereco
  def normalizar({0, 0, 0, 0, 0, 0xFFFF, alto, baixo})
      when alto in 0..0xFFFF and baixo in 0..0xFFFF,
      do: {alto >>> 8, alto &&& 0xFF, baixo >>> 8, baixo &&& 0xFF}

  def normalizar({a, b, c, d} = ip)
      when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255,
      do: ip

  def normalizar({_, _, _, _, _, _, _, _} = ip) do
    if Enum.all?(Tuple.to_list(ip), &(&1 in 0..0xFFFF)), do: ip, else: :sem_endereco
  end

  def normalizar(_), do: :sem_endereco

  @doc """
  Lê um endereço de texto **estritamente** (L12): apara o espaço e usa
  `:inet.parse_strict_address/1`. Forma curta (`127.1`), hexadecimal, porta, colchetes e zona
  (`%eth0`) são `:error`. O resultado já vem normalizado.
  """
  @spec analisar_estrito(String.t()) :: {:ok, :inet.ip_address()} | :error
  def analisar_estrito(texto) when is_binary(texto) do
    limpo = String.trim(texto)

    with false <- String.contains?(limpo, "%"),
         {:ok, ip} <- :inet.parse_strict_address(String.to_charlist(limpo)),
         ip when ip != :sem_endereco <- normalizar(ip) do
      {:ok, ip}
    else
      _ -> :error
    end
  end

  @doc """
  Se o endereço pertence ao bloco. Os dois lados são normalizados antes: o IPv4 mapeado casa
  um bloco IPv4.
  """
  @spec pertence?(term(), cidr()) :: boolean()
  def pertence?(endereco, {rede, bits}) do
    with ip when ip != :sem_endereco <- normalizar(endereco),
         r when r != :sem_endereco <- normalizar(rede),
         true <- tuple_size(ip) == tuple_size(r) do
      largura = largura(ip)
      bits <= largura and mascarar(ip, bits) == mascarar(r, bits)
    else
      _ -> false
    end
  end

  @doc """
  Lê um bloco `endereço/bits` estritamente. Sem `/bits`, é o endereço sozinho (`/32` ou `/128`).
  """
  @spec analisar_cidr(String.t()) :: {:ok, cidr()} | :error
  def analisar_cidr(texto) when is_binary(texto) do
    case String.split(String.trim(texto), "/") do
      [endereco] -> com_bits(analisar_estrito(endereco), nil)
      [endereco, bits] -> com_bits(analisar_estrito(endereco), Integer.parse(bits))
      _ -> :error
    end
  end

  defp com_bits({:ok, ip}, nil), do: {:ok, {ip, largura(ip)}}

  defp com_bits({:ok, ip}, {bits, ""}) when bits >= 0 do
    if bits <= largura(ip), do: {:ok, {ip, bits}}, else: :error
  end

  defp com_bits(_, _), do: :error

  defp chave({_, _, _, _} = ip), do: ip |> :inet.ntoa() |> to_string()

  defp chave(ip) do
    bits = bits_da_regra(:ipv6_key_bits)
    "#{ip |> zerar(bits) |> :inet.ntoa()}/#{bits}"
  end

  defp prefixo({_, _, _, _} = ip) do
    bits = bits_da_regra(:ipv4_log_bits)
    "#{ip |> zerar(bits) |> :inet.ntoa()}/#{bits}"
  end

  defp prefixo(ip) do
    bits = bits_da_regra(:ipv6_log_bits)
    "#{ip |> zerar(bits) |> :inet.ntoa()}/#{bits}"
  end

  defp largura(ip) when tuple_size(ip) == 4, do: 32
  defp largura(_ip), do: 128

  defp para_inteiro({_, _, _, _} = ip),
    do: ip |> Tuple.to_list() |> Enum.reduce(0, &(&2 * 256 + &1))

  defp para_inteiro(ip), do: ip |> Tuple.to_list() |> Enum.reduce(0, &(&2 * 65_536 + &1))

  defp mascarar(ip, bits) do
    largura = largura(ip)
    para_inteiro(ip) >>> (largura - bits)
  end

  defp zerar(ip, bits) do
    largura = largura(ip)
    n = (para_inteiro(ip) >>> (largura - bits)) <<< (largura - bits)
    de_inteiro(n, tuple_size(ip))
  end

  defp de_inteiro(n, 4),
    do: {n >>> 24 &&& 0xFF, n >>> 16 &&& 0xFF, n >>> 8 &&& 0xFF, n &&& 0xFF}

  defp de_inteiro(n, 8),
    do: 7..0//-1 |> Enum.map(&(n >>> (&1 * 16) &&& 0xFFFF)) |> List.to_tuple()

  # Os bits moram na base de conhecimento (`access.origin_limit`, `origin_key`), lidos a cada
  # chamada, como os da `ApiRateLimit`. Regra ausente é base incompleta, e quebra alto.
  defp bits_da_regra(campo) do
    case TheBand.Ontology.KnowledgeBase.rule("access.origin_limit") do
      {:ok, %{"rules" => %{"origin_key" => %{"values" => v}}}} -> Map.fetch!(v, to_string(campo))
      _ -> raise "regra access.origin_limit/origin_key ausente da base de conhecimento"
    end
  end
end
