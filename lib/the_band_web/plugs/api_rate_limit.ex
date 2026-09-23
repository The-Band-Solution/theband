defmodule TheBandWeb.Plugs.ApiRateLimit do
  @moduledoc """
  Limita quantas chamadas um token faz por janela — achado A2, 2026-09-22.

  ## O que faltava

  **Não havia limite algum.** A spec do servidor MCP decidia, na Q4, *"o limite de taxa é o
  da 061"* — e a 061 não implementou nenhum. Herdar um controle inexistente é herdar zero.

  Por MCP seria pior que pela API: o consumidor é um programa que itera sem cansar.

  ## Os números moram na base de conhecimento

  `api.access.thresholds`, regra `rate_limit`. **Não** em constante de módulo, pela mesma
  razão do prazo do token: limiar em constante muda num diff e ninguém percebe.

  São **proposta**, e estão lá para quem decide mudar — em um lugar, não espalhados.

  ## A contagem é por TOKEN

  Não por tenant, não por endereço de rede. O token é a identidade que a API conhece, e é a
  que se revoga. Por tenant, uma integração ruidosa derrubaria as outras da mesma
  organização; por endereço, um proxy compartilhado juntaria quem não tem relação.

  ## A recusa DIZ o limite

  `429`, com o limite, a janela e quantos segundos faltam para ela reabrir. Recusa muda faria
  quem integra tentar de novo imediatamente, que é o contrário do que o limite quer.

  ## Janela fixa, e o que isso custa

  Contador em ETS por `{token, janela}`, descartado quando a janela vira. É o desenho mais
  simples que resolve o problema que existe.

  **O que fica pior**: numa virada de janela, alguém pode emitir até o dobro do limite em
  dois instantes próximos — o fim de uma janela e o começo da seguinte. Uma janela
  deslizante não teria isso, e custaria guardar os instantes de cada chamada. Para um limite
  que existe para conter laço que não converge, o dobro momentâneo não é o problema; a
  ausência de qualquer limite era.
  """
  import Plug.Conn

  alias TheBand.Ontology.KnowledgeBase
  alias TheBandWeb.Api.V1.Erro

  require Logger

  @tabela :api_rate_limit
  @regra "api.access.thresholds"

  @doc """
  Cria a tabela do contador. Chamada uma vez, na subida da aplicação.

  `:public` com `write_concurrency`: cada requisição incrementa a sua chave, e as chaves de
  tokens diferentes não se tocam.
  """
  @spec preparar() :: :ok
  def preparar do
    if :ets.whereis(@tabela) == :undefined do
      :ets.new(@tabela, [:set, :public, :named_table, write_concurrency: true])
    end

    :ok
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:api_token] do
      %{public_id: publico} -> conferir(conn, publico)
      _ -> conn
    end
  end

  defp conferir(conn, publico) do
    %{limite: limite, janela: janela} = limiares()
    agora = System.system_time(:second)
    inicio = div(agora, janela) * janela
    quantas = :ets.update_counter(@tabela, {publico, inicio}, {2, 1}, {{publico, inicio}, 0})

    if quantas > limite do
      recusar(conn, limite, janela, inicio + janela - agora)
    else
      conn
      |> put_resp_header("x-ratelimit-limit", to_string(limite))
      |> put_resp_header("x-ratelimit-remaining", to_string(max(limite - quantas, 0)))
    end
  end

  # A recusa diz o limite, a janela e quando ela reabre. `retry-after` é o cabeçalho que um
  # cliente bem-feito já obedece sem que ninguém leia o corpo.
  defp recusar(conn, limite, janela, faltam) do
    id = Logger.metadata()[:request_id] || "sem-id"

    Logger.warning("api: limite de taxa excedido · limite=#{limite}/#{janela}s request_id=#{id}")

    corpo =
      Erro.corpo(:too_many_requests, id)
      |> put_in([:error, :message], mensagem(limite, janela, faltam))

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("retry-after", to_string(faltam))
    |> put_resp_header("x-ratelimit-limit", to_string(limite))
    |> put_resp_header("x-ratelimit-remaining", "0")
    |> send_resp(429, Jason.encode!(corpo))
    |> halt()
  end

  defp mensagem(limite, janela, faltam) do
    "Rate limit of #{limite} requests per #{janela}s exceeded. " <>
      "The window reopens in #{faltam}s."
  end

  # Da base de conhecimento, a cada chamada — a regra vive em ETS desde o boot, e lê-la não
  # custa consulta. Se a regra sumir, a aplicação tem problema maior que o limite, e
  # `Mix.raise` na carga já o teria denunciado; aqui o `case` explícito evita que uma base
  # incompleta vire limite silencioso de zero.
  defp limiares do
    case KnowledgeBase.rule(@regra) do
      {:ok, %{"rules" => %{"rate_limit" => %{"values" => v}}}} ->
        %{limite: v["requests_per_minute"], janela: v["window_seconds"]}

      _ ->
        raise "regra #{@regra}/rate_limit ausente da base de conhecimento"
    end
  end
end
