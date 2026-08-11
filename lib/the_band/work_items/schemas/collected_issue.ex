defmodule TheBand.WorkItems.Schemas.CollectedIssue do
  @moduledoc """
  A issue como a origem a devolveu — camada de plataforma.

  `issue_type` fica **cru**. Normalizar destruiria o dado que a lacuna precisa mostrar:
  a tela exibe o nome do tipo encontrado, e "tipo desconhecido" sem o nome não diz onde
  a regra precisa mudar.

  `number` é para exibir e localizar, **nunca para identificar**: mover a issue entre
  repositórios cria outro número no destino.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_issues" do
    field :tenant_id, :binary_id
    field :observed_repository_id, :binary_id

    field :number, :integer
    field :title, :string
    field :state, :string

    field :issue_type, :string
    field :issue_type_external_id, :string

    field :external_parent_id, :string
    field :sub_issue_count, :integer, default: 0

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :external_created_at, :utc_datetime
    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [
      :tenant_id,
      :observed_repository_id,
      :number,
      :title,
      :state,
      :issue_type,
      :issue_type_external_id,
      :external_parent_id,
      :sub_issue_count,
      :source_system,
      :source_instance,
      :external_id,
      :external_created_at,
      :collected_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([
      :tenant_id,
      :observed_repository_id,
      :number,
      :title,
      :state,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :external_id],
      name: :collected_issues_application_reference_index
    )
  end
end
