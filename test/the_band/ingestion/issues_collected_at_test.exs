defmodule TheBand.Ingestion.IssuesCollectedAtTest do
  @moduledoc """
  A data de coleta de issues, gravada no fim da fase (T004).

  ## As duas asserções que importam

  A primeira não é "o repositório coletado tem a data" — é **o inacessível não tem**. A
  data existe para a tela poder dizer "olhei e não achei" em vez de "não sei", e gravá-la
  para quem a plataforma não consultou faria a marca **mentir sobre coleta** — que é pior
  que não saber.

  A segunda é a fase **concluir** quando o repositório sai da observação no meio da
  execução. `mark_issues_collected/3` devolve `{:error, :not_found}` nesse caso, e casar
  só `{:ok, _}` derrubaria a coleta inteira com `MatchError` por causa de um repositório.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion.GithubWorkItems
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
    organization = organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, organization: organization, tool: tool, sync: sync(tenant, tool)}
  end

  test "o repositório coletado recebe a data, e o inacessível não", ctx do
    responder(fn query, vars ->
      cond do
        String.contains?(query, "repositories(") -> pagina_de_repositorios()
        vars[:name] == "quebrado" -> nil
        true -> pagina_de_issues()
      end
    end)

    assert {:ok, _} = coletar(ctx)

    %{"visivel" => visivel, "quebrado" => quebrado} = observados(ctx.tenant)

    assert visivel.issues_collected_at, """
    O repositório que a coleta alcançou ficou sem a data.

    Sem ela a tela não distingue "coletado e vazio" de "nunca coletado", e mostra `0` para
    os dois — ausência desenhada como quantidade.
    """

    refute quebrado.issues_collected_at, """
    O repositório que a coleta NÃO alcançou recebeu a data de coleta.

    Esta é a asserção que importa. A ausência da data é a informação: ela é o que permite
    a tela dizer "não sei" sobre um repositório que a plataforma não consultou. Gravá-la
    aqui faz a marca afirmar coleta que não houve, e afirmar é pior que não saber.
    """
  end

  test "repositório que sai da observação no meio da coleta não interrompe a fase", ctx do
    # A corrida, reproduzida onde ela acontece de verdade: o repositório desaparece da
    # observação **entre** a descoberta e a marcação. A consulta de issues é o único ponto
    # dentro da fase em que dá para intervir, e é exatamente a janela real.
    #
    # A página vem vazia de propósito: com issue dentro, gravá-la falharia na chave
    # estrangeira antes de a marcação ser alcançada, e o teste mediria outra coisa.
    responder(fn query, vars ->
      cond do
        String.contains?(query, "repositories(") ->
          pagina_de_repositorios()

        vars[:name] == "visivel" ->
          sair_da_observacao(ctx.tenant, "visivel")
          pagina_de_issues([])

        true ->
          pagina_de_issues()
      end
    end)

    assert {:ok, resultado} = coletar(ctx), """
    A fase de coleta foi interrompida porque um repositório saiu da observação.

    `mark_issues_collected/3` devolve `{:error, :not_found}` nesse caso, e casar só
    `{:ok, _}` derruba a fase inteira com `MatchError` — o defeito que já matou o LiveView
    na feature 003. A data ausente é exatamente o que se quer para quem saiu da observação:
    a plataforma não tem mais o que dizer sobre ele.
    """

    assert resultado.repositories == 2, "os dois repositórios entraram na fase"

    refute Map.has_key?(observados(ctx.tenant), "visivel"),
           "o repositório saiu da observação, e é o cenário que o teste monta"
  end

  defp sair_da_observacao(tenant, nome) do
    %{^nome => observado} = observados(tenant)

    Repo.delete_all(
      from o in "observed_repositories",
        where: o.id == type(^observado.observed_repository_id, :binary_id)
    )
  end

  defp coletar(ctx) do
    GithubWorkItems.collect(%{
      tenant: ctx.tenant,
      sync: ctx.sync,
      tool: ctx.tool,
      token: "token-de-teste"
    })
  end

  defp observados(tenant), do: Map.new(CMPO.list_observed(tenant), &{&1.name, &1})

  defp responder(fun) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: vars}, _token ->
      case fun.(query, vars) do
        nil -> {:error, :unauthorized}
        data -> {:ok, %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}}
      end
    end)
  end

  defp pagina_de_repositorios do
    %{
      "organization" => %{
        "id" => "O_1",
        "repositories" => %{
          "totalCount" => 2,
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
          "nodes" => [no_de_repositorio("visivel"), no_de_repositorio("quebrado")]
        }
      }
    }
  end

  defp no_de_repositorio(nome) do
    %{
      "id" => "R_#{nome}",
      "name" => nome,
      "nameWithOwner" => "acme/#{nome}",
      "url" => "https://github.com/acme/#{nome}",
      "description" => nil,
      "primaryLanguage" => %{"name" => "Elixir"},
      "defaultBranchRef" => %{"name" => "main"},
      "archivedAt" => nil,
      "createdAt" => "2026-01-01T00:00:00Z",
      "pushedAt" => "2026-08-01T00:00:00Z"
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

  defp pagina_de_issues do
    %{
      "repository" => %{
        "issues" => %{
          "totalCount" => 1,
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
          "nodes" => [
            %{
              "id" => "I_1",
              "number" => 1,
              "title" => "uma issue",
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
          ]
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
