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

  ## Janela DESLIZANTE, em fatias

  A primeira versão usava janela **fixa**: um contador por `{token, janela}`, zerado quando a
  janela virava. O defeito é conhecido e foi declarado então — **na virada, alguém emite até
  o dobro do limite em dois instantes próximos**: o fim de uma janela e o começo da seguinte.
  Com 120 por minuto, 240 chamadas em poucos segundos.

  Agora a janela desliza. O minuto é dividido em **fatias de dez segundos**, cada uma com o
  seu contador; a conta é a **soma das fatias que cobrem os últimos sessenta segundos**. À
  medida que o tempo anda, a fatia mais velha sai da soma sozinha — não há instante em que
  tudo zera.

  ### Por que fatias, e não os instantes de cada chamada

  Guardar o instante de cada chamada daria a janela exata. Mas contar exige **ler, podar e
  escrever**, e isso não é atômico: duas requisições simultâneas do mesmo token leriam a
  mesma lista e as duas passariam. O limite falharia justamente sob a carga que ele existe
  para conter.

  Com fatias, o incremento é `:ets.update_counter/4` — **atômico**, uma fatia por vez. A
  soma lê fatias que já estão fechadas e não mudam mais, ou a corrente, que erra no máximo
  por uma chamada.

  ### O que se perde, e é pouco

  A soma cobre entre **cinquenta e sessenta segundos** de história, conforme o ponto da fatia
  corrente. Ou seja: **mais estrita que a janela declarada, nunca mais frouxa** — que é a
  direção certa para um limite.

  A rajada na virada cai de um minuto inteiro para dez segundos de imprecisão.
  """
  import Plug.Conn

  alias TheBand.Ontology.KnowledgeBase
  alias TheBandWeb.Api.V1.Erro

  require Logger

  @tabela :api_rate_limit
  @regra "api.access.thresholds"

  # Seis fatias de dez segundos para uma janela de sessenta. Mais fatias dariam mais
  # precisão e mais leituras por requisição; menos, uma rajada maior na virada. Seis é o
  # ponto em que a imprecisão (dez segundos) já é pequena diante do que o limite contém.
  @fatias 6

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
    largura = max(div(janela, @fatias), 1)
    agora = System.system_time(:second)
    atual = div(agora, largura)

    # O incremento é ATÔMICO e mexe numa fatia só. Duas requisições simultâneas do mesmo
    # token incrementam a mesma fatia sem se perderem — que é o que uma lista de instantes
    # não garantiria.
    :ets.update_counter(@tabela, {publico, atual}, {2, 1}, {{publico, atual}, 0})

    podar(publico, atual)
    quantas = somar(publico, atual)

    if quantas > limite do
      recusar(conn, limite, janela, reabre_em(publico, atual, largura, agora))
    else
      conn
      |> put_resp_header("x-ratelimit-limit", to_string(limite))
      |> put_resp_header("x-ratelimit-remaining", to_string(max(limite - quantas, 0)))
    end
  end

  # A soma das fatias que cobrem a janela: a corrente e as `@fatias - 1` anteriores.
  defp somar(publico, atual) do
    Enum.reduce((atual - @fatias + 1)..atual, 0, fn i, total ->
      case :ets.lookup(@tabela, {publico, i}) do
        [{_, n}] -> total + n
        [] -> total
      end
    end)
  end

  # Fatia que saiu da janela não volta, e guardá-la faria a tabela crescer sem teto — uma
  # entrada por token por dez segundos, para sempre.
  defp podar(publico, atual) do
    :ets.select_delete(@tabela, [
      {{{:"$1", :"$2"}, :_}, [{:==, :"$1", publico}, {:<, :"$2", atual - @fatias}], [true]}
    ])
  end

  # Quando a próxima vaga abre: é o fim da fatia mais VELHA que ainda conta, porque é ela
  # que sai da soma primeiro. Dizer "espere a janela inteira" mandaria esperar mais do que
  # o necessário; dizer "tente já" faria bater de novo.
  defp reabre_em(publico, atual, largura, agora) do
    mais_velha =
      Enum.find((atual - @fatias + 1)..atual, atual, fn i ->
        :ets.lookup(@tabela, {publico, i}) != []
      end)

    max((mais_velha + @fatias) * largura - agora, 1)
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
