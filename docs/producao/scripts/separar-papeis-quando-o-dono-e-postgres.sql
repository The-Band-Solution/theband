-- Separação dos papéis quando o dono de hoje é o `postgres` (runbook §14.2, caso que o REASSIGN
-- OWNED não cobre). Rodar como `postgres`, NA BASE DA APLICAÇÃO, numa transação: ou tudo, ou nada.
-- Troque <senha do dono> e <senha de quem serve> por `openssl rand -hex 32` (só hexadecimal).
BEGIN;

CREATE ROLE the_band_owner LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS
  PASSWORD '<senha do dono>';
CREATE ROLE the_band_app   LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS
  PASSWORD '<senha de quem serve>';

DO $$
DECLARE r record;
BEGIN
  -- Tabelas (as sequências de coluna serial/identity acompanham a tabela).
  FOR r IN SELECT format('ALTER TABLE %I.%I OWNER TO the_band_owner', schemaname, tablename) AS c
             FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE r.c;
  END LOOP;

  -- Sequências avulsas, views e views materializadas; nada que pertença a extensão.
  FOR r IN SELECT format('ALTER %s %I.%I OWNER TO the_band_owner',
                         CASE c.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW'
                                        ELSE 'MATERIALIZED VIEW' END,
                         n.nspname, c.relname) AS c
             FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind IN ('S', 'v', 'm')
              AND pg_get_userbyid(c.relowner) <> 'the_band_owner'
              AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e') LOOP
    EXECUTE r.c;
  END LOOP;

  -- Funções (as dos triggers somente-acréscimo), menos as de extensão.
  FOR r IN SELECT format('ALTER ROUTINE %s OWNER TO the_band_owner', p.oid::regprocedure) AS c
             FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e') LOOP
    EXECUTE r.c;
  END LOOP;

  -- Tipos próprios (enum, domínio), menos os de linha de tabela e os de extensão.
  FOR r IN SELECT format('ALTER TYPE %I.%I OWNER TO the_band_owner', n.nspname, t.typname) AS c
             FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = 'public' AND t.typtype IN ('e', 'd')
              AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = t.oid AND d.deptype = 'e') LOOP
    EXECUTE r.c;
  END LOOP;
END $$;

ALTER SCHEMA public OWNER TO the_band_owner;
SELECT format('ALTER DATABASE %I OWNER TO the_band_owner', current_database()) \gexec

-- Conferência antes do COMMIT: as quatro devem dar 0.
SELECT 'tabelas de outro dono' AS o_que, count(*) FROM pg_tables
 WHERE schemaname = 'public' AND tableowner <> 'the_band_owner'
UNION ALL
SELECT 'funções de outro dono', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND pg_get_userbyid(p.proowner) <> 'the_band_owner'
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
UNION ALL
SELECT 'sequências de outro dono', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'S' AND pg_get_userbyid(c.relowner) <> 'the_band_owner'
UNION ALL
SELECT 'the_band_app é membro do dono', count(*) FROM pg_auth_members m
 WHERE m.roleid = 'the_band_owner'::regrole AND m.member = 'the_band_app'::regrole;

COMMIT;
