defmodule TheBand.Ontology.SEON.EO.Visibility do
  @moduledoc """
  Quem vê o painel de trabalho de quem — issue #369, `FR-012`.

  ## A regra, e de onde ela vem

  Decisão da pessoa mantenedora em 2026-08-26: **a própria pessoa, o líder da equipe dela,
  e o responsável da organização.**

  O que vigorava até então era "toda pessoa autenticada vê qualquer outra do tenant", e
  vigorava **por omissão** — o roteador exigia `require_user` e nada além. Era a terceira
  opção da pergunta original, escolhida sem que ninguém a escolhesse.

  ## Duas perguntas, e a primeira é a que faltava

  Para decidir, a plataforma precisa responder:

    1. **quem é você** — qual das pessoas observadas é a conta logada. É o elo
       `users.person_id`, que o GitHub não fornecia e passou a ser declarado;
    2. **você lidera quem** — qual papel confere qual escopo, em `eo_role_visibility_grants`.

  A segunda não serve de nada sem a primeira: sem saber quem a conta é, nem o próprio
  painel dela é alcançável.

  ## O veredito nomeia o motivo, e não devolve booleano

  `pode_ver/3` devolve `{:ok, motivo}` ou `{:nao, motivo}`, e o motivo importa: "não
  declararam quem você é" e "ninguém foi declarado líder" são bloqueios diferentes, com
  remédios diferentes, e a tela precisa dizer qual é — `FR-012g`. Um booleano faria a tela
  dar a mesma frase para os dois, e quem lesse iria procurar no lugar errado.

  ## Admin da plataforma NÃO vê tudo — mais (feature 045, FR-022)

  A decisão de 2026-08-27 ("admin vê tudo") juntava duas coisas que o resto desta
  regra separa, e foi revista quando o vocabulário que faltava passou a existir: o
  escopo `organization` da feature 045. Administrar é mexer; ver é escopo — quem
  administra e precisa ver recebe concessão como qualquer conta (a migração da 045
  deu aos admins de então uma concessão organization por organização observada,
  para a virada não rebaixar ninguém em silêncio).

  Este módulo segue dono de UMA regra: a liderança declarada (#369). A união com os
  escopos acumulativos vive em `TheBand.Tenants.Access`, que chama esta função por
  último — os escopos SOMAM sobre ela, nunca a substituem (FR-018).

  ## O que esta regra NÃO faz

    * **não infere liderança por nome de papel.** `Tech Leader` parece liderança e
      `Coordenador` também; a concessão é declarada, e é `FR-012e`;
    * **não usa o `role` da plataforma.** `admin`/`member` diz quem pode mexer na
      plataforma, e não o que a pessoa faz na organização. Trocar os dois daria o painel de
      todo mundo a quem administra ferramentas;
    * **não abre por ausência.** Sem elo e sem concessão, fecha — e diz por quê. Abrir "até
      alguém declarar" é o comportamento que a #369 existe para acabar.
  """
  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.RoleVisibilityGrant
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @type motivo ::
          :propria_pessoa
          | :lidera_a_equipe
          | :responsavel_da_organizacao
          | :conta_sem_pessoa_declarada
          | :sem_alcance_declarado

  @doc """
  Esta conta pode ver o painel desta pessoa observada?

  Devolve `{:ok, motivo}` ou `{:nao, motivo}`. O motivo é para a tela dizer, e não para
  ser descartado: `FR-012g` exige distinguir os dois bloqueios.
  """
  @spec pode_ver(Tenant.t(), User.t(), Ecto.UUID.t()) :: {:ok, motivo()} | {:nao, motivo()}
  def pode_ver(%Tenant{} = tenant, %User{} = quem, alvo_person_id) do
    case Tenants.person_of_user(quem) do
      {:ok, ^alvo_person_id} ->
        {:ok, :propria_pessoa}

      {:ok, minha_pessoa} ->
        alcance(tenant, minha_pessoa, alvo_person_id)

      # Sem o elo, nem o próprio painel seria alcançável — e é um bloqueio com remédio, que
      # a tela nomeia diferente do outro. Admin NÃO passa mais por aqui (FR-022):
      # administrar é mexer; ver vem de escopo, decidido em Tenants.Access.
      :not_declared ->
        {:nao, :conta_sem_pessoa_declarada}
    end
  end

  @doc """
  As concessões vigentes deste tenant, por papel — para a tela dos papéis.

  Devolve `%{organizational_role_id => [escopo]}`. Um papel pode ter os dois escopos: quem
  responde pela organização também lidera a própria equipe, e declarar um não retira o
  outro.
  """
  @spec grants_by_role(Tenant.t()) :: %{Ecto.UUID.t() => [String.t()]}
  def grants_by_role(%Tenant{id: tenant_id}) do
    Repo.all(
      from g in RoleVisibilityGrant,
        where: g.tenant_id == type(^tenant_id, :binary_id) and is_nil(g.revoked_at),
        select: {type(g.organizational_role_id, :binary_id), g.scope}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc """
  Quantos papéis conferem cada escopo — a lacuna, dita como lacuna.

  Zero em `team` significa que **ninguém** vê o painel de mais ninguém além do próprio, e
  a tela precisa poder dizer isso em vez de deixar a pessoa concluir que perdeu acesso.
  """
  @spec grant_coverage(Tenant.t()) :: %{team: non_neg_integer(), organization: non_neg_integer()}
  def grant_coverage(%Tenant{} = tenant) do
    escopos = tenant |> grants_by_role() |> Map.values() |> List.flatten()

    %{
      team: Enum.count(escopos, &(&1 == "team")),
      organization: Enum.count(escopos, &(&1 == "organization"))
    }
  end

  @doc "Declara que este papel confere este escopo. Acrescenta, e não substitui o outro."
  @spec declare_grant(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, RoleVisibilityGrant.t()} | {:error, Ecto.Changeset.t()}
  def declare_grant(%Tenant{id: tenant_id}, role_id, scope, actor_id) do
    %RoleVisibilityGrant{}
    |> RoleVisibilityGrant.changeset(%{
      tenant_id: tenant_id,
      organizational_role_id: role_id,
      scope: scope,
      declared_by_user_id: actor_id,
      declared_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
  end

  @doc "Revoga UMA concessão. Marca, e nunca apaga."
  @spec revoke_grant(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, non_neg_integer()} | {:error, :not_declared}
  def revoke_grant(%Tenant{id: tenant_id}, role_id, scope, actor_id) do
    agora = DateTime.utc_now(:second)

    Repo.update_all(
      from(g in RoleVisibilityGrant,
        where:
          g.tenant_id == type(^tenant_id, :binary_id) and
            g.organizational_role_id == type(^role_id, :binary_id) and
            g.scope == ^scope and is_nil(g.revoked_at)
      ),
      set: [revoked_at: agora, revoked_by_user_id: actor_id, updated_at: agora]
    )
    |> case do
      {0, _} -> {:error, :not_declared}
      {n, _} -> {:ok, n}
    end
  end

  # --------------------------------------------------------------------------- privadas

  defp alcance(tenant, minha_pessoa, alvo_person_id) do
    cond do
      lidera_equipe_do_alvo?(tenant, minha_pessoa, alvo_person_id) ->
        {:ok, :lidera_a_equipe}

      responde_pela_organizacao?(tenant, minha_pessoa, alvo_person_id) ->
        {:ok, :responsavel_da_organizacao}

      true ->
        {:nao, :sem_alcance_declarado}
    end
  end

  # Alcança quem está na MESMA equipe em que a pessoa tem um papel com escopo `team`.
  #
  # Vínculo encerrado não alcança, dos dois lados: quem saiu da equipe deixou de liderá-la,
  # e quem saiu deixou de ser liderado. `ended_at` preenchido é história, e não permissão.
  defp lidera_equipe_do_alvo?(%Tenant{id: tenant_id}, minha_pessoa, alvo_person_id) do
    from(meu in TeamMembership,
      as: :meu,
      join: g in RoleVisibilityGrant,
      on:
        g.organizational_role_id == meu.organizational_role_id and
          g.tenant_id == meu.tenant_id and is_nil(g.revoked_at) and g.scope == "team",
      join: dele in TeamMembership,
      as: :dele,
      on: dele.team_id == meu.team_id and dele.tenant_id == meu.tenant_id
    )
    |> where([meu: m], m.tenant_id == type(^tenant_id, :binary_id))
    |> where([meu: m], m.person_id == type(^minha_pessoa, :binary_id))
    |> where([dele: d], d.person_id == type(^alvo_person_id, :binary_id))
    |> ambos_os_lados_vigentes()
    |> Repo.exists?()
  end

  # Vigente são DUAS condições — sem fim registrado E sem invalidação —, e valem
  # para os dois lados do elo. Extraído porque a repetição inline empurrava a
  # complexidade da função acima do que o credo aceita, e porque a regra é uma só:
  # quem saiu deixou de liderar, e quem nunca esteve nunca liderou.
  defp ambos_os_lados_vigentes(query) do
    query
    |> where([meu: m], is_nil(m.ended_at) and is_nil(m.invalidated_at))
    |> where([dele: d], is_nil(d.ended_at) and is_nil(d.invalidated_at))
  end

  # Alcança quem está numa equipe da MESMA organização em que a pessoa tem um papel com
  # escopo `organization`. A organização vem da equipe, e não é inferida do trabalho: "é
  # membro" e "trabalhou lá" são afirmações diferentes, e só a primeira é declaração.
  defp responde_pela_organizacao?(%Tenant{id: tenant_id}, minha_pessoa, alvo_person_id) do
    from(meu in TeamMembership,
      as: :meu,
      join: g in RoleVisibilityGrant,
      on:
        g.organizational_role_id == meu.organizational_role_id and
          g.tenant_id == meu.tenant_id and is_nil(g.revoked_at) and g.scope == "organization",
      join: minha_equipe in "eo_teams",
      on: minha_equipe.id == meu.team_id,
      join: dele in TeamMembership,
      as: :dele,
      on: dele.tenant_id == meu.tenant_id,
      join: equipe_dele in "eo_teams",
      on:
        equipe_dele.id == dele.team_id and
          equipe_dele.organization_id == minha_equipe.organization_id
    )
    |> where([meu: m], m.tenant_id == type(^tenant_id, :binary_id))
    |> where([meu: m], m.person_id == type(^minha_pessoa, :binary_id))
    |> where([dele: d], d.person_id == type(^alvo_person_id, :binary_id))
    |> ambos_os_lados_vigentes()
    |> Repo.exists?()
  end
end
