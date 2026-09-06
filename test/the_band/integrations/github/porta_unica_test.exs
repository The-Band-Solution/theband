defmodule TheBand.Integrations.GitHub.PortaUnicaTest do
  @moduledoc """
  A porta única do cliente — ADR 0007, parte 3 — e a Verificação 1 da ADR: zero 403 sob
  concorrência.

  O cliente pede licença ao gestor de cotas antes de cada requisição e lhe devolve a
  leitura dos cabeçalhos depois. O que se prova aqui é o que a integração dos dois faz —
  e o defeito que a primeira versão teve: a recusa do gestor passava por `resposta_rest/1`
  e virava `{:transport, {:rate_limited, _}}`, que nenhuma etapa reconhece como cota.
  """
  use ExUnit.Case, async: true

  import Mox

  alias TheBand.Ingestion.Cota
  alias TheBand.Integrations.GitHub.Client

  setup :verify_on_exit!

  @instancia "https://github.com"

  defp chave(nome), do: {@instancia, "porta-#{nome}-#{System.unique_integer([:positive])}"}

  defp reset_futuro, do: Integer.to_string(System.system_time(:second) + 1800)

  defp cabecalhos(restante),
    do: [
      {"x-ratelimit-remaining", Integer.to_string(restante)},
      {"x-ratelimit-reset", reset_futuro()}
    ]

  describe "a recusa do gestor" do
    test "na REST é `{:rate_limited, reset}`, e nenhuma requisição sai" do
      chave = chave("rest")
      :ok = Cota.pedir(chave, :core)
      Cota.observar(chave, :core, %{remaining: 2, reset: DateTime.add(DateTime.utc_now(), 900)})

      # Sem `expect`: se o cliente chamar o HTTP, o Mox levanta — e é isso que se prova.
      assert {:error, {:rate_limited, %DateTime{}}} =
               Client.run_jobs(@instancia, "tok", "acme/repo", 1, cota: chave),
             """
             A recusa do gestor chegou à etapa com outra forma. Na primeira versão ela passava
             por `resposta_rest/1` e virava `{:transport, {:rate_limited, _}}` — a etapa a
             tratava como falha do repositório e seguia para o próximo, que era recusado igual.
             """
    end

    test "na GraphQL é `{:rate_limited, reset}`, e nenhuma requisição sai" do
      chave = chave("graphql")
      :ok = Cota.pedir(chave, :graphql)
      Cota.observar(chave, :graphql, %{remaining: 50, cost: 100, reset: nil})

      assert {:error, {:rate_limited, %DateTime{}}} =
               Client.graphql(@instancia, "tok", "query { x }", %{}, cota: chave)
    end

    test "é cota para `rate_limit?/1` E transitória para `transient?/1`" do
      assert Client.rate_limit?({:rate_limited, DateTime.utc_now()})

      assert Client.transient?({:rate_limited, DateTime.utc_now()}), """
      `{:rate_limited, _}` caía no permanente: um repositório saudável era marcado como
      inacessível — e tirado de toda coleta seguinte — por causa da hora do dia.
      """
    end
  end

  describe "sem identidade de cota" do
    test "o cliente não governa — é a validação de credencial, antes de existir dono" do
      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok, %{status: 200, body: %{"jobs" => []}, headers: cabecalhos(0)}}
      end)

      assert {:ok, %{jobs: []}} = Client.run_jobs(@instancia, "tok", "acme/repo", 1)
    end
  end

  describe "Verificação 1 da ADR 0007: zero 403 sob concorrência" do
    test "25 requisições concorrentes contra um saldo de 15 — o gestor concede até a margem" do
      chave = chave("concorrencia")
      teto = Cota.teto_em_voo()

      # A origem, honesta: um saldo que só cai, e 403 quando acabar. É o que o GitHub faz.
      {:ok, saldo} = Agent.start_link(fn -> %{restante: teto + 5, recusas: 0} end)

      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        Agent.get_and_update(saldo, fn
          %{restante: 0} = s ->
            {{:ok, %{status: 403, body: %{}, headers: cabecalhos(0)}},
             %{s | recusas: s.recusas + 1}}

          %{restante: r} = s ->
            {{:ok, %{status: 200, body: %{"jobs" => []}, headers: cabecalhos(r - 1)}},
             %{s | restante: r - 1}}
        end)
      end)

      # A primeira requisição sai no escuro e traz a leitura; as outras 24 já a encontram.
      {:ok, _} = Client.run_jobs(@instancia, "tok", "acme/repo", 0, cota: chave)

      resultados =
        1..24
        |> Task.async_stream(
          fn n -> Client.run_jobs(@instancia, "tok", "acme/repo", n, cota: chave) end,
          max_concurrency: 24,
          ordered: false
        )
        |> Enum.map(fn {:ok, r} -> r end)

      concedidas = Enum.count(resultados, &match?({:ok, _}, &1))
      recusadas = Enum.count(resultados, &match?({:error, {:rate_limited, _}}, &1))

      assert Agent.get(saldo, & &1.recusas) == 0, """
      A origem devolveu 403 #{Agent.get(saldo, & &1.recusas)} vez(es). Com 25 em voo e 15 de
      saldo, sem o gestor o 403 é garantido — e cada um conta contra a cota secundária sem
      trazer nada. O gestor existe para que a origem nunca precise recusar.
      """

      assert concedidas + recusadas == 24
      assert recusadas > 0, "com saldo #{teto + 5} e margem #{teto}, alguém tinha de ser recusado"
    end
  end
end
