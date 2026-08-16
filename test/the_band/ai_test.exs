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

  import Mox
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0, tenant_with_admin: 1]

  alias TheBand.AI
  alias TheBand.Repo

  setup :verify_on_exit!

  @chave "sk-uma-chave-de-teste-com-mais-de-vinte-caracteres-9876"

  setup do
    # A chave do ambiente é do processo, e o processo é compartilhado pela suíte: sem
    # tirá-la, o estado `:nenhuma` dependeria de quem rodou o teste ter ou não `.env`
    # carregado — que é exatamente a diferença que este módulo existe para nomear.
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")
    on_exit(fn -> if anterior, do: System.put_env("API_KEY", anterior) end)

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
        assert secret == @chave
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

      assert {:error, {:rejeitada, "HTTP 401"}} = AI.put(ctx.tenant, %{"secret" => @chave})
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "provedor inalcançável não grava, e a recusa não é a mesma de chave recusada", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:indisponivel, "timeout"}} end)

      assert {:error, {:indisponivel, "timeout"}} = AI.put(ctx.tenant, %{"secret" => @chave})
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "chave aceita que não alcança modelo algum não grava", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:error, {:sem_modelos, "nenhum"}} end)

      assert {:error, {:sem_modelos, "nenhum"}} = AI.put(ctx.tenant, %{"secret" => @chave})
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "modelo que o provedor não lista é recusado, e não trocado pelo padrão", ctx do
      aceita(["gpt-5.4-mini"])

      assert {:error, {:modelo_desconhecido, "gpt-4o", ["gpt-5.4-mini"]}} =
               AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => "gpt-4o"})

      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "modelo em branco é escolha, e vale o padrão do provedor", ctx do
      aceita()

      assert {:ok, cred} = AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => ""})
      assert is_nil(cred.default_model)
    end

    test "modelo listado pelo provedor é gravado", ctx do
      aceita()

      assert {:ok, cred} = AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => "gpt-5.4"})
      assert cred.default_model == "gpt-5.4"
    end

    # O provedor chega a ser consultado aqui, e é aceitável: a regra de tamanho mínimo mora
    # no changeset, e duplicá-la antes da chamada colocaria o mesmo número em dois lugares.
    test "chave curta demais é recusada pelo changeset, e nada é gravado", ctx do
      aceita()

      assert {:error, %Ecto.Changeset{} = changeset} =
               AI.put(ctx.tenant, %{"secret" => "sk-1234"})

      assert %{secret: ["curta demais para ser uma chave de API"]} = errors_on(changeset)
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "gravar de novo substitui, e o tenant continua com uma linha só", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      aceita()
      {:ok, segunda} = AI.put(ctx.tenant, %{"secret" => "sk-outra-chave-bem-mais-longa-4321"})

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
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

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
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave, "default_model" => "gpt-5.4"})

      opcoes = AI.opcoes(ctx.tenant)

      assert opcoes[:key] == @chave
      assert opcoes[:base_url] == "https://api.openai.com"
      assert opcoes[:model] == "gpt-5.4"
    end

    test "sem modelo escolhido, a opção não vai — quem decide é o provedor", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      refute Keyword.has_key?(AI.opcoes(ctx.tenant), :model)
    end
  end

  describe "apagar (delete/2)" do
    test "o segredo some, e apagar de novo diz que não há o que apagar", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      assert :ok = AI.delete(ctx.tenant)
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
      assert {:error, :not_found} = AI.delete(ctx.tenant)
    end
  end

  describe "isolamento entre organizações" do
    test "a chave de uma organização não é lida nem usada pela outra", ctx do
      {outro, _} = tenant_with_admin("outro")

      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      assert {:error, :not_found} = AI.fetch(outro)
      assert AI.origem_da_chave(outro) == :nenhuma
      assert AI.opcoes(outro) == []
    end
  end
end
