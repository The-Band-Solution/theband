defmodule TheBand.Ingestion.PularSemAtividadeTest do
  @moduledoc """
  O repositório sem push desde a última revisão não é consultado (T007 a T010).

  ## A medida que justifica

  Em 2026-08-14, na `leds-conectafapes`: **106 dos 121** repositórios não haviam recebido
  push algum desde a última vez que a plataforma leu as issues deles. Foram percorridos
  inteiros mesmo assim, e a coleta levou 5min 08s para trazer 4295 issues das quais 34 tinham
  mudado.

  ## O que este teste afirma, e por que a asserção é negativa

  A borda HTTP simulada **reprova o teste se for chamada** para o repositório parado. Afirmar
  que "não trouxe issues" não prova que não pediu — e o que custa é o pedido, não o resultado.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.QueryVersion
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    _org = organization_fixture(tenant, "acme")
    %{tenant: tenant, tool: ferramenta(tenant)}
  end

  describe "a decisão" do
    test "sem push desde a revisão E já percorrido com esta consulta, não percorre" do
      assert {:nao, :sem_push_desde_a_revisao} =
               GithubWorkItems.percorrer?(
                 %{last_pushed_at: ~U[2026-05-01 00:00:00Z]},
                 %{
                   issues_collected_at: ~U[2026-08-01 00:00:00Z],
                   query_versions: %{"issues" => QueryVersion.atual("issues")}
                 }
               )
    end

    # Issue #452 aplicada a esta fase pela #368. O corte responde "já percorri este
    # repositório"; a consulta que ganha um campo muda a pergunta para "já percorri COM
    # ESTA CONSULTA". Aqui o silêncio seria o pior dos três cortes, porque este pula o
    # repositório INTEIRO — e "sem push" é o estado normal da maioria.
    test "sem push, mas a consulta ganhou campo: percorre uma vez", _ctx do
      assert :sim =
               GithubWorkItems.percorrer?(
                 %{last_pushed_at: ~U[2026-05-01 00:00:00Z]},
                 %{
                   issues_collected_at: ~U[2026-08-01 00:00:00Z],
                   query_versions: %{"issues" => QueryVersion.atual("issues") - 1}
                 }
               )
    end

    test "repositório nunca marcado com versão nenhuma percorre", _ctx do
      assert :sim =
               GithubWorkItems.percorrer?(
                 %{last_pushed_at: ~U[2026-05-01 00:00:00Z]},
                 %{issues_collected_at: ~U[2026-08-01 00:00:00Z], query_versions: %{}}
               ),
             """
             O repositório já coletado antes da #368 não foi reaberto.

             Todos os 135 observados estão nesse estado: a marca de versão para `issues` não
             existia. Se o corte valesse para eles, as 5.216 issues ficariam com
             `milestone_due_on` nulo para sempre, e ninguém veria.
             """
    end

    test "com push depois da revisão, percorre" do
      assert :sim =
               GithubWorkItems.percorrer?(
                 %{last_pushed_at: ~U[2026-08-10 00:00:00Z]},
                 %{
                   issues_collected_at: ~U[2026-08-01 00:00:00Z],
                   query_versions: %{"issues" => QueryVersion.atual("issues")}
                 }
               )
    end

    test "nunca revisto percorre" do
      assert :sim =
               GithubWorkItems.percorrer?(
                 %{last_pushed_at: ~U[2026-05-01 00:00:00Z]},
                 %{issues_collected_at: nil}
               )
    end

    test "sem data de push percorre", _ctx do
      assert :sim =
               GithubWorkItems.percorrer?(
                 %{last_pushed_at: nil},
                 %{issues_collected_at: ~U[2026-08-01 00:00:00Z]}
               )

      # Ausência de data não é ausência de mudança. Concluir o contrário faria a plataforma
      # deixar de ler um repositório porque a origem não informou algo — é a L47.
    end
  end

  describe "a coleta" do
    test "não pede as issues do repositório parado", ctx do
      # Primeira coleta: percorre e grava a revisão.
      responder(ctx, fn _query -> :normal end)
      primeira = coletar(ctx)
      assert primeira.records_collected > 0

      # A origem não recebeu push nenhum desde então — o `pushedAt` continua o mesmo, e a
      # revisão acabou de ser gravada.
      #
      # **A asserção é a função de resposta**: pedir issues aqui reprova o teste.
      responder(ctx, fn query ->
        if String.contains?(query, "issues("),
          do: flunk("a coleta pediu as issues de um repositório sem push desde a revisão"),
          else: :normal
      end)

      segunda = coletar(ctx)

      assert segunda.records_collected == 1, """
      Só o repositório foi percorrido — a consulta de issues não aconteceu.
      """
    end

    test "pular não marca vínculo, e não grava a revisão de novo", ctx do
      responder(ctx, fn _query -> :normal end)
      _primeira = coletar(ctx)

      %{"um" => antes} = observados(ctx.tenant)

      responder(ctx, fn query ->
        if String.contains?(query, "issues("), do: flunk("pediu issues"), else: :normal
      end)

      _segunda = coletar(ctx)

      %{"um" => depois} = observados(ctx.tenant)

      assert depois.issues_collected_at == antes.issues_collected_at, """
      A data de revisão foi regravada num repositório que não foi percorrido.

      Ela diz **quando foi percorrido por inteiro**. Regravá-la sem percorrer faz a marca
      afirmar uma coleta que não houve — e é pior que não saber.
      """

      assert marcados(ctx.tenant) == 0, """
      Pular marcou vínculo como ausente.

      Repositório não percorrido é repositório não olhado, e "não apareceu" só significa algo
      em relação ao que foi olhado. Esta é a garantia mais importante desta fase.
      """
    end

    test "volta a percorrer quando a origem recebe push", ctx do
      responder(ctx, fn _query -> :normal end)
      _primeira = coletar(ctx)

      # Push depois da revisão: o repositório volta para a coleta.
      #
      # A asserção é que a coleta **pediu** as issues, e não que trouxe alguma: a página de
      # teste vem vazia, e "trouxe zero" é o que o repositório pulado também produz. O que
      # distingue os dois é o pedido.
      pai = self()

      responder(ctx, fn query ->
        if String.contains?(query, "issues("), do: send(pai, :pediu_issues)
        :com_push_novo
      end)

      _segunda = coletar(ctx)

      assert_received :pediu_issues, """
      Um push na origem tem de trazer o repositório de volta. Sem isso, pular seria
      permanente — e o repositório ficaria congelado sem erro e sem aviso.
      """
    end
  end

  # ---------------------------------------------------------------- montagem

  defp coletar(ctx) do
    sync = sync(ctx.tenant, ctx.tool)

    {:ok, _} =
      GithubWorkItems.collect(%{
        tenant: ctx.tenant,
        sync: sync,
        tool: ctx.tool,
        token: "token-de-teste"
      })

    contada = Ingestion.reload(sync)
    {:ok, _} = Ingestion.finish(contada, :completed)
    contada
  end

  defp observados(tenant), do: Map.new(CMPO.list_observed(tenant), &{&1.name, &1})

  defp marcados(tenant) do
    Repo.aggregate(
      from(l in TheBand.WorkItems.Schemas.DecompositionLink,
        where: l.tenant_id == ^tenant.id and not is_nil(l.no_longer_observed_at)
      ),
      :count
    )
  end

  defp responder(_ctx, fun) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: _vars}, _token ->
      data =
        case fun.(query) do
          :normal -> pagina(query, "2026-08-01T00:00:00Z")
          :com_push_novo -> pagina(query, "2030-01-01T00:00:00Z")
        end

      {:ok, %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}}
    end)
  end

  defp pagina(query, pushed_at) do
    if String.contains?(query, "repositories(") do
      %{
        "organization" => %{
          "id" => "O_1",
          "repositories" => %{
            "totalCount" => 1,
            "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
            "nodes" => [
              %{
                "id" => "R_um",
                "name" => "um",
                "nameWithOwner" => "acme/um",
                "url" => "https://github.com/acme/um",
                "description" => nil,
                "primaryLanguage" => %{"name" => "Elixir"},
                "defaultBranchRef" => %{"name" => "main"},
                "archivedAt" => nil,
                "createdAt" => "2026-01-01T00:00:00Z",
                "pushedAt" => pushed_at
              }
            ]
          }
        }
      }
    else
      %{
        "repository" => %{
          "issues" => %{
            "totalCount" => 0,
            "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
            "nodes" => []
          }
        }
      }
    end
  end

  defp ferramenta(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme"
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "teste",
        secret: "token-de-teste",
        last_four: "este",
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    tool
  end

  defp sync(tenant, tool) do
    {:ok, sync} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        status: "running",
        started_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    sync
  end
end
