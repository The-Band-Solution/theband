defmodule TheBand.Saude do
  @moduledoc """
  A saúde da fila, lida **fora** do Oban — issue #801. O contrato é
  `docs/producao/saude-da-fila.md`.

  Depende de: nenhuma ontologia. Lê `oban_jobs` diretamente, pelo `Repo`.

  ## Por que fora do Oban

  Em 2026-09-04, no desenvolvimento, o Oban parou por quatro dias com o servidor respondendo
  `200` e a fila acumulando 524 jobs. `TheBand.Jobs.ReconcileStuckSyncs`, o guarda desta família
  de defeito, é um job do Oban, e parou junto. O verificador tem de estar num lugar que não
  para com o que ele verifica: aqui, uma consulta ao banco chamada pela rota `/health` e pelo
  healthcheck do contêiner.
  """

  import Ecto.Query, only: [from: 2]

  alias TheBand.Repo

  @type estado :: :ok | {:parada, non_neg_integer()}

  @doc """
  O estado da fila no instante `agora`, com o limiar em minutos.

  Parada é: o último job completado tem `limiar` minutos ou mais; ou nunca houve job completado
  e existe job esperando há `limiar` minutos ou mais. Sem histórico e sem nada esperando é
  instalação nova, e está `:ok`.
  """
  @spec fila(DateTime.t(), pos_integer()) :: estado()
  def fila(agora \\ DateTime.utc_now(), limiar \\ limiar()) do
    corte = agora |> DateTime.add(-limiar, :minute) |> DateTime.to_naive()

    case ultimo_completado() do
      nil -> sem_historico(corte, agora)
      completado -> comparar(completado, corte, agora)
    end
  end

  @doc "O limiar declarado, em minutos: três ciclos do `Cron`, que agenda a cada 5."
  @spec limiar() :: pos_integer()
  def limiar, do: Application.get_env(:the_band, :fila_parada_apos_minutos, 15)

  defp comparar(completado, corte, agora) do
    if NaiveDateTime.compare(completado, corte) == :gt,
      do: :ok,
      else: {:parada, minutos_desde(completado, agora)}
  end

  defp sem_historico(corte, agora) do
    case esperando_mais_antigo() do
      %NaiveDateTime{} = desde ->
        if NaiveDateTime.compare(desde, corte) == :gt,
          do: :ok,
          else: {:parada, minutos_desde(desde, agora)}

      nil ->
        :ok
    end
  end

  # Tabela de uma dependência, lida sem schema: o Oban não expõe consulta para isto, e passar
  # pelo Oban seria justamente o que este módulo existe para não fazer.
  defp ultimo_completado do
    Repo.one(from(j in "oban_jobs", where: j.state == "completed", select: max(j.completed_at)))
  end

  defp esperando_mais_antigo do
    Repo.one(from(j in "oban_jobs", where: j.state == "available", select: min(j.scheduled_at)))
  end

  defp minutos_desde(%NaiveDateTime{} = desde, agora),
    do: max(div(NaiveDateTime.diff(DateTime.to_naive(agora), desde), 60), 0)
end
