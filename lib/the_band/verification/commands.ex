defmodule TheBand.Verification.Commands do
  @moduledoc "Gravação das verificações — feature 037. Mesmo contrato das demais coletas."

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.Verification.Schemas.{CollectedVerification, VerificationComponent}

  @spec record_verification(Tenant.t(), map()) ::
          {:ok, CollectedVerification.t()} | {:error, Ecto.Changeset.t()}
  def record_verification(%Tenant{id: tenant_id}, attrs) do
    upsert(CollectedVerification, tenant_id, attrs[:external_id], attrs)
  end

  @spec record_component(Tenant.t(), map()) ::
          {:ok, VerificationComponent.t()} | {:error, Ecto.Changeset.t()}
  def record_component(%Tenant{id: tenant_id}, attrs) do
    upsert(VerificationComponent, tenant_id, attrs[:external_id], attrs)
  end

  # Reexecução reescreve a mesma execução: o `external_id` do run não muda entre
  # tentativas, e `attempt` guarda qual é a vigente. Passar na terceira é sucesso.
  defp upsert(schema, tenant_id, external_id, attrs) do
    now = DateTime.utc_now(:second)
    base = Repo.get_by(schema, tenant_id: tenant_id, external_id: external_id) || struct(schema)

    base
    |> schema.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || now)
      |> Map.put(:last_observed_at, now)
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end

  @doc "Marca o repositório como percorrido — o checkpoint do incremental."
  @spec touch_repository(Ecto.UUID.t(), DateTime.t()) :: :ok
  def touch_repository(repo_id, quando) do
    Repo.update_all(
      from(r in "observed_repositories", where: r.id == type(^repo_id, :binary_id)),
      set: [verifications_collected_at: quando]
    )

    :ok
  end
end
