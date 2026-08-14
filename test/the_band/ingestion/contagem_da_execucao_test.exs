defmodule TheBand.Ingestion.ContagemDaExecucaoTest do
  @moduledoc """
  O que a execução fez — criados, atualizados e inalterados (T002, T003, T004).

  ## O que estava errado, e por quanto tempo

  Medido em 2026-08-14: `records_updated` era **zero nas 38 execuções** que existiam no
  banco, e `records_created` tinha valor em quatro — todas da fase de EO. A tela mostrava

      records collected   4553
      created                0
      updated                0

  e estava exibindo fielmente o que fora gravado. `github_work_items.ex` chamava
  `Ingestion.tally(:unchanged)` **fixo**, para toda issue e todo repositório.

  A informação existia no instante em que era descartada: naquela coleta entraram 502 issues
  novas e 182 mudaram na origem.

  ## Por que este teste vem antes de qualquer corte

  A feature 020 corta o que a coleta baixa. Sem contagem correta, *"baixou 5% do que
  baixava"* e *"perdeu 95% do que devia trazer"* produzem **a mesma tela** — e o sucesso da
  feature deixa de ser verificável.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    _organization = organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, tool: tool}
  end

  describe "a contagem de issues" do
    test "issue que não existia conta como criada", ctx do
      responder(&pagina(&1, [issue(1, "uma issue")]))

      sync = coletar(ctx)

      assert sync.records_created == 2, """
      Esperados dois criados: o repositório observado e a issue.

      Enquanto `tally(:unchanged)` era fixo, este número era **zero** em toda execução — e a
      tela mostrava zero sobre 4553 registros coletados.
      """

      assert sync.records_updated == 0
      assert sync.records_collected == 2
    end

    test "issue idêntica na segunda coleta não conta como atualizada", ctx do
      responder(&pagina(&1, [issue(1, "uma issue")]))

      _primeira = coletar(ctx)
      segunda = coletar(ctx)

      assert segunda.records_created == 0, """
      Nada foi criado na segunda coleta: o repositório já era observado e a issue já existia.
      """

      assert segunda.records_updated == 0, """
      **Esta é a asserção que importa.** A coleta reescreve `last_observed_at` em toda
      passada, e contar isso como atualização faria `records_updated` dizer "tudo mudou" em
      toda execução — um número que parece informação e não é.

      A comparação é pelos campos da origem, e `last_observed_at` não é um deles.
      """

      assert segunda.records_collected == 2, "o total percorrido não muda"
    end

    test "issue com título diferente conta como atualizada", ctx do
      responder(&pagina(&1, [issue(1, "título antigo")]))
      _primeira = coletar(ctx)

      responder(&pagina(&1, [issue(1, "título novo")]))
      segunda = coletar(ctx)

      assert segunda.records_updated == 1, "a issue mudou na origem e tem de contar"
      assert segunda.records_created == 0
    end
  end

  describe "a contagem de repositórios" do
    test "repositório já observado não conta como criado nem atualizado", ctx do
      responder(&pagina(&1, []))

      primeira = coletar(ctx)
      segunda = coletar(ctx)

      assert primeira.records_created == 1, "o repositório foi observado pela primeira vez"

      assert segunda.records_created == 0

      assert segunda.records_updated == 0, """
      Reobservar um repositório que já era observado não muda nada nele. Contar como
      atualização inflaria o número em toda coleta, com valor que não corresponde a mudança
      alguma na origem.
      """
    end
  end

  describe "a execução interrompida" do
    test "preserva a contagem do que já foi feito", ctx do
      responder(&pagina(&1, [issue(1, "uma issue")]))

      sync = coletar(ctx)
      {:ok, interrompida} = Ingestion.finish(sync, :interrupted, error_reason: "encenada")

      assert interrompida.records_created == 2, """
      Interromper não pode zerar o que já aconteceu. Zero afirma que nada foi feito, e a
      execução gravou dois registros — é a mesma regra da contagem de repositório
      inacessível, que soma a cada falha e não no fim.
      """
    end
  end

  # ---------------------------------------------------------------- montagem

  # Encerra a execução ao final, porque o índice parcial só permite uma `running` por
  # ferramenta — FR-018. Sem isso, a segunda coleta do teste não nasce, e o erro aparece como
  # `MatchError` num changeset, longe do que o teste quer medir.
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

  defp responder(fun) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: _vars}, _token ->
      {:ok, %{status: 200, body: %{"data" => Map.put(fun.(query), "rateLimit", @rate_limit)}}}
    end)
  end

  defp pagina(query, issues) do
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
                "pushedAt" => "2026-08-01T00:00:00Z"
              }
            ]
          }
        }
      }
    else
      %{
        "repository" => %{
          "issues" => %{
            "totalCount" => length(issues),
            "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
            "nodes" => issues
          }
        }
      }
    end
  end

  defp issue(numero, titulo) do
    %{
      "id" => "I_#{numero}",
      "number" => numero,
      "title" => titulo,
      "body" => "",
      "state" => "OPEN",
      "issueType" => %{"id" => "IT_Task", "name" => "Task"},
      "createdAt" => "2026-08-01T00:00:00Z",
      "updatedAt" => "2026-08-02T00:00:00Z",
      "closedAt" => nil,
      "author" => nil,
      "assignees" => %{"nodes" => []},
      "labels" => %{"nodes" => []},
      "subIssues" => %{"totalCount" => 0, "nodes" => []},
      "parent" => nil
    }
  end
end
