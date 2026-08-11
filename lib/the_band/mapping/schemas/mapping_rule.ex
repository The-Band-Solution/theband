defmodule TheBand.Mapping.Schemas.MappingRule do
  @moduledoc """
  A regra que uma organização declarou para decidir o conceito de uma issue.

  **`created_by_id` é obrigatório no changeset, e não há caminho que o dispense.**
  Mapeamento é decisão: uma regra sem autor não tem a quem perguntar por que aquele texto
  designa aquele conceito.

  `target_concept` é **texto**, e não chave estrangeira: conceito vive na base de
  conhecimento em YAML, não em tabela. Validar que ele existe é responsabilidade do
  comando, contra a base carregada — o banco não tem como saber.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @wheres ~w(declared_type title)
  @hows ~w(equals starts_with contains regex)

  schema "issue_mapping_rules" do
    field :tenant_id, :binary_id
    field :organization_id, :binary_id

    field :where, :string
    field :how, :string
    field :pattern, :string
    field :case_sensitive, :boolean, default: false
    field :target_concept, :string

    field :position, :integer
    field :active, :boolean, default: true
    field :deactivated_at, :utc_datetime
    field :deactivated_by_id, :binary_id

    field :created_by_id, :binary_id
    field :catalog_key, :string
    field :version, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  @spec wheres() :: [String.t()]
  def wheres, do: @wheres

  @spec hows() :: [String.t()]
  def hows, do: @hows

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :tenant_id,
      :organization_id,
      :where,
      :how,
      :pattern,
      :case_sensitive,
      :target_concept,
      :position,
      :active,
      :deactivated_at,
      :deactivated_by_id,
      :created_by_id,
      :catalog_key,
      :version
    ])
    |> validate_required([
      :tenant_id,
      :organization_id,
      :where,
      :how,
      :pattern,
      :target_concept,
      :position,
      :created_by_id
    ])
    |> validate_inclusion(:where, @wheres)
    |> validate_inclusion(:how, @hows)
    |> unique_constraint([:organization_id, :where, :how, :pattern],
      name: :issue_mapping_rules_comparison_index,
      message: "esta organização já declarou esta comparação"
    )
    |> unique_constraint([:organization_id, :position],
      message: "já existe regra nesta posição"
    )
  end

  @doc """
  A chave que liga a regra à entrada do catálogo: `(where, how, pattern)` normalizado.

  **Nunca o índice na lista.** Reordenar o catálogo não pode desligar decisões já tomadas,
  e o índice faria exatamente isso.
  """
  @spec catalog_key(String.t(), String.t(), String.t()) :: String.t()
  def catalog_key(where, how, pattern),
    do: "#{where}|#{how}|#{String.downcase(String.trim(pattern))}"
end
