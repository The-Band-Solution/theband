defmodule TheBand.WorkItems.Schemas.IssuePromotion do
  @moduledoc """
  A decisão da plataforma sobre o que uma issue é — **append-only**.

  Sem `update_changeset`, e sem `updated_at`. Uma issue que muda de conceito entre
  coletas ganha **linha nova**, e a vigente é a última: atualizar reescreveria o
  passado, e "como esta issue estava classificada em março" desapareceria.

  `inserted_at` em microssegundo porque duas promoções do mesmo segundo empatariam, e a
  "vigente" passaria a depender do plano de execução — é a L20.

  ## Três estados, e o `check_constraint` os separa

      derived_concept preenchido, skip_reason nulo    promovida
      derived_concept nulo, skip_reason preenchido    não promovida, com o motivo
      divergence_reason preenchido                    promovida CONTRA o rótulo
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @skip_reasons ~w(type_absent type_unknown sub_issues_unavailable)

  schema "issue_promotions" do
    field :tenant_id, :binary_id
    field :collected_issue_id, :binary_id

    field :declared_concept, :string
    field :derived_concept, :string
    field :target_table, :string
    field :target_id, :binary_id

    field :rule_id, :string
    field :rule_version, :integer

    # De onde veio a evidência, e com que confiança (feature 005).
    #
    # Nulos nas promoções decididas antes daquela feature: preencher retroativamente
    # afirmaria que alguém verificou de onde cada uma veio, e ninguém verificou.
    #
    # `confidence` é NÍVEL — `high` para tipo declarado, `medium` para inferência de
    # título. Um número seria inventado, e viraria meta.
    field :evidence_source, :string
    field :confidence, :string
    field :mapping_rule_id, :binary_id

    # A frase explica; o tipo **classifica**. Sem o tipo, "quantas issues têm tarefa com
    # partes?" exigiria casar substring — e substring quebra na primeira vez que alguém
    # melhorar a redação. É o mesmo par de `skip_reason` e `skip_detail`.
    field :divergence_reason, :string
    field :divergence_kind, :string
    field :skip_reason, :string
    field :skip_detail, :string

    field :promoted_at, :utc_datetime

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec skip_reasons() :: [String.t()]
  def skip_reasons, do: @skip_reasons

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(promotion, attrs) do
    promotion
    |> cast(attrs, [
      :tenant_id,
      :collected_issue_id,
      :declared_concept,
      :derived_concept,
      :target_table,
      :target_id,
      :rule_id,
      :rule_version,
      :evidence_source,
      :confidence,
      :mapping_rule_id,
      :divergence_reason,
      :divergence_kind,
      :skip_reason,
      :skip_detail,
      :promoted_at
    ])
    |> validate_required([:tenant_id, :collected_issue_id, :rule_id, :rule_version, :promoted_at])
    |> validate_inclusion(:skip_reason, @skip_reasons)
    |> check_constraint(:derived_concept,
      name: :issue_promotions_promoted_xor_skipped,
      message: "ou promoveu, ou tem motivo para não ter promovido — nunca os dois"
    )
  end
end
