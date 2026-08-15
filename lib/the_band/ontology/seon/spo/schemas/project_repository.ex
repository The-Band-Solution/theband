defmodule TheBand.Ontology.SEON.SPO.Schemas.ProjectRepository do
  @moduledoc """
  O vínculo entre um projeto e um repositório observado.

  **Declarado por pessoa, e nunca observado**: a origem não diz a que projeto um
  repositório pertence, e inferir de nome ou organização produziria agrupamento que
  ninguém decidiu.

  Desfazer **marca**, com autor e data, e nunca apaga — trocar um repositório de projeto
  preserva os dois registros.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_project_repositories" do
    field :tenant_id, :binary_id
    field :project_id, :binary_id
    field :observed_repository_id, :binary_id

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
      :observed_repository_id,
      :linked_by_user_id,
      :linked_at,
      :unlinked_by_user_id,
      :unlinked_at
    ])
    |> validate_required([:tenant_id, :project_id, :observed_repository_id, :linked_at])
    |> unique_constraint(:observed_repository_id,
      name: :spo_project_repositories_vigente_index
    )
  end
end
