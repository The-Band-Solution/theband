defmodule TheBand.Telemetria.Exportador do
  @moduledoc """
  O filtro do que sai — spec 074, T009; contrato §6; seguranca.md, S1.

  Depende de: nenhuma ontologia. Lê a taxonomia de `TheBand.Telemetria.Taxonomia`.

  É um exportador de traços (`:otel_exporter_traces`) que **envolve** o destino de verdade —
  `:opentelemetry_exporter` em produção, o processo do teste nos testes — e é o **último ponto
  antes do envio**. Cada span é **reconstruído**, e não filtrado: começa vazio, e recebe só o
  que a lista permite.

  ## O que pode sair, e na forma de quê

  - **nome**: `"the_band.acesso." <> passo`, com o passo declarado na taxonomia. Span de outro
    nome é descartado **inteiro** — é também a guarda da FR-012: um span de consulta, ou de
    qualquer instrumentador que alguém ligar sem avaliação, não sai;
  - **atributos**: só os sete de `@atributos`, e cada um com o **valor na forma**:
    `journey.name` é a jornada; `journey.step` é o passo do nome; `journey.id` é o correlator
    (22 caracteres base64url); `outcome` é um desfecho **que a aplicação emite** para aquele
    passo; `failure.reason` é um motivo declarado **para aquele passo**, e só com
    `outcome = falhou`; `tenant.id` e `user.ref` são UUID;
  - **eventos e links**: nenhum. Some com eles o `record_exception`, cuja mensagem e pilha
    carregariam o argumento da função que falhou (S1);
  - **status**: o código, sem a descrição, que é texto livre;
  - **recurso**: reconstruído com `service.name`, `service.version` e `deployment.environment`,
    e nada do que o SDK detectou — nem `OTEL_RESOURCE_ATTRIBUTES`, nem o nome do host;
  - **escopo de instrumentação** e `tracestate`: fixos.

  Lista do que **pode**, e não do que não pode: a lista proibida precisaria prever o nome do
  próximo vazamento.

  ## O que este módulo NÃO expõe

  Nenhuma função para liberar um atributo em tempo de execução. A lista é constante do módulo,
  e só muda por commit com teste.

  ## Todo descarte é contado

  Em `TheBand.Telemetria.Contadores`, pelo **nome** do atributo, nunca pelo valor. E este
  módulo **nunca levanta**: o processador do SDK loga a exceção de um exportador com a pilha, e
  a pilha traz os argumentos — o span inteiro.
  """

  @behaviour :otel_exporter_traces

  require Logger
  require Record

  alias TheBand.Telemetria.Contadores
  alias TheBand.Telemetria.Taxonomia

  @campos_do_span Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  Record.defrecordp(:span, @campos_do_span)

  Record.defrecordp(
    :status,
    Record.extract(:status, from_lib: "opentelemetry_api/include/opentelemetry.hrl")
  )

  # A posição do escopo no registro: as tabelas do SDK usam o escopo como chave, e o exportador
  # OTLP agrupa por ela. `+ 2` = o índice começa em zero, e a primeira posição é a etiqueta.
  @pos_do_escopo Enum.find_index(@campos_do_span, &(elem(&1, 0) == :instrumentation_scope)) + 2

  @prefixo "the_band.acesso."
  @atributos ~w(journey.name journey.step journey.id outcome failure.reason tenant.id user.ref)
  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  @correlator ~r/\A[A-Za-z0-9_-]{22}\z/

  @doc "Os atributos que podem sair. Para o teste conferir, e não para alguém ampliar."
  @spec atributos_permitidos() :: [String.t()]
  def atributos_permitidos, do: @atributos

  @impl :otel_exporter_traces
  def init(%{destino: {modulo, configuracao}} = opcoes) when is_atom(modulo) do
    case :otel_exporter.init({modulo, configuracao}) do
      :undefined ->
        :ignore

      destino ->
        {:ok,
         %{
           destino: destino,
           recurso: recurso(Map.get(opcoes, :ambiente, "prod")),
           escopo: escopo()
         }}
    end
  end

  @impl :otel_exporter_traces
  def export(tabela, _recurso_detectado_pelo_sdk, %{destino: destino} = estado) do
    regras = Taxonomia.regras_por_passo()

    limpos =
      :ets.foldl(
        fn original, acc ->
          case reconstruir(original, regras, estado.escopo) do
            {:ok, limpo} -> [limpo | acc]
            :descartado -> acc
          end
        end,
        [],
        tabela
      )

    entregar(limpos, destino, estado.recurso)
  catch
    # Nunca a razão nem a pilha: carregariam o span. Só o tipo.
    kind, _razao ->
      Contadores.incrementar(:exportacao_falhou, kind)
      Logger.error("telemetria: o exportador falhou (#{kind}); spans do lote descartados")
      :failed_not_retryable
  end

  @impl :otel_exporter_traces
  def shutdown(%{destino: destino}), do: :otel_exporter.shutdown(destino)

  defp entregar([], _destino, _recurso), do: :ok

  defp entregar(spans, destino, recurso) do
    saida =
      :ets.new(:the_band_telemetria_saida, [:duplicate_bag, :public, keypos: @pos_do_escopo])

    try do
      :ets.insert(saida, spans)
      resultado = :otel_exporter_traces.export(destino, saida, recurso)

      if resultado in [:ok, :success] do
        Contadores.incrementar(:span_exportado, nil, length(spans))
      else
        Contadores.incrementar(:exportacao_falhou, resultado, length(spans))
      end

      resultado
    after
      :ets.delete(saida)
    end
  end

  @doc false
  # Público só para o teste do filtro chamar com um registro montado à mão.
  @spec reconstruir(tuple(), map(), term()) :: {:ok, tuple()} | :descartado
  def reconstruir(original, regras, escopo) do
    with {:ok, passo} <- passo_do_nome(span(original, :name), regras) do
      contar_eventos_e_links(original)

      {:ok,
       span(
         trace_id: span(original, :trace_id),
         span_id: span(original, :span_id),
         tracestate: [],
         parent_span_id: span(original, :parent_span_id),
         parent_span_is_remote: span(original, :parent_span_is_remote),
         name: @prefixo <> passo,
         kind: :internal,
         start_time: span(original, :start_time),
         end_time: span(original, :end_time),
         attributes:
           original |> span(:attributes) |> atributos(passo, regras[passo]) |> novos_atributos(),
         events: :otel_events.new(0, 0, 0),
         links: :otel_links.new([], 0, 0, 0),
         status: status_sem_descricao(span(original, :status)),
         trace_flags: span(original, :trace_flags),
         is_recording: false,
         instrumentation_scope: escopo
       )}
    end
  end

  defp passo_do_nome(nome, regras) do
    nome = if is_atom(nome), do: Atom.to_string(nome), else: nome

    with @prefixo <> passo when is_binary(passo) <- nome,
         true <- Map.has_key?(regras, passo) do
      {:ok, passo}
    else
      _ ->
        Contadores.incrementar(:span_descartado)
        :descartado
    end
  end

  defp atributos(:undefined, _passo, _regra), do: %{}

  defp atributos(atributos, passo, regra) do
    mapa = Map.new(:otel_attributes.map(atributos), fn {k, v} -> {to_string(k), v} end)

    Enum.reduce(mapa, %{}, fn {nome, valor}, acc ->
      if nome in @atributos and valido?(nome, valor, passo, regra, mapa) do
        Map.put(acc, nome, valor)
      else
        Contadores.incrementar(:atributo_descartado, nome)
        acc
      end
    end)
  end

  defp valido?("journey.name", valor, _passo, _regra, _mapa), do: valor == Taxonomia.jornada()
  defp valido?("journey.step", valor, passo, _regra, _mapa), do: valor == passo
  defp valido?("journey.id", valor, _passo, _regra, _mapa), do: forma?(valor, @correlator)
  defp valido?("outcome", valor, _passo, regra, _mapa), do: valor in regra.desfechos

  defp valido?("failure.reason", valor, _passo, regra, mapa),
    do: mapa["outcome"] == "falhou" and valor in regra.motivos

  defp valido?(nome, valor, _passo, _regra, _mapa) when nome in ["tenant.id", "user.ref"],
    do: forma?(valor, @uuid)

  defp forma?(valor, forma) when is_binary(valor), do: Regex.match?(forma, valor)
  defp forma?(_valor, _forma), do: false

  defp novos_atributos(mapa), do: :otel_attributes.new(mapa, length(@atributos), :infinity)

  defp contar_eventos_e_links(original) do
    descartados =
      quantos(span(original, :events), &:otel_events.list/1) +
        quantos(span(original, :links), &:otel_links.list/1)

    if descartados > 0, do: Contadores.incrementar(:evento_descartado, nil, descartados)
  end

  defp quantos(:undefined, _listar), do: 0
  defp quantos(colecao, listar), do: length(listar.(colecao))

  defp status_sem_descricao(status(code: codigo)) when codigo in [:ok, :error, :unset],
    do: status(code: codigo, message: "")

  defp status_sem_descricao(_), do: :undefined

  # O recurso é montado aqui, e não filtrado do que o SDK detectou (S1): o detector lê
  # `OTEL_RESOURCE_ATTRIBUTES` e o nome do host, e nada disso tem de sair.
  defp recurso(ambiente) do
    :otel_resource.create(%{
      "service.name" => "the_band",
      "service.version" => versao(),
      "deployment.environment" => ambiente
    })
  end

  defp escopo, do: :opentelemetry.instrumentation_scope("the_band", versao(), :undefined)

  defp versao do
    case Application.spec(:the_band, :vsn) do
      nil -> "desconhecida"
      vsn -> to_string(vsn)
    end
  end
end
