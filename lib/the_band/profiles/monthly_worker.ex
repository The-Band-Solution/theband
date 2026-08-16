defmodule TheBand.Profiles.MonthlyWorker do
  @moduledoc """
  O cron mensal: enfileira **uma rodada por organização elegível** — feature 027, T017.

  ## Por que agendamento próprio, e não um passo do sync

  Sincronizar é observar; gerar perfil é interpretar. O sync roda a cada poucos minutos, e
  pendurar a geração nele faria toda observação custar dinheiro — `FR-002`.

  ## Elegível é ligada **e** com credencial

  Organização sem evento de automação não está ligada (`FR-018a`), e organização sem
  credencial própria não roda (`FR-011`): a chave do ambiente é da instalação, e usá-la faria
  a conta de uma pagar pela outra. Nenhuma das duas é erro — são estados, e a tela os nomeia.
  """

  use Oban.Worker, queue: :rodadas, max_attempts: 1

  require Logger

  alias TheBand.Profiles.{Automation, Runs}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    resultados = Enum.map(Automation.enabled_tenants(), &{&1, Runs.start(&1, trigger: :cron)})

    abertas = Enum.count(resultados, &match?({_, {:ok, _}}, &1))

    Logger.info(
      "rodada mensal: #{abertas} aberta(s) de #{length(resultados)} organização(ões) ligada(s)" <>
        recusas(resultados)
    )

    :ok
  end

  # As recusas vão para o log **nomeadas**. "3 de 5" sem os dois motivos deixaria quem lê sem
  # saber se faltou credencial ou se havia rodada em execução — e as duas pedem ação diferente.
  defp recusas(resultados) do
    resultados
    |> Enum.flat_map(fn
      {tenant, {:error, motivo}} -> ["#{tenant.slug}: #{inspect(motivo)}"]
      _ -> []
    end)
    |> case do
      [] -> ""
      lista -> " — recusadas: " <> Enum.join(lista, ", ")
    end
  end
end
