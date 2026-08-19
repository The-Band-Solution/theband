defmodule TheBand.Quality.Schemas.ArtifactEvaluation do
  @moduledoc """
  Uma avaliação de artefato — `qapo.artifact_evaluation`, feature 039.

  `state` fica **cru** porque aprovar não é atestar conformidade: a definição da QAPO diz
  que a avaliação "avalia objetivamente a aderência", e o mapeamento declara que
  "aprovação não implica ausência de não conformidades, apenas ausência de bloqueio".
  Guardar `conforme: true` afirmaria o que a origem não disse.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_artifact_evaluations" do
    field :tenant_id, :binary_id
    field :collected_change_request_id, :binary_id

    field :state, :string
    field :body, :string
    # Nulo é review não submetida (rascunho), nunca "sem data".
    field :external_submitted_at, :utc_datetime

    field :author_login, :string
    # `User` × `Bot`: a distinção que o mapeamento manda fazer, e sem ela a medida de tempo
    # até a primeira revisão mediria o robô.
    field :author_type, :string
    field :author_person_id, :binary_id

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :raw_payload, :map

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id collected_change_request_id state body external_submitted_at
             author_login author_type author_person_id source_system source_instance
             external_id raw_payload collected_at last_observed_at no_longer_observed_at)a

  def changeset(avaliacao, attrs) do
    avaliacao
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :collected_change_request_id,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
  end
end
