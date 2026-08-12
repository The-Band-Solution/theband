defmodule TheBandWeb.DecompositionAbsenceScreenTest do
  @moduledoc """
  A coluna `part of` recebendo o vínculo ausente **pela coleta** (T008 — issue #263).

  ## Por que este arquivo existe, se `issue_parent_test.exs` já assere o rótulo

  Ele monta o estado escrevendo `no_longer_observed_at` direto no banco — e tinha de ser
  assim, porque quando a feature 011 foi escrita **nenhum caminho do código produzia esse
  estado**. Era leitura pronta para um dado que nunca chegava.

  Aqui o estado vem de **duas coletas**, com a borda HTTP simulada: a segunda deixa de
  declarar uma parte. É a diferença entre "a tela sabe exibir" e "a tela exibe o que a
  plataforma produz", que é a L28 aplicada à feature inteira.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Mox
  import Phoenix.LiveViewTest

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.DecompositionLink

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)

    %{conn: log_in(conn, user), tenant: tenant, tool: tool}
  end

  test "a linha diz que o vínculo acabou, e não conta como pai vigente", ctx do
    # Primeira coleta: a issue 1 declara as partes 2 e 3.
    responder(partes: [2, 3])
    assert {:ok, _} = coletar(ctx)

    # Segunda: a origem declara só a 2. O vínculo com a 3 deixou de existir.
    tempo_passou(30)
    responder(partes: [2])
    assert {:ok, resultado} = coletar(ctx)
    assert resultado.decomposition_links_absent == 1

    ausente = celula_de(ctx, 3)
    vigente = celula_de(ctx, 2)

    assert ausente =~ "absent: this link existed and is not present now", """
    A coleta marcou o vínculo, e a lista continua apresentando a decomposição como atual.

    O dado chegou ao estado que a tela sabe exibir desde a feature 011 — se o texto não
    aparece, o que quebrou foi a ligação entre os dois, e não a marca.
    """

    assert ausente =~ "no longer observed since"
    refute vigente =~ "absent: this link"
  end

  test "um pai vigente e um vínculo que a coleta marcou é UM pai, não dois", ctx do
    # A parte 3 tem dois pais: a issue 1 e a issue 4.
    responder_dois_pais()
    assert {:ok, _} = coletar(ctx)
    assert celula_de(ctx, 3) =~ "2 parents at the source"

    # Agora a issue 4 deixa de declarar a parte 3. Sobra um pai vigente.
    tempo_passou(30)
    responder(partes: [2, 3])
    assert {:ok, _} = coletar(ctx)

    celula = celula_de(ctx, 3)

    refute celula =~ "2 parents at the source", """
    A tela contou como dois pais um vigente mais um vínculo que a origem largou.

    Dizer "2 parents" aqui afirmaria uma decomposição que a origem não declara mais — e o
    número viria de uma contagem que ninguém suspeitaria estar errada.
    """

    assert celula =~ "absent: this link existed and is not present now"
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

  defp abrir(ctx) do
    [observado] = CMPO.list_observed(ctx.tenant)
    live(ctx.conn, ~p"/work/repositories/#{observado.observed_repository_id}")
  end

  defp celula_de(ctx, numero) do
    {:ok, _live, html} = abrir(ctx)

    linha =
      html
      |> then(&Regex.scan(~r{<tr>(?:(?!</tr>).)*?</tr>}s, &1))
      |> Enum.map(&hd/1)
      |> Enum.find(&(&1 =~ ~r{data-label="\#"[^>]*>\s*#{numero}\s*<}))

    case linha && Regex.run(~r{data-label="part of"(.*?)</td>}s, linha) do
      [_, celula] -> celula
      _ -> flunk("não achei a célula `part of` da issue ##{numero}")
    end
  end

  # Duas coletas seguidas na suíte caem no mesmo segundo, e o corte é estrito. No dado real
  # passam horas entre uma e outra.
  defp tempo_passou(minutos) do
    antes = DateTime.add(DateTime.utc_now(:second), -minutos * 60, :second)

    Repo.update_all(from(l in DecompositionLink), set: [last_observed_at: antes])
    Repo.update_all(from(i in CollectedIssue), set: [last_observed_at: antes])
  end

  defp responder(partes: numeros) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
      if String.contains?(q, "repositories(") do
        {:ok, resposta(pagina_de_repositorios(["um"]))}
      else
        filhas = Enum.map(numeros, &{"I_#{&1}", &1})

        nodes =
          [no_de_issue(1, filhas), no_de_issue(4, [])] ++ Enum.map(numeros, &no_de_issue(&1, []))

        {:ok, resposta(pagina_de_issues(nodes))}
      end
    end)
  end

  defp responder_dois_pais do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
      if String.contains?(q, "repositories(") do
        {:ok, resposta(pagina_de_repositorios(["um"]))}
      else
        nodes = [
          no_de_issue(1, [{"I_2", 2}, {"I_3", 3}]),
          no_de_issue(4, [{"I_3", 3}]),
          no_de_issue(2, []),
          no_de_issue(3, [])
        ]

        {:ok, resposta(pagina_de_issues(nodes))}
      end
    end)
  end

  defp resposta(data),
    do: %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}

  defp pagina_de_repositorios(nomes) do
    %{
      "organization" => %{
        "id" => "O_1",
        "repositories" => %{
          "totalCount" => length(nomes),
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
          "nodes" => Enum.map(nomes, &no_de_repositorio/1)
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
      "primaryLanguage" => nil,
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

  defp no_de_issue(numero, partes) do
    %{
      "id" => "I_#{numero}",
      "number" => numero,
      "title" => "issue ##{numero}",
      "bodyText" => "",
      "state" => "OPEN",
      "issueType" => %{"id" => "IT_Feature", "name" => "Feature"},
      "createdAt" => "2026-08-01T00:00:00Z",
      "updatedAt" => "2026-08-02T00:00:00Z",
      "closedAt" => nil,
      "author" => nil,
      "assignees" => %{"nodes" => []},
      "labels" => %{"nodes" => []},
      "subIssues" => %{
        "totalCount" => length(partes),
        "nodes" => Enum.map(partes, fn {id, n} -> %{"id" => id, "number" => n} end)
      },
      "parent" => nil
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
