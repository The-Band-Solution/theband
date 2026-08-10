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

  alias TheBand.Ingestion.Sync
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
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

  @doc """
  De qual organização de origem veio cada equipe coletada (T011).

  Devolve `[{external_id_da_equipe, organization_login}]`, atravessando
  `raw_payloads → syncs → connected_tools`. A organização não está no payload das
  equipes antigas — ela é o pai da consulta —, mas a ferramenta conectada que
  originou a sincronização sempre soube qual era.

  Uma consulta só, e não uma por equipe: percorrer a corrente equipe a equipe faria
  N+1 idas ao banco para responder exatamente isto.

  `distinct` porque a mesma equipe é preservada em cada sincronização. Se duas
  sincronizações de **ferramentas diferentes** trouxerem a mesma equipe, ela aparece
  duas vezes e quem chama decide — não é caso conhecido hoje, e resolver por
  arbitragem silenciosa aqui esconderia o conflito.
  """
  @spec team_organization_logins(Ecto.UUID.t()) :: [{String.t(), String.t()}]
  def team_organization_logins(tenant_id) do
    Repo.all(
      from r in __MODULE__,
        join: s in Sync,
        on: s.id == r.sync_id,
        join: t in ConnectedTool,
        on: t.id == s.connected_tool_id,
        where:
          r.tenant_id == ^tenant_id and r.raw_entity_type == "github.team" and
            not is_nil(t.organization_login),
        distinct: true,
        select: {r.external_id, t.organization_login}
    )
  end

  @spec count(Tenant.t()) :: non_neg_integer()
  def count(%Tenant{id: tenant_id}) do
    Repo.aggregate(from(r in __MODULE__, where: r.tenant_id == ^tenant_id), :count, :id)
  end
end
