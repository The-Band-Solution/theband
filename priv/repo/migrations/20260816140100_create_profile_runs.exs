defmodule TheBand.Repo.Migrations.CreateProfileRuns do
  @moduledoc """
  A rodada de geração de perfis — feature 027, `FR-014` e `FR-017`.

  ## `finished_at` nulo é "em execução", e é o que a `FR-003` consulta

  Duas rodadas do mesmo tenant não podem executar juntas — inclusive as disparadas a mão.
  O índice parcial existe para essa consulta, e não para relatório: ela roda a cada disparo.

  ## As contagens **não** moram aqui

  Consideradas, geradas, puladas por motivo, falhas e tokens saem de agregação sobre
  `profile_run_entries`. Guardá-las em coluna seria mais rápido e criaria o defeito que este
  repositório já teve duas vezes: dois lugares guardando o mesmo fato, e eles discordando
  depois de uma retentativa.
  """

  use Ecto.Migration

  def change do
    create table(:profile_runs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :trigger, :string, null: false

      # Nulo aqui é ausência **real**, e não desconhecida: rodada automática não tem quem a
      # pediu, porque ninguém a pediu.
      add :requested_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime
      add :outcome, :string
      add :ended_reason, :text

      # Os quatro últimos da chave usada. É o que torna a `SC-006` — nenhuma rodada consome a
      # credencial de outra — verificável **pelo registro**, e não por inspeção de código.
      add :credential_last_four, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:profile_runs, [:tenant_id, :started_at])

    create unique_index(:profile_runs, [:tenant_id],
             where: "finished_at IS NULL",
             name: :profile_runs_uma_aberta_por_tenant
           )

    create constraint(:profile_runs, :profile_run_trigger_valido,
             check: "trigger in ('cron', 'manual')"
           )

    create constraint(:profile_runs, :profile_run_outcome_valido,
             check: "outcome is null or outcome in ('completed', 'ended_early')"
           )
  end
end
