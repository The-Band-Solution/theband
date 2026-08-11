defmodule TheBand.Mapping.Schemas.UnmappedPatternDecision do
  @moduledoc """
  O registro de que um padrão **não** designa tipo — pendência virando ausência declarada.

  `[Devops]`, `[Back-end]`, `[QA]` dizem quem faz ou em que área, não o que a issue é.
  Sem este registro eles ficam para sempre na lista de pendências, e a insistência empurra
  alguém a mapear área como tipo.

  A decisão é **reversível**, e a reversão é um fato novo: `reverted_at` e `reverted_by_id`
  são preenchidos, e o registro de quem decidiu o quê permanece.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "unmapped_pattern_decisions" do
    field :tenant_id, :binary_id
    field :organization_id, :binary_id
    field :pattern, :string
    field :decided_by_id, :binary_id
    field :decided_at, :utc_datetime
    field :reverted_at, :utc_datetime
    field :reverted_by_id, :binary_id
    field :note, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :tenant_id,
      :organization_id,
      :pattern,
      :decided_by_id,
      :decided_at,
      :reverted_at,
      :reverted_by_id,
      :note
    ])
    |> validate_required([:tenant_id, :organization_id, :pattern, :decided_by_id, :decided_at])
    |> unique_constraint([:organization_id, :pattern])
  end
end
