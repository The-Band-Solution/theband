defmodule TheBand.Jobs.ReconcileStuckSyncs do
  @moduledoc """
  Encerra execuções presas, a cada cinco minutos.

  ## Por que um trabalho periódico, e não telemetria

  Telemetria vê **o que aconteceu**. O defeito da issue #175 é algo que **não** aconteceu:
  ninguém encerrou o registro. Trabalho que morre com o nó não emite evento nenhum — não há
  exceção, há ausência de processo.

  Este trabalho vê **estado**, e estado sobrevive a reinício da aplicação, a nó que morre sem
  avisar, e a handler que ninguém registrou.

  ## Não decide nada

  Chama `Ingestion.reconcile_stuck_syncs/0` e, em seguida,
  `Ingestion.flag_tools_failing_repeatedly/0`. A decisão vive num lugar só, e os
  três gatilhos — este trabalho, a tela ao carregar, e a ação humana — chamam a **mesma**
  função. Três implementações da mesma regra é o defeito que este projeto pagou em
  `classification/2`, na prévia contra o recálculo, e na coleta contra o recálculo.

  ## Silencioso quando não acha nada

  Nenhum log de "reconciliei 0". Ruído periódico treina quem lê a ignorar o log, e aí o log
  que importa passa batido.
  """
  use Oban.Worker, queue: :ingestion, max_attempts: 3

  alias TheBand.Ingestion

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, _encerradas} = Ingestion.reconcile_stuck_syncs()

    # **Depois de reconciliar, nunca antes.** A reconciliação é o que transforma coleta presa
    # em `interrupted`; avaliar a sequência antes dela leria a presa como `running` e não
    # contaria a falha que acabou de ser reconhecida.
    #
    # A avaliação vem aqui e não num trabalho próprio porque olha o MESMO estado, no mesmo
    # intervalo, e dois trabalhos periódicos sobre a mesma tabela discordariam entre si — é a
    # razão que este moduledoc já dá para a decisão viver num lugar só.
    {:ok, _atencao} = Ingestion.flag_tools_failing_repeatedly()
    :ok
  end
end
