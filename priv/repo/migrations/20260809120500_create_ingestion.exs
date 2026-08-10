defmodule TheBand.Repo.Migrations.CreateIngestion do
  @moduledoc """
  Sincronizações, checkpoints e payload bruto (US2).

  FR-011 preserva o dado original antes de qualquer transformação; FR-015
  registra o progresso para retomar de onde parou; FR-018 impede duas
  sincronizações simultâneas da mesma ferramenta.
  """

  use Ecto.Migration

  def change do
    create table(:syncs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :connected_tool_id, references(:connected_tools, type: :uuid, on_delete: :delete_all),
        null: false

      # Credenciais diferentes enxergam conjuntos diferentes — qual foi usada
      # fica registrado junto do resultado.
      add :credential_id, references(:tool_credentials, type: :uuid, on_delete: :nilify_all)

      add :status, :string, null: false, default: "running"
      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime

      # FR-028 — o relatório do fim da sincronização.
      add :records_collected, :integer, null: false, default: 0
      add :records_created, :integer, null: false, default: 0
      add :records_updated, :integer, null: false, default: 0
      add :records_skipped, :integer, null: false, default: 0
      add :skip_reasons, :map, null: false, default: %{}
      # SC-010 — a lacuna de conhecimento, apresentada como número.
      add :memberships_pending_role, :integer, null: false, default: 0

      add :error_reason, :string

      timestamps(type: :utc_datetime)
    end

    create constraint(:syncs, :syncs_status_check,
             check: "status in ('running','completed','failed','interrupted')"
           )

    # FR-018 — primeira das duas defesas contra corrida. A segunda é o `unique`
    # do worker Oban: a corrida existe nos dois níveis, a segunda requisição HTTP
    # e o segundo job enfileirado.
    create unique_index(:syncs, [:connected_tool_id],
             where: "status = 'running'",
             name: :syncs_one_running_per_tool_index
           )

    create table(:sync_checkpoints, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :sync_id, references(:syncs, type: :uuid, on_delete: :delete_all), null: false

      add :entity_type, :string, null: false
      # Cursor opaco: armazenado como veio, nunca interpretado ou construído.
      # Não interpretá-lo é o que mantém o mecanismo válido se o formato mudar.
      add :cursor, :string
      add :page_count, :integer, null: false, default: 0
      add :record_count, :integer, null: false, default: 0
      add :last_page_at, :utc_datetime
      add :status, :string, null: false, default: "running"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sync_checkpoints, [:sync_id, :entity_type])

    create table(:raw_payloads, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :sync_id, references(:syncs, type: :uuid, on_delete: :delete_all), null: false

      add :raw_entity_type, :string, null: false
      add :external_id, :string, null: false
      add :payload, :map, null: false

      # Guardar o mapeamento aplicado é o que torna FR-017 verificável:
      # reprocessar com mapeamento corrigido lê daqui, sem consultar a origem.
      add :mapping_id, :string
      add :mapping_version, :integer

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :collected_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:raw_payloads, [:tenant_id, :raw_entity_type])
    create index(:raw_payloads, [:sync_id])
  end
end
