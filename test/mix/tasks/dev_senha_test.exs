defmodule Mix.Tasks.Dev.SenhaTest do
  @moduledoc """
  `mix dev.senha` — issue #1410, parecer em `docs/seguranca/2026-10-05-1410-senha-local.md`.

  A tarefa define senha sem pedir a atual: fora do banco de desenvolvimento local, é tomada de
  conta. Por isso as duas recusas (ambiente e banco) e a senha fora do log e da saída são as
  guardas, cada uma vista reprovando com o defeito injetado.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Mix.Tasks.Dev.Senha, as: Tarefa
  alias TheBand.Tenants.Auth

  # Fictícia e óbvia: nunca foi senha de ninguém.
  @senha "senha-ficticia-de-teste-1410"

  @banco_local [hostname: "localhost", database: "the_band_dev"]

  defp leitor(senha) do
    pai = self()

    fn _prompt ->
      send(pai, :leitor_chamado)
      {:ok, senha}
    end
  end

  describe "a recusa fora de MIX_ENV=dev (R1)" do
    test "aceita só :dev, com o banco local" do
      assert :ok = Tarefa.conferir(:dev, @banco_local)

      for env <- [:test, :prod, :staging] do
        assert {:error, motivo} = Tarefa.conferir(env, @banco_local)
        assert motivo =~ "MIX_ENV"
      end
    end

    test "rodada sob :test, recusa antes de pedir a senha (R3)" do
      assert_raise Mix.Error, ~r/MIX_ENV/, fn ->
        capture_io(fn -> Tarefa.run(["pessoa@example.test"]) end)
      end
    end
  end

  describe "a recusa quando o banco não é local (R2)" do
    test "aceita os quatro hosts locais, por igualdade exata" do
      for host <- ["localhost", "127.0.0.1", "::1", "the_band_postgres"] do
        assert :ok = Tarefa.conferir(:dev, hostname: host, database: "the_band_dev")
      end
    end

    test "recusa host remoto, mesmo parecido com local" do
      for host <- ["db.exemplo.com", "localhost.atacante.example", "127.0.0.1.nip.io", "10.0.0.5"] do
        assert {:error, motivo} = Tarefa.conferir(:dev, hostname: host, database: "the_band_dev")
        assert motivo =~ "local"
      end
    end

    test "recusa url, socket, endpoints, host ausente e banco que não é o de dev" do
      recusadas = [
        [
          url: "ecto://u:p@localhost/the_band_dev",
          hostname: "localhost",
          database: "the_band_dev"
        ],
        [socket: "/tmp/.s.PGSQL.5432", hostname: "localhost", database: "the_band_dev"],
        [socket_dir: "/tmp", hostname: "localhost", database: "the_band_dev"],
        [endpoints: [{"localhost", 5432}], hostname: "localhost", database: "the_band_dev"],
        [database: "the_band_dev"],
        [hostname: "localhost", database: "band_prod"]
      ]

      for config <- recusadas do
        assert {:error, _} = Tarefa.conferir(:dev, config), inspect(Keyword.keys(config))
      end
    end
  end

  describe "a senha fora do log e da saída (R4)" do
    setup do
      # O teste roda em :warning; sem baixar o nível, o log estaria vazio e o teste passaria
      # sem provar nada.
      nivel = Logger.level()
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: nivel) end)

      %{user: user_fixture(tenant_fixture())}
    end

    test "define a senha, avisa das sessões e não escreve a senha em lugar nenhum", %{user: user} do
      {saida, log} =
        with_log(fn ->
          capture_io(fn ->
            assert :ok = Tarefa.definir(String.upcase(user.email), leitor(@senha))
          end)
        end)

      assert_received :leitor_chamado
      assert log != "", "a captura do log está vazia: o teste não prova nada"
      refute log =~ @senha
      refute saida =~ @senha
      assert saida =~ "sessões"

      assert {:ok, _} = Auth.authenticate(user.email, @senha)
    end

    test "na senha recusada pela validação, nem a saída nem o log a mostram", %{user: user} do
      curta = "curta-1410"

      {saida, log} =
        with_log(fn ->
          capture_io(fn ->
            send(self(), {:resultado, Tarefa.definir(user.email, leitor(curta))})
          end)
        end)

      # O motivo é o que `run/1` imprime, por `Mix.raise/1`.
      assert_received {:resultado, {:error, motivo}}
      assert motivo =~ "12"
      refute motivo =~ curta
      refute log =~ curta
      refute saida =~ curta
    end

    test "as duas senhas divergindo, recusa sem gravar (R8)", %{user: user} do
      {:ok, respostas} = Agent.start_link(fn -> [@senha, @senha <> "-outra"] end)
      leitor = fn _ -> {:ok, Agent.get_and_update(respostas, fn [h | t] -> {h, t} end)} end

      capture_io(fn ->
        assert {:error, motivo} = Tarefa.definir(user.email, leitor)
        assert motivo =~ "não coincidem"
      end)

      assert {:error, :invalid_credentials} = Auth.authenticate(user.email, @senha)
    end

    test "conta inexistente não pede a senha" do
      capture_io(fn ->
        assert {:error, motivo} = Tarefa.definir("ninguem@example.test", leitor(@senha))
        assert motivo =~ "não encontrada"
      end)

      refute_received :leitor_chamado
    end
  end

  describe "a senha nunca vem por argumento (R5)" do
    test "recusa mais de um argumento, antes de qualquer outra coisa" do
      assert_raise Mix.Error, ~r/argumento/, fn ->
        Tarefa.run(["pessoa@example.test", @senha])
      end
    end
  end
end
