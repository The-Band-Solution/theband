defmodule TheBand.Repo.Migrations.OperadorDaPlataforma do
  @moduledoc """
  O operador da plataforma — spec 070, T018 (`data-model.md` §1, §2 e §3). As colunas do segundo
  fator vêm na migração seguinte (T020).

  As três tabelas **não têm `tenant_id`**: o operador é uma entidade fora de qualquer organização
  (FR-011), e é por isso que nenhum caminho de domínio o alcança. É uma das quatro exceções
  declaradas ao AGENTS §7.3 (`plan.md`, Technical Context).

  ## O que os triggers protegem, e o que não

  `platform_operator_grants` é registro somente-acréscimo: a concessão não se apaga, e a única
  alteração é a revogação (FR-002, O11, A13). Os triggers recusam `DELETE`, `TRUNCATE` e todo
  `UPDATE` que mude outra coisa além das quatro colunas da revogação.

  **Eles protegem de código, e não de quem tem o banco** (research R7): o dono das tabelas pode
  desligá-los. Separar o papel que migra do que serve é a #1131.
  """
  use Ecto.Migration

  def change do
    create table(:platform_operators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string, null: false
      add :password_hash, :string
      add :password_epoch, :integer, null: false, default: 0
      add :setup_code_hash, :binary
      add :setup_code_expires_at, :utc_datetime
      add :failed_attempts, :integer, null: false, default: 0
      add :last_failed_at, :utc_datetime
      add :logged_in_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:platform_operators, ["lower(email)"],
             name: :platform_operators_email_index
           )

    create constraint(:platform_operators, :platform_operators_codigo_de_definicao_em_par,
             check: "(setup_code_hash IS NULL) = (setup_code_expires_at IS NULL)"
           )

    create table(:platform_operator_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :operator_id, references(:platform_operators, type: :binary_id, on_delete: :restrict),
        null: false

      add :granted_at, :utc_datetime, null: false
      add :granted_via, :string, null: false
      add :granted_by_declared, :text, null: false
      add :email_at_grant, :string, null: false
      add :revoked_at, :utc_datetime
      add :revoked_via, :string
      add :revoked_by_declared, :text
      add :revoke_note, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Uma concessão vigente por operador, na forma de `access_scope_grants`.
    create unique_index(:platform_operator_grants, [:operator_id],
             where: "revoked_at IS NULL",
             name: :platform_operator_grants_vigente_index
           )

    create constraint(:platform_operator_grants, :platform_operator_grants_via_comando,
             check: "granted_via = 'release_command'"
           )

    create constraint(:platform_operator_grants, :platform_operator_grants_revogacao_via_comando,
             check: "revoked_via IS NULL OR revoked_via = 'release_command'"
           )

    create constraint(:platform_operator_grants, :platform_operator_grants_revogacao_inteira,
             check:
               "(revoked_at IS NULL) = (revoked_via IS NULL) AND " <>
                 "(revoked_at IS NULL) = (revoked_by_declared IS NULL)"
           )

    create table(:platform_operator_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :operator_id, references(:platform_operators, type: :binary_id, on_delete: :restrict),
        null: false

      add :token_hash, :binary, null: false
      add :password_epoch, :integer, null: false
      add :ended_at, :utc_datetime
      add :last_seen_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:platform_operator_sessions, [:token_hash])
    create index(:platform_operator_sessions, [:operator_id])
    create index(:platform_operator_sessions, [:ended_at])
    create index(:platform_operator_sessions, [:inserted_at])

    # Os triggers da concessão. Cada `execute` tem o seu par de `down`.
    execute(
      """
      CREATE FUNCTION platform_operator_grants_recusa() RETURNS trigger
      SET search_path = pg_catalog, public AS $$
      BEGIN
        RAISE EXCEPTION 'platform_operator_grants é somente-acréscimo: % recusado', TG_OP
          USING ERRCODE = 'restrict_violation';
      END $$ LANGUAGE plpgsql;
      """,
      "DROP FUNCTION platform_operator_grants_recusa();"
    )

    execute(
      """
      CREATE TRIGGER platform_operator_grants_nao_apaga
        BEFORE DELETE ON platform_operator_grants
        FOR EACH ROW EXECUTE FUNCTION platform_operator_grants_recusa();
      """,
      "DROP TRIGGER platform_operator_grants_nao_apaga ON platform_operator_grants;"
    )

    # `TRUNCATE` não dispara trigger de linha (A13a): precisa do seu, por comando.
    execute(
      """
      CREATE TRIGGER platform_operator_grants_nao_trunca
        BEFORE TRUNCATE ON platform_operator_grants
        FOR EACH STATEMENT EXECUTE FUNCTION platform_operator_grants_recusa();
      """,
      "DROP TRIGGER platform_operator_grants_nao_trunca ON platform_operator_grants;"
    )

    # Coluna a coluna, com `IS DISTINCT FROM`, que é seguro com nulo (A13b): o UPDATE só passa
    # se a concessão estava vigente e nada além das quatro colunas da revogação mudou.
    execute(
      """
      CREATE FUNCTION platform_operator_grants_so_revoga() RETURNS trigger
      SET search_path = pg_catalog, public AS $$
      BEGIN
        IF OLD.revoked_at IS NOT NULL
           OR NEW.id IS DISTINCT FROM OLD.id
           OR NEW.operator_id IS DISTINCT FROM OLD.operator_id
           OR NEW.granted_at IS DISTINCT FROM OLD.granted_at
           OR NEW.granted_via IS DISTINCT FROM OLD.granted_via
           OR NEW.granted_by_declared IS DISTINCT FROM OLD.granted_by_declared
           OR NEW.email_at_grant IS DISTINCT FROM OLD.email_at_grant
           OR NEW.inserted_at IS DISTINCT FROM OLD.inserted_at THEN
          RAISE EXCEPTION 'platform_operator_grants: só a revogação de uma concessão vigente é aceita'
            USING ERRCODE = 'restrict_violation';
        END IF;
        RETURN NEW;
      END $$ LANGUAGE plpgsql;
      """,
      "DROP FUNCTION platform_operator_grants_so_revoga();"
    )

    execute(
      """
      CREATE TRIGGER platform_operator_grants_so_revoga
        BEFORE UPDATE ON platform_operator_grants
        FOR EACH ROW EXECUTE FUNCTION platform_operator_grants_so_revoga();
      """,
      "DROP TRIGGER platform_operator_grants_so_revoga ON platform_operator_grants;"
    )
  end
end
