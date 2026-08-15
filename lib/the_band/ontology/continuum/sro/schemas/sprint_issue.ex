defmodule TheBand.Ontology.Continuum.SRO.Schemas.SprintIssue do
  @moduledoc """
  O vínculo entre uma issue e uma caixa de tempo.

  ## Muitos-para-muitos, e a medida obrigou

  Medido em 2026-08-15 no quadro DevOps: `527 + 203 = 730` vínculos sobre **677 itens**.
  A mesma issue está num `Sprint` de 14 dias e num `Quarter` de 90.

  Uma coluna `sprint_id` em `collected_issues` teria de escolher uma das duas, e não há
  regra que justifique a escolha — o Produtos Internos inverte a proporção, com
  `Quarter` em 15 itens e `Sprint` em 3.

  ## Ausência marca, nunca apaga

  Issue que saiu de um sprint continua tendo estado nele. Apagar a linha faria a
  história do sprint mudar retroativamente, e ninguém saberia que ela esteve lá.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sro_sprint_issues" do
    field :tenant_id, :binary_id
    field :sprint_id, :binary_id
    field :collected_issue_id, :binary_id

    field :observed_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(vinculo, attrs) do
    vinculo
    |> cast(attrs, [
      :tenant_id,
      :sprint_id,
      :collected_issue_id,
      :observed_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([
      :tenant_id,
      :sprint_id,
      :collected_issue_id,
      :observed_at,
      :last_observed_at
    ])
    |> unique_constraint(:collected_issue_id, name: :sro_sprint_issues_par_index)
  end
end
