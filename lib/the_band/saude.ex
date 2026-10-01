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

  @type leitura :: %{
          estado: :andando | :parada | :sem_historico,
          causa: :ultimo_completado | :esperando_mais_antigo | nil,
          ultimo_completado_em: DateTime.t() | nil,
          esperando_desde: DateTime.t() | nil,
          parada_ha_minutos: non_neg_integer() | nil,
          conferido_em: DateTime.t()
        }

  @doc """
  O estado da fila no instante `agora`, com o limiar em minutos — o veredito de `/health` e do
  healthcheck.

  Parada é: o último job completado tem `limiar` minutos ou mais; ou nunca houve job completado
  e existe job esperando há `limiar` minutos ou mais. Sem histórico e sem nada esperando é
  instalação nova, e está `:ok`. Calculada a partir de `leitura/2`, e as duas não podem
  discordar.
  """
  @spec fila(DateTime.t(), pos_integer()) :: estado()
  def fila(agora \\ DateTime.utc_now(), limiar \\ limiar()) do
    case leitura(agora, limiar) do
      %{estado: :parada, parada_ha_minutos: minutos} -> {:parada, minutos}
      %{} -> :ok
    end
  end

  @doc """
  O que a tela `/syncs` precisa: o veredito, a causa e os horários — issue #801, parte 3,
  decisão Q3. Contrato em `docs/producao/saude-da-fila.md`.

  `:sem_historico` é a instalação em que nenhum job jamais completou e nada espera há `limiar`
  minutos: não está parada, e também não está "andando". A tela diz isso com outra marca.
  """
  @spec leitura(DateTime.t(), pos_integer()) :: leitura()
  def leitura(agora \\ DateTime.utc_now(), limiar \\ limiar()) do
    corte = agora |> DateTime.add(-limiar, :minute) |> DateTime.to_naive()

    base = %{
      estado: :andando,
      causa: nil,
      ultimo_completado_em: nil,
      esperando_desde: nil,
      parada_ha_minutos: nil,
      conferido_em: agora
    }

    case ultimo_completado() do
      nil ->
        sem_historico(base, corte, agora)

      completado ->
        comparar(%{base | ultimo_completado_em: utc(completado)}, completado, corte, agora)
    end
  end

  @doc "O limiar declarado, em minutos: três ciclos do `Cron`, que agenda a cada 5."
  @spec limiar() :: pos_integer()
  def limiar, do: Application.get_env(:the_band, :fila_parada_apos_minutos, 15)

  defp comparar(base, completado, corte, agora) do
    if NaiveDateTime.compare(completado, corte) == :gt,
      do: base,
      else: %{
        base
        | estado: :parada,
          causa: :ultimo_completado,
          parada_ha_minutos: minutos_desde(completado, agora)
      }
  end

  defp sem_historico(base, corte, agora) do
    case esperando_mais_antigo() do
      %NaiveDateTime{} = desde ->
        base = %{base | esperando_desde: utc(desde)}

        if NaiveDateTime.compare(desde, corte) == :gt,
          do: %{base | estado: :sem_historico},
          else: %{
            base
            | estado: :parada,
              causa: :esperando_mais_antigo,
              parada_ha_minutos: minutos_desde(desde, agora)
          }

      nil ->
        %{base | estado: :sem_historico}
    end
  end

  # As colunas do Oban são `timestamp without time zone`, gravadas em UTC.
  defp utc(%NaiveDateTime{} = n), do: DateTime.from_naive!(n, "Etc/UTC")

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
