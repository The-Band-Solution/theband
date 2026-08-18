defmodule TheBand.Verification.Schemas.VerificationComponent do
  @moduledoc """
  O job de uma execução, com os componentes da CIRO que ele materializa (feature 037).

  `components` é **array** porque um job pode ser build E teste E inspeção — o
  antipadrão `ci.ap01.monolithic_job`. Guardar um só perderia justamente o que a máxima
  existe para mostrar; e array vazio é `ci.ap02.unnamed_components`, ausência nomeada,
  nunca "build por padrão".
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "verification_components" do
    field :tenant_id, :binary_id
    field :collected_verification_id, :binary_id

    field :job_name, :string
    field :conclusion, :string
    field :phase, :string
    field :components, {:array, :string}, default: []
    field :step_names, {:array, :string}, default: []

    field :external_started_at, :utc_datetime
    field :external_finished_at, :utc_datetime

    field :external_id, :string
    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id collected_verification_id job_name conclusion phase components
             step_names external_started_at external_finished_at external_id collected_at
             last_observed_at no_longer_observed_at)a

  def changeset(componente, attrs) do
    componente
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :collected_verification_id,
      :job_name,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
  end
end
