defmodule TheBand.Ontology.SEON.CMPO.Queries do
  @moduledoc "Leituras de CMPO. A fronteira é `TheBand.Ontology.SEON.CMPO`."

  import Ecto.Query

  alias TheBand.Ontology.SEON.CMPO.Schemas.LoadedSoftwareSystemCopy, as: Copy
  alias TheBand.Ontology.SEON.CMPO.Schemas.ObservedRepository
  alias TheBand.Ontology.SEON.CMPO.Schemas.SourceRepository
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  Repositórios observados por uma ferramenta, com o estado de cada um.

  Devolve mapas e não structs: a tela precisa de repositório, identidade e situação
  juntos, e devolver a struct obrigaria quem chama a alcançar a tabela do kind — o que
  é justamente o que a fronteira impede.
  """
  @spec list_observed(Tenant.t(), keyword()) :: [map()]
  def list_observed(%Tenant{id: tenant_id}, opts \\ []) do
    tool_id = Keyword.get(opts, :connected_tool_id)

    from(o in ObservedRepository,
      join: r in SourceRepository,
      on: r.id == o.source_repository_id,
      join: c in Copy,
      on: c.id == r.loaded_software_system_copy_id,
      where: o.tenant_id == ^tenant_id,
      order_by: [asc: r.name],
      select: %{
        observed_repository_id: o.id,
        source_repository_id: r.id,
        connected_tool_id: o.connected_tool_id,
        name: r.name,
        qualified_name: r.qualified_name,
        url: r.url,
        primary_language: r.primary_language,
        default_branch: r.default_branch,
        archived_at: r.archived_at,
        last_pushed_at: r.last_pushed_at,
        excluded_at: o.excluded_at,
        inaccessible_since: o.inaccessible_since,
        inaccessible_reason: o.inaccessible_reason,
        external_id: c.external_id,
        last_observed_at: c.last_observed_at,
        no_longer_observed_at: c.no_longer_observed_at
      }
    )
    |> then(fn q -> if tool_id, do: where(q, [o], o.connected_tool_id == ^tool_id), else: q end)
    |> Repo.all()
  end

  @doc """
  Os repositórios que a coleta deve consultar.

  Exclui os que o tenant excluiu e os inacessíveis — e nenhum dos dois tem a ausência
  marcada por causa disso.
  """
  @spec list_collectable(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_collectable(%Tenant{} = tenant, connected_tool_id) do
    tenant
    |> list_observed(connected_tool_id: connected_tool_id)
    |> Enum.reject(&(&1.excluded_at || &1.inaccessible_since))
  end

  @spec count_observed(Tenant.t(), keyword()) :: non_neg_integer()
  def count_observed(%Tenant{} = tenant, opts \\ []),
    do: tenant |> list_observed(opts) |> length()

  @spec fetch_observed(Tenant.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, :not_found}
  def fetch_observed(%Tenant{} = tenant, id) do
    case Enum.find(list_observed(tenant), &(&1.observed_repository_id == id)) do
      # FR-037 — id de outro tenant devolve :not_found, nunca o registro.
      nil -> {:error, :not_found}
      observed -> {:ok, observed}
    end
  end
end
