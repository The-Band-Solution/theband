defmodule TheBand.WorkItems.Schemas.IssueLabel do
  @moduledoc """
  Os rótulos que a origem dá à issue — preservados, nunca promovidos.

  Um rótulo chamado `bug` **não** faz a issue um defeito. Quem decide o conceito é o
  tipo declarado ou a regra da organização; promover por semelhança de nome é o
  antipadrão que o princípio I proíbe.

  Esta tabela existe justamente para registrar o rótulo sem agir sobre ele: sem ela, a
  tela não teria como mostrar o que a origem diz, e a tentação de inferir a partir do
  nome voltaria.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "issue_labels" do
    field :tenant_id, :binary_id
    field :collected_issue_id, :binary_id
    field :name, :string
    field :color, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(label, attrs) do
    label
    |> cast(attrs, [:tenant_id, :collected_issue_id, :name, :color])
    |> validate_required([:tenant_id, :collected_issue_id, :name])
    |> unique_constraint([:collected_issue_id, :name])
  end
end
