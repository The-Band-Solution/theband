defmodule TheBand.Ontology.SEON.SPO.EndCriterion do
  @moduledoc """
  Qual evento marca o **fim** do trabalho, por quadro — feature 066.

  Espelha `StartCriterion`: mesmo alvo, mesma precedência (quadro sobre projeto), mesma
  resolução **na leitura**, mesmo "revogar marca". A diferença é a pergunta, e o dado que a
  exige: quadros da mesma organização terminam de maneiras diferentes, e a plataforma vinha
  assumindo uma delas para todos.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.ActivityEndCriterion, as: Criterio
  alias TheBand.Ontology.SEON.SPO.StartCriterion
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type alvo :: {:board, Ecto.UUID.t()} | {:project, Ecto.UUID.t()}

  @doc """
  Declara o evento que marca o fim. Só aceita tipo que a coleta **traz** — declarar o que não
  se observa produziria um critério que nunca resolve, e a ausência ficaria parecendo defeito.
  """
  @spec declare(Tenant.t(), alvo(), String.t(), Ecto.UUID.t()) ::
          {:ok, Criterio.t()} | {:error, :unknown_event_type | Ecto.Changeset.t()}
  def declare(%Tenant{id: tenant_id} = tenant, alvo, event_type, actor_id) do
    if event_type in Enum.map(StartCriterion.collected_event_types(tenant), & &1.event_type) do
      Repo.transaction(fn -> substituir(tenant, tenant_id, alvo, event_type, actor_id) end)
    else
      {:error, :unknown_event_type}
    end
  end

  @doc "Revoga o critério vigente do alvo. Marca — e nunca apaga."
  @spec revoke(Tenant.t(), alvo(), Ecto.UUID.t()) ::
          {:ok, Criterio.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def revoke(%Tenant{} = tenant, alvo, actor_id) do
    case current(tenant, alvo) do
      nil ->
        {:error, :not_found}

      criterio ->
        criterio
        |> Criterio.revogar_changeset(%{
          revoked_by_user_id: actor_id,
          revoked_at: DateTime.utc_now(:second)
        })
        |> Repo.update()
    end
  end

  @doc "O critério vigente do alvo, ou `nil`."
  @spec current(Tenant.t(), alvo()) :: Criterio.t() | nil
  def current(%Tenant{id: tenant_id}, alvo) do
    Repo.one(
      from(c in Criterio,
        where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.revoked_at),
        where: ^condicao_do_alvo(alvo)
      )
    )
  end

  # Revoga e insere na mesma transação — nunca `update`, que apagaria quem declarou antes.
  defp substituir(tenant, tenant_id, alvo, event_type, actor_id) do
    agora = DateTime.utc_now(:second)

    case current(tenant, alvo) do
      nil ->
        :ok

      vigente ->
        vigente
        |> Criterio.revogar_changeset(%{revoked_by_user_id: actor_id, revoked_at: agora})
        |> Repo.update!()
    end

    attrs =
      Map.merge(campo_do_alvo(alvo), %{
        tenant_id: tenant_id,
        event_type: event_type,
        declared_by_user_id: actor_id,
        declared_at: agora
      })

    case Repo.insert(Criterio.declarar_changeset(%Criterio{}, attrs)) do
      {:ok, criterio} -> criterio
      {:error, motivo} -> Repo.rollback(motivo)
    end
  end

  defp campo_do_alvo({:board, id}), do: %{observed_project_id: id}
  defp campo_do_alvo({:project, id}), do: %{project_id: id}

  defp condicao_do_alvo({:board, id}),
    do: dynamic([c], c.observed_project_id == type(^id, :binary_id))

  defp condicao_do_alvo({:project, id}),
    do: dynamic([c], c.project_id == type(^id, :binary_id))
end
