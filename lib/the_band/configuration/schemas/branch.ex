defmodule TheBand.Configuration.Schemas.Branch do
  @moduledoc """
  Uma linha de desenvolvimento — `cmpo.branch`, feature 039.

  A CMPO define branch como o **coletivo** dos artefatos de um repositório numa linha de
  desenvolvimento. Origem e destino são papéis assumidos num check-in, e não tipos de
  branch — é por isso que não há coluna de tipo aqui: `release/x` e `feature/y` são
  convenção da organização, não distinção ontológica, e a limitação do mapeamento diz
  exatamente isso.

  `is_protected` guarda `false` quando a origem não informa, e a ingestão registra a
  diferença: sem escopo de administração o campo chega nulo, e nulo é "não sabemos" — nunca
  "não protegida".
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "cmpo_branches" do
    field :tenant_id, :binary_id
    field :observed_repository_id, :binary_id

    field :name, :string
    field :head_sha, :string
    # O que separa branch em uso de branch esquecida. Sem a data, "existe" não diz nada
    # sobre atividade.
    field :head_committed_at, :utc_datetime

    field :is_default, :boolean, default: false
    field :is_protected, :boolean, default: false

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :raw_payload, :map

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_repository_id name head_sha head_committed_at is_default
             is_protected source_system source_instance external_id raw_payload collected_at
             last_observed_at no_longer_observed_at)a

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :observed_repository_id,
      :name,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
    |> unique_constraint([:observed_repository_id, :name])
  end
end
