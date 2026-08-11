defmodule TheBand.Ontology.SEON.CMPO.Schemas.ObservedRepository do
  @moduledoc """
  O que a plataforma decidiu sobre um repositório — camada de plataforma.

  Três situações, e **duas delas não marcam ausência**: excluído é decisão do tenant,
  inacessível é falha de alcance da credencial. As duas impedem a coleta, e nenhuma
  significa que o dado sumiu.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "observed_repositories" do
    field :tenant_id, :binary_id
    field :connected_tool_id, :binary_id
    field :source_repository_id, :binary_id

    field :excluded_at, :utc_datetime
    field :excluded_by_user_id, :binary_id
    field :inaccessible_since, :utc_datetime
    field :inaccessible_reason, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(observed, attrs) do
    observed
    |> cast(attrs, [
      :tenant_id,
      :connected_tool_id,
      :source_repository_id,
      :excluded_at,
      :excluded_by_user_id,
      :inaccessible_since,
      :inaccessible_reason
    ])
    |> validate_required([:tenant_id, :connected_tool_id, :source_repository_id])
    |> unique_constraint([:connected_tool_id, :source_repository_id])
    |> check_constraint(:excluded_by_user_id,
      name: :observed_repositories_exclusion_has_author,
      message: "exclusão é decisão, e decisão tem autor"
    )
  end
end
