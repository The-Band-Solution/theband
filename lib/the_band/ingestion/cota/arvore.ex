defmodule TheBand.Ingestion.Cota.Arvore do
  @moduledoc """
  A árvore do gestor de cotas: o `Registry` que localiza cada identidade e o
  `DynamicSupervisor` sob o qual os processos nascem no primeiro pedido.

  Separada do `GenServer` de propósito: o `child_spec/1` do `TheBand.Ingestion.Cota` é o
  do processo por identidade (é o que o `DynamicSupervisor` usa), e a aplicação precisa de
  um filho diferente — este. Misturar os dois no mesmo módulo fez cada pedido de cota
  iniciar uma árvore inteira em vez de um processo, e derrubou a aplicação nos testes.

  `:rest_for_one`: se o `Registry` cair, os processos registrados nele já não são
  encontráveis, e o supervisor deles precisa recomeçar junto.
  """

  use Supervisor

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    Supervisor.init(
      [
        {Registry, keys: :unique, name: TheBand.Ingestion.Cota.Registry},
        {DynamicSupervisor, name: TheBand.Ingestion.Cota.Supervisor, strategy: :one_for_one}
      ],
      strategy: :rest_for_one
    )
  end
end
