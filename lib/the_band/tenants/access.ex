defmodule TheBand.Tenants.Access do
  @moduledoc """
  O veredito único do acesso — contrato em
  `specs/045-autenticacao-e-acesso/contracts/access-scopes.md`.

  ## O axioma, executável

  **A pessoa tem acesso aos dados com os quais está relacionada.** O elo diz quem
  a conta é; vínculo e ligação declarada dizem com o que ela se relaciona; a
  concessão cobre o que a relação não cobre. A visão é a UNIÃO — escopos somam,
  nunca subtraem (FR-006/018).

  ## Derivado não se grava

  `scopes/2` LÊ as relações vigentes a cada chamada: elo → pessoa → vínculos →
  equipes → ligações declaradas → projetos. Encerrou o fato, fechou o escopo —
  sem job, sem coluna, sem segunda verdade (FR-020/021). Só a concessão vira
  linha, com proveniência e revogação por marca.

  ## Administrar não é ver (FR-022)

  Nenhum ramo aqui olha `users.role` para conceder visão. O ramo "admin vê tudo"
  saiu do `EO.Visibility` nesta feature; quem administra e precisa ver recebe
  concessão organization — a migração deu essa concessão aos admins de então.

  ## O motivo importa

  `pode_ver/3` devolve `{:ok, motivo}`/`{:nao, motivo}` — booleano no lugar de
  relator é antipadrão da casa. O mais específico vence, e a liderança declarada
  (#369) continua valendo por delegação, somada por último (FR-018).
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Access.ScopeGrant
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @type scope :: %{
          level: :person | :team | :project | :organization,
          target_id: Ecto.UUID.t() | nil,
          target_name: String.t() | nil,
          origin: :floor | :derived_team | :derived_project | :granted,
          grant: ScopeGrant.t() | nil
        }

  @doc "A união vigente, com a origem de cada escopo — a tela pinta hachura por ela."
  @spec scopes(Tenant.t(), User.t()) :: [scope()]
  def scopes(%Tenant{} = tenant, %User{} = user) do
    {piso, equipes} =
      case Tenants.person_of_user(user) do
        {:ok, person_id} -> {[floor_scope()], EO.person_active_teams(tenant, person_id)}
        :not_declared -> {[], []}
      end

    derivados_team =
      for e <- equipes do
        %{
          level: :team,
          target_id: e.team_id,
          target_name: e.team_name,
          origin: :derived_team,
          grant: nil
        }
      end

    derivados_project =
      for p <- SPO.projects_of_teams(tenant, Enum.map(equipes, & &1.team_id)),
          uniq: true do
        %{
          level: :project,
          target_id: p.project_id,
          target_name: p.project_name,
          origin: :derived_project,
          grant: nil
        }
      end

    piso ++ derivados_team ++ derivados_project ++ granted_scopes(tenant, user)
  end

  defp floor_scope,
    do: %{level: :person, target_id: nil, target_name: nil, origin: :floor, grant: nil}

  defp granted_scopes(%Tenant{id: tenant_id} = tenant, %User{id: user_id}) do
    grants =
      Repo.all(
        from g in ScopeGrant,
          where: g.tenant_id == ^tenant_id and g.user_id == ^user_id and is_nil(g.revoked_at),
          order_by: [asc: g.granted_at]
      )

    nomes = target_names(tenant, grants)

    for g <- grants do
      %{
        level: String.to_existing_atom(g.level),
        target_id: g.target_id,
        # nil = alvo que não existe mais: a concessão ficou órfã, e a tela diz.
        target_name: Map.get(nomes, {g.level, g.target_id}),
        origin: :granted,
        grant: g
      }
    end
  end

  # Três consultas no máximo — uma por nível presente (L38), nunca por concessão.
  defp target_names(tenant, grants) do
    por_nivel = Enum.group_by(grants, & &1.level, & &1.target_id)

    equipes = EO.teams_by_ids(tenant, Map.get(por_nivel, "team", []))
    projetos = SPO.projects_by_ids(tenant, Map.get(por_nivel, "project", []))

    organizacoes =
      case Map.get(por_nivel, "organization", []) do
        [] -> %{}
        ids -> tenant |> EO.list_organizations() |> Map.new(&{&1.id, &1.name}) |> Map.take(ids)
      end

    %{}
    |> juntar("team", equipes)
    |> juntar("project", projetos)
    |> juntar("organization", organizacoes)
  end

  defp juntar(acc, nivel, mapa),
    do: Enum.into(mapa, acc, fn {id, nome} -> {{nivel, id}, nome} end)

  @doc """
  Esta conta pode ver o painel desta pessoa? O motivo mais específico vence.
  """
  @spec pode_ver(Tenant.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, atom()} | {:nao, atom()}
  def pode_ver(%Tenant{} = tenant, %User{} = user, alvo_person_id) do
    meus = scopes(tenant, user)

    cond do
      propria_pessoa?(user, alvo_person_id) ->
        {:ok, :propria_pessoa}

      motivo = alcanca_por_escopo(tenant, meus, alvo_person_id) ->
        {:ok, motivo}

      true ->
        # A liderança declarada (#369) soma por último — FR-018.
        case EO.Visibility.pode_ver(tenant, user, alvo_person_id) do
          {:ok, motivo} -> {:ok, motivo}
          {:nao, _} -> {:nao, motivo_da_recusa(meus)}
        end
    end
  end

  defp propria_pessoa?(%User{} = user, alvo_person_id) do
    match?({:ok, ^alvo_person_id}, Tenants.person_of_user(user))
  end

  # Devolve o motivo (:escopo_de_equipe | :escopo_de_projeto | :escopo_da_organizacao)
  # ou nil. Uma leitura das relações do ALVO, comparada aos meus alvos por nível.
  defp alcanca_por_escopo(tenant, meus, alvo_person_id) do
    alvo_equipes = EO.person_active_teams(tenant, alvo_person_id)
    alvo_team_ids = MapSet.new(alvo_equipes, & &1.team_id)
    alvo_org_ids = MapSet.new(alvo_equipes, & &1.organization_id) |> MapSet.delete(nil)

    alvo_project_ids =
      tenant
      |> SPO.projects_of_teams(Enum.map(alvo_equipes, & &1.team_id))
      |> MapSet.new(& &1.project_id)

    alvos = fn nivel ->
      for s <- meus, s.level == nivel, s.target_id, into: MapSet.new(), do: s.target_id
    end

    cond do
      not MapSet.disjoint?(alvos.(:team), alvo_team_ids) -> :escopo_de_equipe
      not MapSet.disjoint?(alvos.(:project), alvo_project_ids) -> :escopo_de_projeto
      not MapSet.disjoint?(alvos.(:organization), alvo_org_ids) -> :escopo_da_organizacao
      true -> nil
    end
  end

  # Recusa com remédio certo: sem elo E sem escopo é um pedido de declaração;
  # concessões todas órfãs são outro; fora do alcance é o caso geral.
  defp motivo_da_recusa(meus) do
    cond do
      meus == [] ->
        :sem_elo_declarado

      Enum.all?(meus, &(&1.origin == :granted and is_nil(&1.target_name))) ->
        :alvo_da_concessao_nao_existe_mais

      true ->
        :fora_dos_escopos
    end
  end

  @doc "Concede escopo — só administrador, alvo obrigatório e existente (FR-007/008)."
  @spec grant(
          Tenant.t(),
          Ecto.UUID.t(),
          :team | :project | :organization,
          Ecto.UUID.t(),
          User.t()
        ) ::
          {:ok, ScopeGrant.t()} | {:error, :not_admin | :target_not_found | Ecto.Changeset.t()}
  def grant(%Tenant{} = tenant, user_id, level, target_id, %User{} = actor)
      when level in [:team, :project, :organization] do
    cond do
      not User.admin?(actor) ->
        {:error, :not_admin}

      not target_exists?(tenant, level, target_id) ->
        {:error, :target_not_found}

      true ->
        %ScopeGrant{}
        |> ScopeGrant.changeset(%{
          tenant_id: tenant.id,
          user_id: user_id,
          level: Atom.to_string(level),
          target_id: target_id,
          granted_by_user_id: actor.id,
          granted_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()
    end
  end

  @doc "Revoga por marca — só administrador (FR-008); derivado nunca passa por aqui."
  @spec revoke(Tenant.t(), Ecto.UUID.t(), User.t()) ::
          {:ok, ScopeGrant.t()} | {:error, :not_admin | :not_found}
  def revoke(%Tenant{id: tenant_id}, grant_id, %User{} = actor) do
    cond do
      not User.admin?(actor) ->
        {:error, :not_admin}

      grant =
          Repo.one(
            from g in ScopeGrant,
              where: g.id == ^grant_id and g.tenant_id == ^tenant_id and is_nil(g.revoked_at)
          ) ->
        grant |> ScopeGrant.revoke_changeset(actor.id) |> Repo.update()

      true ->
        {:error, :not_found}
    end
  end

  @doc """
  FR-023: quem alcança as telas operacionais, e com que recorte.

  Uma consulta só, e direto nas concessões: organization NÃO tem caminho
  derivado (contrato), então a união inteira não precisa ser montada — e isso
  importa porque o menu pergunta isto a cada tela.
  """
  @spec operacional?(Tenant.t(), User.t()) ::
          {true, :admin | {:organizations, [Ecto.UUID.t()]}} | false
  def operacional?(%Tenant{id: tenant_id}, %User{} = user) do
    cond do
      User.admin?(user) ->
        {true, :admin}

      (orgs =
         Repo.all(
           from g in ScopeGrant,
             where:
               g.tenant_id == ^tenant_id and g.user_id == ^user.id and
                 g.level == "organization" and is_nil(g.revoked_at),
             select: g.target_id
         )) != [] ->
        {true, {:organizations, orgs}}

      true ->
        false
    end
  end

  defp target_exists?(tenant, :team, id), do: EO.teams_by_ids(tenant, [id]) != %{}
  defp target_exists?(tenant, :project, id), do: SPO.projects_by_ids(tenant, [id]) != %{}

  defp target_exists?(tenant, :organization, id),
    do: Enum.any?(EO.list_organizations(tenant), &(&1.id == id))
end
