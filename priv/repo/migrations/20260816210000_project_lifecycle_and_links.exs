defmodule TheBand.Repo.Migrations.ProjectLifecycleAndLinks do
  @moduledoc """
  O ciclo de vida do projeto declarado, e os vínculos com organização e equipe —
  feature 028 (US1, US2, US3).

  **Remover é marca** (`removed_at` + autor), nunca apagamento: a declaração desfeita
  continua consultável, como tudo neste banco. E os dois vínculos novos têm o desenho do
  vínculo com repositório — `linked_by/at`, `unlinked_by/at`, religar cria linha nova —
  porque a história dos vínculos é o dado.

  `eo_teams` ganha `declared_by_user_id`: a equipe criada pela tela tem autor, e a
  observada tem `nil` ali — que é ausência real, não falta de preenchimento.
  """

  use Ecto.Migration

  def change do
    alter table(:spo_projects) do
      add :updated_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :removed_at, :utc_datetime
      add :removed_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:eo_teams) do
      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
    end

    create table(:spo_project_organizations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :project_id,
          references(:spo_projects, type: :uuid, on_delete: :delete_all),
          null: false

      add :organization_id,
          references(:eo_organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :linked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :linked_at, :utc_datetime, null: false
      add :unlinked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :unlinked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Um vínculo VIGENTE por par — histórico (desfeito) pode repetir.
    create unique_index(:spo_project_organizations, [:tenant_id, :project_id, :organization_id],
             where: "unlinked_at IS NULL",
             name: :spo_project_organizations_vigente_index
           )

    create table(:spo_project_teams, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :project_id,
          references(:spo_projects, type: :uuid, on_delete: :delete_all),
          null: false

      add :team_id, references(:eo_teams, type: :uuid, on_delete: :delete_all), null: false

      add :linked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :linked_at, :utc_datetime, null: false
      add :unlinked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :unlinked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:spo_project_teams, [:tenant_id, :project_id, :team_id],
             where: "unlinked_at IS NULL",
             name: :spo_project_teams_vigente_index
           )
  end
end
