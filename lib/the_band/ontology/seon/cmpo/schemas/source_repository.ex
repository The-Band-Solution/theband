defmodule TheBand.Ontology.SEON.CMPO.Schemas.SourceRepository do
  @moduledoc """
  `cmpo.source_repository` — a extensão, com os atributos próprios do repositório.

  A identidade **não está aqui**: Application Reference, `internal_id` e o par de
  observação vivem na tabela do kind. Aqui ficam só os atributos que o kind não teria
  como ter, porque não valem para um servidor de CI nem para um ambiente de build.

  ## `archived_at` não é ausência

  Arquivado é fato da origem. Não mais observado é inferência da plataforma, e vive na
  tabela do kind. Um repositório arquivado continua observado.

  ## Sem `is_fork`

  Ser fork é a cópia derivar de outra cópia — relação, não propriedade. Um booleano
  guardaria que existe origem e perderia qual é.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "cmpo_source_repositories" do
    field :tenant_id, :binary_id
    field :loaded_software_system_copy_id, :binary_id
    field :organization_id, :binary_id

    field :name, :string
    field :qualified_name, :string
    field :url, :string
    field :description, :string
    field :primary_language, :string
    field :default_branch, :string
    field :archived_at, :utc_datetime
    field :external_created_at, :utc_datetime
    field :last_pushed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(repo, attrs) do
    repo
    |> cast(attrs, [
      :tenant_id,
      :loaded_software_system_copy_id,
      :organization_id,
      :name,
      :qualified_name,
      :url,
      :description,
      :primary_language,
      :default_branch,
      :archived_at,
      :external_created_at,
      :last_pushed_at
    ])
    |> validate_required([
      :tenant_id,
      :loaded_software_system_copy_id,
      :organization_id,
      :name,
      :qualified_name,
      :url
    ])
    |> unique_constraint(:loaded_software_system_copy_id)
  end
end
