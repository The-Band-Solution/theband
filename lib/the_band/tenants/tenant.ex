defmodule TheBand.Tenants.Tenant do
  @moduledoc """
  Organização cliente — a fronteira de isolamento (FR-001).

  Não confundir com `TheBand.Ontology.SEON.EO.Schemas.Organization`, que é a
  organização **observada** na ferramenta de origem. São coisas diferentes: uma
  é quem usa a plataforma, a outra é o que a plataforma conhece.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :status, :string, default: "active"

    has_many :users, TheBand.Tenants.User

    timestamps(type: :utc_datetime)
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :status])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "usa apenas minúsculas, números e hífen")
    |> unique_constraint(:slug)
  end
end
