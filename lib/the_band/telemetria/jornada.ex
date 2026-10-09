defmodule TheBand.Telemetria.Jornada do
  @moduledoc """
  O handler que traduz o passo de jornada em span — spec 074, T010; contrato §4.

  Depende de: nenhuma ontologia. Recebe o evento `[:the_band, :jornada, :passo]`, emitido só
  por `TheBand.Tenants.AccessEvents.passo/1`.

  ## Fora do domínio

  O domínio conhece o **nome** de um evento `:telemetry`, e não o OpenTelemetry (ADR 0005,
  decisão 1). É aqui, e só aqui, que o evento vira span.

  ## Só os campos permitidos, nunca a metadata inteira

  Os atributos são montados campo a campo, a partir das sete chaves que o contrato §3 nomeia.
  É defesa em profundidade: a garantia é o `TheBand.Telemetria.Exportador`, que reconstrói o
  span de novo antes de ele sair (seguranca.md, S1).

  ## O span é um instante

  Aberto e fechado no mesmo instante, num contexto **vazio**: não é filho do que estiver
  corrente no processo, e não carrega duração (research R2). A duração da autenticação inteira,
  exportada por motivo, recriaria o oráculo de tempo que a 045 e a #1047 fecharam.

  ## Falhar sem sumir

  O `:telemetry` **desanexa** o handler que levanta (ADR 0005, S5), e a telemetria sumiria em
  silêncio até o próximo boot. Por isso `catch kind, _` — e não `rescue`, que não pega `exit`
  nem `throw` (seguranca.md, S11). A falha é contada em `TheBand.Telemetria.Contadores` e
  logada com **só o tipo** e o módulo da exceção: a mensagem pode conter valor, e a pilha de um
  `FunctionClauseError` traz os argumentos.
  """

  require Logger

  alias TheBand.Telemetria.Contadores
  alias TheBand.Telemetria.Taxonomia

  @evento [:the_band, :jornada, :passo]
  @id "the_band-telemetria-jornada"
  @prefixo "the_band.acesso."

  @doc "Anexa o handler. Chamado por `TheBand.Application` antes dos filhos."
  @spec anexar() :: :ok | {:error, :already_exists}
  def anexar, do: :telemetry.attach(@id, @evento, &__MODULE__.handle_event/4, %{})

  @doc "O id do handler no `:telemetry`, para quem confere que ele segue anexado."
  @spec id() :: String.t()
  def id, do: @id

  @doc "O evento que este handler escuta."
  @spec evento() :: [atom()]
  def evento, do: @evento

  @doc "O handler está anexado? O `telemetry_poller` pergunta a cada rodada."
  @spec anexado?() :: boolean()
  def anexado?, do: Enum.any?(:telemetry.list_handlers(@evento), &(&1.id == @id))

  @doc false
  @spec handle_event([atom()], map(), map(), term()) :: :ok
  # `config` é a configuração do `:telemetry.attach/4`: em produção, `%{}`. O teste de
  # resiliência anexa ESTE MESMO handler, com o mesmo id, passando em `:emitir` uma função que
  # levanta, faz `exit` ou `throw` — é o `catch` daqui que ele prova, e não uma cópia.
  def handle_event(_evento, _medidas, metadados, config) do
    Contadores.incrementar(:passo_emitido)
    Map.get(config, :emitir, &emitir/1).(metadados)
    :ok
  catch
    kind, razao ->
      Contadores.incrementar(:handler_falhou, kind)

      Logger.error(
        "telemetria da jornada: o handler falhou (#{kind}#{modulo(kind, razao)}); passo perdido"
      )

      :ok
  end

  defp emitir(%{passo: passo, desfecho: desfecho} = metadados) do
    tracer = :opentelemetry.get_application_tracer(__MODULE__)

    contexto =
      :otel_tracer.start_span(:otel_ctx.new(), tracer, @prefixo <> Atom.to_string(passo), %{
        kind: :internal,
        attributes: atributos(metadados)
      })

    :otel_span.set_status(contexto, codigo(desfecho))
    :otel_span.end_span(contexto)
  end

  defp atributos(%{passo: passo, desfecho: desfecho} = metadados) do
    %{
      "journey.name" => Taxonomia.jornada(),
      "journey.step" => Atom.to_string(passo),
      "outcome" => Atom.to_string(desfecho)
    }
    |> colocar("failure.reason", metadados[:motivo] && Atom.to_string(metadados[:motivo]))
    |> colocar("tenant.id", metadados[:tenant_id])
    |> colocar("user.ref", metadados[:user_id])
    |> colocar("journey.id", metadados[:jornada_id])
  end

  defp colocar(atributos, _nome, nil), do: atributos
  defp colocar(atributos, nome, valor), do: Map.put(atributos, nome, valor)

  defp codigo(:concluiu), do: :ok
  defp codigo(:falhou), do: :error

  defp modulo(:error, %{__exception__: true} = excecao), do: ", " <> inspect(excecao.__struct__)
  defp modulo(_kind, _razao), do: ""
end
