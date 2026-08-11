defmodule TheBand.Ontology.SEON.CMPO.Schemas.LoadedSoftwareSystemCopy do
  @moduledoc """
  `sys_swo.loaded_software_system_copy` — o kind que CMPO referencia.

  **Vive em CMPO por conveniência de fronteira, e a tabela é de SysSwO.** Quando a
  SysSwO ganhar módulo próprio, este schema muda de lugar e a tabela não muda de nome:
  é o que a referência garante — a tabela é uma só, e quem a lê aponta para ela.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @types ~w(source_repository)

  schema "sys_swo_loaded_software_system_copies" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :type, :string

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec types() :: [String.t()]
  def types, do: @types

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(copy, attrs) do
    copy
    |> cast(attrs, [
      :tenant_id,
      :internal_id,
      :record_version,
      :type,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([
      :tenant_id,
      :internal_id,
      :type,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> validate_inclusion(:type, @types)
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :external_id],
      name: :sys_swo_copies_application_reference_index
    )
  end
end
