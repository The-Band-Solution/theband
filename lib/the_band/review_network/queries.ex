defmodule TheBand.ReviewNetwork.Queries do
  @moduledoc """
  A leitura vigente da rede de revisão — feature 073, T016. Privado a `TheBand.ReviewNetwork`:
  devolve a struct do schema só para o `Reader`, que nunca a entrega a quem consulta.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.ReviewNetwork.Schemas.Reading
  alias TheBand.Tenants.Tenant

  @doc "A leitura vigente de `(tenant, organização, janela)`, ou `nil` quando não foi calculada."
  @spec current(Tenant.t(), Ecto.UUID.t(), pos_integer()) :: Reading.t() | nil
  def current(%Tenant{id: tenant_id}, organization_id, window_days) do
    Repo.one(
      from r in Reading,
        where:
          r.tenant_id == ^tenant_id and r.organization_id == ^organization_id and
            r.window_days == ^window_days
    )
  end
end
