defmodule TheBand.Repo.Migrations.CreateProfileAutomationEvents do
  @moduledoc """
  O ato de ligar ou desligar a geração automática — feature 027, `FR-018` e `FR-019`.

  ## Por que evento, e não uma coluna em `tenants`

  A `FR-019` quer o autor de **ligar e de desligar**. Um booleano guardaria o estado e
  perderia o autor; um booleano mais uma tabela de auditoria guardaria o mesmo fato em dois
  lugares, e os dois divergiriam.

  Este projeto já pagou por isso: a issue #178 corrigiu exatamente esse desenho em
  `connected_tools`, onde uma coluna de situação discordava dos eventos de observação.
  `Sources.situacao/1` passou a derivar, e o defeito sumiu.

  ## Ausência de evento é "desligada"

  É o que faz a `FR-018c` valer sem migração de dados: organização que já existe não tem
  evento, logo não está ligada. Um deploy não pode fazer texto passar a existir sobre
  ninguém.
  """

  use Ecto.Migration

  def change do
    create table(:profile_automation_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :event, :string, null: false

      # **Não anulável.** Um evento sem autor é o estado sem dono que a `FR-018a` existe para
      # impedir — e é a única pessoa identificável por trás de todo texto que a rodada
      # produzir.
      add :actor_user_id, references(:users, type: :uuid, on_delete: :restrict), null: false

      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:profile_automation_events, [:tenant_id, :occurred_at])

    create constraint(:profile_automation_events, :profile_automation_event_valido,
             check: "event in ('enabled', 'disabled')"
           )
  end
end
