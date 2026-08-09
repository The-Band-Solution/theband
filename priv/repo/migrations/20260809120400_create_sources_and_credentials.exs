defmodule TheBand.Repo.Migrations.CreateSourcesAndCredentials do
  @moduledoc """
  Ferramentas conectadas e credenciais (US1).

  FR-002 e FR-003: o cadastro acomoda outros tipos além do GitHub sem mudança
  estrutural. FR-004: mais de uma credencial por ferramenta, ativáveis de forma
  independente. FR-005: o segredo é cifrado pela plataforma antes de gravar.
  """

  use Ecto.Migration

  def change do
    create table(:connected_tools, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # Enum e não texto livre: ferramenta nova é migração declarada, não dado
      # solto que ninguém sabe de onde veio.
      add :tool_type, :string, null: false
      add :instance_url, :string, null: false
      add :status, :string, null: false, default: "active"

      # FR-009 — data e motivo da falha, sem afetar as demais ferramentas.
      add :needs_attention_since, :utc_datetime
      add :needs_attention_reason, :string

      add :last_sync_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:connected_tools, [:tenant_id, :tool_type, :instance_url])

    create constraint(:connected_tools, :connected_tools_status_check,
             check: "status in ('active','needs_attention','disabled')"
           )

    create table(:tool_credentials, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :connected_tool_id, references(:connected_tools, type: :uuid, on_delete: :delete_all),
        null: false

      add :label, :string, null: false
      # Cifrado pelo Ecto.Type do Cloak. Ler a tabela devolve texto cifrado.
      add :secret, :binary, null: false
      # FR-007 — identificação parcial suficiente para distinguir uma credencial
      # da outra. Quatro caracteres não reduzem materialmente o espaço de busca
      # de um token de 40.
      add :last_four, :string, null: false
      add :active, :boolean, null: false, default: true
      # FR-006 — validada contra a ferramenta no cadastro; sem isso não se grava.
      add :validated_at, :utc_datetime, null: false
      add :scopes, {:array, :string}, default: []
      add :last_failure_at, :utc_datetime
      add :last_failure_reason, :string

      timestamps(type: :utc_datetime)
    end

    create index(:tool_credentials, [:tenant_id, :connected_tool_id])
  end
end
