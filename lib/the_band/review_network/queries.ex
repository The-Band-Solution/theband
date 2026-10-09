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

  @doc """
  As leituras vigentes da organização, por janela, **só com ids** — a entrada da rede de revisão
  da análise de rede (076, T028; `contracts/fronteiras.md`, `current_edges/2`).

  `source` é quem revisou, `target` quem abriu, `weight` as solicitações distintas. As exclusões
  levam o motivo da versão 2 (`organization_account`), nulo na leitura da versão 1. Mapa vazio
  quando não há leitura. **Não aplica alcance**: é para o cálculo, e não para a tela.
  """
  @spec current_edges(Tenant.t(), Ecto.UUID.t()) :: %{pos_integer() => map()}
  def current_edges(%Tenant{id: tenant_id}, organization_id) do
    Repo.all(
      from r in Reading,
        where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id
    )
    |> Map.new(fn r ->
      {r.window_days,
       %{
         edges:
           r.edges
           |> Enum.map(fn %{"reviewer" => s, "author" => t, "change_requests" => n} ->
             %{source: s, target: t, weight: n}
           end)
           |> Enum.sort_by(&{&1.source, &1.target}),
         excluded: %{
           self_review: r.excluded_self_review,
           bot_or_app: r.excluded_bot_or_app,
           organization_account: r.excluded_organization_account,
           unlinked_person: r.excluded_unlinked
         },
         reviews: r.reviews_in_network,
         computed_at: r.computed_at
       }}
    end)
  end
end
