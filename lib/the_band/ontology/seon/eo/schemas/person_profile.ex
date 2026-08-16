defmodule TheBand.Ontology.SEON.EO.Schemas.PersonProfile do
  @moduledoc """
  Um perfil derivado de uma pessoa, num momento — feature 026.

  **Não é afirmação de competência.** A rede de ontologias não ganhou conceito de habilidade,
  e a decisão está registrada em `specs/026-perfil-de-competencias/research.md`, R1: criar
  `eo.competence` faria a plataforma afirmar que a pessoa **tem** a habilidade, que é
  exatamente o que a spec recusa — e licenciaria a consulta "quem sabe X", pergunta que a
  evidência não sustenta.

  O que este schema guarda é um **texto sobre uma pessoa**, com quem o escreveu, quando, e
  sobre qual recorte.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @recorte [
    :tasks_closed,
    :tasks_open,
    :tasks_with_body,
    :tasks_authored_by_other,
    :tasks_shared,
    :period_from,
    :period_to,
    :baseline_verdict
  ]

  schema "eo_person_profiles" do
    field :tenant_id, :binary_id
    field :person_id, :binary_id

    field :generated_at, :utc_datetime
    field :requested_by_user_id, :binary_id

    field :model, :string
    field :body, :string
    field :citations_removed, :integer, default: 0

    field :tasks_closed, :integer
    field :tasks_open, :integer
    field :tasks_with_body, :integer
    field :tasks_authored_by_other, :integer
    field :tasks_shared, :integer
    field :period_from, :date
    field :period_to, :date
    field :baseline_verdict, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  O changeset de gravação.

  **Corpo vazio é recusado aqui e no banco.** Duas barreiras porque um perfil vazio é
  indistinguível de um perfil na tela, e quem lê acreditaria nele.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(perfil, attrs) do
    perfil
    |> cast(attrs, [
      :tenant_id,
      :person_id,
      :generated_at,
      :requested_by_user_id,
      :model,
      :body,
      :citations_removed | @recorte
    ])
    |> validate_required([:tenant_id, :person_id, :generated_at, :model, :body])
    |> update_change(:body, &String.trim/1)
    |> validate_length(:body, min: 1, message: "resposta vazia é falha, e não perfil")
    |> unique_constraint([:tenant_id, :person_id, :generated_at],
      name: :eo_person_profiles_momento_index
    )
    |> check_constraint(:body,
      name: :eo_person_profiles_body_nao_vazio,
      message: "resposta vazia é falha, e não perfil"
    )
  end
end
