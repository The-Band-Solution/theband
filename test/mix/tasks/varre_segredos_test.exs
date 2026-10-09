defmodule Mix.Tasks.TheBand.VarreSegredosTest do
  @moduledoc """
  `mix the_band.varre_segredos` — feature 064, T002 a T004.

  O teste que distingue esta tarefa de um `grep` é o do controle positivo: com o exemplo de um
  padrão adulterado para não casar, a saída é `2`, e não `0`. "Zero ocorrências" sem controle
  significaria tanto *limpo* quanto *não olhei*.
  """
  use TheBand.DataCase, async: false

  alias Mix.Tasks.TheBand.VarreSegredos, as: Tarefa
  alias TheBand.Repo
  alias TheBand.Segredo.Padroes
  alias TheBand.Tenants
  alias TheBandWeb.ConnCase

  # Um token com a forma de um do GitHub, montado para não existir como literal no repositório.
  @token "gh" <> "p_" <> String.duplicate("V", 32) <> "azul"

  setup do
    dir = Path.join(System.tmp_dir!(), "varre-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp dump(ctx, nome, linhas) do
    caminho = Path.join(ctx.dir, nome)
    File.write!(caminho, Enum.join(linhas, "\n") <> "\n")
    caminho
  end

  defp limpo(ctx) do
    dump(ctx, "limpo.sql", [
      "-- PostgreSQL database dump",
      "COPY public.collected_issues (id, title) FROM stdin;",
      "1\tuma issue qualquer",
      "\\.",
      "COPY public.collected_verifications (id, phase) FROM stdin;",
      # 43 caracteres base64url FORA da coluna do token de sessão: era a forma dos 5 926 falsos
      # positivos do dump de desenvolvimento.
      "1\t" <> String.duplicate("f", 43),
      "\\."
    ])
  end

  describe "o uso" do
    test "sem argumento, recusa com 3 e explica", _ctx do
      assert {3, texto} = Tarefa.executar([])
      assert texto =~ "--dump CAMINHO ou --banco"
    end

    test "com --dump e --banco juntos, recusa com 3", ctx do
      assert {3, _} = Tarefa.executar(["--dump", limpo(ctx), "--banco"])
    end

    test "com --dump de arquivo inexistente, recusa com 3", ctx do
      assert {3, texto} = Tarefa.executar(["--dump", Path.join(ctx.dir, "nao-existe.sql")])
      assert texto =~ "não existe"
    end
  end

  describe "o dump" do
    test "limpo sai com 0, e o relatório traz a linha do controle positivo", ctx do
      assert {0, texto} = Tarefa.executar(["--dump", limpo(ctx)])

      assert texto =~ "controle positivo ......... ACHOU"
      assert texto =~ "RESULTADO: limpo"
      # Diz o que procurou, e não só o que achou.
      for p <- Padroes.todos(), do: assert(texto =~ p.nome)
    end

    test "com um token plantado sai com 1, e diz onde sem dizer o quê", ctx do
      caminho =
        dump(ctx, "sujo.sql", [
          "COPY public.oban_jobs (id, errors) FROM stdin;",
          "7\t{\"erro\": \"graphql(\\\"https://github.com\\\", \\\"#{@token}\\\")\"}",
          "\\."
        ])

      assert {1, texto} = Tarefa.executar(["--dump", caminho, "--saida", ctx.dir])

      assert texto =~ "public.oban_jobs.errors · linha 2"
      assert texto =~ "40 caracteres"
      refute texto =~ @token, "o relatório virou mais uma cópia do segredo"

      [arquivo] = Path.wildcard(Path.join(ctx.dir, "varredura-*.txt"))
      refute File.read!(arquivo) =~ @token, "o arquivo de --saida virou mais uma cópia do segredo"
    end

    test "o token de sessão só é achado na coluna dele", ctx do
      sessao = String.duplicate("k", 43)

      caminho =
        dump(ctx, "sessao.sql", [
          "COPY public.users (id, session_token) FROM stdin;",
          "1\t#{sessao}",
          "\\."
        ])

      assert {1, texto} = Tarefa.executar(["--dump", caminho])
      assert texto =~ "public.users.session_token · linha 2"
      refute texto =~ sessao

      # O mesmo valor em outra coluna não é achado: é o limpo acima, que sai 0.
      assert {0, _} = Tarefa.executar(["--dump", limpo(ctx)])
    end

    test "o material original não é tocado", ctx do
      caminho = limpo(ctx)
      antes = File.read!(caminho)

      Tarefa.executar(["--dump", caminho])

      assert File.read!(caminho) == antes
      assert Path.wildcard(Path.join(System.tmp_dir!(), "varredura-*.sql")) == []
    end
  end

  describe "o controle positivo" do
    test "com o exemplo de um padrão adulterado, sai com 2, e NÃO com 0", ctx do
      # É o teste que distingue esta tarefa de um `grep`: a varredura que não enxerga um padrão
      # não pode relatar "limpo" para ele.
      adulterados =
        Enum.map(Padroes.todos(), fn
          %{tipo: :token_github} = p -> %{p | exemplo_valido: "nao-casa"}
          p -> p
        end)

      assert {2, texto} = Tarefa.executar(["--dump", limpo(ctx)], adulterados)
      assert texto =~ "FALHOU para token_github"
      assert texto =~ "RESULTADO: inválido"
      refute texto =~ "RESULTADO: limpo"
    end
  end

  describe "o banco" do
    test "planta em tabelas temporárias, acha o token de sessão, e desfaz tudo", _ctx do
      {tenant, _admin} = ConnCase.tenant_with_admin()

      {:ok, u} =
        Tenants.create_user(tenant, %{
          "email" => "varredura-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      # A coluna antiga continua existindo até a T014b, e a plataforma não a escreve mais desde a
      # T014a. O valor é gravado por SQL, na forma que a coluna guardava, para a varredura ter o
      # que achar num banco com dado de antes da v0.11.0.
      sessao = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      Repo.query!("UPDATE users SET session_token = $1 WHERE id = $2", [
        sessao,
        Ecto.UUID.dump!(u.id)
      ])

      assert {1, texto} = Tarefa.executar(["--banco"])

      assert texto =~ "controle positivo ......... ACHOU"
      assert texto =~ "public.users.session_token"
      refute texto =~ sessao

      # As tabelas do controle eram temporárias e somem com a transação desfeita.
      %{rows: temporarias} =
        Repo.query!(
          "SELECT count(*) FROM pg_tables WHERE schemaname = pg_my_temp_schema()::regnamespace::text"
        )

      assert temporarias == [[0]]
    end
  end
end
