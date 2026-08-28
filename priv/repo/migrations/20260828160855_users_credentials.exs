defmodule TheBand.Repo.Migrations.UsersCredentials do
  use Ecto.Migration

  @moduledoc """
  Feature 045 (US1): a conta ganha credencial e sessão versionada.

  `password_hash` NULO é estado legítimo: conta anterior à feature, que a entrada
  recusa com a mensagem única e orienta a procurar quem administra (FR-014).
  Nenhuma senha é semeada aqui — credencial não nasce em migração.
  """

  def change do
    alter table(:users) do
      add :password_hash, :string
      add :password_set_at, :utc_datetime
      add :must_change_password, :boolean, default: false, null: false
      add :session_token, :string
      add :logged_in_at, :utc_datetime
      add :failed_attempts, :integer, default: 0, null: false
      add :last_failed_at, :utc_datetime
    end
  end
end
