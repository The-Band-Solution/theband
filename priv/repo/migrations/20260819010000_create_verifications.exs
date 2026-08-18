defmodule TheBand.Repo.Migrations.CreateVerifications do
  @moduledoc """
  As execuções de verificação contínua — feature 037, issue #401.

  `collected_verifications` instancia `ciro.continuous_integration_process`;
  `verification_components`, os processos componentes (build, teste, inspeção) que a
  CIRO distingue e o GitHub agrupa em jobs.

  **Duas colunas para dois eixos independentes**: `trigger` decide o SUBTIPO
  (check-in, agendado, sob demanda) e `phase` decide a FASE (bem-sucedido, malsucedido,
  interrompido, não executado, expirado). Um processo pode ser "iniciado por check-in" E
  "bem-sucedido" sem contradição — são eixos distintos na ontologia, e uma coluna só os
  colapsaria.
  """
  use Ecto.Migration

  def change do
    create table(:collected_verifications, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_repository_id,
          references(:observed_repositories, type: :uuid, on_delete: :delete_all),
          null: false

      add :workflow_name, :string
      add :head_sha, :string, null: false
      add :head_branch, :string

      # O evento cru da origem: push, pull_request, schedule, workflow_dispatch…
      add :trigger_event, :string
      # queued | in_progress | completed — cru.
      add :run_status, :string
      # success | failure | cancelled | skipped | timed_out | nil — cru.
      add :conclusion, :string

      # **A fase derivada**, nula enquanto o processo não termina: em andamento não é nem
      # bem nem malsucedido, e atribuir fase afirmaria resultado que não existe.
      add :phase, :string

      # Reexecução: passar na terceira tentativa é sucesso, e a tentativa importa para o
      # antipadrão `ci.ap03.integrated_with_red_verification`.
      add :attempt, :integer, default: 1

      add :external_started_at, :utc_datetime
      add :external_finished_at, :utc_datetime

      add :actor_login, :string
      add :actor_person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all)

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :raw_payload, :map

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collected_verifications, [:tenant_id, :external_id])
    # O índice que liga verificação ao rastreio: o CI executa sobre um commit, e o commit
    # já está lá.
    create index(:collected_verifications, [:tenant_id, :head_sha])
    create index(:collected_verifications, [:tenant_id, :observed_repository_id])

    create table(:verification_components, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :collected_verification_id,
          references(:collected_verifications, type: :uuid, on_delete: :delete_all),
          null: false

      add :job_name, :string, null: false
      add :conclusion, :string
      add :phase, :string

      # **Os componentes reconhecidos, em array**: um job pode ser build E teste E
      # inspeção — é o antipadrão `ci.ap01.monolithic_job`, e guardar só um perderia o
      # que a máxima existe para mostrar. Array vazio é "não classificado", que é
      # ausência nomeada (`ci.ap02.unnamed_components`), nunca "build por padrão".
      add :components, {:array, :string}, null: false, default: []
      add :step_names, {:array, :string}, null: false, default: []

      add :external_started_at, :utc_datetime
      add :external_finished_at, :utc_datetime

      add :external_id, :string, null: false
      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:verification_components, [:tenant_id, :external_id])
    create index(:verification_components, [:tenant_id, :collected_verification_id])

    alter table(:observed_repositories) do
      add :verifications_collected_at, :utc_datetime
    end
  end
end
