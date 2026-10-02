defmodule TheBand.Repo.Migrations.EpisodioDeSuspensao do
  @moduledoc """
  O episódio de suspensão — spec 070, T044 (`data-model.md` §4; FR-006, SC-002, O9).

  `tenants.status` continua sendo a resposta rápida, e o episódio é o registro: quem suspendeu,
  quando, por quê, e quem reativou. **Um aberto por organização** (o índice parcial), e nada se
  apaga nem se reescreve: o único `UPDATE` aceito fecha um episódio aberto.

  ## As organizações já suspensas

  Uma organização `suspended` antes desta feature foi suspensa à mão no banco, sem autor nem razão.
  O `up` grava para cada uma um episódio `not_recorded`, sem autor, com a data de agora: a consulta
  do SC-002 (`data-model.md` §7) passa a dar zero, e o histórico diz que a razão não foi registrada
  em vez de inventar uma. É a regra de research R6: nunca mapear em silêncio.

  O invariante "estado só com episódio" no banco vem na migração seguinte (T044a), que confere as
  contagens antes de criar o trigger.

  **Os triggers protegem de código, e não de quem tem o banco** (research R7; a #1131).
  """
  use Ecto.Migration

  def up do
    create table(:tenant_suspensions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :suspended_at, :utc_datetime, null: false

      add :suspended_by_operator_id,
          references(:platform_operators, type: :binary_id, on_delete: :restrict)

      add :suspend_reason, :string, null: false
      add :suspend_note, :text
      add :reactivated_at, :utc_datetime

      add :reactivated_by_operator_id,
          references(:platform_operators, type: :binary_id, on_delete: :restrict)

      add :reactivate_reason, :string
      add :reactivate_note, :text

      timestamps(type: :utc_datetime)
    end

    # Um episódio aberto por organização (O9, SC-002).
    create unique_index(:tenant_suspensions, [:tenant_id],
             where: "reactivated_at IS NULL",
             name: :tenant_suspensions_aberto_index
           )

    create index(:tenant_suspensions, [:tenant_id, :suspended_at])

    # Sem autor só no caso da migração: toda suspensão pela tela tem operador.
    create constraint(:tenant_suspensions, :tenant_suspensions_autor_so_falta_no_nao_registrado,
             check: "(suspend_reason = 'not_recorded') = (suspended_by_operator_id IS NULL)"
           )

    create constraint(:tenant_suspensions, :tenant_suspensions_reativacao_inteira,
             check:
               "(reactivated_at IS NULL) = (reactivated_by_operator_id IS NULL) AND " <>
                 "(reactivated_at IS NULL) = (reactivate_reason IS NULL)"
           )

    create constraint(:tenant_suspensions, :tenant_suspensions_nota_so_com_reativacao,
             check: "reactivate_note IS NULL OR reactivated_at IS NOT NULL"
           )

    execute("""
    CREATE FUNCTION tenant_suspensions_recusa() RETURNS trigger
    SET search_path = pg_catalog, public AS $$
    BEGIN
      RAISE EXCEPTION 'tenant_suspensions é somente-acréscimo: % recusado', TG_OP
        USING ERRCODE = 'restrict_violation';
    END $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER tenant_suspensions_nao_apaga
      BEFORE DELETE ON tenant_suspensions
      FOR EACH ROW EXECUTE FUNCTION tenant_suspensions_recusa();
    """)

    # `TRUNCATE` não dispara trigger de linha (A13a): precisa do seu, por comando.
    execute("""
    CREATE TRIGGER tenant_suspensions_nao_trunca
      BEFORE TRUNCATE ON tenant_suspensions
      FOR EACH STATEMENT EXECUTE FUNCTION tenant_suspensions_recusa();
    """)

    # Coluna a coluna, com `IS DISTINCT FROM` (A13b): o UPDATE só passa se o episódio estava aberto
    # e nada da abertura mudou. `updated_at` é liberado; a reativação, só a partir de nulos, e o
    # `CHECK` de tudo-ou-nada diz que os três campos vêm juntos.
    execute("""
    CREATE FUNCTION tenant_suspensions_so_fecha() RETURNS trigger
    SET search_path = pg_catalog, public AS $$
    BEGIN
      IF OLD.reactivated_at IS NOT NULL
         OR OLD.reactivate_note IS NOT NULL
         OR NEW.id IS DISTINCT FROM OLD.id
         OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
         OR NEW.suspended_at IS DISTINCT FROM OLD.suspended_at
         OR NEW.suspended_by_operator_id IS DISTINCT FROM OLD.suspended_by_operator_id
         OR NEW.suspend_reason IS DISTINCT FROM OLD.suspend_reason
         OR NEW.suspend_note IS DISTINCT FROM OLD.suspend_note
         OR NEW.inserted_at IS DISTINCT FROM OLD.inserted_at THEN
        RAISE EXCEPTION 'tenant_suspensions: só o fechamento de um episódio aberto é aceito'
          USING ERRCODE = 'restrict_violation';
      END IF;
      RETURN NEW;
    END $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER tenant_suspensions_so_fecha
      BEFORE UPDATE ON tenant_suspensions
      FOR EACH ROW EXECUTE FUNCTION tenant_suspensions_so_fecha();
    """)

    flush()
    registrar_nao_registradas!(repo())
  end

  @doc """
  Um episódio `not_recorded`, sem autor, para cada organização `suspended` sem episódio aberto.
  Devolve quantas. Pública para o teste, que a chama no sandbox (o migrator não convive com ele).
  """
  def registrar_nao_registradas!(repo) do
    %{num_rows: n} =
      repo.query!("""
      INSERT INTO tenant_suspensions (id, tenant_id, suspended_at, suspend_reason, inserted_at, updated_at)
      SELECT gen_random_uuid(), t.id, date_trunc('second', timezone('UTC', now())), 'not_recorded',
             date_trunc('second', timezone('UTC', now())), date_trunc('second', timezone('UTC', now()))
      FROM tenants t
      WHERE t.status = 'suspended'
        AND NOT EXISTS (SELECT 1 FROM tenant_suspensions s
                        WHERE s.tenant_id = t.id AND s.reactivated_at IS NULL)
      """)

    n
  end

  # Apagar a tabela leva os triggers junto; a função fica, e sai por último. Os episódios
  # `not_recorded` também se vão: voltar daqui é voltar a antes da feature, quando eles não
  # existiam, e o estado das organizações não muda.
  def down do
    drop table(:tenant_suspensions)
    execute("DROP FUNCTION tenant_suspensions_so_fecha();")
    execute("DROP FUNCTION tenant_suspensions_recusa();")
  end
end
