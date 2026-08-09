defmodule TheBand.Ontology.SEON.EO.Queries do
  @moduledoc """
  Leituras do módulo EO. Todas recebem o tenant explicitamente.

  `list_*` e `count_*` aceitam **exatamente as mesmas** `opts`, e isso não é
  preferência de estilo: uma contagem que ignora o filtro que a listagem aplica
  exibe "41 pessoas" acima de uma lista de 10, e o defeito permanece invisível
  enquanto não houver consumidor. O filtro é montado uma vez, em `scope/3`, e as
  duas funções o compartilham.

  Nenhuma função devolve `Ecto.Query`: devolver query vazaria o schema interno e
  permitiria compor fora da fronteira, contornando o filtro de tenant.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.Organization
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Ontology.SEON.EO.Schemas.Team
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  # ------------------------------------------------------------------- pessoas

  @spec list_people(Tenant.t(), keyword()) :: [Person.t()]
  def list_people(tenant, opts \\ []) do
    Person
    |> scope(tenant, opts)
    |> order_by([p], asc: p.name)
    |> paginate(opts)
    |> Repo.all()
  end

  @spec count_people(Tenant.t(), keyword()) :: non_neg_integer()
  def count_people(tenant, opts \\ []) do
    Person |> scope(tenant, opts) |> Repo.aggregate(:count, :id)
  end

  # ------------------------------------------------------------------- equipes

  @spec list_teams(Tenant.t(), keyword()) :: [Team.t()]
  def list_teams(tenant, opts \\ []) do
    Team
    |> scope(tenant, opts)
    |> order_by([t], asc: t.name)
    |> paginate(opts)
    |> Repo.all()
  end

  @spec count_teams(Tenant.t(), keyword()) :: non_neg_integer()
  def count_teams(tenant, opts \\ []) do
    Team |> scope(tenant, opts) |> Repo.aggregate(:count, :id)
  end

  @doc """
  Integrantes observados de uma equipe.

  Devolve o nível de acesso **na plataforma**, nunca um papel. A distinção é
  preservada até no nome do campo, porque desfazê-la na camada de leitura
  anularia o cuidado tomado no modelo.
  """
  @spec list_team_members(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def list_team_members(%Tenant{id: tenant_id}, team_id, opts \\ []) do
    include_absent? = Keyword.get(opts, :include_no_longer_observed, true)

    query =
      from e in TeamMembershipEvidence,
        join: p in Person,
        on: p.id == e.person_id,
        where: e.tenant_id == ^tenant_id and e.team_id == ^team_id,
        order_by: [asc: p.name],
        select: %{
          person: p,
          platform_access_level: e.platform_access_level,
          observed_at: e.observed_at,
          last_observed_at: e.last_observed_at,
          no_longer_observed_at: e.no_longer_observed_at,
          pending_role: is_nil(e.promoted_membership_id)
        }

    query =
      if include_absent?, do: query, else: where(query, [e], is_nil(e.no_longer_observed_at))

    Repo.all(query)
  end

  # --------------------------------------------------------------- organizações

  @spec list_organizations(Tenant.t(), keyword()) :: [Organization.t()]
  def list_organizations(%Tenant{id: tenant_id}, _opts \\ []) do
    Repo.all(from o in Organization, where: o.tenant_id == ^tenant_id, order_by: o.name)
  end

  # ------------------------------------------------------------------- lacunas

  @doc """
  FR-021 e SC-010 — quantos vínculos observados ainda não têm papel atribuído.

  É medida de lacuna de conhecimento, não erro: diz quanto da estrutura
  organizacional o sistema ainda não conhece.
  """
  @spec count_evidence_pending_role(Tenant.t(), keyword()) :: non_neg_integer()
  def count_evidence_pending_role(%Tenant{id: tenant_id}, opts \\ []) do
    query =
      from e in TeamMembershipEvidence,
        where: e.tenant_id == ^tenant_id and is_nil(e.promoted_membership_id)

    query =
      case Keyword.get(opts, :team_id) do
        nil -> query
        team_id -> where(query, [e], e.team_id == ^team_id)
      end

    Repo.aggregate(query, :count, :id)
  end

  # --------------------------------------------------------------------- escopo

  # O filtro de tenant não é opcional nem parametrizável: entra sempre, e é a
  # primeira cláusula. Query sem ele é bug de segurança, não de correção.
  defp scope(schema, %Tenant{id: tenant_id}, opts) do
    schema
    |> where([r], r.tenant_id == ^tenant_id)
    |> filter_account_type(opts[:account_type])
    |> filter_search(opts[:search])
    |> filter_observed(opts[:only_observed])
  end

  defp filter_account_type(query, nil), do: query

  defp filter_account_type(query, types) when is_list(types),
    do: where(query, [r], r.account_type in ^types)

  defp filter_account_type(query, type), do: where(query, [r], r.account_type == ^type)

  defp filter_search(query, nil), do: query
  defp filter_search(query, ""), do: query

  defp filter_search(query, term) do
    like = "%#{term}%"
    where(query, [r], ilike(r.name, ^like) or ilike(r.login, ^like))
  end

  defp filter_observed(query, true), do: where(query, [r], is_nil(r.no_longer_observed_at))
  defp filter_observed(query, _), do: query

  defp paginate(query, opts) do
    query
    |> then(fn q -> if opts[:limit], do: limit(q, ^opts[:limit]), else: q end)
    |> then(fn q -> if opts[:offset], do: offset(q, ^opts[:offset]), else: q end)
  end
end
