defmodule TheBand.Ontology.SEON.SPO.Schemas.ProjectOrganization do
  @moduledoc """
  O vínculo entre um projeto declarado e uma organização observada — feature 028.

  Declarado por pessoa, nunca observado. Desfazer **marca**, com autor e data, e religar
  cria linha nova — a história dos vínculos é o dado, como em projeto↔repositório.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_project_organizations" do
    field :tenant_id, :binary_id
    field :project_id, :binary_id
    field :organization_id, :binary_id

    field :linked_by_user_id, :binary_id
    field :linked_at, :utc_datetime
    field :unlinked_by_user_id, :binary_id
    field :unlinked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(vinculo, attrs) do
    vinculo
    |> cast(attrs, [
      :tenant_id,
      :project_id,
      :organization_id,
      :linked_by_user_id,
      :linked_at,
      :unlinked_by_user_id,
      :unlinked_at
    ])
    |> validate_required([:tenant_id, :project_id, :organization_id, :linked_at])
    |> unique_constraint(:organization_id, name: :spo_project_organizations_vigente_index)
  end
end
