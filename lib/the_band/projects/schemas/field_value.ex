defmodule TheBand.Projects.Schemas.FieldValue do
  @moduledoc """
  O valor de um campo em um item — feature 004 F7 (T051).

  **`raw_value` é sempre gravado; `interpreted_as` só quando há mapeamento declarado**
  (FR-025). `interpreted_as: nil` não é falha — é o caso comum, e é o que a tela mostra
  como *não interpretado*. Converter por semelhança de nome é o antipadrão de
  `AGENTS.md` §7.7: `Priority` não é `importance`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "item_field_values" do
    field :tenant_id, :binary_id
    field :project_item_id, :binary_id
    field :project_field_definition_id, :binary_id

    field :raw_value, :map
    field :interpreted_as, :string

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id project_item_id project_field_definition_id raw_value interpreted_as
             collected_at last_observed_at)a

  @obrigatorios ~w(tenant_id project_item_id project_field_definition_id raw_value
                   collected_at last_observed_at)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(valor, attrs) do
    valor
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> unique_constraint([:tenant_id, :project_item_id, :project_field_definition_id],
      name: :item_field_values_um_por_campo_index
    )
  end
end
