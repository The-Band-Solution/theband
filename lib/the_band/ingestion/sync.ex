defmodule TheBand.Ingestion.Sync do
  @moduledoc "Uma execução de coleta, com início, fim, progresso e resultado."

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @statuses ~w(running completed failed interrupted)

  schema "syncs" do
    field :tenant_id, :binary_id
    field :connected_tool_id, :binary_id
    field :credential_id, :binary_id

    field :status, :string, default: "running"
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    field :records_collected, :integer, default: 0
    field :records_created, :integer, default: 0
    field :records_updated, :integer, default: 0
    field :records_skipped, :integer, default: 0
    field :skip_reasons, :map, default: %{}
    field :memberships_pending_role, :integer, default: 0

    field :error_reason, :string

    # Quem encerrou. **Nulo afirma "foi a plataforma"** — não "não se sabe quem": a
    # plataforma sabe que não foi pessoa. Sem check constraint exigindo autor, porque há
    # dois encerradores legítimos; exigir forçaria inventar um usuário-sistema.
    field :interrupted_by_user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sync, attrs) do
    sync
    |> cast(attrs, [
      :tenant_id,
      :connected_tool_id,
      :credential_id,
      :status,
      :started_at,
      :finished_at,
      :records_collected,
      :records_created,
      :records_updated,
      :records_skipped,
      :skip_reasons,
      :memberships_pending_role,
      :error_reason,
      :interrupted_by_user_id
    ])
    |> validate_required([:tenant_id, :connected_tool_id, :status, :started_at])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:connected_tool_id,
      name: :syncs_one_running_per_tool_index,
      message: "já existe uma sincronização em andamento para esta ferramenta"
    )
  end

  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{status: "running"}), do: true
  def running?(_), do: false
end
