defmodule TheBand.Ingestion.AutorObservadoTest do
  @moduledoc """
  Quem escreveu a issue passa a ser observado (feature 015, T002 a T005).

  ## O caso que a análise achou, e que quebraria em silêncio

  O mapa login → pessoa nasce **uma vez**, antes do primeiro repositório. A coleta passou a criar
  pessoas — e sem fiar o `ctx` entre os repositórios, quem nascesse no terceiro não existiria no mapa
  ao coletar o quarto. As issues dela ficariam sem vínculo **em alguns repositórios e não em
  outros**, na mesma execução, sem erro nenhum.

  Por isso o caso central aqui tem **dois** repositórios.

  ## E o que não pode acontecer

  Bot não vira pessoa, e ninguém entra em equipe por ter escrito issue: "quem é da organização" e
  "quem trabalhou nela" são perguntas diferentes.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.WorkItems.Schemas.CollectedIssue

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, tool: tool}
  end

  describe "a pessoa nasce da coleta" do
    test "o autor que não é membro passa a existir, com identidade da origem", ctx do
      responder(%{"um" => [issue(1, autor("U_sofia", "sofialctv", "Sofia"))]})

      assert {:ok, _} = coletar(ctx)

      assert [pessoa] = pessoas(ctx.tenant, "sofialctv")

      assert pessoa.external_id == "U_sofia", """
      A pessoa foi criada sem o identificador da origem.

      Chavear identidade pelo login é a L25 aplicada a pessoa: o GitHub deixa renomear, e o login
      liberado pode ser tomado por outra conta.
      """

      assert pessoa.account_type == "person"
      assert pessoa.name == "Sofia"
    end

    test "a issue grava o vínculo na mesma execução", ctx do
      responder(%{"um" => [issue(1, autor("U_sofia", "sofialctv", "Sofia"))]})

      assert {:ok, _} = coletar(ctx)

      assert %{author_person_id: id, author_login: "sofialctv"} = Repo.one(CollectedIssue)
      assert id, "a pessoa existe e a issue ficou sem vínculo — é a ordem entre criar e gravar"
    end

    test "quem nasce no primeiro repositório é resolvido no segundo", ctx do
      responder(%{
        "um" => [issue(1, autor("U_sofia", "sofialctv", "Sofia"))],
        "dois" => [issue(2, autor("U_sofia", "sofialctv", "Sofia"))]
      })

      assert {:ok, _} = coletar(ctx)

      vinculos =
        Repo.all(CollectedIssue) |> Enum.map(& &1.author_person_id) |> Enum.reject(&is_nil/1)

      assert length(vinculos) == 2, """
      A pessoa nasceu no primeiro repositório e a issue do segundo ficou sem vínculo.

      O mapa login → pessoa é montado uma vez, antes de todos os repositórios. Sem fiá-lo entre
      eles, a coleta resolve em alguns e não em outros — na mesma execução, e sem erro.
      """

      assert Enum.uniq(vinculos) |> length() == 1, "a mesma pessoa virou duas"
    end

    test "o designado também", ctx do
      no = issue(1, autor("U_sofia", "sofialctv", "Sofia"))
      no = put_in(no["assignees"], %{"nodes" => [conta("U_luiz", "LuizRojas", "Luiz")]})
      responder(%{"um" => [no]})

      assert {:ok, _} = coletar(ctx)
      assert [_] = pessoas(ctx.tenant, "LuizRojas")
    end
  end

  describe "o que não vira pessoa" do
    test "bot não vira pessoa", ctx do
      bot = %{"__typename" => "Bot", "id" => "B_1", "login" => "dependabot[bot]"}
      responder(%{"um" => [issue(1, bot)]})

      assert {:ok, _} = coletar(ctx)

      assert pessoas(ctx.tenant, "dependabot[bot]") == [], """
      Um bot virou pessoa.

      O mapeamento declara a limitação — "contas do tipo Bot e App não são pessoas" —, e criar bots
      como gente contaminaria toda medida que conta pessoas.
      """
    end

    test "autor sem identidade continua sem pessoa", ctx do
      # Conta apagada na origem: o nó vem sem `id`.
      sem_id = %{"__typename" => "User", "login" => "conta-apagada"}
      responder(%{"um" => [issue(1, sem_id)]})

      assert {:ok, _} = coletar(ctx)
      assert pessoas(ctx.tenant, "conta-apagada") == []
      assert %{author_login: "conta-apagada", author_person_id: nil} = Repo.one(CollectedIssue)
    end
  end

  describe "trabalhar não é pertencer" do
    test "ninguém entra em equipe por ter escrito issue", ctx do
      responder(%{"um" => [issue(1, autor("U_sofia", "sofialctv", "Sofia"))]})

      evidencias_antes = Repo.aggregate(EO.Schemas.TeamMembershipEvidence, :count)

      assert {:ok, _} = coletar(ctx)

      assert Repo.aggregate(EO.Schemas.TeamMembershipEvidence, :count) == evidencias_antes, """
      A coleta criou evidência de participação em equipe.

      "Quem é da organização" e "quem trabalhou nela" são perguntas diferentes. Somar as duas faria
      a primeira responder com gente que ninguém admitiu — só escreveu issue.
      """
    end
  end

  describe "a idempotência" do
    test "coletar duas vezes não cria pessoa de novo", ctx do
      responder(%{"um" => [issue(1, autor("U_sofia", "sofialctv", "Sofia"))]})
      assert {:ok, _} = coletar(ctx)

      [antes] = pessoas(ctx.tenant, "sofialctv")

      responder(%{"um" => [issue(1, autor("U_sofia", "sofialctv", "Sofia"))]})
      assert {:ok, _} = coletar(ctx)

      assert [depois] = pessoas(ctx.tenant, "sofialctv")
      assert depois.id == antes.id
      assert depois.collected_at == antes.collected_at, "a primeira observação foi reescrita"
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

  defp pessoas(tenant, login) do
    import Ecto.Query

    Repo.all(from p in EO.Schemas.Person, where: p.tenant_id == ^tenant.id and p.login == ^login)
  end

  defp conta(id, login, nome),
    do: %{"__typename" => "User", "id" => id, "login" => login, "name" => nome}

  defp autor(id, login, nome), do: conta(id, login, nome)

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

  defp responder(por_repositorio) do
    nomes = Map.keys(por_repositorio)

    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q, variables: v}, _token ->
      if String.contains?(q, "repositories(") do
        {:ok, resposta(pagina_de_repositorios(nomes))}
      else
        {:ok, resposta(pagina_de_issues(Map.get(por_repositorio, v[:name], [])))}
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
