defmodule TheBand.Projects.Schemas.Item do
  @moduledoc """
  Um item do quadro — feature 004 F7 (T049 e T050).

  `collected_issue_id` **nulo com `is_draft: true` é rascunho** (FR-022): item sem
  trabalho associado, registrado em vez de descartado. Rascunho não promove a nada —
  é intenção de alguém, não escopo do produto. A constraint do banco impede as duas
  coisas ao mesmo tempo: um item com issue **e** marcado rascunho afirmaria trabalho
  e o negaria na mesma linha.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "project_items" do
    field :tenant_id, :binary_id
    field :observed_project_id, :binary_id
    field :collected_issue_id, :binary_id

    field :is_draft, :boolean, default: false

    field :source_system, :string
    field :source_instance, :string
    field :source_external_id, :string

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_project_id collected_issue_id is_draft source_system
             source_instance source_external_id collected_at last_observed_at
             no_longer_observed_at)a

  @obrigatorios ~w(tenant_id observed_project_id source_system source_instance
                   source_external_id collected_at last_observed_at)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :source_external_id],
      name: :project_items_application_reference_index
    )
    |> check_constraint(:is_draft, name: :project_items_rascunho_sem_issue)
  end
end
