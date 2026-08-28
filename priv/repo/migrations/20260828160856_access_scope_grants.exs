defmodule TheBand.Repo.Migrations.AccessScopeGrants do
  use Ecto.Migration

  @moduledoc """
  Feature 045 (US2): concessões de escopo de acesso, com proveniência.

  Só o CONCEDIDO se grava — escopo derivado é leitura das relações vigentes e
  nunca vira linha (FR-020/021). Revogação é marca (`revoked_at`), nunca delete.

  ## O seed dos administradores (research R9)

  O modelo novo tira do administrador a visão automática (FR-022: administrar é
  mexer, ver é escopo). Quem hoje é admin VÊ tudo — e a virada de chave não pode
  rebaixar ninguém em silêncio. Por isso este arquivo semeia, para cada conta
  admin, uma concessão `organization` por organização observada do tenant,
  concedida pela própria conta na data da migração. Tenant sem organização não
  ganha nada — não havia visão a preservar.
  """

  def up do
    create table(:access_scope_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :level, :string, null: false
      add :target_id, :binary_id, null: false
      add :granted_by_user_id, :binary_id, null: false
      add :granted_at, :utc_datetime, null: false
      add :revoked_by_user_id, :binary_id
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:access_scope_grants, [:tenant_id, :user_id])

    # Uma concessão VIGENTE por alvo; o histórico de revogadas fica livre.
    create unique_index(:access_scope_grants, [:tenant_id, :user_id, :level, :target_id],
             where: "revoked_at IS NULL",
             name: :access_scope_grants_vigente_index
           )

    execute """
    INSERT INTO access_scope_grants
      (id, tenant_id, user_id, level, target_id, granted_by_user_id, granted_at,
       inserted_at, updated_at)
    SELECT gen_random_uuid(), u.tenant_id, u.id, 'organization', o.id, u.id, now(),
           now(), now()
    FROM users u
    JOIN eo_organizations o ON o.tenant_id = u.tenant_id
    WHERE u.role = 'admin'
    """
  end

  def down do
    drop table(:access_scope_grants)
  end
end
