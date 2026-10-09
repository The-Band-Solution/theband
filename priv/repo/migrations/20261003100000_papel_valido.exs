defmodule TheBand.Repo.Migrations.PapelValido do
  @moduledoc """
  O papel da conta é restrito no banco — spec 072, T001 (FR-006; S7 de
  `specs/072-papel-de-administrador/seguranca.md`). Antes da constraint, conta as linhas fora da
  lista e levanta com a contagem: nunca mapear em silêncio.
  """
  use Ecto.Migration

  def up do
    execute(fn -> conferir_papeis!(repo()) end)

    create constraint(:users, :users_role_valido, check: "role IN ('admin', 'member')")
  end

  @doc "Levanta se houver conta com papel fora de `admin` e `member`. Pública para o teste."
  def conferir_papeis!(repo) do
    %{rows: [[n]]} =
      repo.query!(
        "SELECT count(*) FROM users WHERE role IS NULL OR role NOT IN ('admin', 'member')"
      )

    if n > 0,
      do: raise("#{n} conta(s) com papel fora de admin e member; corrija antes de migrar")

    :ok
  end

  def down do
    drop constraint(:users, :users_role_valido)
  end
end
