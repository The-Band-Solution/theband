defmodule TheBand.Projects.Schemas.FieldDefinition do
  @moduledoc """
  A definição de um campo configurável do quadro — feature 004 F7 (T048).

  **A identidade é `field_external_id`** (FR-027): renomear "Priority" para
  "Prioridade" atualiza `name` da mesma linha, não cria campo novo, e não invalida o
  mapeamento declarado. `options` só existe em seleção única — nos demais é `nil`,
  ausência real e não lista vazia.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "project_field_definitions" do
    field :tenant_id, :binary_id
    field :observed_project_id, :binary_id

    field :field_external_id, :string
    field :name, :string
    field :data_type, :string
    field :options, {:array, :map}

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_project_id field_external_id name data_type options
             collected_at last_observed_at no_longer_observed_at)a

  @obrigatorios ~w(tenant_id observed_project_id field_external_id name data_type
                   collected_at last_observed_at)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(campo, attrs) do
    campo
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> unique_constraint([:tenant_id, :observed_project_id, :field_external_id],
      name: :project_field_definitions_identidade_index
    )
  end
end
