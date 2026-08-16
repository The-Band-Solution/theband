defmodule TheBand.Projects.Schemas.Iteration do
  @moduledoc """
  A razão-fonte das iterações — feature 004 F7 (T052 e T053).

  Cada iteração coletada aponta para o que ela virou: `sro_sprint_id` quando o início
  já passou, `spo_intended_process_id` quando ainda não chegou. **Exatamente um dos
  dois, nunca os dois, nunca nenhum** (SC-009c) — e a constraint é do banco.

  `no_longer_in_configuration_at` é a FR-031: removida da configuração do quadro é
  marcada, nunca apagada. Os itens dela **não** voltam ao product backlog — voltar
  afirmaria um replanejamento que ninguém decidiu.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "project_iterations" do
    field :tenant_id, :binary_id
    field :observed_project_id, :binary_id

    field :iteration_external_id, :string
    field :field_external_id, :string
    field :title, :string
    field :start_date, :date
    field :duration_days, :integer

    field :sro_sprint_id, :binary_id
    field :spo_intended_process_id, :binary_id

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_in_configuration_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_project_id iteration_external_id field_external_id title
             start_date duration_days sro_sprint_id spo_intended_process_id collected_at
             last_observed_at no_longer_in_configuration_at)a

  @obrigatorios ~w(tenant_id observed_project_id iteration_external_id field_external_id
                   title start_date duration_days collected_at last_observed_at)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(iteracao, attrs) do
    iteracao
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> unique_constraint(
      [:tenant_id, :observed_project_id, :field_external_id, :iteration_external_id],
      name: :project_iterations_identidade_index
    )
    |> check_constraint(:sro_sprint_id, name: :project_iterations_exatamente_um_destino)
  end
end
