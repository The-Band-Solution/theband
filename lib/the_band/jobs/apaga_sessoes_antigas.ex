defmodule TheBand.Jobs.ApagaSessoesAntigas do
  @moduledoc """
  Apaga as sessões que deixaram de valer há mais de 90 dias, todo dia — feature 064, T020,
  decisão P3.

  Não decide nada: chama `TheBand.Tenants.Sessions.apagar_as_que_deixaram_de_valer/1`, onde a
  regra vive, com as duas condições e o porquê delas.

  Silencioso quando não acha nada, como `ReconcileStuckSyncs`: ruído periódico treina quem lê o
  log a ignorá-lo.
  """
  use Oban.Worker, queue: :ingestion, max_attempts: 3

  alias TheBand.Tenants.Sessions

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, _apagadas} = Sessions.apagar_as_que_deixaram_de_valer()
    :ok
  end
end
