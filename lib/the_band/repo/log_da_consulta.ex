defmodule TheBand.Repo.LogDaConsulta do
  @moduledoc """
  O log das consultas do `TheBand.Repo`, com os parâmetros redigidos onde há campo cifrado —
  issue #1222.

  Depende de: nenhuma ontologia. Lê a lista de campos cifrados de `TheBand.Rotacao`.

  ## Por que o log embutido do Ecto está desligado

  Em `:debug`, o Ecto loga os parâmetros **como o changeset os leu** (`cast_params`), antes de
  `TheBand.Encrypted.Binary` cifrar. Toda gravação de segredo saía em claro no log. O tipo não
  tem como impedir: o Ecto loga os valores de `changeset.changes`, que nunca passam por ele, e
  `Ecto.Changeset.change/2` nem chama `cast`.

  `log: false` em cada gravação resolveria os caminhos de hoje, e o próximo caminho de escrita
  esqueceria. Por isso o Repo tem `log: false` na configuração, e este handler, anexado antes
  de o Repo subir, loga no lugar dele: **toda** consulta passa por aqui, inclusive a que ainda
  não foi escrita.

  ## A regra

  Consulta cuja fonte ou cujo SQL menciona uma tabela de `TheBand.Rotacao.campos_cifrados/0`
  tem **todos** os parâmetros redigidos. Por tabela, e não por coluna: o parâmetro é posicional,
  e casar posição com coluna lendo o SQL seria o lugar de errar. Na dúvida, redige — perder o
  `id` de uma leitura no log de desenvolvimento custa menos que um segredo.

  O SQL é lido sem distinguir maiúsculas, porque `Repo.query` cru chega com `source` nulo.

  ## O que o handler respeita

  O Oban passa `log: conf.log` (padrão `false`) e `telemetry_options: [oban_conf: conf]`. Com
  o Repo silenciado, o handler é quem decide; ler `oban_conf.log` mantém a sondagem do Oban
  fora do log, como antes.

  `log:` com nível **por chamada** contornaria tudo isto, porque o Ecto ainda loga quando a
  chamada pede um nível. `test/the_band/segredo_fora_do_log_test.exs` reprova se aparecer um.
  """

  alias Ecto.Adapters.SQL
  alias TheBand.Rotacao

  require Logger

  @evento [:the_band, :repo, :query]
  @id "the_band-repo-log-da-consulta"
  @redigido "[parâmetros redigidos: a consulta toca tabela com campo cifrado]"

  @doc "Anexa o handler. Chamado por `TheBand.Application` antes de o Repo subir."
  @spec anexar() :: :ok | {:error, :already_exists}
  def anexar, do: :telemetry.attach(@id, @evento, &__MODULE__.handle_event/4, %{})

  @doc "O id do handler no `:telemetry`, para quem precisa conferir que está anexado."
  @spec id() :: String.t()
  def id, do: @id

  @doc "As tabelas cujas consultas têm os parâmetros redigidos."
  @spec tabelas_cifradas() :: [String.t()]
  def tabelas_cifradas,
    do: Rotacao.campos_cifrados() |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

  @doc "A consulta toca tabela com campo cifrado?"
  @spec redigir?(String.t() | nil, String.t()) :: boolean()
  def redigir?(source, sql) do
    sql = String.downcase(sql)
    Enum.any?(tabelas_cifradas(), &(&1 == source or String.contains?(sql, &1)))
  end

  @doc false
  # O corpo é protegido: um handler que levanta é desanexado pelo `:telemetry`, e o log das
  # consultas sumiria em silêncio até o próximo boot. O `rescue` loga só o TIPO do erro — nunca
  # a consulta nem os parâmetros, que são o que este módulo existe para não vazar.
  def handle_event(_evento, medidas, metadados, _config) do
    case nivel(metadados) do
      false -> :ok
      nivel -> Logger.log(nivel, fn -> linha(medidas, metadados) end, ansi_color: :cyan)
    end

    :ok
  rescue
    erro ->
      Logger.error("log da consulta falhou ao formatar: #{inspect(erro.__struct__)}")
      :ok
  end

  defp nivel(%{options: options}) when is_list(options) do
    case Keyword.get(options, :oban_conf) do
      %{log: true} -> :debug
      %{log: nivel} -> nivel
      _ -> :debug
    end
  end

  defp nivel(_), do: :debug

  defp linha(medidas, %{query: sql, source: source} = metadados) do
    params =
      if redigir?(source, sql),
        do: @redigido,
        else: inspect(metadados[:cast_params] || metadados[:params], charlists: false)

    [
      "QUERY ",
      resultado(metadados[:result]),
      fonte(source),
      tempo("db", medidas[:query_time], true),
      tempo("decode", medidas[:decode_time], false),
      tempo("queue", medidas[:queue_time], false),
      tempo("idle", medidas[:idle_time], true),
      ?\n,
      sql,
      ?\s,
      params,
      chamador(metadados)
    ]
  end

  defp resultado({:ok, _}), do: "OK"
  defp resultado(_), do: "ERROR"

  defp fonte(nil), do: ""
  defp fonte(source), do: " source=#{inspect(source)}"

  # Mesma regra do Ecto: `db` e `idle` sempre que medidos; os outros só quando acima de zero.
  defp tempo(_rotulo, nil, _sempre), do: []

  defp tempo(rotulo, nativo, sempre) do
    ms = div(System.convert_time_unit(nativo, :native, :microsecond), 100) / 10
    if sempre or ms > 0, do: [?\s, rotulo, ?=, :io_lib_format.fwrite_g(ms), "ms"], else: []
  end

  # A linha `↳` que o Ecto imprime com `stacktrace: true` (desenvolvimento), pela mesma função
  # pública que ele usa.
  defp chamador(%{stacktrace: [_ | _] = stacktrace, repo: repo}) do
    stacktrace
    |> SQL.first_non_ecto_stacktrace(%{repo: repo}, 1)
    |> Enum.map(fn {m, f, a, info} ->
      local =
        case info[:file] do
          nil -> []
          file -> [", at: ", to_string(file), ?:, Integer.to_string(info[:line] || 0)]
        end

      ["\n↳ ", Exception.format_mfa(m, f, a), local]
    end)
  end

  defp chamador(_), do: []
end
