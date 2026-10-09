defmodule TheBand.Repo.Migrations.EstadoTemEpisodio do
  @moduledoc """
  O banco recusa estado sem episódio — spec 070, T044a (`data-model.md` §4a; achado D1-a, decidido
  pela pessoa mantenedora em 2026-10-01; O10, SC-002).

  Um trigger de constraint **adiado**: no `COMMIT`, a organização `suspended` tem de ter um episódio
  aberto, e a `active` não pode ter nenhum. Fecha o caminho por acidente (`update_all`,
  `force_change`, `eval`, SQL cru); **não** é controle contra quem é dono das tabelas, que pode
  desligar o trigger (G1; a #1131).

  É o primeiro trigger adiado do repositório. Adiado porque, na transação legítima de
  `Platform.Suspensions`, o estado muda **antes** do episódio, e só no `COMMIT` os dois têm de
  concordar.

  Migração da `Platform`, e não de `Tenants`: o invariante é do episódio (exceção declarada à letra
  D do princípio X, só no banco; `plan.md`, Constitution Check).
  """
  use Ecto.Migration

  def up do
    # G4: antes da conferência, para nenhuma escrita de uma instância antiga caber entre ela e o
    # CREATE TRIGGER.
    execute("LOCK TABLE tenants, tenant_suspensions IN SHARE ROW EXCLUSIVE MODE")

    # O trigger só confere linhas escritas depois dele: o que já discorda tem de ser visto agora.
    execute(fn -> conferir_contagens!(repo()) end)

    # G2: uma tabela temporária de mesmo nome não pode sombrear a conferência. Duas camadas: os nomes
    # qualificados com `public.`, e `pg_temp` POR ÚLTIMO no `search_path`. Sem listá-lo, o
    # PostgreSQL procura `pg_temp` PRIMEIRO, e `pg_catalog, public` sozinho não protegeria nada
    # (documentação do PostgreSQL, "Writing SECURITY DEFINER Functions Safely").
    execute("""
    CREATE FUNCTION tenant_estado_tem_episodio() RETURNS trigger
    SET search_path = pg_catalog, public, pg_temp AS $$
    DECLARE
      alvo uuid;
      estado text;
      aberto boolean;
    BEGIN
      -- O ramo por IF, e não um CASE no DECLARE: o PL/pgSQL resolve os dois campos do CASE contra
      -- o NEW, e em `tenants` não há `tenant_id` (achado E1). Com IF, só o campo do ramo tomado é
      -- lido.
      IF TG_TABLE_NAME = 'tenants' THEN
        alvo := NEW.id;
      ELSE
        alvo := NEW.tenant_id;
      END IF;

      SELECT status INTO estado FROM public.tenants WHERE id = alvo;
      IF NOT FOUND THEN RETURN NULL; END IF;
      aberto := EXISTS (SELECT 1 FROM public.tenant_suspensions
                        WHERE tenant_id = alvo AND reactivated_at IS NULL);
      IF (estado = 'suspended') IS DISTINCT FROM aberto THEN
        RAISE EXCEPTION 'organização % com estado % e episódio aberto = %', alvo, estado, aberto
          USING ERRCODE = 'check_violation', CONSTRAINT = 'tenant_estado_tem_episodio';
      END IF;
      RETURN NULL;
    END $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER tenants_estado_tem_episodio
      AFTER INSERT OR UPDATE OF status ON tenants
      DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tenant_estado_tem_episodio();
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER tenant_suspensions_estado_tem_episodio
      AFTER INSERT OR UPDATE OF reactivated_at ON tenant_suspensions
      DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tenant_estado_tem_episodio();
    """)
  end

  @doc """
  A consulta do SC-002 (`data-model.md` §7) e a recíproca. Levanta com as contagens se alguma não
  der zero: nunca mapear em silêncio (research R6). Pública para o teste.
  """
  def conferir_contagens!(repo) do
    %{rows: [[sem_episodio, ativa_com_aberto]]} =
      repo.query!("""
      SELECT
        (SELECT count(*) FROM tenants t WHERE t.status = 'suspended'
           AND NOT EXISTS (SELECT 1 FROM tenant_suspensions s
                           WHERE s.tenant_id = t.id AND s.reactivated_at IS NULL)),
        (SELECT count(*) FROM tenants t WHERE t.status = 'active'
           AND EXISTS (SELECT 1 FROM tenant_suspensions s
                       WHERE s.tenant_id = t.id AND s.reactivated_at IS NULL))
      """)

    if sem_episodio + ativa_com_aberto > 0,
      do:
        raise(
          "#{sem_episodio} organização(ões) suspensa(s) sem episódio aberto e " <>
            "#{ativa_com_aberto} ativa(s) com episódio aberto: o trigger não confere linhas " <>
            "antigas, e elas precisam ser resolvidas antes"
        )

    :ok
  end

  def down do
    execute("DROP TRIGGER tenant_suspensions_estado_tem_episodio ON tenant_suspensions")
    execute("DROP TRIGGER tenants_estado_tem_episodio ON tenants")
    execute("DROP FUNCTION tenant_estado_tem_episodio()")
  end
end
