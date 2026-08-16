defmodule TheBand.Projects.Schemas.ObservedProject do
  @moduledoc """
  O quadro como a origem o devolve — artefato de fonte, feature 004 F7 (T047).

  **Não há campo de promoção, e a ausência é o desenho** (FR-020): quadro é
  planejamento e visualização, nunca o empreendimento. `rules/github_project_board.yaml`
  nomeia os três conceitos que ele não vira. Quem promove é o conteúdo — iterações e
  itens.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "observed_projects" do
    field :tenant_id, :binary_id
    field :connected_tool_id, :binary_id

    field :number, :integer
    field :title, :string
    field :closed, :boolean, default: false

    field :source_system, :string
    field :source_instance, :string
    field :source_external_id, :string

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id connected_tool_id number title closed source_system source_instance
             source_external_id collected_at last_observed_at no_longer_observed_at)a

  @obrigatorios ~w(tenant_id connected_tool_id number title source_system source_instance
                   source_external_id collected_at last_observed_at)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(quadro, attrs) do
    quadro
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :source_external_id],
      name: :observed_projects_application_reference_index
    )
  end
end
