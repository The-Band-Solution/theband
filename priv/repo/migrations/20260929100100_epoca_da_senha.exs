defmodule TheBand.Repo.Migrations.EpocaDaSenha do
  @moduledoc """
  A época da senha — feature 064, T010, research R2.

  Um inteiro que sobe a cada definição de senha. A sessão guarda a época com que nasceu, e uma
  época diferente da atual quer dizer que a senha foi definida depois, e então a sessão cai.

  Hoje `users.session_token` faz dois trabalhos: prova que a sessão é válida e serve de época.
  Por isso não pode ser resumido como está. Esta coluna fica com o segundo trabalho.

  **NÃO É SEGREDO.** Quem a lê não ganha nada, porque ela sozinha não abre sessão nenhuma.

  Aditiva: uma coluna não nula, com padrão `0`. O rollback a remove.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :password_epoch, :integer, null: false, default: 0
    end
  end
end
