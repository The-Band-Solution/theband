defmodule TheBand.Ontology.SEON.EO.Schemas.OrganizationalRole do
  @moduledoc """
  `eo.organizational_role` — papel social reconhecido pela organização.

  Catálogo reificado: papel é **linha**, não valor de enum (ADR 0004, D6). Papel
  novo é um `INSERT`, não uma migração, e cada tenant define os seus.

  Esta tabela nasce vazia na feature 001: o GitHub não fornece papel
  organizacional, e `MAINTAINER`/`MEMBER` não são papéis.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "eo_organizational_roles" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :code, :string
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:tenant_id, :internal_id, :record_version, :code, :name])
    |> validate_required([:tenant_id, :internal_id, :code, :name])
    # **O erro cai em `:code`**, e não em `:tenant_id`. `unique_constraint/2` com lista põe a
    # mensagem no primeiro campo, e ninguém digita o tenant: quem preenche o formulário
    # preenche o código, e é lá que a mensagem precisa aparecer.
    |> unique_constraint(:code, name: :eo_organizational_roles_tenant_id_code_index)
  end
end
