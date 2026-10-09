defmodule TheBand.NetworkAnalysis.Notices do
  @moduledoc """
  O aviso de leitura pronta da análise de rede — feature 076, T014 (`contracts/network-analysis.md`,
  `subscribe/1`; R3 da segurança da 073, A11).

  O tópico é do tenant, e a mensagem leva **só ids**: a organização e as leituras novas. Nunca
  aresta, contagem, `person_id` nem nome. Quem recebe relê por `NetworkAnalysis.read/4`, que
  recorta pelo alcance de quem lê.

  Depende de: `Phoenix.PubSub`.
  """

  alias TheBand.Tenants.Tenant

  @doc "Assina os avisos da análise de rede do tenant."
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, topico(tenant_id))

  @doc "Avisa que a organização tem leituras novas. Só ids."
  @spec broadcast(Ecto.UUID.t(), Ecto.UUID.t(), [Ecto.UUID.t()]) :: :ok | {:error, term()}
  def broadcast(tenant_id, organization_id, reading_ids) when is_list(reading_ids) do
    Phoenix.PubSub.broadcast(
      TheBand.PubSub,
      topico(tenant_id),
      {:network_analysis_ready, organization_id, reading_ids}
    )
  end

  defp topico(tenant_id), do: "network_analysis:" <> tenant_id
end
