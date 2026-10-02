defmodule TheBand.PapeisTest do
  @moduledoc """
  Os privilégios do papel que serve — spec 071, T002 a T004 (FR-002, FR-003, FR-009, FR-011;
  cenários A1 a A5, A8 e A10 de `seguranca.md`).

  O papel não-dono nasce na transação do sandbox (`CREATE ROLE` é transacional) e morre no
  `ROLLBACK`. Ele recebe os privilégios pelo **mesmo** artefato da produção, `Papeis.conceder/2`, e
  não por `GRANT` escrito aqui. Antes de cada bateria, o teste afirma que mediu: `current_user` é o
  papel criado, e ele não é superusuário.
  """
  # Síncrono: as tentativas tomam locks de tabela (TRUNCATE, ALTER), e com testes assíncronos
  # segurando linhas elas esperariam o `lock_timeout` e dariam inconclusivo.
  use TheBand.DataCase, async: false

  # Cria papel no setup: excluído quando a suíte roda como o papel que serve (T005).
  @moduletag :precisa_criar_papel

  alias TheBand.Papeis

  setup do
    papel = "serve_t_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE ROLE #{papel} NOLOGIN")

    # Uma guarda própria do teste: tabela com CHECK, função de trigger com search_path fixo, e o
    # trigger. As guardas reais da 070 entram na conferência quando estiverem na base.
    Repo.query!("CREATE TABLE public.papeis_alvo (x int CHECK (x > 0))")

    Repo.query!("""
    CREATE FUNCTION public.papeis_alvo_recusa() RETURNS trigger
    SET search_path = pg_catalog, public, pg_temp AS $$
    BEGIN RAISE EXCEPTION 'recusado'; END $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER papeis_alvo_nao_apaga BEFORE DELETE ON public.papeis_alvo
      FOR EACH ROW EXECUTE FUNCTION public.papeis_alvo_recusa()
    """)

    Repo.query!("INSERT INTO public.papeis_alvo VALUES (1)")
    :ok = Papeis.conceder(Repo, papel)
    %{papel: papel}
  end

  defp como(papel, fun) do
    Repo.query!("SET LOCAL ROLE #{papel}")

    try do
      %{rows: [[eu, super]]} =
        Repo.query!("SELECT current_user, rolsuper FROM pg_roles WHERE rolname = current_user")

      assert eu == papel and super == false, "a medição não mediu: o papel não é o do teste"
      fun.()
    after
      Repo.query!("RESET ROLE")
    end
  end

  # Dentro de uma transação, e não com SAVEPOINT manual: no nível de cima do teste, o sandbox
  # envolve cada comando no próprio savepoint e desfaz o nosso quando o comando falha.
  defp tentativa(sql) do
    case Repo.transaction(fn ->
           Repo.query!(sql)
           Repo.rollback(:passou)
         end) do
      {:error, :passou} -> :passou
    end
  rescue
    e in Postgrex.Error -> e.postgres.code
  end

  @ataques [
    disable_trigger: "ALTER TABLE public.papeis_alvo DISABLE TRIGGER papeis_alvo_nao_apaga",
    drop_trigger: "DROP TRIGGER papeis_alvo_nao_apaga ON public.papeis_alvo",
    drop_constraint: "ALTER TABLE public.papeis_alvo DROP CONSTRAINT papeis_alvo_x_check",
    truncate: "TRUNCATE public.papeis_alvo",
    drop_function: "DROP FUNCTION public.papeis_alvo_recusa() CASCADE",
    drop_table: "DROP TABLE public.papeis_alvo",
    create_table: "CREATE TABLE public.papeis_nova (x int)",
    replica: "SET session_replication_role = replica",
    migracao_falsa:
      "INSERT INTO public.schema_migrations (version, inserted_at) VALUES (99999999999998, now())"
  ]

  defp guardas_intactas! do
    %{rows: [[habilitado]]} =
      Repo.query!("SELECT tgenabled FROM pg_trigger WHERE tgname = 'papeis_alvo_nao_apaga'")

    assert habilitado == "O"

    %{rows: [[n]]} =
      Repo.query!("SELECT count(*) FROM pg_constraint WHERE conname = 'papeis_alvo_x_check'")

    assert n == 1
    %{rows: [[linhas]]} = Repo.query!("SELECT count(*) FROM public.papeis_alvo")
    assert linhas == 1
    %{rows: [[papel_de_replica]]} = Repo.query!("SHOW session_replication_role")
    assert papel_de_replica == "origin"
  end

  describe "conceder/2 (T002)" do
    test "a lista fechada de FR-002, e nada além", %{papel: papel} do
      privilegio = fn tabela, p ->
        %{rows: [[r]]} =
          Repo.query!("SELECT has_table_privilege($1, $2, $3)", [papel, tabela, p])

        r
      end

      for p <- ~w(SELECT INSERT UPDATE DELETE), do: assert(privilegio.("public.tenants", p), p)
      for p <- ~w(TRUNCATE REFERENCES TRIGGER), do: refute(privilegio.("public.tenants", p), p)

      assert privilegio.("public.schema_migrations", "SELECT")

      for p <- ~w(INSERT UPDATE DELETE),
          do: refute(privilegio.("public.schema_migrations", p), p)
    end

    test "é idempotente, e retira o privilégio a mais", %{papel: papel} do
      Repo.query!("GRANT TRUNCATE ON public.tenants TO #{papel}")
      :ok = Papeis.conceder(Repo, papel)
      :ok = Papeis.conceder(Repo, papel)

      %{rows: [[t]]} =
        Repo.query!("SELECT has_table_privilege($1, 'public.tenants', 'TRUNCATE')", [papel])

      refute t
    end

    test "recusa o papel que não existe, e o papel igual ao que migra" do
      assert_raise ArgumentError, ~r/não existe/, fn -> Papeis.conceder(Repo, "ninguem_x") end

      %{rows: [[eu]]} = Repo.query!("SELECT current_user")
      assert_raise ArgumentError, ~r/mesma_credencial/, fn -> Papeis.conceder(Repo, eu) end
    end
  end

  describe "as tentativas (T003, A1, A3, A4)" do
    test "quem serve tem cada tentativa recusada com 42501, e as guardas seguem de pé", %{
      papel: papel
    } do
      como(papel, fn ->
        for {nome, sql} <- @ataques,
            do: assert(tentativa(sql) == :insufficient_privilege, inspect(nome))

        # As escritas normais passam (US1-4).
        {:error, :ok} =
          Repo.transaction(fn ->
            Repo.query!("UPDATE public.papeis_alvo SET x = 2")
            Repo.rollback(:ok)
          end)
      end)

      guardas_intactas!()
    end

    # A10: o controle positivo, por tentativa. Com o papel do sandbox, que tem o privilégio de
    # cada uma, todas passam. Sem isso, um 42501 por nome errado seria lido como recusa.
    test "controle positivo: com o privilégio, cada tentativa passa" do
      for {nome, sql} <- @ataques, do: assert(tentativa(sql) == :passou, inspect(nome))
      guardas_intactas!()
    end
  end

  describe "conferir/2 (T004)" do
    test "com o papel concedido, em vigor", %{papel: papel} do
      assert como(papel, fn -> Papeis.conferir(Repo) end) == {:em_vigor, []}
      guardas_intactas!()
    end

    test "com o papel do sandbox, superusuário e dono, não em vigor" do
      {veredito, motivos} = Papeis.conferir(Repo)
      assert veredito == :nao_em_vigor
      assert :superusuario in motivos
      assert :tentativa_passou in motivos
    end

    test "A2: membro do dono não está em vigor", %{papel: papel} do
      %{rows: [[dono]]} =
        Repo.query!("SELECT tableowner FROM pg_tables WHERE tablename = 'tenants'")

      Repo.query!(~s(GRANT "#{dono}" TO #{papel}))

      {veredito, motivos} = como(papel, fn -> Papeis.conferir(Repo) end)
      assert veredito == :nao_em_vigor
      assert :membro_do_dono in motivos
    end

    test "A3: dono do esquema não está em vigor", %{papel: papel} do
      Repo.query!("ALTER SCHEMA public OWNER TO #{papel}")
      {veredito, motivos} = como(papel, fn -> Papeis.conferir(Repo) end)
      assert veredito == :nao_em_vigor
      assert :dono_de_objeto in motivos
    end

    test "A5: SET em session_replication_role não está em vigor", %{papel: papel} do
      Repo.query!("GRANT SET ON PARAMETER session_replication_role TO #{papel}")
      {_, motivos} = como(papel, fn -> Papeis.conferir(Repo) end)
      assert :replica_permitida in motivos
    end

    test "A8: o papel que migra igual ao que serve", %{papel: papel} do
      {_, motivos} = como(papel, fn -> Papeis.conferir(Repo, papel_que_migra: papel) end)
      assert :mesma_credencial in motivos
    end
  end

  test "pendentes/1 lê schema_migrations sem a Ecto.Migrator, e acha a versão que falta" do
    {:ok, []} = Papeis.pendentes(Repo)
    # A última versão que TEM arquivo neste checkout: a base de teste é compartilhada entre
    # worktrees, e pode ter versões de outros branches.
    ultima =
      Application.app_dir(:the_band, "priv/repo/migrations/*.exs")
      |> Path.wildcard()
      |> Enum.map(&(&1 |> Path.basename() |> Integer.parse() |> elem(0)))
      |> Enum.max()

    Repo.query!("DELETE FROM schema_migrations WHERE version = $1", [ultima])
    assert Papeis.pendentes(Repo) == {:ok, [ultima]}
  end
end
