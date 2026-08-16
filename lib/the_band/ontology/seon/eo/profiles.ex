defmodule TheBand.Ontology.SEON.EO.Profiles do
  @moduledoc """
  Comando e consulta dos perfis derivados — feature 026.

  A tabela é **somente-acréscimo**: não existe função de atualizar. O perfil vigente é o mais
  recente, e os anteriores continuam legíveis.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.PersonProfile
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc "Grava uma geração. Nunca sobrescreve a anterior."
  @spec record(Tenant.t(), map()) :: {:ok, PersonProfile.t()} | {:error, Ecto.Changeset.t()}
  def record(%Tenant{id: tenant_id}, attrs) do
    %PersonProfile{}
    |> PersonProfile.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  @doc "O perfil vigente — o mais recente."
  @spec current(Tenant.t(), binary()) :: {:ok, PersonProfile.t()} | {:error, :not_found}
  def current(%Tenant{id: tenant_id}, person_id) do
    from(p in PersonProfile,
      where: p.tenant_id == ^tenant_id and p.person_id == ^person_id,
      order_by: [desc: p.generated_at],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      perfil -> {:ok, perfil}
    end
  end

  @doc "Todas as gerações, da mais recente para a mais antiga."
  @spec list(Tenant.t(), binary()) :: [PersonProfile.t()]
  def list(%Tenant{id: tenant_id}, person_id) do
    from(p in PersonProfile,
      where: p.tenant_id == ^tenant_id and p.person_id == ^person_id,
      order_by: [desc: p.generated_at]
    )
    |> Repo.all()
  end
end
