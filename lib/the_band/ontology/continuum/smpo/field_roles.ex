defmodule TheBand.Ontology.Continuum.SMPO.FieldRoles do
  @moduledoc """
  Declarar, revogar e ler o papel de cada campo de iteração — issue #514.

  A declaração é por **quadro E campo**: o mesmo nome significa coisas diferentes em
  quadros diferentes, e os seis quadros com `Quarter` também têm `Sprint`. Declarar por
  nome de campo sozinho decidiria por quadros que ninguém olhou.
  """
  import Ecto.Query

  alias TheBand.Ontology.Continuum.SMPO.Schemas.IterationFieldRole
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @horizonte "planning_horizon"

  @doc """
  Declara o papel do campo naquele quadro, substituindo o anterior.

  Revogar e inserir na mesma transação: sem isso, uma falha entre as duas deixaria o
  quadro sem papel algum, e a leitura voltaria a tratar trimestre como sprint em silêncio.
  """
  @spec declare_field_role(Tenant.t(), Ecto.UUID.t(), String.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, IterationFieldRole.t()} | {:error, term()}
  def declare_field_role(%Tenant{id: tenant_id}, board_id, field_name, role, actor_id) do
    Repo.transaction(fn ->
      agora = DateTime.utc_now(:second)
      revogar(tenant_id, board_id, field_name, actor_id, agora)

      %IterationFieldRole{}
      |> IterationFieldRole.changeset(%{
        tenant_id: tenant_id,
        observed_project_id: board_id,
        field_name: field_name,
        role: role,
        declared_by_user_id: actor_id,
        declared_at: agora
      })
      |> Repo.insert()
      |> case do
        {:ok, papel} -> papel
        {:error, erro} -> Repo.rollback(erro)
      end
    end)
  end

  @doc "Revoga o papel vigente. Marca, e nunca apaga."
  @spec revoke_field_role(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, non_neg_integer()} | {:error, :not_declared}
  def revoke_field_role(%Tenant{id: tenant_id}, board_id, field_name, actor_id) do
    case revogar(tenant_id, board_id, field_name, actor_id, DateTime.utc_now(:second)) do
      {0, _} -> {:error, :not_declared}
      {n, _} -> {:ok, n}
    end
  end

  defp revogar(tenant_id, board_id, field_name, actor_id, agora) do
    Repo.update_all(
      from(p in IterationFieldRole,
        where:
          p.tenant_id == type(^tenant_id, :binary_id) and
            p.observed_project_id == type(^board_id, :binary_id) and
            p.field_name == ^field_name and is_nil(p.revoked_at)
      ),
      set: [revoked_at: agora, revoked_by_user_id: actor_id, updated_at: agora]
    )
  end

  @doc "Os papéis vigentes deste quadro, por nome de campo."
  @spec field_roles(Tenant.t(), Ecto.UUID.t()) :: %{String.t() => String.t()}
  def field_roles(%Tenant{id: tenant_id}, board_id) do
    Repo.all(
      from p in IterationFieldRole,
        where:
          p.tenant_id == type(^tenant_id, :binary_id) and
            p.observed_project_id == type(^board_id, :binary_id) and is_nil(p.revoked_at),
        select: {p.field_name, p.role}
    )
    |> Map.new()
  end

  @doc """
  Os campos de iteração que a coleta trouxe para este quadro, com **volume e duração
  média** — a evidência para a decisão, `FR-012` da 042 aplicada aqui.

  Mostrar duração é informar; recomendar seria escolher, e a plataforma não escolhe.
  Nenhum campo vem marcado como sugerido.
  """
  @spec iteration_fields(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def iteration_fields(%Tenant{id: tenant_id} = tenant, board_id) do
    papeis = field_roles(tenant, board_id)

    from(s in "sro_sprints",
      join: o in "observed_projects",
      on: o.number == s.board_number and o.tenant_id == s.tenant_id,
      where:
        s.tenant_id == type(^tenant_id, :binary_id) and
          o.id == type(^board_id, :binary_id),
      group_by: s.field_name,
      order_by: [desc: count(s.id)],
      select: %{
        field_name: s.field_name,
        iteracoes: count(s.id),
        duracao_media: fragment("round(avg(?))", s.duration_days),
        duracao_min: min(s.duration_days),
        duracao_max: max(s.duration_days)
      }
    )
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :papel, Map.get(papeis, &1.field_name)))
  end

  @doc """
  As iterações que a organização declarou serem **horizonte de planejamento**.

  Lidas de `sro_sprints`, e não copiadas: a declaração vale imediatamente para o que já
  foi coletado, e revogar devolve a linha à leitura de sprint sem migração nenhuma.
  """
  @spec planning_horizons(Tenant.t()) :: [map()]
  def planning_horizons(%Tenant{id: tenant_id}) do
    Repo.all(
      from s in "sro_sprints",
        join: o in "observed_projects",
        on: o.number == s.board_number and o.tenant_id == s.tenant_id,
        join: p in IterationFieldRole,
        on:
          p.observed_project_id == o.id and p.field_name == s.field_name and
            p.tenant_id == s.tenant_id and is_nil(p.revoked_at) and p.role == ^@horizonte,
        where: s.tenant_id == type(^tenant_id, :binary_id),
        order_by: [desc: s.started_on],
        select: %{
          id: type(s.id, :binary_id),
          title: s.title,
          board_title: s.board_title,
          field_name: s.field_name,
          started_on: s.started_on,
          ended_on: s.ended_on,
          duration_days: s.duration_days
        }
    )
  end

  @doc """
  Os `field_external_id` que este quadro declarou horizonte de planejamento.

  O papel é declarado pelo **nome** do campo — que é o que `sro_sprints` grava e o que a
  pessoa lê na tela. As iterações em `project_iterations` só carregam o id externo do
  campo, então a ponte é `project_field_definitions`. Um campo declarado cuja definição a
  coleta não trouxe simplesmente não aparece aqui: sem definição não há iteração para
  separar, e inventar o id produziria um horizonte que não corresponde a nada.
  """
  @spec horizon_field_external_ids(Tenant.t(), Ecto.UUID.t()) :: MapSet.t(String.t())
  def horizon_field_external_ids(%Tenant{id: tenant_id}, board_id) do
    from(d in "project_field_definitions",
      join: p in IterationFieldRole,
      on:
        p.observed_project_id == d.observed_project_id and p.field_name == d.name and
          p.tenant_id == d.tenant_id and is_nil(p.revoked_at) and p.role == ^@horizonte,
      where:
        d.tenant_id == type(^tenant_id, :binary_id) and
          d.observed_project_id == type(^board_id, :binary_id),
      select: d.field_external_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Este campo, neste quadro, foi declarado horizonte de planejamento?"
  @spec horizon_field?(Tenant.t(), Ecto.UUID.t(), String.t()) :: boolean()
  def horizon_field?(tenant, board_id, field_name) do
    Map.get(field_roles(tenant, board_id), field_name) == @horizonte
  end
end
