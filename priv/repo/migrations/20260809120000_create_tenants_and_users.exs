defmodule TheBand.Repo.Migrations.CreateTenantsAndUsers do
  @moduledoc """
  FR-001 — a organização cliente é a fronteira de isolamento sobre a qual todo
  dado coletado é atribuído.

  `tenants` não tem `tenant_id`: ela **é** o tenant.
  """

  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"", "DROP EXTENSION IF EXISTS \"pgcrypto\""

    create table(:tenants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:slug])

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :email, :string, null: false
      add :name, :string
      # Assumptions da spec: só `admin` conecta ferramenta e gerencia credencial.
      add :role, :string, null: false, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:tenant_id])
  end
end
