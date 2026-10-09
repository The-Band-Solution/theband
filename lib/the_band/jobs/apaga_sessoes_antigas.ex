defmodule TheBand.Jobs.ApagaSessoesAntigas do
  @moduledoc """
  Apaga as sessões que deixaram de valer há mais de 90 dias, todo dia — feature 064, T020,
  decisão P3.

  Não decide nada: chama `TheBand.Tenants.Sessions.apagar_as_que_deixaram_de_valer/1`, onde a
  regra vive, com as duas condições e o porquê delas.

  Desde a spec 070 (T058, research R3.1), apaga também as sessões vencidas do operador da
  plataforma e os códigos de recuperação que deixaram de valer, pelas funções da `Platform`.
  Sem worker novo: a retenção é a mesma, e um segundo agendamento seria uma segunda coisa para
  esquecer de configurar.

  Silencioso quando não acha nada, como `ReconcileStuckSyncs`: ruído periódico treina quem lê o
  log a ignorá-lo.
  """
  use Oban.Worker, queue: :manutencao, max_attempts: 3

  alias TheBand.Platform.Credentials
  alias TheBand.Platform.Sessions, as: SessoesDoOperador
  alias TheBand.Tenants.Sessions

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, _apagadas} = Sessions.apagar_as_que_deixaram_de_valer()
    {:ok, _do_operador} = SessoesDoOperador.apagar_as_que_deixaram_de_valer()
    {:ok, _codigos} = Credentials.apagar_codigos_que_deixaram_de_valer()
    :ok
  end
end
