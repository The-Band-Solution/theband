defmodule TheBand.Papeis do
  @moduledoc """
  Os privilégios do papel que serve: concedidos a cada deploy e conferidos contra o banco — spec
  071 (#1131, achado G1 da 070). Contrato em `specs/071-papeis-do-banco/contracts/papeis.md`.

  Depende de: nenhuma ontologia. Não recebe tenant: é infraestrutura de acesso.

  ## Por que isto existe

  A aplicação migrava e servia com o mesmo papel, dono das tabelas. Quem executasse SQL por ela
  desligava as guardas que vivem no banco — os triggers somente-acréscimo, o trigger adiado da 070,
  as `CHECK` e as FKs. O papel que serve passa a ter só DML (FR-002), e quem migra é outro.

  ## SQL literal

  Nenhum identificador é interpolado em Elixir. Os nomes entram por `set_config/3` local à
  transação, e o bloco `DO` os cita com `format('%I', …)` do próprio PostgreSQL. Uma tentativa que
  o servidor recusa propaga o `SQLSTATE` original, e só `42501` conta como recusa (FR-003).
  """
  require Logger

  @type motivo ::
          :superusuario
          | :atributo_perigoso
          | :dono_de_objeto
          | :membro_do_dono
          | :membro_predefinido
          | :privilegio_a_mais
          | :schema_migrations_gravavel
          | :replica_permitida
          | :create_no_esquema
          | :mesma_credencial
          | :tentativa_passou
          | :tentativa_inconclusiva
          | :funcao_sem_search_path
          | :dono_superusuario

  @type veredito :: :em_vigor | :nao_em_vigor | :inconclusivo

  @predefinidos ~w(pg_execute_server_program pg_read_server_files pg_write_server_files
                   pg_signal_backend)

  # ------------------------------------------------------------------ conceder

  @doc """
  Concede ao `papel_que_serve` exatamente a lista fechada de FR-002, e os privilégios padrão para
  o que o papel corrente (o que migra) criar. Idempotente: rodar de novo dá o mesmo estado, e
  retira o que estivesse a mais (`TRUNCATE`, `REFERENCES`, `TRIGGER`, escrita em
  `schema_migrations`). Roda dentro de uma transação, com a conexão do papel que migra.
  """
  @spec conceder(Ecto.Repo.t(), String.t()) :: :ok
  def conceder(repo, papel_que_serve) when is_binary(papel_que_serve) do
    {:ok, :ok} =
      repo.transaction(fn ->
        %{rows: [[existe, mesmo]]} =
          repo.query!(
            "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = $1), $1 = current_user",
            [papel_que_serve]
          )

        unless existe,
          do:
            raise(ArgumentError, "o papel que serve não existe no banco; crie-o pelo roteiro §14")

        if mesmo,
          do:
            raise(
              ArgumentError,
              "o papel que serve é o mesmo que migra: a separação não existe (:mesma_credencial)"
            )

        repo.query!("SELECT set_config('the_band.papel_que_serve', $1, true)", [papel_que_serve])

        repo.query!("""
        DO $$
        DECLARE p text := current_setting('the_band.papel_que_serve');
        BEGIN
          EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), p);
          EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', p);
          EXECUTE format('REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public FROM %I', p);
          EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %I', p);
          EXECUTE format('REVOKE UPDATE ON ALL SEQUENCES IN SCHEMA public FROM %I', p);
          EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO %I', p);
          EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', current_user, p);
          EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO %I', current_user, p);
          IF to_regclass('public.schema_migrations') IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON public.schema_migrations FROM %I', p);
            EXECUTE format('GRANT SELECT ON public.schema_migrations TO %I', p);
          END IF;
          EXECUTE 'REVOKE CREATE ON SCHEMA public FROM PUBLIC';
          EXECUTE format('REVOKE CREATE ON DATABASE %I FROM PUBLIC', current_database());
        END $$;
        """)

        :ok
      end)

    :ok
  end

  # ------------------------------------------------------------------ conferir

  @doc """
  Mede, com a conexão de quem serve, se a separação está em vigor (FR-009). Lê o catálogo e tenta
  as recusas de FR-003 numa transação que **sempre** termina em `ROLLBACK`. Nunca grava.

  `:em_vigor` só com a lista de motivos vazia, ou só com `:dono_superusuario`, que é aviso sobre
  quem migra (`opcoes[:papel_que_migra]`, quando conhecido).
  """
  @spec conferir(Ecto.Repo.t(), keyword()) :: {veredito(), [motivo()]}
  def conferir(repo, opcoes \\ []) do
    catalogo = motivos_do_catalogo(repo, opcoes)
    tentativas = motivos_das_tentativas(repo)
    motivos = Enum.uniq(catalogo ++ tentativas)
    {veredito(motivos), motivos}
  rescue
    erro in [Postgrex.Error, DBConnection.ConnectionError] ->
      Logger.warning("papéis: conferência inconclusiva (#{erro.__struct__})")
      {:inconclusivo, [:tentativa_inconclusiva]}
  end

  defp veredito(motivos) do
    cond do
      motivos -- [:dono_superusuario] == [] ->
        :em_vigor

      :tentativa_inconclusiva in motivos and
          motivos -- [:tentativa_inconclusiva, :dono_superusuario] == [] ->
        :inconclusivo

      true ->
        :nao_em_vigor
    end
  end

  defp motivos_do_catalogo(repo, opcoes) do
    Enum.flat_map(
      [&atributos/1, &posse/1, &pertencas/1, &privilegios/1, &funcoes_de_trigger/1],
      & &1.(repo)
    ) ++ motivos_de_quem_migra(repo, opcoes[:papel_que_migra])
  end

  defp marcar(motivos), do: for({m, true} <- motivos, do: m)

  defp atributos(repo) do
    %{rows: [[super, perigoso]]} =
      repo.query!("""
      SELECT rolsuper, rolcreaterole OR rolcreatedb OR rolreplication OR rolbypassrls
      FROM pg_roles WHERE rolname = current_user
      """)

    marcar(superusuario: super, atributo_perigoso: perigoso)
  end

  defp posse(repo) do
    %{rows: [[donos_de_objeto]]} =
      repo.query!("""
      SELECT
        (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relowner = (SELECT oid FROM pg_roles WHERE rolname = current_user))
      + (SELECT count(*) FROM pg_proc f JOIN pg_namespace n ON n.oid = f.pronamespace
           WHERE n.nspname = 'public' AND f.proowner = (SELECT oid FROM pg_roles WHERE rolname = current_user))
      + (SELECT count(*) FROM pg_namespace WHERE nspname = 'public'
           AND nspowner = (SELECT oid FROM pg_roles WHERE rolname = current_user))
      + (SELECT count(*) FROM pg_database WHERE datname = current_database()
           AND datdba = (SELECT oid FROM pg_roles WHERE rolname = current_user))
      """)

    marcar(dono_de_objeto: donos_de_objeto > 0)
  end

  defp pertencas(repo) do
    %{rows: [[membro_do_dono]]} =
      repo.query!("""
      SELECT EXISTS (
        SELECT 1 FROM (
          SELECT DISTINCT c.relowner AS dono FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
          UNION SELECT nspowner FROM pg_namespace WHERE nspname = 'public'
          UNION SELECT datdba FROM pg_database WHERE datname = current_database()
        ) d
        JOIN pg_roles r ON r.oid = d.dono
        WHERE r.rolname <> current_user AND pg_has_role(current_user, r.oid, 'MEMBER')
      )
      """)

    %{rows: [[membro_predefinido]]} =
      repo.query!(
        """
        SELECT EXISTS (SELECT 1 FROM pg_roles r
                       WHERE r.rolname = ANY($1) AND pg_has_role(current_user, r.oid, 'MEMBER'))
        """,
        [@predefinidos]
      )

    marcar(membro_do_dono: membro_do_dono, membro_predefinido: membro_predefinido)
  end

  defp privilegios(repo) do
    %{rows: [[a_mais, migracoes_gravavel, create_esquema, create_base]]} =
      repo.query!("""
      SELECT
        EXISTS (SELECT 1 FROM information_schema.role_table_grants
                WHERE grantee = current_user AND table_schema = 'public'
                  AND privilege_type NOT IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')),
        to_regclass('public.schema_migrations') IS NOT NULL AND (
          has_table_privilege(current_user, 'public.schema_migrations', 'INSERT')
          OR has_table_privilege(current_user, 'public.schema_migrations', 'UPDATE')
          OR has_table_privilege(current_user, 'public.schema_migrations', 'DELETE')),
        has_schema_privilege(current_user, 'public', 'CREATE'),
        has_database_privilege(current_user, current_database(), 'CREATE')
      """)

    marcar(
      privilegio_a_mais: a_mais,
      schema_migrations_gravavel: migracoes_gravavel,
      create_no_esquema: create_esquema or create_base
    )
  end

  # S10: com `TEMP` para `PUBLIC`, uma função de trigger sem `search_path` fixo pode ser sombreada
  # por uma tabela temporária de mesmo nome.
  defp funcoes_de_trigger(repo) do
    %{rows: [[sem_search_path]]} =
      repo.query!("""
      SELECT EXISTS (
        SELECT 1 FROM pg_proc f JOIN pg_namespace n ON n.oid = f.pronamespace
        WHERE n.nspname = 'public' AND f.prorettype = 'trigger'::regtype
          AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(f.proconfig, '{}')) c WHERE c LIKE 'search_path=%')
      )
      """)

    marcar(funcao_sem_search_path: sem_search_path)
  end

  defp motivos_de_quem_migra(_repo, nil), do: []

  defp motivos_de_quem_migra(repo, papel) do
    %{rows: [[mesmo, super]]} =
      repo.query!(
        "SELECT $1 = current_user, coalesce((SELECT rolsuper FROM pg_roles WHERE rolname = $1), false)",
        [papel]
      )

    marcar(mesma_credencial: mesmo, dono_superusuario: super)
  end

  # As tentativas de FR-003. Cada uma num SAVEPOINT; a transação inteira é desfeita no fim.
  @tentativas [
    trigger: """
    DO $$ DECLARE t regclass; g name; BEGIN
      SELECT tgrelid::regclass, tgname INTO t, g FROM pg_trigger tr
        JOIN pg_class c ON c.oid = tr.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE NOT tr.tgisinternal AND n.nspname = 'public' LIMIT 1;
      IF t IS NULL THEN RAISE EXCEPTION 'sem alvo' USING ERRCODE = 'no_data_found'; END IF;
      EXECUTE format('ALTER TABLE %s DISABLE TRIGGER %I', t, g);
    END $$
    """,
    constraint: """
    DO $$ DECLARE t regclass; k name; BEGIN
      SELECT conrelid::regclass, conname INTO t, k FROM pg_constraint co
        JOIN pg_namespace n ON n.oid = co.connamespace
        WHERE co.contype = 'c' AND n.nspname = 'public' LIMIT 1;
      IF t IS NULL THEN RAISE EXCEPTION 'sem alvo' USING ERRCODE = 'no_data_found'; END IF;
      EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', t, k);
    END $$
    """,
    truncate: """
    DO $$ DECLARE t regclass; BEGIN
      SELECT c.oid::regclass INTO t FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname <> 'schema_migrations' LIMIT 1;
      IF t IS NULL THEN RAISE EXCEPTION 'sem alvo' USING ERRCODE = 'no_data_found'; END IF;
      EXECUTE format('TRUNCATE %s CASCADE', t);
    END $$
    """,
    funcao: """
    DO $$ DECLARE f regprocedure; BEGIN
      SELECT p.oid::regprocedure INTO f FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.prorettype = 'trigger'::regtype LIMIT 1;
      IF f IS NULL THEN RAISE EXCEPTION 'sem alvo' USING ERRCODE = 'no_data_found'; END IF;
      EXECUTE format('DROP FUNCTION %s CASCADE', f);
    END $$
    """,
    create: "CREATE TABLE public.papeis_conferencia_nao_deve_existir (x int)",
    replica: "SET LOCAL session_replication_role = replica",
    migracoes:
      "INSERT INTO public.schema_migrations (version, inserted_at) VALUES (99999999999999, now())"
  ]

  defp motivos_das_tentativas(repo) do
    {:error, {:desfeito, motivos}} =
      repo.transaction(fn ->
        repo.query!("SET LOCAL lock_timeout = '200ms'")
        motivos = Enum.flat_map(@tentativas, fn {nome, sql} -> tentar(repo, nome, sql) end)
        repo.rollback({:desfeito, motivos})
      end)

    motivos
  end

  defp tentar(repo, nome, sql) do
    repo.query!("SAVEPOINT papeis_tentativa")

    resultado =
      try do
        repo.query!(sql)
        :passou
      rescue
        e in Postgrex.Error -> e.postgres.code
      end

    repo.query!("ROLLBACK TO SAVEPOINT papeis_tentativa")

    case resultado do
      :insufficient_privilege -> []
      # Sem alvo na base (nenhum trigger, por exemplo): a tentativa não mediu nada.
      :no_data_found -> []
      :passou -> [if(nome == :replica, do: :replica_permitida, else: :tentativa_passou)]
      _outro -> [:tentativa_inconclusiva]
    end
  end

  # ------------------------------------------------------------------ pendentes

  @doc """
  As versões de `priv/repo/migrations` que não estão em `schema_migrations`. Lê com `SELECT`
  direto, e não pela `Ecto.Migrator`, que faz `CREATE TABLE IF NOT EXISTS` e é recusada a quem não
  tem `CREATE` no esquema (medido, research R4).
  """
  @spec pendentes(Ecto.Repo.t()) :: {:ok, [integer()]}
  def pendentes(repo) do
    nos_arquivos =
      repo.config()[:priv]
      |> Kernel.||("priv/repo")
      |> then(&Application.app_dir(:the_band, Path.join(&1, "migrations/*.exs")))
      |> Path.wildcard()
      |> Enum.flat_map(fn caminho ->
        case Integer.parse(Path.basename(caminho)) do
          {versao, "_" <> _} -> [versao]
          _ -> []
        end
      end)

    %{rows: linhas} = repo.query!("SELECT version FROM public.schema_migrations")
    aplicadas = MapSet.new(linhas, fn [v] -> v end)
    {:ok, nos_arquivos |> Enum.reject(&MapSet.member?(aplicadas, &1)) |> Enum.sort()}
  end
end
