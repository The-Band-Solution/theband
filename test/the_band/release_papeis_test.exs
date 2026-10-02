defmodule TheBand.ReleasePapeisTest do
  @moduledoc """
  O deploy com e sem a credencial que migra, a frase da conferência e o aviso a cada subida —
  spec 071, T006, T007, T009 e T010 (FR-004, FR-008, FR-009, FR-012; A6, A7).
  """
  use TheBand.DataCase, async: false

  # Cria papel no setup: excluído quando a suíte roda como o papel que serve (T005).
  @moduletag :precisa_criar_papel

  import ExUnit.CaptureLog

  alias TheBand.Papeis
  alias TheBand.Release

  setup do
    papel = "serve_t_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE ROLE #{papel} NOLOGIN")
    :ok = Papeis.conceder(Repo, papel)
    %{papel: papel}
  end

  defp como(papel, fun) do
    Repo.query!("SET LOCAL ROLE #{papel}")

    try do
      fun.()
    after
      Repo.query!("RESET ROLE")
    end
  end

  defp ultima_com_arquivo do
    Application.app_dir(:the_band, "priv/repo/migrations/*.exs")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> Path.basename() |> Integer.parse() |> elem(0)))
    |> Enum.max()
  end

  describe "os três estados sem a credencial que migra (T007)" do
    test "quem serve é dono, o estado de hoje: migra como hoje" do
      assert Papeis.estado_sem_credencial(Repo) == :migra_como_hoje
    end

    test "quem serve não é dono, e não há pendente: sobe sem migrar", %{papel: papel} do
      assert como(papel, fn -> Papeis.estado_sem_credencial(Repo) end) == :sobe_sem_migrar
    end

    test "quem serve não é dono, e há pendente: não sobe", %{papel: papel} do
      v = ultima_com_arquivo()
      Repo.query!("DELETE FROM schema_migrations WHERE version = $1", [v])
      assert como(papel, fn -> Papeis.estado_sem_credencial(Repo) end) == {:nao_sobe, [v]}
    end
  end

  describe "a frase da conferência (T010)" do
    test "um veredito por frase, e nenhuma credencial" do
      assert Papeis.frase({:em_vigor, []}) == "papéis: separação em vigor"
      assert Papeis.frase({:em_vigor, [:dono_superusuario]}) =~ "aviso: dono_superusuario"
      assert Papeis.frase({:nao_em_vigor, [:superusuario]}) =~ "NÃO em vigor (superusuario)"
      assert Papeis.frase({:inconclusivo, [:tentativa_inconclusiva]}) =~ "inconclusiva"
    end

    test "conferir_papeis/0 com o papel concedido diz em vigor", %{papel: papel} do
      assert como(papel, fn -> Release.conferir_papeis() end) == "papéis: separação em vigor"
    end
  end

  # A7 (S6): a senha não sai na mensagem de uma URL malformada.
  test "a URL malformada vira uma frase que nomeia a variável, sem a senha" do
    erro =
      assert_raise RuntimeError, fn ->
        Release.com_url_redigida(fn ->
          Ecto.Repo.Supervisor.parse_url("ecto://serve:SENHA/DE-TESTE@host/base")
        end)
      end

    assert erro.message =~ "DATABASE_URL"
    refute erro.message =~ "SENHA"
  end

  # A6 e FR-004: nenhum código de `lib/` nem o `runtime.exs` LÊ a variável que migra. Se lesse, todo
  # `eval` de comando de release, que tem o ambiente do contêiner, conectaria como dono.
  test "nenhum código lê DATABASE_MIGRATION_URL do ambiente" do
    leitura = ~r/(get_env|fetch_env!?)\(\s*"DATABASE_MIGRATION_URL"/

    arquivos = ["config/runtime.exs" | Path.wildcard("lib/**/*.ex")]
    assert length(arquivos) > 50, "a medição não mediu: não achou os arquivos"

    for arquivo <- arquivos,
        do: refute(File.read!(arquivo) =~ leitura, arquivo)
  end

  test "o aviso a cada subida: warning quando não está em vigor, info quando está (T009)" do
    assert capture_log([level: :info], fn ->
             TheBand.Application.avisar_papeis({:nao_em_vigor, [:superusuario]})
           end) =~
             "[warning] papéis: separação NÃO em vigor"

    refute capture_log([level: :info], fn ->
             TheBand.Application.avisar_papeis({:em_vigor, []})
           end) =~
             "[warning]"
  end
end
