defmodule TheBand.Ingestion.Checkpoint do
  @moduledoc """
  Progresso da coleta por `(sync, tipo de entidade)`, com cursor opaco (R5).

  O cursor é gravado **depois** de a página ser processada com sucesso, nunca
  antes. Assim uma interrupção reprocessa no máximo a última página — seguro,
  porque a ingestão é idempotente; perder a página não seria.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sync_checkpoints" do
    field :tenant_id, :binary_id
    field :sync_id, :binary_id

    field :entity_type, :string
    # Opaco: armazenado como veio da origem. Não interpretá-lo é o que mantém o
    # mecanismo válido se o formato do cursor mudar.
    field :cursor, :string
    field :page_count, :integer, default: 0
    field :record_count, :integer

    # Denominador do progresso, vindo da origem. Anulável: onde a origem não informa
    # total, a tela mostra contagem em vez de percentual — inventar o denominador
    # produziria número que parece informação e não é.
    field :expected_count, :integer, default: 0
    field :last_page_at, :utc_datetime
    field :status, :string, default: "running"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, [
      :tenant_id,
      :sync_id,
      :entity_type,
      :cursor,
      :page_count,
      :record_count,
      :expected_count,
      :last_page_at,
      :status
    ])
    |> validate_required([:tenant_id, :sync_id, :entity_type])
    |> unique_constraint([:sync_id, :entity_type])
  end
end
