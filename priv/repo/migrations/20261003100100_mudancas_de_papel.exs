defmodule TheBand.Repo.Migrations.MudancasDePapel do
  @moduledoc """
  O registro das mudanças de papel — spec 072, T002 e T003 (`data-model.md`; FR-005; S6 de
  `specs/072-papel-de-administrador/seguranca.md`).

  Somente-acréscimo, garantido no banco, como o episódio da 070: nada se apaga, nada se altera,
  nada se trunca. E um trigger de constraint **adiado** em `users`: no `COMMIT`, toda mudança de
  `users.role` precisa do episódio da mesma transação (`txid`), com o papel de chegada. Isso torna
  a SC-002 ("só o ato muda o papel") mensurável, e fecha o caminho por acidente: `update_all`,
  `eval`, SQL cru.

  **Protege de código, e não de quem tem o banco**: o dono das tabelas pode desligar os triggers
  (#1131, spec 071). O `INSERT` em `users` não entra: o bootstrap cria a primeira conta como
  administradora, e o cadastro cria sempre `member` pelo código (FR-006).

  Sem backfill (Q6, decidida em 2026-10-03): os administradores de hoje não ganham episódio, e a
  tela escreve "no role change recorded".
  """
  use Ecto.Migration

  def up do
    create table(:account_role_changes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :changed_by_user_id, references(:users, type: :binary_id, on_delete: :restrict),
        null: false

      add :from_role, :string, null: false
      add :to_role, :string, null: false
      add :note, :text
      add :txid, :bigint, null: false, default: fragment("txid_current()")

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:account_role_changes, [:tenant_id, :inserted_at])
    create index(:account_role_changes, [:user_id, :inserted_at])

    create constraint(:account_role_changes, :account_role_changes_papeis_validos,
             check:
               "from_role IN ('admin', 'member') AND to_role IN ('admin', 'member') " <>
                 "AND from_role <> to_role"
           )

    execute("""
    CREATE FUNCTION account_role_changes_recusa() RETURNS trigger
    SET search_path = pg_catalog, public, pg_temp AS $$
    BEGIN
      RAISE EXCEPTION 'account_role_changes é somente-acréscimo: % recusado', TG_OP
        USING ERRCODE = 'restrict_violation';
    END $$ LANGUAGE plpgsql;
    """)

    for {nome, quando, nivel} <- [
          {"nao_apaga", "DELETE", "ROW"},
          {"nao_altera", "UPDATE", "ROW"},
          {"nao_trunca", "TRUNCATE", "STATEMENT"}
        ] do
      execute("""
      CREATE TRIGGER account_role_changes_#{nome}
        BEFORE #{quando} ON account_role_changes
        FOR EACH #{nivel} EXECUTE FUNCTION account_role_changes_recusa();
      """)
    end

    # T003: o papel só muda com o episódio da mesma transação. Adiado, porque o ato escreve o papel
    # antes do episódio. Nomes qualificados e `pg_temp` por último (o G2 da 070).
    execute("""
    CREATE FUNCTION users_papel_tem_episodio() RETURNS trigger
    SET search_path = pg_catalog, public, pg_temp AS $$
    BEGIN
      IF NEW.role IS DISTINCT FROM OLD.role AND NOT EXISTS (
        SELECT 1 FROM public.account_role_changes c
        WHERE c.user_id = NEW.id AND c.to_role = NEW.role AND c.txid = txid_current()
      ) THEN
        RAISE EXCEPTION 'conta % mudou de papel sem episódio', NEW.id
          USING ERRCODE = 'check_violation', CONSTRAINT = 'users_papel_tem_episodio';
      END IF;
      RETURN NULL;
    END $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER users_papel_tem_episodio
      AFTER UPDATE OF role ON users
      DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION users_papel_tem_episodio();
    """)
  end

  def down do
    execute("DROP TRIGGER users_papel_tem_episodio ON users")
    execute("DROP FUNCTION users_papel_tem_episodio()")
    drop table(:account_role_changes)
    execute("DROP FUNCTION account_role_changes_recusa()")
  end
end
