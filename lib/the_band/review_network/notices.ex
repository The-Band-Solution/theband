defmodule TheBand.ReviewNetwork.Notices do
  @moduledoc """
  O aviso de leitura pronta — feature 073, T017/T019 (FR-011; R3 da segurança, item 2; A11).

  O tópico é do tenant, e a mensagem leva **só ids**: a organização e as leituras novas. Nunca
  aresta, contagem, `person_id` nem nome. Quem recebe relê por `ReviewNetwork.read/4`, que recorta
  pelo alcance de quem lê. O padrão de `RecomputePromotions`, que transmite o resultado, **não** é
  copiado: toda tela aberta do tenant receberia a rede inteira na caixa de mensagens.

  Depende de: `Phoenix.PubSub`.
  """

  alias TheBand.Tenants.Tenant

  @doc "Assina os avisos da rede de revisão do tenant."
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, topico(tenant_id))

  @doc "Avisa que a organização tem leituras novas. Só ids."
  @spec broadcast(Ecto.UUID.t(), Ecto.UUID.t(), [Ecto.UUID.t()]) :: :ok | {:error, term()}
  def broadcast(tenant_id, organization_id, reading_ids) when is_list(reading_ids) do
    Phoenix.PubSub.broadcast(
      TheBand.PubSub,
      topico(tenant_id),
      {:review_network_ready, organization_id, reading_ids}
    )
  end

  defp topico(tenant_id), do: "review_network:" <> tenant_id
end
