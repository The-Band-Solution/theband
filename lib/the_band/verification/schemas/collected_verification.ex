defmodule TheBand.Verification.Schemas.CollectedVerification do
  @moduledoc """
  A execução de verificação contínua — `ciro.continuous_integration_process` (feature 037).

  `trigger_event` e `conclusion` ficam **crus**, como a origem entrega; `subtype` e
  `phase` são a tradução para a CIRO. Guardar os quatro é o que permite rever a tradução
  sem recoletar — e é a mesma postura de `issue_type` na issue.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_verifications" do
    field :tenant_id, :binary_id
    field :observed_repository_id, :binary_id

    field :workflow_name, :string
    field :head_sha, :string
    field :head_branch, :string

    field :trigger_event, :string
    field :run_status, :string
    field :conclusion, :string
    # Nula enquanto o processo não termina — em andamento não é nem bem nem malsucedido.
    field :phase, :string
    # Derivado dos componentes dos jobs. Vazio é ausência nomeada: a rede não tem
    # conceito para automação que não é nem verificação nem implantação.
    field :process_kinds, {:array, :string}, default: []
    field :attempt, :integer, default: 1

    field :external_started_at, :utc_datetime
    field :external_finished_at, :utc_datetime

    field :actor_login, :string
    field :actor_person_id, :binary_id

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :raw_payload, :map

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_repository_id workflow_name head_sha head_branch
             trigger_event run_status conclusion phase process_kinds attempt external_started_at
             external_finished_at actor_login actor_person_id source_system
             source_instance external_id raw_payload collected_at last_observed_at
             no_longer_observed_at)a

  def changeset(verificacao, attrs) do
    verificacao
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :observed_repository_id,
      :head_sha,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
  end
end
