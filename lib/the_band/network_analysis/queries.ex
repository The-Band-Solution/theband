defmodule TheBand.NetworkAnalysis.Queries do
  @moduledoc """
  As leituras vigentes da análise de rede — feature 076, T014/T017. Privado a
  `TheBand.NetworkAnalysis`: devolve a struct do schema só para `Commands` e `Reader`, que nunca a
  entregam a quem consulta.

  Toda consulta filtra por tenant **e** organização.

  Depende de: nenhuma ontologia.
  """

  import Ecto.Query

  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc "As impressões digitais vigentes da organização, por `{rede, janela}`."
  @spec fingerprints(Tenant.t(), Ecto.UUID.t()) :: %{{String.t(), pos_integer()} => String.t()}
  def fingerprints(%Tenant{id: tenant_id}, organization_id) do
    from(r in Reading,
      where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id,
      select: {{r.network, r.window_days}, r.fingerprint}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "A leitura vigente de `(tenant, organização, rede, janela)`, ou `nil`."
  @spec current(Tenant.t(), Ecto.UUID.t(), String.t(), pos_integer()) :: Reading.t() | nil
  def current(%Tenant{id: tenant_id}, organization_id, rede, dias) do
    Repo.one(
      from r in Reading,
        where:
          r.tenant_id == ^tenant_id and r.organization_id == ^organization_id and
            r.network == ^rede and r.window_days == ^dias
    )
  end
end
