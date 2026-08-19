defmodule TheBand.Jobs.ScheduleDueSyncs do
  @moduledoc """
  Enfileira a coleta das ferramentas vencidas, a cada cinco minutos — issue #443.

  ## Por que este trabalho existe

  A sincronização **nunca foi agendada**. O `crontab` tinha o reconciliador e a rodada mensal
  de perfis, e o único disparo era o botão na tela. Medido em 2026-08-19: os dois maiores
  tenants estavam há **cinco dias** sem nenhuma coleta completa.

  E a ausência de agendamento era o que escondia o resto: sem periodicidade **ninguém
  esperava** coleta, então falha não coletar era indistinguível de ninguém ter clicado.

  ## Não decide nada

  Chama `Ingestion.enqueue_due_syncs/0` e nada mais. A regra de quem está vencido vive num
  lugar só, e o intervalo mora no banco — em `connected_tools.sync_interval_minutes`, escolha
  de quem administra o tenant.

  Três implementações da mesma regra é o defeito que este projeto pagou em outras features, e
  é o que o moduledoc de `ReconcileStuckSyncs` já registra.
  """
  use Oban.Worker, queue: :ingestion, max_attempts: 1

  require Logger

  alias TheBand.Ingestion

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, resumo} = Ingestion.enqueue_due_syncs()

    # Só registra quando houve o que fazer: um `info` a cada cinco minutos dizendo "zero"
    # afogaria o log e treinaria quem lê a ignorá-lo.
    if resumo.enqueued > 0 or resumo.skipped_running > 0 do
      Logger.info(
        "coleta automática: #{resumo.enqueued} enfileirada(s), " <>
          "#{resumo.skipped_running} adiada(s) por já estar em andamento"
      )
    end

    :ok
  end
end
