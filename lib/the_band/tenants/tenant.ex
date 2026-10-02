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

  @estados ~w(active suspended)

  # `:status` NÃO está no `cast` — spec 070, T013, achado O10. Com ele castável, qualquer chamador
  # de `create_tenant/1` ou deste changeset mudava o estado da organização sem episódio, sem autor
  # e sem razão. O estado só muda pela suspensão e pela reativação do operador da plataforma
  # (`Tenants.trocar_estado/3`). A validação e a constraint ficam para o valor que entra
  # pelo `default` ou por aquele caminho.
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "usa apenas minúsculas, números e hífen")
    |> validate_inclusion(:status, @estados)
    |> unique_constraint(:slug)
    |> check_constraint(:status, name: :tenants_status_valido)
  end
end
