defmodule TheBand.Ontology.SEON.SPO.Schemas.ActivityEndCriterion do
  @moduledoc """
  `spo.activity_end_criterion` — o evento que a organização declara como aquele que marca o
  **fim** de um trabalho, por quadro. Feature 066.

  ## A simetria com o começo

  A 042 declarou o início e deixou o fim implícito: a plataforma assumia *a issue fechou*, sem
  perguntar. Medido em 2026-09-15, itens de quadro × issues fechadas na origem: **#43 Conecta
  Fapes 10%**, **#19 Delivery 4%**, **#31 DevOps 95%**, **#26 AgentES 95%**. Uma definição
  única mentiria para metade dos quadros.

  ## Dá o instante, não a aceitação

  Fecha o cycle time, como o de início o abre. **Não** diz que o entregável passou: aceitação
  decorre dos critérios de aceitação (`sro.rule03`), e é a feature 067.

  ## Convive com a declaração por coluna

  A 066 declara o que cada **coluna** significa, e resolve os quadros que têm coluna final.
  Este critério existe para os que não têm: medido no mesmo dia, **13 campos de seleção única
  não têm nenhuma coluna que signifique concluído**.

  ## Revogar marca

  E nunca apaga, como nos irmãos.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_activity_end_criteria" do
    field :tenant_id, :binary_id

    # Exatamente um dos dois — a `CHECK` garante, e a validação traz o erro ao formulário.
    field :project_id, :binary_id
    field :observed_project_id, :binary_id

    field :event_type, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id project_id observed_project_id event_type
             declared_by_user_id declared_at)a

  @spec declarar_changeset(t(), map()) :: Ecto.Changeset.t()
  def declarar_changeset(criterio, attrs) do
    criterio
    |> cast(attrs, @campos)
    |> validate_required([:tenant_id, :event_type, :declared_by_user_id, :declared_at])
    |> validate_alvo_unico()
  end

  @spec revogar_changeset(t(), map()) :: Ecto.Changeset.t()
  def revogar_changeset(criterio, attrs) do
    criterio
    |> cast(attrs, [:revoked_by_user_id, :revoked_at])
    |> validate_required([:revoked_by_user_id, :revoked_at])
  end

  # Traz o erro ao formulário em vez de deixá-lo virar `Ecto.ConstraintError`.
  defp validate_alvo_unico(changeset) do
    projeto = get_field(changeset, :project_id)
    quadro = get_field(changeset, :observed_project_id)

    case {projeto, quadro} do
      {nil, nil} ->
        add_error(changeset, :observed_project_id, "o critério precisa de um alvo")

      {p, q} when not is_nil(p) and not is_nil(q) ->
        add_error(changeset, :project_id, "um alvo só")

      _ ->
        changeset
    end
  end
end
