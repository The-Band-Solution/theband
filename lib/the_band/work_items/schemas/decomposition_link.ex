defmodule TheBand.WorkItems.Schemas.DecompositionLink do
  @moduledoc """
  Um vínculo de decomposição observado: pai e parte.

  É deste conjunto que a classificação épico/atômica é derivada. Nada guarda a
  classificação — ela sai da existência de partes que são user stories.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "decomposition_links" do
    field :tenant_id, :binary_id
    field :parent_issue_id, :binary_id
    field :child_issue_id, :binary_id

    field :observed_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :tenant_id,
      :parent_issue_id,
      :child_issue_id,
      :observed_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([:tenant_id, :parent_issue_id, :child_issue_id, :observed_at])
    |> unique_constraint([:parent_issue_id, :child_issue_id])
    |> check_constraint(:parent_issue_id,
      name: :decomposition_links_no_self_parent,
      message: "uma issue não é parte de si mesma"
    )
  end
end
