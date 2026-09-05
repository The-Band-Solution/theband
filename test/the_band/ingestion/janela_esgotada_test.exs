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
  alias TheBand.Ingestion.GithubVerifications
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

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
      ctx: %{tenant: tenant, sync: sync, tool: tool, token: "token-de-teste"},
      repo_id: cenario.observed_repository_id
    }
  end

  # A janela esgotada, como a ORIGEM a entrega: 403 com `x-ratelimit-remaining: 0`. É o
  # cliente que traduz isso para `{:rate_limited, _}`, e um duplo que devolvesse a tupla
  # pronta pularia justamente a tradução que decide.
  defp responder_com_janela_fechada do
    stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok,
       %{
         status: 403,
         headers: [{"x-ratelimit-remaining", "0"}, {"x-ratelimit-reset", "1788580800"}],
         body: %{}
       }}
    end)
  end

  # 500 é falha da origem, e não cota: `x-ratelimit-remaining` nem aparece.
  defp responder_quebrado do
    stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok, %{status: 500, headers: [], body: "boom"}}
    end)
  end

  describe "a janela esgotada é contada como janela, e não como repositório quebrado" do
    test "rate limit vira `rate_limited`, e NÃO `unreachable`", ctx do
      responder_com_janela_fechada()

      {:ok, resumo} = GithubVerifications.collect(ctx.ctx)

      assert resumo.rate_limited > 0, """
      A janela esgotada não foi contada como janela. O estado `:sem_janela` existe no
      contador e precisa ser PRODUZIDO por alguém — antes desta correção, nada o produzia,
      e 98 repositórios saudáveis apareceram como inalcançáveis na coleta real.
      """

      assert resumo.unreachable == 0, """
      O repositório foi marcado como inalcançável por causa da cota. "Volte daqui a
      pouco" e "algo está errado com este repositório" levam a ações opostas, e quem lê
      `unreachable` vai investigar um repositório que não tem nada.
      """
    end

    test "o checkpoint NÃO avança quando a janela fecha", ctx do
      responder_com_janela_fechada()

      {:ok, _} = GithubVerifications.collect(ctx.ctx)

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
