defmodule TheBandWeb.Operacao do
  @moduledoc """
  O recorte operacional nas telas — FR-023 da feature 045.

  `require_operacao` decide QUEM entra; este módulo decide O QUE aparece:
  administrador vê o tenant inteiro, e quem tem concessão organization vê o que
  pertence às organizações concedidas. A corrente é a mesma da 046:
  `connected_tools.organization_login ↔ eo_organizations.login` — ferramenta é
  o que pertence a organização, e sync pertence à ferramenta.
  """

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants.Tenant

  @doc "Ferramentas dentro do recorte. `:admin` = todas."
  def filtrar_tools(tools, :admin, _tenant), do: tools

  def filtrar_tools(tools, {:organizations, org_ids}, %Tenant{} = tenant) do
    logins = logins_das(tenant, org_ids)
    Enum.filter(tools, &(&1.organization_login in logins))
  end

  @doc "Syncs dentro do recorte — pela ferramenta a que pertencem."
  def filtrar_syncs(syncs, :admin, _tools_permitidas), do: syncs

  def filtrar_syncs(syncs, {:organizations, _}, tools_permitidas) do
    ids = MapSet.new(tools_permitidas, & &1.id)
    Enum.filter(syncs, &MapSet.member?(ids, &1.connected_tool_id))
  end

  defp logins_das(tenant, org_ids) do
    ids = MapSet.new(org_ids)

    tenant
    |> EO.list_organizations()
    |> Enum.filter(&MapSet.member?(ids, &1.id))
    |> MapSet.new(& &1.login)
  end
end
