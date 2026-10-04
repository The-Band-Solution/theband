defmodule TheBand.NetworkAnalysis.Inputs do
  @moduledoc """
  A função de entrada do cálculo: as arestas de cada rede numa janela — feature 076, T014 (a
  forma) e T028 (a ligação às duas redes).

  `Commands.compute/5` recebe as arestas por esta função, e não as busca: a busca de cada rede
  mora no dono dela (`ReviewNetwork.current_edges/2` e `WorkItems.assignment_pairs/3`), e o cálculo
  não muda quando a fonte muda.

  **Nesta fatia (T014), nenhuma rede tem fonte ligada**: as duas devolvem
  `{:ausente, :source_not_connected}`, nada é gravado, e o relator diz por quê. Devolver lista
  vazia gravaria uma leitura afirmando que não houve aresta — o fallback silencioso da §7.7. A
  T028 troca este corpo pelas duas fontes.

  Depende de: nenhuma ontologia, nesta fatia.
  """

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.Tenants.Tenant

  @doc "A função de entrada da organização, para as redes e janelas dos parâmetros."
  @spec for_organization(Tenant.t(), map(), DateTime.t(), map()) :: Commands.entradas()
  def for_organization(%Tenant{}, %{id: _organization_id}, %DateTime{}, _parametros) do
    fn _rede, _dias, _inicio -> {:ausente, :source_not_connected} end
  end
end
