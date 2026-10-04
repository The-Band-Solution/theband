defmodule TheBand.Telemetria.Contadores do
  @moduledoc """
  Os contadores de perda da telemetria — spec 074, contrato §7; seguranca.md, S11.

  Depende de: nenhuma ontologia.

  ## Por que fora do OpenTelemetry

  Contar a perda pelo mesmo cano que perdeu é circular: com o exportador parado, o contador
  sumiria junto com o que ele conta. Os contadores vivem numa tabela ETS da própria aplicação,
  e `TheBandWeb.Telemetry` os **loga** periodicamente quando não são zero.

  ## O que se conta

  | nome | quando | rótulo |
  |---|---|---|
  | `passo_emitido` | o handler recebeu um passo | — |
  | `span_exportado` | o exportador entregou um span ao destino | — |
  | `span_descartado` | o exportador descartou o span inteiro (nome fora da enumeração) | — |
  | `atributo_descartado` | o exportador tirou um atributo | o **nome** do atributo |
  | `evento_descartado` | o exportador tirou eventos ou links | — |
  | `exportacao_falhou` | o destino recusou, ou o exportador levantou | o tipo |
  | `handler_falhou` | o handler levantou, fez `exit` ou `throw` | o `kind` |

  A perda na fila do `otel_batch_processor` **não é exposta pelo SDK** (lido em
  `deps/opentelemetry/src/otel_batch_processor.erl`, 1.7.0: `on_end/2` devolve `dropped` e
  ninguém o conta; research R13). Ela aparece como a diferença entre `passo_emitido` e a soma de
  `span_exportado` com `span_descartado`.

  ## O rótulo nunca carrega valor

  O rótulo de `atributo_descartado` é o nome do atributo, e só quando o nome tem a forma de um
  nome (`[a-z0-9_.]`, até 64). Um nome fora da forma vira `"(nome fora da forma)"`: quem
  escrevesse `set_attribute(senha, ...)` poria o segredo **na chave**, e o log dos contadores o
  imprimiria.
  """

  @tabela :the_band_telemetria_contadores
  @fora_da_forma "(nome fora da forma)"

  @type nome ::
          :passo_emitido
          | :span_exportado
          | :span_descartado
          | :atributo_descartado
          | :evento_descartado
          | :exportacao_falhou
          | :handler_falhou

  @doc "Cria a tabela. Chamado por `TheBand.Application` antes de anexar o handler."
  @spec preparar() :: :ok
  def preparar do
    if :ets.whereis(@tabela) == :undefined do
      :ets.new(@tabela, [:set, :public, :named_table, write_concurrency: true])
    end

    :ok
  end

  @doc "Soma `n` ao contador `nome`, com o rótulo."
  @spec incrementar(nome(), String.t() | atom() | nil, non_neg_integer()) :: :ok
  def incrementar(nome, rotulo \\ nil, n \\ 1) when is_atom(nome) and is_integer(n) do
    chave = {nome, rotulo(rotulo)}
    _ = :ets.update_counter(@tabela, chave, {2, n}, {chave, 0})
    :ok
  end

  @doc "O valor de um contador, somando todos os rótulos quando `rotulo` é `:todos`."
  @spec valor(nome(), String.t() | atom() | nil | :todos) :: non_neg_integer()
  def valor(nome, :todos) do
    @tabela
    |> :ets.match_object({{nome, :_}, :_})
    |> Enum.reduce(0, fn {_, n}, acc -> acc + n end)
  end

  def valor(nome, rotulo) do
    case :ets.lookup(@tabela, {nome, rotulo(rotulo)}) do
      [{_, n}] -> n
      [] -> 0
    end
  end

  @doc "Os contadores que não são zero, para o log periódico."
  @spec nao_zero() :: [{{nome(), String.t() | nil}, pos_integer()}]
  def nao_zero do
    @tabela
    |> :ets.tab2list()
    |> Enum.filter(fn {_, n} -> n > 0 end)
    |> Enum.sort()
  end

  defp rotulo(nil), do: nil
  defp rotulo(rotulo) when is_atom(rotulo), do: rotulo |> Atom.to_string() |> rotulo()

  defp rotulo(rotulo) when is_binary(rotulo) do
    if rotulo =~ ~r/\A[a-z0-9_.]{1,64}\z/, do: rotulo, else: @fora_da_forma
  end

  defp rotulo(_), do: @fora_da_forma
end
