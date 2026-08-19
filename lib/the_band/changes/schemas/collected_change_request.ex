defmodule TheBand.Changes.Schemas.CollectedChangeRequest do
  @moduledoc """
  A solicitação de mudança como a origem a entregou — `cmpo.change_request`.

  Quem submeteu e quem integrou vivem em campos **distintos** porque são atos
  diferentes: a CMPO declara `stakeholder_submitted_change_request` (participação no ato
  de submeter) e `stakeholder_performed_checkin` (participação no ato de integrar). A
  própria definição do conceito diz que o PR "não é o merge, nem a decisão de aprovação".
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_change_requests" do
    field :tenant_id, :binary_id
    field :observed_repository_id, :binary_id

    field :number, :integer
    field :title, :string
    field :body, :string
    field :state, :string

    field :source_branch, :string
    field :target_branch, :string
    field :changed_files, :integer
    # Truncamento dito, nunca silencioso: 509 das 5.032 solicitações do tenant real têm
    # mais commits do que a página traz, e "cinquenta" e "os cinquenta primeiros de
    # duzentos" afirmam coisas diferentes.
    field :commits_total, :integer
    # O estado da verificação do commit que ENTROU — issue #439. Cru, como a origem entrega:
    # `SUCCESS`, `FAILURE`, `PENDING`, `ERROR`, `EXPECTED`. A tradução para fase da CIRO fica na
    # leitura.
    field :merged_head_sha, :string
    field :merged_check_state, :string
    # Zero com estado nulo = nenhum check rodou. Nulo aqui = não medimos ainda.
    field :merged_check_contexts, :integer
    field :commits_collected, :integer

    field :author_login, :string
    field :author_person_id, :binary_id
    field :merged_by_login, :string
    field :merged_by_person_id, :binary_id

    field :external_created_at, :utc_datetime
    field :external_merged_at, :utc_datetime
    field :external_closed_at, :utc_datetime

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :raw_payload, :map

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_repository_id number title body state source_branch
             target_branch changed_files commits_total commits_collected merged_head_sha
             merged_check_state merged_check_contexts author_login author_person_id merged_by_login
             merged_by_person_id external_created_at external_merged_at external_closed_at
             source_system source_instance external_id raw_payload collected_at
             last_observed_at no_longer_observed_at)a

  def changeset(cr, attrs) do
    cr
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :observed_repository_id,
      :number,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
  end
end
