defmodule TheBand.Ingestion.GithubWorkItemsAccountTypeTest do
  @moduledoc """
  O tipo da conta de quem abriu a issue e de cada responsável, gravado na coleta — feature 076,
  T021 (research.md R13; A3 da revisão semântica 2; `contracts/fronteiras.md`, *Coleta*).

  O tipo vem de `Mapper.account_type/1` sobre o nó, **chamado e nunca reimplementado**: o
  `__typename` decide antes do sufixo do login. Uma conta `Bot` cujo login vem sem `[bot]` é
  `bot`, e não `person` — é o caso que a regra de hoje classificaria errado.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, tool: tool}
  end

  test "autor Bot sem o sufixo grava bot; responsável User grava person; App grava app", ctx do
    # O login NÃO termina em [bot]: só o __typename diz que é máquina.
    robo = %{"__typename" => "Bot", "id" => "B_1", "login" => "renovate-sem-sufixo"}
    pessoa = %{"__typename" => "User", "id" => "U_1", "login" => "ana", "name" => "Ana"}
    app = %{"__typename" => "App", "id" => "A_1", "login" => "um-app"}

    no =
      issue(1, robo)
      |> put_in(["assignees"], %{"nodes" => [pessoa, app]})

    responder([no, issue(2, pessoa), issue(3, nil)])

    assert {:ok, _} = coletar(ctx)

    por_numero = Repo.all(CollectedIssue) |> Map.new(&{&1.number, &1})
    assert map_size(por_numero) == 3

    assert por_numero[1].author_account_type == "bot"
    assert por_numero[2].author_account_type == "person"

    # Autor apagado na origem: nulo é "não se sabe", nunca "person".
    assert por_numero[3].author_account_type == nil

    tipos =
      Repo.all(from a in IssueAssignee, where: a.collected_issue_id == ^por_numero[1].id)
      |> Map.new(&{&1.login, &1.account_type})

    assert tipos == %{"ana" => "person", "um-app" => "app"}
  end

  test "um valor fora dos três é recusado pelo banco", ctx do
    responder([issue(1, %{"__typename" => "User", "id" => "U_1", "login" => "ana"})])
    assert {:ok, _} = coletar(ctx)
    issue = Repo.one!(CollectedIssue)

    assert_raise Postgrex.Error, ~r/collected_issues_author_account_type_allowed/, fn ->
      Repo.update_all(from(i in CollectedIssue, where: i.id == ^issue.id),
        set: [author_account_type: "organization"]
      )
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp coletar(ctx) do
    GithubWorkItems.collect(%{
      tenant: ctx.tenant,
      sync: sync(ctx.tenant, ctx.tool),
      tool: ctx.tool,
      token: "token-de-teste"
    })
  end

  defp issue(numero, autor) do
    %{
      "id" => "I_#{numero}",
      "number" => numero,
      "title" => "issue ##{numero}",
      "bodyText" => "",
      "state" => "OPEN",
      "issueType" => %{"id" => "IT_Task", "name" => "Task"},
      "createdAt" => "2026-08-01T00:00:00Z",
      "updatedAt" => "2026-08-02T00:00:00Z",
      "closedAt" => nil,
      "author" => autor,
      "assignees" => %{"nodes" => []},
      "labels" => %{"nodes" => []},
      "subIssues" => %{"totalCount" => 0, "nodes" => []},
      "parent" => nil
    }
  end

  defp responder(nodes) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
      if String.contains?(q, "repositories(") do
        {:ok, resposta(pagina_de_repositorios())}
      else
        {:ok, resposta(pagina_de_issues(nodes))}
      end
    end)
  end

  defp resposta(data),
    do: %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}

  defp pagina_de_repositorios do
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
              "primaryLanguage" => nil,
              "defaultBranchRef" => %{"name" => "main"},
              "archivedAt" => nil,
              "createdAt" => "2026-01-01T00:00:00Z",
              "pushedAt" => "2026-08-01T00:00:00Z"
            }
          ]
        }
      }
    }
  end

  defp pagina_de_issues(nodes) do
    %{
      "repository" => %{
        "issues" => %{
          "totalCount" => length(nodes),
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
          "nodes" => nodes
        }
      }
    }
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

    TheBand.Sources.fetch_connected_tool(tenant, tool.id) |> then(fn {:ok, t} -> t end)
  end

  defp sync(tenant, tool) do
    case Ingestion.running_sync(tool) do
      nil -> :ok
      anterior -> Ingestion.finish(anterior, :completed)
    end

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
