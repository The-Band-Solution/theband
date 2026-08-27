defmodule TheBand.Ontology.Continuum.SMPO.Schemas.IterationFieldRole do
  @moduledoc """
  O que a organização declara que um campo de iteração significa — issue #514.

  Não é conceito da SMPO: é a **declaração** que decide se as iterações daquele campo são
  lidas como `sro.sprint` ou como `smpo.planning_quarter`. O mesmo papel que o
  `spo.activity_start_criterion` cumpre para o instante de início.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @papeis ~w(sprint planning_horizon)

  @type t :: %__MODULE__{}

  schema "smpo_iteration_field_roles" do
    field :tenant_id, :binary_id
    field :observed_project_id, :binary_id
    field :field_name, :string
    field :role, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "Os papéis que a tela oferece. A lista é da interface, e não do banco."
  @spec papeis() :: [String.t()]
  def papeis, do: @papeis

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(papel, attrs) do
    papel
    |> cast(attrs, [
      :tenant_id,
      :observed_project_id,
      :field_name,
      :role,
      :declared_by_user_id,
      :declared_at,
      :revoked_by_user_id,
      :revoked_at
    ])
    |> validate_required([:tenant_id, :observed_project_id, :field_name, :role, :declared_at])
    |> validate_inclusion(:role, @papeis)
    |> unique_constraint(:field_name, name: :smpo_papel_vigente_do_campo_index)
  end
end
