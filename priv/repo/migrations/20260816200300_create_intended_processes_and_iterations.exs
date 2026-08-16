defmodule TheBand.Repo.Migrations.CreateIntendedProcessesAndIterations do
  @moduledoc """
  O par pretendida/ocorrida das iterações — sprint 017, T052 e T053. FR-029 a FR-031.

  `spo_intended_project_processes` é a iteração **futura**: planejamento que não foi
  feito — `spo.specific_intended_project_process`, categoria UFO `intention`.

  `project_iterations` é a razão-fonte: cada iteração coletada, apontando para o que
  ela virou. **Exatamente um dos dois preenchido, nunca os dois, nunca nenhum**
  (SC-009c) — a constraint é do banco, não de changeset, porque é o banco que
  sobrevive à retentativa.

  ## A reconciliação com a feature 024

  A 024 gravou as iterações iniciadas direto em `sro_sprints` — 220 vivas, 2225
  vínculos — e elas **ficam onde estão**. `project_iterations` nasce por cima,
  backfillada dessas 220 na primeira coleta que ligar cada sprint ao quadro novo:
  o backfill exige o `observed_project_id`, que só existe depois da coleta de quadros
  rodar, então é a coleta que liga — nunca esta migração, que não tem como saber a
  qual quadro cada `board_number` pertence sem a Application Reference do quadro.
  """

  use Ecto.Migration

  def change do
    create table(:spo_intended_project_processes, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      add :title, :string, null: false
      add :planned_start_on, :date, null: false
      add :duration_days, :integer, null: false

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :source_external_id, :string, null: false

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :spo_intended_project_processes,
             [:tenant_id, :source_system, :source_instance, :source_external_id],
             name: :spo_intended_processes_application_reference_index
           )

    create table(:project_iterations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all),
          null: false

      add :iteration_external_id, :string, null: false
      add :field_external_id, :string, null: false
      add :title, :string, null: false
      add :start_date, :date, null: false
      add :duration_days, :integer, null: false

      add :sro_sprint_id, references(:sro_sprints, type: :uuid, on_delete: :nilify_all)

      add :spo_intended_process_id,
          references(:spo_intended_project_processes, type: :uuid, on_delete: :nilify_all)

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false

      # FR-031: removida da configuração é marcada, nunca apagada. Os itens dela NÃO
      # voltam ao product backlog — voltar afirmaria replanejamento que ninguém decidiu.
      add :no_longer_in_configuration_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # O id da iteração é local ao campo (medido em 2026-08-15: `d8d2574c` no Sprint 40),
    # então a identidade é o par campo:iteração dentro do quadro — a mesma decisão da 024.
    create unique_index(
             :project_iterations,
             [:tenant_id, :observed_project_id, :field_external_id, :iteration_external_id],
             name: :project_iterations_identidade_index
           )

    create constraint(:project_iterations, :project_iterations_exatamente_um_destino,
             check: """
             (sro_sprint_id IS NOT NULL AND spo_intended_process_id IS NULL) OR
             (sro_sprint_id IS NULL AND spo_intended_process_id IS NOT NULL)
             """
           )
  end
end
