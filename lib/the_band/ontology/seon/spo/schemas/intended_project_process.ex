defmodule TheBand.Ontology.SEON.SPO.Schemas.IntendedProjectProcess do
  @moduledoc """
  Um processo pretendido — `spo.specific_intended_project_process`, categoria UFO
  `intention`. Feature 004 F7 (T052), FR-030.

  É a iteração **futura** do quadro: um planejamento que não foi feito. Quando a coleta
  seguinte a encontrar iniciada, ela vira `sro.sprint` — mesma identidade externa,
  registro novo, e a transição acontece **na coleta**, nunca no instante do início: a
  plataforma afirma o que observou, não o que o calendário implica.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_intended_project_processes" do
    field :tenant_id, :binary_id

    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :title, :string
    field :planned_start_on, :date
    field :duration_days, :integer

    field :source_system, :string
    field :source_instance, :string
    field :source_external_id, :string

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id internal_id record_version title planned_start_on duration_days
             source_system source_instance source_external_id collected_at
             last_observed_at no_longer_observed_at)a

  @obrigatorios ~w(tenant_id internal_id title planned_start_on duration_days
                   source_system source_instance source_external_id collected_at
                   last_observed_at)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(processo, attrs) do
    processo
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :source_external_id],
      name: :spo_intended_processes_application_reference_index
    )
  end
end
