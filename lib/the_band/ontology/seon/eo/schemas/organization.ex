defmodule TheBand.Ontology.SEON.EO.Schemas.Organization do
  @moduledoc """
  `eo.organization` — agente social que reconhece papéis organizacionais e
  emprega pessoas.

  Privado ao módulo EO. Nenhum outro módulo alcança este schema; a fronteira é
  `TheBand.Ontology.SEON.EO` (ADR 0003).
  """

  use Ecto.Schema

  import Ecto.Changeset
  import TheBand.Provenance.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "eo_organizations" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :name, :string
    field :login, :string
    field :parent_organization_id, :binary_id

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :collected_at, :utc_datetime

    # Resultado da última escrita — :created, :updated ou :unchanged.
    # Virtual porque descreve o que aconteceu na chamada, não o registro.
    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def from_source_changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :tenant_id,
      :internal_id,
      :record_version,
      :name,
      :login,
      :parent_organization_id,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> validate_required([:tenant_id, :internal_id])
    |> validate_application_reference()
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :external_id],
      name: :eo_organizations_application_reference_index
    )
  end
end
