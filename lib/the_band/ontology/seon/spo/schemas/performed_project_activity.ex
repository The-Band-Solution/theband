defmodule TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity do
  @moduledoc """
  Uma ocorrência de atividade executada — `spo.performed_project_activity`.

  **É o *kind* de todas as ocorrências da rede.** A ontologia diz que commits, execuções
  de teste, cerimônias, implantações e inspeções *"compartilham o mesmo princípio de
  identidade"*, e por isso este schema é modelado pelo critério do conceito, não pela
  timeline do GitHub — que é só a primeira origem a chegar aqui.

  ## O que distingue este schema dos outros

  **Não existe `:updated`.** Os outros schemas da plataforma têm três resultados porque
  descrevem entidades que mudam: uma pessoa troca de nome, um repositório é arquivado.
  Uma ocorrência não muda — ela aconteceu. Reprocessar a mesma origem devolve
  `:unchanged`, e nunca reescreve o que foi gravado.

  **Nulo em `concept_id` é informação**, e não dado faltando: significa que a rede não
  nomeia este tipo de atividade. É o estado honesto de `labeled` e `cross-referenced`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  # Marcador do componente ausente no hash de identidade. A ontologia exige
  # representação canônica para a ausência — sem ela, `to_string(nil)` vira `""` e
  # um `source_external_id` vazio colidiria com um inexistente, que são coisas
  # diferentes: a origem que não deu identidade ao evento e a que deu uma vazia.
  @ausente "\x00"

  schema "spo_performed_project_activities" do
    field :tenant_id, :binary_id
    field :internal_id, :string

    field :organization_id, :binary_id
    field :project_id, :binary_id

    field :activity_type, :string
    field :concept_id, :string

    field :performer_id, :binary_id
    field :performer_login, :string

    field :occurred_at, :utc_datetime

    field :subject_type, :string
    field :subject_id, :binary_id

    field :source_system, :string
    field :source_instance, :string
    field :source_external_id, :string

    field :payload, :map

    # Só dois valores, e a ausência do terceiro é a decisão: uma ocorrência não é
    # atualizada. Ver o moduledoc.
    field :outcome, Ecto.Enum, values: [:created, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [
      :tenant_id,
      :internal_id,
      :organization_id,
      :project_id,
      :activity_type,
      :concept_id,
      :performer_id,
      :performer_login,
      :occurred_at,
      :subject_type,
      :subject_id,
      :source_system,
      :source_instance,
      :source_external_id,
      :payload
    ])
    |> validate_required([
      :tenant_id,
      :internal_id,
      :activity_type,
      :occurred_at,
      :subject_type,
      :subject_id,
      :source_system,
      :source_instance
    ])
    |> unique_constraint(:internal_id,
      name: :spo_performed_project_activities_identity_index
    )
  end

  @doc """
  O hash do critério de identidade declarado na ontologia.

  Os componentes são exatamente os de `identity_criterion` em
  `spo/modules/processes_and_activities.yaml`, na ordem em que a ontologia os
  escreveu, e mudá-la mudaria toda identidade já gravada.

  `start_date` e `end_date` ficam de fora **de propósito** — a nota da própria
  ontologia explica: `end_date` é nulo enquanto a atividade corre e preenchido ao
  terminar, e incluí-lo faria o hash mudar no encerramento, quebrando toda referência
  existente.
  """
  @spec internal_id(map()) :: String.t()
  def internal_id(attrs) do
    [
      attrs[:tenant_id],
      attrs[:organization_id],
      attrs[:project_id],
      attrs[:activity_type],
      attrs[:performer_id],
      attrs[:occurred_at],
      attrs[:source_external_id]
    ]
    |> Enum.map_join("|", &canonico/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp canonico(nil), do: @ausente
  defp canonico(%DateTime{} = at), do: DateTime.to_iso8601(DateTime.truncate(at, :second))
  defp canonico(valor), do: to_string(valor)
end
