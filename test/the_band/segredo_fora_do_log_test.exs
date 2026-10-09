defmodule TheBand.SegredoForaDoLogTest do
  @moduledoc """
  Segredo cifrado não chega ao log da consulta — issue #1222.

  Em `:debug`, o Ecto loga os parâmetros **como o changeset os leu** (`cast_params`), antes de
  `TheBand.Encrypted.Binary` cifrar. Um caso por caminho de escrita de campo cifrado.

  Cada caso afirma primeiro que a medida **mediu**: que alguma consulta da tabela cifrada chegou
  ao log. Sem isso, um log vazio — nível errado, logger desligado — passaria o `refute` sem
  provar nada.

  `async: false` porque o nível do Logger é global.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import Mox

  alias TheBand.AI
  alias TheBand.Platform.{Credentials, Grant, Operator}
  alias TheBand.Repo.LogDaConsulta
  alias TheBand.Rotacao
  alias TheBand.Segredo
  alias TheBand.Sources
  alias TheBand.Sources.{ConnectedTool, ToolCredential}

  setup :verify_on_exit!

  setup do
    nivel = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: nivel) end)
    :ok
  end

  # Valores obviamente falsos: nenhum segredo real entra em teste.
  @segredo_ferramenta "fake-secret-1222-ferramenta"
  @segredo_outra "fake-secret-1222-outra-credencial"
  @segredo_retomada "fake-secret-1222-retomada"
  @segredo_ia "fake-secret-1222-provedor-de-ia-longo"

  defp github_aceita(vezes \\ 1) do
    expect(TheBand.GitHubHTTPMock, :get, vezes, fn _url, _token ->
      {:ok,
       %{
         status: 200,
         body: %{"login" => "conta-1222"},
         headers: %{"x-oauth-scopes" => ["read:org, repo"]}
       }}
    end)
  end

  defp conectar(tenant, segredo) do
    {:ok, %{tool: tool}} =
      Sources.connect_tool(tenant, %{
        "tool_type" => "github",
        "instance_url" => "https://github.com",
        "organization_login" => "org-1222",
        "secret" => segredo
      })

    tool
  end

  # A medida mediu: houve consulta à tabela do campo cifrado no log capturado.
  defp mediu!(log, tabela) do
    assert log =~ "QUERY", "nenhuma consulta chegou ao log: a medida não mediu"
    assert log =~ ~s(source="#{tabela}"), "nenhuma consulta de #{tabela} no log"
  end

  describe "tool_credentials.secret" do
    test "conectar a ferramenta não loga o segredo" do
      tenant = tenant_fixture()
      github_aceita()

      log = capture_log(fn -> conectar(tenant, @segredo_ferramenta) end)

      mediu!(log, "tool_credentials")
      refute log =~ @segredo_ferramenta
    end

    test "acrescentar credencial não loga o segredo" do
      tenant = tenant_fixture()
      github_aceita(2)
      tool = capture_quieto(fn -> conectar(tenant, @segredo_ferramenta) end)

      log =
        capture_log(fn ->
          assert {:ok, _} = Sources.add_credential(tenant, tool, %{"secret" => @segredo_outra})
        end)

      mediu!(log, "tool_credentials")
      refute log =~ @segredo_outra
    end

    test "retomar a observação não loga o segredo novo" do
      tenant = tenant_fixture()
      github_aceita(2)

      tool =
        capture_quieto(fn ->
          tool = conectar(tenant, @segredo_ferramenta)
          {:ok, _} = Sources.end_observation(tenant, tool, %{"confirmation" => "org-1222"})
          tool
        end)

      log =
        capture_log(fn ->
          assert {:ok, _} =
                   Sources.resume_observation(tenant, tool, %{"secret" => @segredo_retomada})
        end)

      mediu!(log, "tool_credentials")
      refute log =~ @segredo_retomada
    end
  end

  describe "ai_provider_credentials.secret" do
    test "gravar e regravar a credencial do provedor não loga o segredo" do
      tenant = tenant_fixture()

      expect(TheBand.LLMHTTPMock, :verify, 2, fn _s, _o -> {:ok, ["gpt-5.4-mini"]} end)

      log =
        capture_log(fn ->
          # A primeira grava (insert); a segunda regrava a existente (update).
          assert {:ok, _} = AI.put(tenant, %{"secret" => @segredo_ia})
          assert {:ok, _} = AI.put(tenant, %{"secret" => @segredo_ia <> "-2"})
        end)

      mediu!(log, "ai_provider_credentials")
      refute log =~ @segredo_ia
    end
  end

  describe "platform_operators.totp_secret" do
    test "definir a senha, que gera o segredo TOTP, não loga o segredo" do
      op =
        Repo.insert!(%Operator{
          email: "op-1222-#{System.unique_integer([:positive])}@example.org",
          name: "Op"
        })

      Repo.insert!(%Grant{
        operator_id: op.id,
        granted_at: DateTime.utc_now(:second),
        granted_via: "release_command",
        granted_by_declared: "teste 1222",
        email_at_grant: op.email
      })

      {:ok, codigo} = capture_quieto(fn -> Credentials.emitir_codigo(op) end)

      log =
        capture_log(fn ->
          send(
            self(),
            {:r,
             Credentials.definir_senha(
               op.email,
               codigo,
               Segredo.novo("fake-senha-1222-do-operador"),
               TheBand.OrigemDeTeste.nova()
             )}
          )
        end)

      assert_received {:r, {:ok, {_, %{segredo: segredo}}}}
      bruto = Segredo.expor(segredo)

      mediu!(log, "platform_operators")

      # O Ecto loga o binário com `inspect/1`; o segredo cru é bytes, e a forma impressa é a que
      # apareceria. A Base32 é a forma que o aplicativo autenticador recebe.
      refute log =~ inspect(bruto)
      refute log =~ bruto
      refute log =~ Base.encode32(bruto, padding: false)
    end
  end

  describe "caminhos fora do changeset" do
    test "update_all que grava o segredo não o loga" do
      tenant = tenant_fixture()
      github_aceita()
      tool = capture_quieto(fn -> conectar(tenant, @segredo_ferramenta) end)
      novo = "fake-secret-1222-update-all"

      log =
        capture_log(fn ->
          {1, _} =
            Repo.update_all(
              from(c in ToolCredential, where: c.connected_tool_id == ^tool.id),
              set: [secret: novo]
            )
        end)

      mediu!(log, "tool_credentials")
      refute log =~ novo
    end

    test "SQL cru que menciona a tabela, sem fonte, tem os parâmetros redigidos" do
      valor = "fake-secret-1222-sql-cru"

      log =
        capture_log(fn ->
          Repo.query!("SELECT $1::text FROM TOOL_CREDENTIALS LIMIT 1", [valor])
        end)

      assert log =~ "QUERY", "nenhuma consulta chegou ao log: a medida não mediu"
      assert log =~ "TOOL_CREDENTIALS"
      refute log =~ valor
      assert log =~ "parâmetros redigidos"
    end

    test "leitura com parâmetro da tabela cifrada sai redigida, e a de outra tabela não" do
      tenant = tenant_fixture()
      github_aceita()
      tool = capture_quieto(fn -> conectar(tenant, @segredo_ferramenta) end)

      log =
        capture_log(fn ->
          Repo.all(from c in ToolCredential, where: c.connected_tool_id == ^tool.id)

          Repo.all(from t in ConnectedTool, where: t.id == ^tool.id)
        end)

      mediu!(log, "tool_credentials")
      assert log =~ "parâmetros redigidos"
      # A redação é por tabela cifrada, e não do log inteiro: a outra consulta segue legível.
      assert log =~ ~s(source="connected_tools")
      assert log =~ tool.id
    end
  end

  describe "a guarda cobre o que vier depois" do
    test "todo schema com campo cifrado está na lista que a redação usa" do
      {:ok, modulos} = :application.get_key(:the_band, :modules)

      cifrados =
        for m <- modulos,
            Code.ensure_loaded?(m),
            function_exported?(m, :__schema__, 1),
            campo <- m.__schema__(:fields),
            m.__schema__(:type, campo) == TheBand.Encrypted.Binary,
            do: {m, m.__schema__(:source), Atom.to_string(campo)}

      # A medida mediu: os três de hoje foram encontrados.
      assert length(cifrados) >= 3

      for {m, source, campo} <- cifrados do
        assert {source, campo} in Rotacao.campos_cifrados(),
               "#{inspect(m)}.#{campo} é cifrado e está fora de Rotacao.campos_cifrados/0"

        assert source in LogDaConsulta.tabelas_cifradas()
      end
    end

    # O Ecto ainda loga quando a CHAMADA pede um nível, mesmo com `log: false` no Repo — e loga
    # os parâmetros em claro, por fora do handler. Lê o código pela AST: o par `log: nível` numa
    # chamada, e não a palavra num comentário ou numa documentação.
    test "nenhuma chamada em lib/ pede log com nível, que contornaria a redação" do
      achados =
        for arquivo <- Path.wildcard("lib/**/*.ex"),
            par <- pares_de_log(File.read!(arquivo)),
            do: "#{arquivo}: #{Macro.to_string(par)}"

      assert achados == []
    end

    test "o Oban não pede log das próprias consultas" do
      assert Keyword.get(Application.fetch_env!(:the_band, Oban), :log, false) == false
    end

    test "o handler está anexado ao evento de consulta do Repo" do
      ids =
        [:the_band, :repo, :query]
        |> :telemetry.list_handlers()
        |> Enum.map(& &1.id)

      assert LogDaConsulta.id() in ids
    end

    test "uma falha ao formatar não desanexa o handler, nem loga a consulta" do
      log =
        capture_log(fn ->
          :telemetry.execute([:the_band, :repo, :query], %{}, %{
            query: :nao_e_sql,
            source: nil,
            params: ["fake-secret-1222-falha"]
          })
        end)

      assert log =~ "log da consulta falhou"
      refute log =~ "fake-secret-1222-falha"

      ids = [:the_band, :repo, :query] |> :telemetry.list_handlers() |> Enum.map(& &1.id)
      assert LogDaConsulta.id() in ids
    end
  end

  @niveis [:debug, :info, :notice, :warning, :error, :critical, :alert, :emergency, true]

  defp pares_de_log(fonte) do
    {:ok, ast} = Code.string_to_quoted(fonte)

    {_, pares} =
      Macro.prewalk(ast, [], fn
        # Um mapa não é opção de chamada: `%{log: true}` casa o `oban_conf`, não pede log. Os
        # valores do mapa continuam sendo percorridos; só as chaves saem.
        {:%{}, meta, pares}, acc ->
          {{:%{}, meta, Enum.map(pares, &valor_do_par/1)}, acc}

        {:log, nivel} = par, acc when nivel in @niveis ->
          {par, [par | acc]}

        no, acc ->
          {no, acc}
      end)

    pares
  end

  defp valor_do_par({_chave, valor}), do: valor
  defp valor_do_par(outro), do: outro

  defp capture_quieto(fun) do
    capture_log(fn -> send(self(), {:quieto, fun.()}) end)
    assert_received {:quieto, r}
    r
  end
end
