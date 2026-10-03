defmodule TheBand.ReviewNetwork.Schemas.Reading do
  @moduledoc """
  A leitura vigente da rede de revisão de uma organização observada, numa janela — feature 073.

  **Privado a `TheBand.ReviewNetwork`.** Ninguém fora do módulo toca este schema nem a tabela
  `review_network_readings` (`contracts/review-network.md`).

  Guarda **ids de pessoa, e nunca nome nem login** (R3, R7 da segurança): o nome se resolve na
  hora de ler, por `EO.people_names/2`, que filtra pelo tenant. Grupos e concentração **não** são
  guardados: dependem do alcance de quem lê, e são recalculados a cada leitura (D5).

  Depende de: EO (a organização observada, pela FK composta).
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "review_network_readings" do
    field :tenant_id, :binary_id
    field :organization_id, :binary_id
    field :window_days, :integer
    field :window_start, :utc_datetime
    field :window_end, :utc_datetime
    field :computed_at, :utc_datetime
    field :edges, {:array, :map}
    field :people, {:array, :map}
    field :reviews_in_network, :integer
    field :excluded_self_review, :integer
    field :excluded_bot_or_app, :integer
    field :excluded_unlinked, :integer
    field :knowledge_versions, :map

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @campos [
    :tenant_id,
    :organization_id,
    :window_days,
    :window_start,
    :window_end,
    :computed_at,
    :edges,
    :people,
    :reviews_in_network,
    :excluded_self_review,
    :excluded_bot_or_app,
    :excluded_unlinked,
    :knowledge_versions
  ]

  @doc """
  O changeset de gravação. Só o cálculo grava, e só substituindo (FR-011).
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(leitura, attrs) do
    leitura
    |> cast(attrs, @campos)
    |> validate_required(@campos)
    |> validate_number(:window_days, greater_than: 0)
    |> foreign_key_constraint(:organization_id,
      name: :review_network_readings_organization_id_fkey
    )
    |> unique_constraint([:tenant_id, :organization_id, :window_days],
      name: :review_network_readings_vigente_index
    )
    |> check_constraint(:window_end, name: :review_network_readings_window_ordered)
    |> check_constraint(:reviews_in_network,
      name: :review_network_readings_counts_non_negative
    )
  end
end
