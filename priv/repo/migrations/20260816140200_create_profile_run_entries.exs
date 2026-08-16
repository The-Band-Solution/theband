defmodule TheBand.Repo.Migrations.CreateProfileRunEntries do
  @moduledoc """
  Uma linha por pessoa **considerada** na rodada — feature 027.

  ## É o checkpoint, e por isso a unicidade é do banco

  A rodada leva de 15 a 35 minutos, e `max_attempts` do Oban é maior que um. Sem este índice,
  a segunda tentativa regeraria quem já foi gerado — e como os perfis são somente-acréscimo
  (`FR-015` da feature 026), a tabela guardaria os dois textos. A série temporal que a 027
  cria passaria a ter pontos duplicados que ninguém pediu.

  Validação de changeset não basta: ela não sobrevive a duas execuções concorrentes.

  ## Pular e falhar são coisas diferentes

  Pular é a plataforma **decidindo** não escrever; falhar é ela ter tentado e não conseguido.
  Por isso `failed` é `outcome`, e não um quarto motivo de pulo — a tela conta os dois
  separados, e a `FR-014` proíbe agregá-los.
  """

  use Ecto.Migration

  def change do
    create table(:profile_run_entries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :profile_run_id, references(:profile_runs, type: :uuid, on_delete: :delete_all),
        null: false

      add :person_id, references(:eo_people, type: :uuid, on_delete: :restrict), null: false

      add :outcome, :string, null: false
      add :reason, :string
      add :failure_reason, :text

      add :person_profile_id,
          references(:eo_person_profiles, type: :uuid, on_delete: :nilify_all)

      # Nulo é ausência nomeada, nunca zero. Zero significaria "chamou e não consumiu", que
      # não acontece — ausência é nula, e é o princípio VIII da constituição.
      add :input_tokens, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profile_run_entries, [:profile_run_id, :person_id])
    create index(:profile_run_entries, [:tenant_id, :profile_run_id])

    create constraint(:profile_run_entries, :profile_run_entry_outcome_valido,
             check: "outcome in ('generated', 'skipped', 'failed')"
           )

    # Os três motivos de pulo são lista fechada. Não existe `other`: um motivo genérico é o
    # "não elegível" que a `FR-014` proíbe.
    create constraint(:profile_run_entries, :profile_run_entry_reason_valido,
             check: """
             (outcome = 'skipped' AND reason in ('no_material','no_new_work','observation_ended'))
             OR (outcome <> 'skipped' AND reason IS NULL)
             """
           )

    create constraint(:profile_run_entries, :profile_run_entry_falha_tem_motivo,
             check: """
             (outcome = 'failed' AND failure_reason IS NOT NULL)
             OR (outcome <> 'failed' AND failure_reason IS NULL)
             """
           )
  end
end
