defmodule TheBand.Telemetria.Configuracao do
  @moduledoc """
  A configuração do SDK OpenTelemetry, montada explicitamente — spec 074, T005; FR-015;
  seguranca.md, S10; research R11.

  Depende de: nenhuma ontologia.

  ## O que o SDK faria sozinho, lido no código (1.7.0 e exportador 1.11.0)

  - `otel_configuration:merge_list_with_environment/3` lê `os:getenv` **antes** da configuração
    da aplicação: `OTEL_TRACES_EXPORTER`, `OTEL_TRACES_SAMPLER`, `OTEL_SDK_DISABLED` e afins
    **vencem** o que estiver em `config/*.exs`. `OTEL_TRACES_EXPORTER=otlp` trocaria o exportador
    dos processadores, e os spans sairiam **por fora** de `TheBand.Telemetria.Exportador`;
  - `otel_exporter_otlp:merge_with_environment/8` faz o mesmo com
    `OTEL_EXPORTER_OTLP_ENDPOINT`, `..._HEADERS` e `..._PROTOCOL`: a variável vence até o
    `endpoints` passado direto ao `init/1` do exportador;
  - o detector de recurso padrão lê `OTEL_RESOURCE_ATTRIBUTES` e `OTEL_SERVICE_NAME`.

  Por isso as variáveis `OTEL_*` são **apagadas do ambiente do processo** em
  `config/runtime.exs`, antes de o SDK subir (`neutralizar_ambiente_otel/0`), e o log de boot diz
  quais foram apagadas — pelo **nome**, nunca pelo valor. O recurso é reconstruído pelo
  exportador de qualquer forma; o apagamento fecha o exportador e o amostrador.

  ## A variável da casa

  A telemetria só liga com `THE_BAND_OTLP_ENDPOINT`, e só para um host da lista
  `@hosts_permitidos`, em `http`, na porta 4318, sem caminho, credencial ou consulta. Fora
  disso, fica **desligada** e o log diz o nome da variável, nunca o valor. A lista muda por
  commit, com teste — uma segunda variável para ampliá-la seria a porta que esta existe para
  fechar.
  """

  alias TheBand.Telemetria.Exportador

  @variavel "THE_BAND_OTLP_ENDPOINT"
  @variavel_do_ambiente "THE_BAND_AMBIENTE"
  # O coletor na rede dedicada e a máquina local, em desenvolvimento. `signoz-otel-collector` é o
  # alias do serviço `otel-collector` na rede `telemetria` de `deploy/signoz/compose.yaml` (#1313):
  # o nome do serviço sozinho é genérico demais para uma rede que o host compartilha.
  # `test/the_band/telemetria/compose_signoz_test.exs` reprova se os dois divergirem.
  @hosts_permitidos ["127.0.0.1", "localhost", "signoz-otel-collector"]
  @porta 4318

  @type estado :: {:ligada, keyword()} | {:desligada, String.t()}

  @doc "Os hosts para onde a telemetria pode ir."
  @spec hosts_permitidos() :: [String.t()]
  def hosts_permitidos, do: @hosts_permitidos

  @doc """
  Monta a configuração do `:opentelemetry` a partir do ambiente (o mapa de `System.get_env/0`).

  `{:ligada, config}` traz as chaves para `config :opentelemetry`; `{:desligada, motivo}` traz
  uma frase que nomeia a variável e **nunca** o valor dela.
  """
  @spec montar(%{optional(String.t()) => String.t()}) :: estado()
  def montar(ambiente) when is_map(ambiente) do
    case Map.get(ambiente, @variavel) do
      vazio when vazio in [nil, ""] ->
        {:desligada, "#{@variavel} ausente"}

      valor ->
        case endpoint(valor) do
          {:ok, url} -> {:ligada, ligada(url, nome_do_ambiente(ambiente))}
          :fora_da_lista -> {:desligada, "#{@variavel} fora dos hosts permitidos"}
        end
    end
  end

  @doc "A configuração do SDK desligado: nenhum exportador."
  @spec desligada() :: keyword()
  def desligada, do: [traces_exporter: :none]

  @doc """
  Os **nomes** das variáveis `OTEL_*` presentes no ambiente — para o log, e para apagá-las.
  """
  @spec variaveis_otel(%{optional(String.t()) => String.t()}) :: [String.t()]
  def variaveis_otel(ambiente) when is_map(ambiente) do
    ambiente |> Map.keys() |> Enum.filter(&String.starts_with?(&1, "OTEL_")) |> Enum.sort()
  end

  @doc """
  Apaga do ambiente do processo toda variável `OTEL_*`, e devolve os nomes apagados.

  Chamado em `config/runtime.exs`, antes de o SDK subir: depois dele, o SDK as leria por cima da
  configuração explícita (ver o moduledoc).
  """
  @spec neutralizar_ambiente_otel() :: [String.t()]
  def neutralizar_ambiente_otel do
    nomes = variaveis_otel(System.get_env())
    Enum.each(nomes, &System.delete_env/1)
    nomes
  end

  defp ligada(url, ambiente) do
    [
      traces_exporter:
        {Exportador,
         %{
           destino: {:opentelemetry_exporter, %{protocol: :http_protobuf, endpoints: [url]}},
           ambiente: ambiente
         }},
      # Sem amostragem (FR-016): todo passo é raiz, num contexto vazio, e `always_on` o exporta.
      sampler: :always_on,
      processors: [{:otel_batch_processor, %{}}]
    ]
  end

  defp endpoint(valor) do
    case URI.new(valor) do
      {:ok,
       %URI{scheme: "http", host: host, port: @porta, path: caminho, userinfo: nil, query: nil} =
           uri}
      when host in @hosts_permitidos and caminho in [nil, "", "/"] and is_nil(uri.fragment) ->
        {:ok, "http://#{host}:#{@porta}"}

      _ ->
        :fora_da_lista
    end
  end

  defp nome_do_ambiente(ambiente) do
    case Map.get(ambiente, @variavel_do_ambiente) do
      nome when is_binary(nome) ->
        if nome =~ ~r/\A[a-z0-9_-]{1,32}\z/, do: nome, else: "prod"

      _ ->
        "prod"
    end
  end
end
