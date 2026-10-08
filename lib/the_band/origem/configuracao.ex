defmodule TheBand.Origem.Configuracao do
  @moduledoc """
  Os três estados da origem, lidos do ambiente — spec 077, contrato §2 (FR-005, FR-009).

  Depende de: nenhuma ontologia.

  ## Nenhum estado liga por ausência (seguranca.md, L1 e L3)

  | `THE_BAND_ORIGEM` | estado | recusa? |
  |---|---|---|
  | ausente | `:nao_declarada` | **não**: conta e registra a transição |
  | `socket` | `:socket` | sim, pelo endereço do socket |
  | `proxy` | `:proxy` | sim, pela origem que o proxy escreveu |

  O ausente não recusa porque, em produção atrás do Traefik, o socket é o proxy: recusar ali seria
  um teto **global**, e quem ataca negaria a entrada a todos a ~0,04 requisição por segundo. É a
  decisão 2 da 070 (2026-10-01) — *sem a medição, o limite por IP não entra* —, aplicada.

  ## Configuração errada não sobe

  Lista de proxies malformada, com `/0`, ou com bloco que não é de rede local faz `ler!/1`
  levantar, e a aplicação não sobe — como a chave mestra ausente. Um proxy que fala com o socket
  da aplicação está na rede local por definição; um bloco público na lista deixaria qualquer
  cliente escolher a própria origem a cada tentativa, com o log dizendo que o limite está ligado.
  A mensagem nomeia a **variável** e o motivo, nunca o valor.
  """

  alias TheBand.Origem

  @type t ::
          %{estado: :socket}
          | %{estado: :nao_declarada}
          | %{estado: :proxy, cabecalho: String.t(), proxies: [Origem.cidr()]}

  @var_estado "THE_BAND_ORIGEM"
  @var_cabecalho "THE_BAND_ORIGEM_CABECALHO"
  @var_proxies "THE_BAND_ORIGEM_PROXIES"

  # As redes locais (RFC 1918, RFC 6598, laço local, RFC 4193). Um bloco da lista precisa estar
  # DENTRO de uma delas.
  @locais [
    {{10, 0, 0, 0}, 8},
    {{172, 16, 0, 0}, 12},
    {{192, 168, 0, 0}, 16},
    {{100, 64, 0, 0}, 10},
    {{127, 0, 0, 0}, 8},
    {{0, 0, 0, 0, 0, 0, 0, 1}, 128},
    {{0xFC00, 0, 0, 0, 0, 0, 0, 0}, 7}
  ]

  @doc """
  Lê o estado do ambiente. Levanta `ArgumentError` com a variável e o motivo, e nunca o valor.
  """
  @spec ler!(%{optional(String.t()) => String.t()}) :: t()
  def ler!(ambiente) when is_map(ambiente) do
    case Map.get(ambiente, @var_estado) do
      nil -> %{estado: :nao_declarada}
      "socket" -> %{estado: :socket}
      "proxy" -> proxy!(ambiente)
      _ -> recusar!(@var_estado, "o valor não é `socket` nem `proxy`")
    end
  end

  defp proxy!(ambiente) do
    cabecalho = Map.get(ambiente, @var_cabecalho, "")

    unless String.match?(cabecalho, ~r/\A[a-z0-9-]+\z/) do
      recusar!(@var_cabecalho, "precisa ser um nome de cabeçalho, em minúsculas")
    end

    proxies =
      ambiente
      |> Map.get(@var_proxies, "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if proxies == [], do: recusar!(@var_proxies, "a lista de proxies está vazia")

    %{estado: :proxy, cabecalho: cabecalho, proxies: Enum.map(proxies, &bloco_local!/1)}
  end

  defp bloco_local!(texto) do
    case Origem.analisar_cidr(texto) do
      {:ok, {_ip, bits} = bloco} ->
        if Enum.any?(@locais, &dentro?(bloco, &1)),
          do: bloco,
          else: recusar!(@var_proxies, "um bloco (/#{bits}) não é de rede local")

      :error ->
        recusar!(@var_proxies, "um bloco não é endereço/bits válido")
    end
  end

  defp dentro?({ip, bits}, {rede, bits_da_rede}),
    do: bits >= bits_da_rede and Origem.pertence?(ip, {rede, bits_da_rede})

  defp recusar!(variavel, motivo),
    do:
      raise(
        ArgumentError,
        "#{variavel}: #{motivo}. A origem do limite por IP não foi configurada."
      )

  @doc """
  A linha do log de subida (FR-009): o estado, e em `proxy` o cabeçalho e a lista. Sem segredo:
  nenhum destes valores é segredo, e são o que quem opera precisa ler para saber o que o limite
  protege.
  """
  @spec frase(t()) :: String.t()
  def frase(%{estado: :socket}),
    do: "limite por origem: ligado, pela origem do socket"

  def frase(%{estado: :proxy, cabecalho: cabecalho, proxies: proxies}) do
    lista = Enum.map_join(proxies, ", ", fn {ip, bits} -> "#{:inet.ntoa(ip)}/#{bits}" end)
    "limite por origem: ligado, pelo cabeçalho #{cabecalho} vindo de #{lista}"
  end

  def frase(%{estado: :nao_declarada}),
    do:
      "limite por origem: só observado — #{@var_estado} não declarada, e atrás de proxy a " <>
        "origem do socket é o proxy; nenhuma tentativa é recusada pelo limite (runbook §15)"
end
