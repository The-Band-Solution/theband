defmodule TheBand.AITest do
  @moduledoc """
  A credencial do provedor de modelo de linguagem — o domínio por trás de `/ai`.

  ## O que este arquivo protege

  **Nada é gravado sem ter sido conferido.** Gravar antes de conferir produz o pior estado
  possível: a tela diz "configurado", e a primeira geração falha meia hora depois, num job
  de fundo, para outra pessoa.

  **Nenhuma substituição silenciosa.** Um modelo que a conta não alcança é recusado, e não
  trocado pelo padrão — trocar em silêncio faz a tela afirmar que gravou o que a pessoa
  pediu quando gravou outra coisa.

  E o Mox substitui **só** a borda HTTP: nada abaixo dela é mockado.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import Mox
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0, tenant_with_admin: 1]

  alias TheBand.AI
  alias TheBand.Repo
  alias TheBand.Segredo

  setup :verify_on_exit!

  @chave "sk-uma-chave-de-teste-com-mais-de-vinte-caracteres-9876"

  setup do
    # A chave do ambiente é do processo, e o processo é compartilhado pela suíte: sem
    # tirá-la, o estado `:nenhuma` dependeria de quem rodou o teste ter ou não `.env`
    # carregado — que é exatamente a diferença que este módulo existe para nomear.
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")

    on_exit(fn ->
      # Restauração SIMÉTRICA: sem isto, um put_env dentro de teste vaza para a
      # suíte inteira quando `anterior` é nil — foi o flake que derrubou o CI do
      # #596 e deixou o do #594 verde por sorte de seed (2026-08-29).
      if anterior, do: System.put_env("API_KEY", anterior), else: System.delete_env("API_KEY")
    end)

    {tenant, user} = tenant_with_admin()
    %{tenant: tenant, user: user}
  end

  defp aceita(modelos \\ ["gpt-5.4", "gpt-5.4-mini"]) do
    expect(TheBand.LLMHTTPMock, :verify, fn _secret, _opts -> {:ok, modelos} end)
  end

  defp segredo_bruto do
    %{rows: [[bruto]]} = Repo.query!("select secret from ai_provider_credentials limit 1")
    bruto
  end

  describe "gravar (put/3)" do
    test "a chave é conferida contra o provedor antes de qualquer escrita", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn secret, opts ->
        # Fechada desde a 064/T006: a borda recebe `Segredo`, e só o cabeçalho a abre.
        assert Segredo.expor(secret) == @chave
        assert opts[:base_url] == "https://api.openai.com"
        {:ok, ["gpt-5.4-mini"]}
      end)

      assert {:ok, cred} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)
      assert cred.validated_at
      assert cred.declared_by_user_id == ctx.user.id
      assert cred.provider == "openai"
    end

    test "os quatro últimos são derivados do segredo, e não recebidos", ctx do
      aceita()

      {:ok, cred} = AI.put(ctx.tenant, %{"secret" => @chave, "last_four" => "0000"}, ctx.user.id)

      assert cred.last_four == "9876"
    end

    test "a tabela guarda o segredo cifrado, e ler a coluna não devolve a chave", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert :binary.match(segredo_bruto(), @chave) == :nomatch
      assert {:ok, %{secret: @chave}} = AI.fetch(ctx.tenant)
    end

    test "chave recusada pelo provedor não grava nada", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:rejeitada, "HTTP 401"}} end)

      assert {:error, {:rejeitada, "HTTP 401"}} =
               AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "provedor inalcançável não grava, e a recusa não é a mesma de chave recusada", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:indisponivel, "timeout"}} end)

      assert {:error, {:indisponivel, "timeout"}} =
               AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "chave aceita que não alcança modelo algum não grava", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:sem_modelos, "nenhum"}} end)

      assert {:error, {:sem_modelos, "nenhum"}} =
               AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "modelo que o provedor não lista é recusado, e não trocado pelo padrão", ctx do
      aceita(["gpt-5.4-mini"])

      assert {:error, {:modelo_desconhecido, "gpt-4o", ["gpt-5.4-mini"]}} =
               AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => "gpt-4o"}, ctx.user.id)

      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "modelo em branco é escolha, e vale o padrão do provedor", ctx do
      aceita()

      assert {:ok, cred} =
               AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => ""}, ctx.user.id)

      assert is_nil(cred.default_model)
    end

    test "modelo listado pelo provedor é gravado", ctx do
      aceita()

      assert {:ok, cred} =
               AI.put(
                 ctx.tenant,
                 %{"secret" => @chave, "default_model" => "gpt-5.4"},
                 ctx.user.id
               )

      assert cred.default_model == "gpt-5.4"
    end

    # O provedor chega a ser consultado aqui, e é aceitável: a regra de tamanho mínimo mora
    # no changeset, e duplicá-la antes da chamada colocaria o mesmo número em dois lugares.
    test "chave curta demais é recusada pelo changeset, e nada é gravado", ctx do
      aceita()

      assert {:error, %Ecto.Changeset{} = changeset} =
               AI.put(ctx.tenant, %{"secret" => "sk-1234"}, ctx.user.id)

      assert %{secret: ["curta demais para ser uma chave de API"]} = errors_on(changeset)
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "gravar de novo substitui, e o tenant continua com uma linha só", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      aceita()

      {:ok, segunda} =
        AI.put(ctx.tenant, %{"secret" => "sk-outra-chave-bem-mais-longa-4321"}, ctx.user.id)

      assert segunda.last_four == "4321"
      assert %{rows: [[1]]} = Repo.query!("select count(*) from ai_provider_credentials")
    end
  end

  describe "de onde a chave vem (origem_da_chave/1)" do
    test "sem credencial e sem ambiente, é ausência nomeada", ctx do
      assert AI.origem_da_chave(ctx.tenant) == :nenhuma
    end

    test "com ambiente e sem credencial, é do processo — e a tela precisa saber", ctx do
      System.put_env("API_KEY", "sk-do-ambiente-abcd")

      assert {:ambiente, "abcd"} = AI.origem_da_chave(ctx.tenant)
    end

    test "credencial gravada vence o ambiente", ctx do
      System.put_env("API_KEY", "sk-do-ambiente-abcd")
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert {:tenant, cred} = AI.origem_da_chave(ctx.tenant)
      assert cred.last_four == "9876"
    end
  end

  describe "as opções de chamada (opcoes/1)" do
    test "sem credencial, a lista é vazia — e é ela que faz a borda cair no ambiente", ctx do
      assert AI.opcoes(ctx.tenant) == []
    end

    test "com credencial, leva chave, base e modelo", ctx do
      aceita()

      {:ok, _} =
        AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => "gpt-5.4"}, ctx.user.id)

      opcoes = AI.opcoes(ctx.tenant)

      assert Segredo.expor(opcoes[:key]) == @chave
      assert opcoes[:base_url] == "https://api.openai.com"
      assert opcoes[:model] == "gpt-5.4"
    end

    test "sem modelo escolhido, a opção não vai — quem decide é o provedor", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      refute Keyword.has_key?(AI.opcoes(ctx.tenant), :model)
    end
  end

  describe "apagar (delete/3)" do
    test "o segredo some, e apagar de novo diz que não há o que apagar", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert :ok = AI.delete(ctx.tenant, ctx.user.id)
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
      assert {:error, :not_found} = AI.delete(ctx.tenant, ctx.user.id)
    end
  end

  describe "isolamento entre organizações" do
    test "a chave de uma organização não é lida nem usada pela outra", ctx do
      {outro, _} = tenant_with_admin("outro")

      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave}, ctx.user.id)

      assert {:error, :not_found} = AI.fetch(outro)
      assert AI.origem_da_chave(outro) == :nenhuma
      assert AI.opcoes(outro) == []
    end
  end

  # ------------------------------------------------------------------ #1221
  #
  # O rastro de quem pôs, trocou e removeu a chave do tenant. Contrato em
  # `specs/064-segredo-em-repouso/contracts/idade-da-credencial.md`, "Quem pôs a chave"; parecer em
  # `docs/seguranca/2026-10-05-1221-troca-da-chave-do-modelo.md`.
  #
  # As chaves terminam fora do hexadecimal (`wxyz`, `mnop`): com sufixo hexadecimal, o `refute`
  # dos quatro últimos casaria por acaso com os UUIDs da linha e reprovaria sem defeito
  # (condição 5).
  @k1 "sk-teste-ficticio-chave-um-do-modelo-wxyz"
  @k2 "sk-teste-ficticio-chave-dois-do-modelo-mnop"

  defp linhas_do_evento(log) do
    log
    |> String.split("\n")
    # Exato: `ato=:chave_do_modelo_recusada` (#1388) começa com o mesmo texto, e casar por
    # trecho contaria a recusa como gravação.
    |> Enum.filter(&(&1 =~ ~r/ato=:chave_do_modelo(\s|$)/))
  end

  defp unica_linha!(log) do
    assert [linha] = linhas_do_evento(log)
    linha
  end

  describe "o rastro da chave (#1221)" do
    test "a primeira gravação emite :primeira e o ator passa a ser o declarante", ctx do
      aceita()

      log =
        capture_log(fn ->
          assert {:ok, cred} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)
          send(self(), {:cred, cred})
        end)

      assert_received {:cred, cred}
      linha = unica_linha!(log)
      assert linha =~ "tipo=:primeira"
      assert linha =~ ~s(tenant_id="#{ctx.tenant.id}")
      assert linha =~ ~s(actor_user_id="#{ctx.user.id}")
      assert cred.declared_by_user_id == ctx.user.id
    end

    test "a mesma chave emite :mesma_chave com quem regravou, e não apaga quem a declarou", ctx do
      outro = user_fixture(ctx.tenant)
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

      aceita()

      log =
        capture_log(fn ->
          assert {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, outro.id)
        end)

      linha = unica_linha!(log)
      assert linha =~ "tipo=:mesma_chave"
      assert linha =~ ~s(actor_user_id="#{outro.id}")
      assert {:ok, %{declared_by_user_id: declarante}} = AI.fetch_sem_segredo(ctx.tenant)
      assert declarante == ctx.user.id
    end

    test "a troca emite :troca e quem trocou passa a ser o declarante", ctx do
      outro = user_fixture(ctx.tenant)
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

      aceita()

      log =
        capture_log(fn -> assert {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k2}, outro.id) end)

      linha = unica_linha!(log)
      assert linha =~ "tipo=:troca"
      assert linha =~ ~s(actor_user_id="#{outro.id}")
      assert {:ok, %{declared_by_user_id: declarante}} = AI.fetch_sem_segredo(ctx.tenant)
      assert declarante == outro.id
    end

    test "a mesma classificação decide as datas e o evento", ctx do
      aceita()
      {:ok, primeira} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

      # Recuar as datas, para a troca se distinguir da primeira no mesmo segundo.
      antes = DateTime.add(DateTime.utc_now(:second), -86_400)

      Repo.query!(
        "update ai_provider_credentials set secret_set_at = $1, validated_at = $1 where id = $2",
        [antes, Ecto.UUID.dump!(primeira.id)]
      )

      aceita()

      log =
        capture_log(fn ->
          {:ok, mesma} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)
          send(self(), {:mesma, mesma})
        end)

      assert_received {:mesma, mesma}
      assert unica_linha!(log) =~ "tipo=:mesma_chave"
      assert mesma.secret_set_at == antes

      aceita()

      log =
        capture_log(fn ->
          {:ok, troca} = AI.put(ctx.tenant, %{"secret" => @k2}, ctx.user.id)
          send(self(), {:troca, troca})
        end)

      assert_received {:troca, troca}
      assert unica_linha!(log) =~ "tipo=:troca"
      assert DateTime.compare(troca.secret_set_at, antes) == :gt
      assert troca.previous_secret_set_at == antes
    end

    # #1387 (R-a): o ator é obrigatório. Antes, `put/3` e `delete/3` aceitavam `nil` por padrão,
    # e uma gravação sem autor deixava `declared_by_user_id` nulo. Sem `aceita()` antes da
    # primeira chamada: o `verify_on_exit!` reprova se o provedor for consultado, e uma gravação
    # sem ator não chega a ele.
    test "sem ator, não se grava nem se remove a chave, e o provedor nem é consultado", ctx do
      # Sem carregar o módulo, `function_exported?/3` devolve `false` de todo jeito, e o `refute`
      # passaria com o defeito (visto ao injetar o `\\ nil` de volta).
      Code.ensure_loaded!(AI)
      refute function_exported?(AI, :put, 2)
      refute function_exported?(AI, :delete, 1)

      # `apply/3` porque o verificador de tipos do compilador já recusa a chamada escrita à mão; os
      # argumentos vêm de variável, como no teste das guardas do evento, abaixo.
      sem_ator_put = [ctx.tenant, %{"secret" => @k1}, nil]
      assert_raise FunctionClauseError, fn -> apply(AI, :put, sem_ator_put) end

      assert {:error, :not_found} = AI.fetch(ctx.tenant)

      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

      sem_ator_delete = [ctx.tenant, nil]
      assert_raise FunctionClauseError, fn -> apply(AI, :delete, sem_ator_delete) end
      assert {:ok, %{declared_by_user_id: declarante}} = AI.fetch_sem_segredo(ctx.tenant)
      assert declarante == ctx.user.id
    end

    test "recusa do provedor, modelo desconhecido e erro de changeset não emitem gravação", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:rejeitada, "HTTP 401"}} end)
      aceita(["gpt-5.4-mini"])
      aceita()

      log =
        capture_log(fn ->
          assert {:error, {:rejeitada, _}} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

          assert {:error, {:modelo_desconhecido, _, _}} =
                   AI.put(ctx.tenant, %{"secret" => @k1, "default_model" => "x"}, ctx.user.id)

          # Passa no provedor (o duplo aceita) e reprova no changeset: curta demais.
          assert {:error, %Ecto.Changeset{}} =
                   AI.put(ctx.tenant, %{"secret" => "sk-curta-wxyz"}, ctx.user.id)
        end)

      assert linhas_do_evento(log) == []
    end

    test "remover emite :removida com o ator, e remover o que não existe não emite", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

      log = capture_log(fn -> assert :ok = AI.delete(ctx.tenant, ctx.user.id) end)

      linha = unica_linha!(log)
      assert linha =~ "tipo=:removida"
      assert linha =~ ~s(tenant_id="#{ctx.tenant.id}")
      assert linha =~ ~s(actor_user_id="#{ctx.user.id}")

      log =
        capture_log(fn -> assert {:error, :not_found} = AI.delete(ctx.tenant, ctx.user.id) end)

      assert linhas_do_evento(log) == []

      # A sequência é o que reconstrói: depois da remoção, a gravação é :primeira, e o log
      # já disse quem removeu.
      aceita()
      log = capture_log(fn -> {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k2}, ctx.user.id) end)
      assert unica_linha!(log) =~ "tipo=:primeira"
    end

    test "o evento de um tenant não cita o outro, e a linha do outro não muda", ctx do
      {outro, outro_user} = tenant_with_admin()

      aceita()
      {:ok, _} = AI.put(outro, %{"secret" => @k1}, outro_user.id)
      {:ok, linha_b} = AI.fetch_sem_segredo(outro)

      aceita()
      aceita()

      log =
        capture_log(fn ->
          {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)
          {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k2}, ctx.user.id)
        end)

      assert {:ok, _} = AI.fetch(ctx.tenant)
      assert {:ok, _} = AI.fetch(outro)
      assert [primeira, troca] = linhas_do_evento(log)
      assert primeira =~ "tipo=:primeira"
      assert troca =~ "tipo=:troca"
      refute log =~ outro.id
      refute log =~ outro_user.id

      {:ok, linha_b_depois} = AI.fetch_sem_segredo(outro)

      assert Map.take(linha_b_depois, [:declared_by_user_id, :secret_set_at, :updated_at]) ==
               Map.take(linha_b, [:declared_by_user_id, :secret_set_at, :updated_at])
    end
  end

  describe "o segredo fora do rastro (#1221, condição 5)" do
    setup do
      nivel = Logger.level()
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: nivel) end)
    end

    test "nenhuma parte da chave no log, em nenhum dos quatro atos", ctx do
      aceita()
      aceita()
      aceita()

      log =
        capture_log([level: :debug], fn ->
          {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)
          {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)
          {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k2}, ctx.user.id)
          :ok = AI.delete(ctx.tenant, ctx.user.id)
        end)

      eventos = linhas_do_evento(log)
      assert length(eventos) == 4

      for chave <- [@k1, @k2] do
        refute log =~ chave
        refute log =~ String.slice(chave, 0, 12)
      end

      for linha <- eventos do
        refute linha =~ "wxyz"
        refute linha =~ "mnop"
        refute linha =~ "last_four"
      end
    end
  end

  # ------------------------------------------------------------------ #1388
  #
  # R-b do parecer da #1221: a recusa da chave pelo provedor deixa rastro, com o ator, o tenant e
  # só o átomo do motivo. A string do provedor imita a da OpenAI, que cita a chave mascarada por
  # ela, numa forma que `HTTP.redigir/2` não reconhece.
  @recusa_do_provedor "Incorrect API key provided: sk-tes*****************wxyz"

  defp linhas_da_recusa(log) do
    log
    |> String.split("\n")
    |> Enum.filter(&(&1 =~ "ato=:chave_do_modelo_recusada"))
  end

  describe "a recusa deixa rastro (#1388)" do
    # Em `:debug`, para o `refute` alcançar tudo o que o caminho loga, e não só a linha do evento.
    setup do
      nivel = Logger.level()
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: nivel) end)
    end

    test "cada um dos quatro motivos emite a recusa com o ator e o tenant", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o ->
        {:error, {:rejeitada, @recusa_do_provedor}}
      end)

      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:indisponivel, "timeout"}} end)
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:sem_modelos, "nenhum"}} end)
      aceita(["gpt-5.4-mini"])

      log =
        capture_log(fn ->
          assert {:error, {:rejeitada, _}} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

          assert {:error, {:indisponivel, _}} =
                   AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

          assert {:error, {:sem_modelos, _}} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

          assert {:error, {:modelo_desconhecido, _, _}} =
                   AI.put(ctx.tenant, %{"secret" => @k1, "default_model" => "x"}, ctx.user.id)
        end)

      linhas = linhas_da_recusa(log)

      assert Enum.map(linhas, &Regex.run(~r/motivo=(:\w+)/, &1, capture: :all_but_first)) ==
               [[":rejeitada"], [":indisponivel"], [":sem_modelos"], [":modelo_desconhecido"]]

      for linha <- linhas do
        assert linha =~ ~s(tenant_id="#{ctx.tenant.id}")
        assert linha =~ ~s(actor_user_id="#{ctx.user.id}")
      end

      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "a string do provedor e a chave nunca entram na linha nem no log", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o ->
        {:error, {:rejeitada, @recusa_do_provedor}}
      end)

      log =
        capture_log([level: :debug], fn ->
          assert {:error, {:rejeitada, @recusa_do_provedor}} =
                   AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)
        end)

      assert [_linha] = linhas_da_recusa(log)
      refute log =~ "Incorrect API key"
      refute log =~ "wxyz"
      refute log =~ String.slice(@k1, 0, 12)
    end

    test "chave aceita e erro de changeset não emitem recusa", ctx do
      aceita()
      aceita()

      log =
        capture_log(fn ->
          assert {:ok, _} = AI.put(ctx.tenant, %{"secret" => @k1}, ctx.user.id)

          assert {:error, %Ecto.Changeset{}} =
                   AI.put(ctx.tenant, %{"secret" => "sk-curta-wxyz"}, ctx.user.id)
        end)

      assert linhas_da_recusa(log) == []
    end
  end

  describe "as guardas do evento (#1221, condição 2)" do
    alias TheBand.Tenants.AccessEvents

    test "só os quatro átomos, tenant binário e ator binário ou nil passam", ctx do
      assert :ok = AccessEvents.chave_do_modelo(:troca, ctx.tenant.id, nil)

      # `apply/3` porque o verificador de tipos do compilador já recusa estas chamadas escritas
      # à mão. O que se mede aqui é a guarda em tempo de execução, que é o que protege quem
      # chama com valor dinâmico.
      for args <- [
            [:outro, ctx.tenant.id, ctx.user.id],
            ["troca", ctx.tenant.id, ctx.user.id],
            [:troca, ctx.tenant.id, %{id: ctx.user.id}],
            [:troca, ctx.tenant, ctx.user.id]
          ] do
        assert_raise FunctionClauseError, fn -> apply(AccessEvents, :chave_do_modelo, args) end
      end
    end

    # O nível do teste é `:warning` (`config/test.exs`): em `:info`, a linha nem seria capturada,
    # e é isso que este teste mede (L69).
    test "o evento sai em :warning, visível no nível padrão do teste", ctx do
      log =
        capture_log(fn -> AccessEvents.chave_do_modelo(:troca, ctx.tenant.id, ctx.user.id) end)

      assert unica_linha!(log) =~ "tipo=:troca"
    end

    test "a recusa aceita só os quatro motivos, ids binários e ator presente (#1388)", ctx do
      log =
        capture_log(fn ->
          assert :ok =
                   AccessEvents.chave_do_modelo_recusada(:rejeitada, ctx.tenant.id, ctx.user.id)
        end)

      assert [linha] = linhas_da_recusa(log)
      assert linha =~ "motivo=:rejeitada"

      # A string do provedor no lugar do átomo é exatamente o que a guarda existe para recusar.
      for args <- [
            [:outro, ctx.tenant.id, ctx.user.id],
            [@recusa_do_provedor, ctx.tenant.id, ctx.user.id],
            [{:rejeitada, @recusa_do_provedor}, ctx.tenant.id, ctx.user.id],
            [:rejeitada, ctx.tenant.id, nil],
            [:rejeitada, ctx.tenant, ctx.user.id]
          ] do
        assert_raise FunctionClauseError, fn ->
          apply(AccessEvents, :chave_do_modelo_recusada, args)
        end
      end
    end
  end
end
