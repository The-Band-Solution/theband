defmodule TheBand.Quality.Commands do
  @moduledoc "Gravação das avaliações de artefato — feature 039."

  import Ecto.Query

  alias TheBand.Quality.Schemas.ArtifactEvaluation
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @spec record_evaluation(Tenant.t(), map()) ::
          {:ok, ArtifactEvaluation.t()} | {:error, Ecto.Changeset.t()}
  def record_evaluation(%Tenant{id: tenant_id}, attrs) do
    now = DateTime.utc_now(:second)

    base =
      Repo.get_by(ArtifactEvaluation, tenant_id: tenant_id, external_id: attrs[:external_id]) ||
        %ArtifactEvaluation{}

    base
    |> ArtifactEvaluation.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || now)
      |> Map.put(:last_observed_at, now)
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end

  @doc """
  Marca as avaliações que sumiram da solicitação.

  **Marca por conjunto observado, nunca por timestamp** — comparar `last_observed_at < now`
  falha quando as duas gravações caem no mesmo segundo, e foi o defeito da feature 032.

  Lista vazia marca todas: solicitação que perdeu as reviews é fato sobre o registro.
  """
  @spec mark_unobserved(Tenant.t(), Ecto.UUID.t(), [String.t()]) :: non_neg_integer()
  def mark_unobserved(%Tenant{id: tenant_id}, change_request_id, observados) do
    consulta =
      from a in ArtifactEvaluation,
        where:
          a.tenant_id == ^tenant_id and
            a.collected_change_request_id == ^change_request_id and
            is_nil(a.no_longer_observed_at)

    consulta =
      if observados == [],
        do: consulta,
        else: where(consulta, [a], a.external_id not in ^observados)

    {quantos, _} =
      Repo.update_all(consulta, set: [no_longer_observed_at: DateTime.utc_now(:second)])

    quantos
  end

  @doc "O total que a origem informou — o que revela truncamento da consulta."
  @spec record_reviews_total(Tenant.t(), Ecto.UUID.t(), integer()) :: :ok
  def record_reviews_total(%Tenant{id: tenant_id}, change_request_id, total) do
    Repo.update_all(
      from(c in "collected_change_requests",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.id == type(^change_request_id, :binary_id)
      ),
      set: [reviews_total: total]
    )

    :ok
  end
end
