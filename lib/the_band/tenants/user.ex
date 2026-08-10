defmodule TheBand.Tenants.User do
  @moduledoc """
  Pessoa usuária da plataforma, ligada a exatamente um tenant.

  `role` distingue quem pode conectar ferramenta e gerenciar credencial
  (`admin`) de quem apenas consulta (`member`) — Assumptions da spec. Um modelo
  de permissões mais rico fica para depois.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(admin member)

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "member"

    belongs_to :tenant, TheBand.Tenants.Tenant

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :tenant_id])
    |> validate_required([:email, :tenant_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
  end

  @spec admin?(t()) :: boolean()
  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false
end
