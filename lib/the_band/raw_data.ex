defmodule TheBand.RawData do
  @moduledoc """
  Payload bruto preservado sem alteração (FR-011).

  É o que torna FR-017 possível: reprocessar com mapeamento corrigido lê daqui e
  **não** consulta a origem de novo. Guardamos junto o `mapping_id` e a
  `mapping_version` aplicados, para que a diferença entre duas leituras do mesmo
  payload seja explicável.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "raw_payloads" do
    field :tenant_id, :binary_id
    field :sync_id, :binary_id

    field :raw_entity_type, :string
    field :external_id, :string
    field :payload, :map

    field :mapping_id, :string
    field :mapping_version, :integer

    field :source_system, :string
    field :source_instance, :string
    field :collected_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(raw, attrs) do
    raw
    |> cast(attrs, [
      :tenant_id,
      :sync_id,
      :raw_entity_type,
      :external_id,
      :payload,
      :mapping_id,
      :mapping_version,
      :source_system,
      :source_instance,
      :collected_at
    ])
    |> validate_required([
      :tenant_id,
      :sync_id,
      :raw_entity_type,
      :external_id,
      :payload,
      :source_system,
      :source_instance,
      :collected_at
    ])
  end

  @spec store(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def store(attrs), do: %__MODULE__{} |> changeset(attrs) |> Repo.insert()

  @doc """
  Payloads já coletados, para reprocessamento sem tocar na origem (FR-017).
  """
  @spec list_for_reprocessing(Tenant.t(), String.t()) :: [t()]
  def list_for_reprocessing(%Tenant{id: tenant_id}, raw_entity_type) do
    Repo.all(
      from r in __MODULE__,
        where: r.tenant_id == ^tenant_id and r.raw_entity_type == ^raw_entity_type,
        order_by: [asc: r.collected_at]
    )
  end

  @spec count(Tenant.t()) :: non_neg_integer()
  def count(%Tenant{id: tenant_id}) do
    Repo.aggregate(from(r in __MODULE__, where: r.tenant_id == ^tenant_id), :count, :id)
  end
end
