defmodule TheBand.Ontology.SEON.SPO.Schemas.ActivityStartCriterion do
  @moduledoc """
  `spo.activity_start_criterion` — o tipo de evento que a organização declara como aquele que
  marca o início de um trabalho. Issue #370.

  ## Objeto social, e não configuração

  A UFO define `social_object` como *"objeto cuja existência depende de convenção social"*, e é
  o que este é: o mesmo evento — mover um cartão, designar alguém — significa "começou" numa
  organização e não significa noutra, e nenhuma está errada.

  A plataforma **não escolhe**. Ela registra a escolha, com quem a fez e quando — que é
  exatamente o que a `FR-007` da feature 022 pede ao proibir a escolha automática.

  ## Dois alvos, e os dois nomes colidem

  `project_id` é o **projeto** da SPO, declarado por pessoa. `observed_project_id` é o
  **quadro** do Projects v2, coletado da origem.

  O GitHub chama o quadro de "project", e é daí que vem a confusão. Exatamente um dos dois
  está preenchido, garantido pela `CHECK` do banco.

  ## `event_type` cru

  `ProjectV2ItemStatusChangedEvent` e afins, como a origem nomeia. Sem enum: congelar a lista
  faria a plataforma recusar um evento novo do GitHub como se fosse erro. A restrição ao que é
  coletado é da tela — `FR-012`.

  ## Revogar marca

  E nunca apaga. A pergunta *"desde quando este critério vale"* só tem resposta se o
  encerramento preservar o começo.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_activity_start_criteria" do
    field :tenant_id, :binary_id

    # Exatamente um dos dois — a `CHECK` garante, e `validate_alvo_unico/1` traz o erro ao
    # formulário em vez de deixá-lo virar `Ecto.ConstraintError`.
    field :project_id, :binary_id
    field :observed_project_id, :binary_id

    field :event_type, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(criterio, attrs) do
    criterio
    |> cast(attrs, [
      :tenant_id,
      :project_id,
      :observed_project_id,
      :event_type,
      :declared_by_user_id,
      :declared_at,
      :revoked_by_user_id,
      :revoked_at
    ])
    |> validate_required([:tenant_id, :event_type, :declared_at])
    |> validate_alvo_unico()
    |> unique_constraint(:project_id,
      name: :spo_activity_start_criteria_projeto_vigente_index
    )
    |> unique_constraint(:observed_project_id,
      name: :spo_activity_start_criteria_quadro_vigente_index
    )
    |> check_constraint(:project_id,
      name: :criterio_tem_um_alvo_so,
      message: "critério vale para um projeto OU um quadro, nunca os dois"
    )
  end

  defp validate_alvo_unico(changeset) do
    projeto = get_field(changeset, :project_id)
    quadro = get_field(changeset, :observed_project_id)

    case {projeto, quadro} do
      {nil, nil} ->
        add_error(changeset, :project_id, "critério precisa de um alvo: projeto ou quadro")

      {p, q} when not is_nil(p) and not is_nil(q) ->
        add_error(changeset, :project_id, "critério não pode valer para projeto e quadro")

      _ ->
        changeset
    end
  end
end
