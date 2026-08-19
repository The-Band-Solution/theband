defmodule TheBand.Configuration.Commands do
  @moduledoc "Gravação das linhas de desenvolvimento — feature 039, `cmpo.branch`."

  import Ecto.Query

  alias TheBand.Configuration.Schemas.Branch
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @spec record_branch(Tenant.t(), map()) :: {:ok, Branch.t()} | {:error, Ecto.Changeset.t()}
  def record_branch(%Tenant{id: tenant_id}, attrs) do
    now = DateTime.utc_now(:second)

    base =
      Repo.get_by(Branch, tenant_id: tenant_id, external_id: attrs[:external_id]) || %Branch{}

    base
    |> Branch.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || now)
      |> Map.put(:last_observed_at, now)
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end

  @doc """
  Marca as branches que sumiram do repositório — **branch apagada é marcada, nunca removida**.

  Ela existiu, e o check-in que aconteceu nela continua sendo fato sobre o processo. Apagar a
  linha faria a plataforma perder a única evidência de que a mudança passou por ali.

  **Marca por conjunto observado, nunca por timestamp**: comparar `last_observed_at < now`
  falha quando as duas gravações caem no mesmo segundo, e foi o defeito da feature 032.
  """
  @spec mark_unobserved(Tenant.t(), Ecto.UUID.t(), [String.t()]) :: non_neg_integer()
  def mark_unobserved(%Tenant{id: tenant_id}, observed_repository_id, observados) do
    consulta =
      from b in Branch,
        where:
          b.tenant_id == ^tenant_id and
            b.observed_repository_id == ^observed_repository_id and
            is_nil(b.no_longer_observed_at)

    consulta =
      if observados == [],
        do: consulta,
        else: where(consulta, [b], b.external_id not in ^observados)

    {quantos, _} =
      Repo.update_all(consulta, set: [no_longer_observed_at: DateTime.utc_now(:second)])

    quantos
  end

  @doc "Marca o repositório como percorrido, com o total que a origem informou."
  @spec touch_repository(Ecto.UUID.t(), DateTime.t(), integer()) :: :ok
  def touch_repository(repo_id, quando, total) do
    Repo.update_all(
      from(r in "observed_repositories", where: r.id == type(^repo_id, :binary_id)),
      set: [branches_collected_at: quando, branches_total: total]
    )

    :ok
  end
end
