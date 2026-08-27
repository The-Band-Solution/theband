defmodule TheBand.Ontology.SEON.CMPO.Schemas.ObservedRepository do
  @moduledoc """
  O que a plataforma decidiu sobre um repositório — camada de plataforma.

  Três situações, e **duas delas não marcam ausência**: excluído é decisão do tenant,
  inacessível é falha de alcance da credencial. As duas impedem a coleta, e nenhuma
  significa que o dado sumiu.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "observed_repositories" do
    field :tenant_id, :binary_id
    field :connected_tool_id, :binary_id
    field :source_repository_id, :binary_id

    field :excluded_at, :utc_datetime
    field :excluded_by_user_id, :binary_id
    field :inaccessible_since, :utc_datetime
    field :inaccessible_reason, :string

    # Registra que a fase de issues rodou para este repositório. `nil` significa "nunca
    # passou por coleta de issues" — e é a diferença entre "olhei e não achei" e "não sei",
    # que a tela precisa para não mostrar `0` nos dois casos.
    field :issues_collected_at, :utc_datetime

    # Issue #452: a versão da consulta com que cada fase percorreu este repositório. A
    # coluna existe desde a #452; o campo entra no schema pela #368, porque a fase de
    # issues passou a precisar dele para decidir o corte — e as outras fases o leem por
    # consulta sem schema.
    field :query_versions, :map, default: %{}
    # Quando os comentários foram percorridos por inteiro — decide o incremental da
    # coleta E qual frase o vazio da discussão usa na tela (feature 030).
    field :comments_collected_at, :utc_datetime
    # Feature 032: quando as solicitações de mudança foram percorridas por inteiro.
    field :changes_collected_at, :utc_datetime
    # Feature 037 e 039. A lição das colunas novas: coluna que existe no banco e não no
    # schema derruba a tela com `KeyError` — aconteceu duas vezes, com
    # `comments_collected_at` e `changes_collected_at`.
    field :verifications_collected_at, :utc_datetime
    field :branches_collected_at, :utc_datetime
    # O total da ORIGEM, comparado com o coletado para revelar truncamento.
    field :branches_total, :integer

    # O que a escrita fez — mesmo campo virtual que `CollectedIssue` e `EO.Schemas.Person`
    # usam, e pelo mesmo motivo: sem ele a contagem da execução não distingue observar um
    # repositório novo de revê-lo.
    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(observed, attrs) do
    observed
    |> cast(attrs, [
      :tenant_id,
      :connected_tool_id,
      :source_repository_id,
      :excluded_at,
      :excluded_by_user_id,
      :inaccessible_since,
      :inaccessible_reason,
      :issues_collected_at,
      :query_versions,
      :comments_collected_at,
      :changes_collected_at,
      :verifications_collected_at,
      :branches_collected_at,
      :branches_total
    ])
    |> validate_required([:tenant_id, :connected_tool_id, :source_repository_id])
    |> unique_constraint([:connected_tool_id, :source_repository_id])
    |> check_constraint(:excluded_by_user_id,
      name: :observed_repositories_exclusion_has_author,
      message: "exclusão é decisão, e decisão tem autor"
    )
  end
end
