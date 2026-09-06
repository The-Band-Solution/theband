defmodule TheBand.Ingestion.JanelaEsgotadaTest do
  @moduledoc """
  Janela esgotada não é repositório quebrado — medido em 2026-09-05.

  ## O defeito que este arquivo fecha

  `GithubVerifications` conta dois estados diferentes de propósito, e o comentário do
  contador diz por quê:

  > Separado de `unreachable` porque as duas frases são diferentes: janela esgotada é
  > "volte daqui a pouco", e inalcançável é "algo está errado com este repositório".
  > Somá-las fez 160 repositórios saudáveis parecerem quebrados na primeira medição, em
  > 2026-08-18.

  **O estado `:sem_janela` aparecia uma vez só no módulo — no contador.** Nada o
  produzia. O rate limit reativo caía no ramo geral e virava `:inalcancavel`.

  Na coleta real de 2026-09-05: **98 repositórios saudáveis contados como
  inalcançáveis**, e o resumo informando `rate_limited: 0`. Exatamente o que o comentário
  diz que não pode acontecer, pela segunda vez.

  ## Por que não havia teste

  A etapa inteira não tinha nenhum: o cliente do GitHub é substituível por configuração
  (`:github_http_client`), e ninguém tinha usado isso para esta fase. É a lacuna que
  permitiu um estado inalcançável sobreviver a três revisões e 1 704 testes.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.WorkItemsFixtures

  setup :verify_on_exit!

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Cota
  alias TheBand.Ingestion.GithubVerifications
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Verification.Commands

  setup do
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)

    tool =
      Repo.one!(
        from t in ConnectedTool, where: t.tenant_id == type(^tenant.id, :binary_id), limit: 1
      )

    {:ok, sync} =
      %Ingestion.Sync{}
      |> Ingestion.Sync.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        status: "running",
        started_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    %{
      ctx: %{
        tenant: tenant,
        sync: sync,
        tool: tool,
        token: "token-de-teste",
        # A identidade da cota (ADR 0007). Sem ela o cliente não passa pelo gestor, e a
        # pausa preventiva — que é o que dois destes testes provam — não existiria.
        cota: Cota.chave(tool, %{id: tool.id, owner_login: nil})
      },
      repo_id: cenario.observed_repository_id
    }
  end

  # Um repositório observado a mais, para a etapa ter vários por onde parar.
  defp observar_repositorio(ctx, nome) do
    org = organization_fixture(ctx.ctx.tenant, "org-#{nome}")

    {:ok, fonte} =
      CMPO.upsert_source_repository_from_source(ctx.ctx.tenant, %{
        organization_id: org.id,
        name: nome,
        qualified_name: "acme/#{nome}",
        url: "https://github.com/acme/#{nome}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_#{nome}"
      })

    {:ok, observado} = CMPO.observe_repository(ctx.ctx.tenant, ctx.ctx.tool.id, fonte.id)
    observado
  end

  # A janela esgotada, como a ORIGEM a entrega: 403 com `x-ratelimit-remaining: 0`. É o
  # cliente que traduz isso para `{:rate_limited, _}`, e um duplo que devolvesse a tupla
  # pronta pularia justamente a tradução que decide.
  defp responder_com_janela_fechada do
    stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok,
       %{
         status: 403,
         headers: [{"x-ratelimit-remaining", "0"}, {"x-ratelimit-reset", reset_futuro()}],
         body: %{}
       }}
    end)
  end

  # O reset SEMPRE no futuro. O primeiro esboço usava um epoch fixo (2026-09-04 12:00), que
  # ficou no passado no dia seguinte — e o gestor de cotas, corretamente, lia "a janela já
  # reabriu" e concedia tudo. Um teste de pausa que passa a depender do calendário não é teste.
  defp reset_futuro, do: Integer.to_string(System.system_time(:second) + 1800)

  # 500 é falha da origem, e não cota: `x-ratelimit-remaining` nem aparece.
  defp responder_quebrado do
    stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok, %{status: 500, headers: [], body: "boom"}}
    end)
  end

  describe "a janela esgotada é contada como janela, e não como repositório quebrado" do
    test "a janela fechada devolve a ESPERA, e não um resumo parcial", ctx do
      responder_com_janela_fechada()

      assert {:snooze, segundos} = GithubVerifications.collect(ctx.ctx), """
      A etapa devolveu um resumo com a janela fechada. O job leria como "acabou", fecharia
      o sync em `completed`, e a tela mostraria os repositórios coletados como se fossem
      todos — foi o que aconteceu em 2026-09-05 (ADR 0006, item 5).
      """

      assert segundos >= 60, "a espera precisa da folga de um minuto sobre o reset"
    end

    test "PARA no primeiro rate limit, em vez de bater em todos os repositórios", ctx do
      # Medido em 2026-09-05: 125 requisições devolveram 403 em cinco segundos, cada uma
      # contando contra a cota secundária, nenhuma trazendo nada. Com `reduce_while`, as
      # tarefas em voo terminam e as não iniciadas nunca começam.
      for n <- 1..20, do: observar_repositorio(ctx, "repo-#{n}")

      {:ok, contador} = Agent.start_link(fn -> 0 end)

      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        Agent.update(contador, &(&1 + 1))

        {:ok,
         %{
           status: 403,
           headers: [{"x-ratelimit-remaining", "0"}, {"x-ratelimit-reset", reset_futuro()}],
           body: %{}
         }}
      end)

      {:snooze, _} = GithubVerifications.collect(ctx.ctx)
      chamadas = Agent.get(contador, & &1)

      # 21 repositórios, concorrência 5: no pior caso as 5 em voo mais o lote que o stream
      # já tinha pedido. Muito menos que 21 — e a diferença é o que a cota agradece.
      assert chamadas < 21, """
      A etapa fez #{chamadas} requisições depois de a janela fechar — ela continuou
      batendo em repositório por repositório. Cada uma conta contra a cota secundária.
      """
    end

    test "o checkpoint NÃO avança quando a janela fecha", ctx do
      responder_com_janela_fechada()

      {:snooze, _} = GithubVerifications.collect(ctx.ctx)

      marcado =
        Repo.one(
          from r in "observed_repositories",
            where: r.id == type(^ctx.repo_id, :binary_id),
            select: r.verifications_collected_at
        )

      refute marcado, """
      O repositório foi marcado como percorrido depois de a cota acabar. O incremental
      filtra por data: marcar aqui faria a próxima coleta pular tudo o que a janela
      impediu de ver, e a lacuna nunca seria preenchida.
      """
    end

    test "execução COMPLETA que já tem jobs não gera nova requisição de jobs", ctx do
      # PASSO 4 da ADR 0006, item 5. A retomada refazia as mesmas requisições de jobs de
      # execuções já gravadas — 3 316 delas — e caía no mesmo buraco de cota, no mesmo
      # lugar, para sempre.
      {:ok, ja_gravada} =
        Commands.record_verification(ctx.ctx.tenant, %{
          observed_repository_id: ctx.repo_id,
          workflow_name: "CI",
          run_status: "completed",
          conclusion: "success",
          head_sha: "abc111",
          external_id: "111",
          source_system: "github",
          source_instance: "https://github.com"
        })

      {:ok, _} =
        Commands.record_component(ctx.ctx.tenant, %{
          collected_verification_id: ja_gravada.id,
          job_name: "build",
          external_id: "job-111"
        })

      {:ok, urls} = Agent.start_link(fn -> [] end)

      stub(TheBand.GitHubHTTPMock, :get, fn url, _token ->
        Agent.update(urls, &[url | &1])

        cond do
          String.contains?(url, "/actions/runs/") and String.ends_with?(url, "/jobs") ->
            {:ok, %{status: 200, headers: [], body: %{"jobs" => []}}}

          String.contains?(url, "/actions/runs") ->
            {:ok,
             %{
               status: 200,
               headers: [],
               body: %{
                 "workflow_runs" => [
                   %{
                     "id" => 111,
                     "status" => "completed",
                     "conclusion" => "success",
                     "name" => "CI",
                     "head_sha" => "abc111"
                   },
                   %{
                     "id" => 222,
                     "status" => "completed",
                     "conclusion" => "success",
                     "name" => "CI",
                     "head_sha" => "abc222"
                   }
                 ]
               }
             }}

          true ->
            {:ok, %{status: 200, headers: [], body: %{}}}
        end
      end)

      {:ok, _} = GithubVerifications.collect(ctx.ctx)
      pedidas = Agent.get(urls, & &1)

      refute Enum.any?(pedidas, &String.contains?(&1, "/runs/111/jobs")), """
      A retomada pediu de novo os jobs da execução 111, que já estava COMPLETA e com jobs
      no banco. É cota gasta para gravar o que já está gravado — e é por isso que a coleta
      caía no mesmo rate limit toda vez.
      """

      assert Enum.any?(pedidas, &String.contains?(&1, "/runs/222/jobs")), """
      A execução 222 é nova e precisa dos jobs. Pular TODAS as requisições de jobs seria
      trocar o defeito por outro.
      """
    end

    test "PARA ANTES de bater: remaining baixo numa resposta 200 já é espera", ctx do
      # Achado da avaliação técnica de 2026-09-05: a REST descartava os cabeçalhos de cota
      # nas respostas 200, e a etapa mais cara não tinha pausa preventiva — só descobria a
      # cota depois de bater, e bater custa uma requisição que não traz nada.
      {:ok, respostas_403} = Agent.start_link(fn -> 0 end)

      stub(TheBand.GitHubHTTPMock, :get, fn url, _token ->
        cabecalhos = [{"x-ratelimit-remaining", "3"}, {"x-ratelimit-reset", reset_futuro()}]

        cond do
          String.ends_with?(url, "/jobs") ->
            {:ok, %{status: 200, headers: cabecalhos, body: %{"jobs" => []}}}

          String.contains?(url, "/actions/runs") ->
            {:ok,
             %{
               status: 200,
               headers: cabecalhos,
               body: %{
                 "workflow_runs" =>
                   for n <- 1..8 do
                     %{
                       "id" => n,
                       "status" => "completed",
                       "conclusion" => "success",
                       "name" => "CI",
                       "head_sha" => "sha#{n}"
                     }
                   end
               }
             }}

          true ->
            Agent.update(respostas_403, &(&1 + 1))
            {:ok, %{status: 403, headers: cabecalhos, body: %{}}}
        end
      end)

      resultado = GithubVerifications.collect(ctx.ctx)

      assert {:snooze, _} = resultado, """
      A etapa viu `remaining: 3` numa resposta 200 e seguiu pedindo — devolveu
      #{inspect(resultado)} com o gestor em #{inspect(Cota.estado(ctx.ctx.cota))}. Com concorrência 5, as
      tarefas em voo gastam a cota que sobrou, e a próxima requisição é um 403 — que conta e
      não traz nada. A GraphQL pausa preventivamente há semanas; a REST não pausava.
      """

      assert Agent.get(respostas_403, & &1) == 0,
             "a pausa preventiva existe para nunca chegar ao 403"
    end

    test "erro de verdade continua sendo `unreachable`", ctx do
      responder_quebrado()

      {:ok, resumo} = GithubVerifications.collect(ctx.ctx)

      assert resumo.unreachable > 0, """
      Um erro que não é de cota deixou de ser inalcançável. A correção precisa separar as
      duas frases, e não trocar uma pela outra.
      """

      assert resumo.rate_limited == 0
    end
  end
end
