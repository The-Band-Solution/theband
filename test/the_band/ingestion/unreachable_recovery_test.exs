defmodule TheBand.Ingestion.UnreachableRecoveryTest do
  @moduledoc """
  A cura, de ponta a ponta (T003, T006, T007, T008).

  ## Por que este arquivo existe, e não bastam os testes de unidade

  "A função classifica" e "o repositório não é marcado" são afirmações diferentes — é a L28. O
  defeito da issue #213 era exatamente um caminho que **existia na função e não era alcançado**:
  `clear_inaccessible/2` era chamada quando a paginação concluía, e o repositório marcado era
  filtrado antes de chegar lá.

  Por isso as asserções aqui vão **ao banco**, e a borda HTTP é simulada com o payload real.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  # A mensagem está gravada no banco de desenvolvimento, e foi ela que criou a 39ª marca.
  @falha_interna %{
    "message" =>
      "Something went wrong while executing your query on 2026-08-12T12:32:30Z. " <>
        "Please include `6D2F:110188:1CD8DB0:1D79ED0:6A7C67D3` when reporting this issue."
  }

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    organization = organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, organization: organization, tool: tool, sync: sync(tenant, tool)}
  end

  describe "a falha do momento não marca" do
    test "o payload real da origem deixa zero repositórios marcados", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["visivel"])},
          else: {:erros, [@falha_interna]}
      end)

      assert {:ok, resultado} = coletar(ctx)

      marcados = Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since)

      assert marcados == [], """
      A falha interna da origem marcou o repositório como inacessível.

      É o defeito #214, com o payload que o produziu: a mensagem pede para reportar o incidente
      com um identificador, e mesmo assim o repositório saía de toda coleta seguinte.
      """

      assert resultado.unreachable == 1, """
      O repositório não foi alcançado nesta execução, e o relatório precisa dizer isso mesmo sem
      marcar: não marcar não é o mesmo que ter alcançado.
      """
    end

    test "não encontrado marca", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["visivel"])},
          else:
            {:erros, [%{"type" => "NOT_FOUND", "message" => "Could not resolve to a Repository"}]}
      end)

      assert {:ok, _} = coletar(ctx)

      assert [marcado] = Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since)
      assert marcado.inaccessible_reason =~ "Could not resolve"
    end
  end

  describe "a cura" do
    test "o repositório marcado é tentado, a marca sai e as issues entram", ctx do
      # Primeira coleta: a origem falha de forma permanente, então o repositório é marcado.
      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["visivel"])},
          else: {:erros, [%{"type" => "NOT_FOUND", "message" => "gone"}]}
      end)

      assert {:ok, _} = coletar(ctx)
      assert [marcado] = Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since)
      desde = marcado.inaccessible_since

      # Segunda coleta: a origem responde. Antes desta feature, o repositório era filtrado antes
      # da fase de issues e a marca ficava para sempre.
      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["visivel"])},
          else: {:ok, pagina_de_issues([issue_node()])}
      end)

      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since) == [], """
      A marca sobreviveu a uma coleta que alcançou a origem.

      É o defeito #213: o repositório marcado era filtrado antes da fase que limparia a marca, e
      a cura declarada — "alcançou, limpa" — nunca era alcançada. Duas coletas concluíram no dado
      real sem limpar nenhuma das 39.
      """

      assert resultado.issues == 1, """
      A marca saiu e nada foi coletado. As duas coisas precisam acontecer na mesma execução —
      limpar a marca sem coletar deixaria o repositório "acessível e vazio", que é falso.
      """

      assert resultado.unreachable == 0
      assert desde
    end

    test "falhando de novo, a data de início não se move", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["visivel"])},
          else: {:erros, [%{"type" => "NOT_FOUND", "message" => "primeira falha"}]}
      end)

      assert {:ok, _} = coletar(ctx)
      assert [primeiro] = Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since)

      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["visivel"])},
          else: {:erros, [%{"type" => "NOT_FOUND", "message" => "segunda falha"}]}
      end)

      assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})
      assert [segundo] = Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since)

      assert segundo.inaccessible_since == primeiro.inaccessible_since
      assert segundo.inaccessible_reason =~ "segunda falha"
    end
  end

  describe "o excluído não é tentado" do
    test "nenhuma requisição é feita por ele", ctx do
      user = user_fixture(ctx.tenant)
      {:ok, pid} = Agent.start_link(fn -> [] end)

      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q, variables: v}, _token ->
        Agent.update(pid, &[v[:name] | &1])

        if String.contains?(q, "repositories("),
          do: {:ok, resposta(pagina_de_repositorios(["visivel", "excluido"]))},
          else: {:ok, resposta(pagina_de_issues([]))}
      end)

      # Primeira coleta: descobre os dois e observa.
      assert {:ok, _} = coletar(ctx)

      excluido = Enum.find(CMPO.list_observed(ctx.tenant), &(&1.name == "excluido"))

      {:ok, _} =
        CMPO.exclude_from_observation(ctx.tenant, excluido.observed_repository_id, user.id)

      {:ok, _} =
        CMPO.mark_inaccessible(ctx.tenant, excluido.observed_repository_id, "e inacessível")

      Agent.update(pid, fn _ -> [] end)
      assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      consultados = Agent.get(pid, & &1)

      refute "excluido" in consultados, """
      O repositório excluído pelo tenant recebeu requisição.

      Ele está **também** marcado como inacessível, e a exclusão vence: é decisão de alguém, e a
      plataforma não a desfaz — FR-004. Tentar de novo aqui gastaria requisição e desfaria a
      decisão dele.
      """
    end
  end

  describe "concluir com tudo falhando" do
    test "a coleta conclui e conta os não alcançados", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "repositories("),
          do: {:ok, pagina_de_repositorios(["um", "dois", "tres"])},
          else: {:erros, [@falha_interna]}
      end)

      assert {:ok, resultado} = coletar(ctx), """
      A coleta foi interrompida porque os repositórios falharam.

      Uma falha por repositório não pode derrubar os outros — FR-005. Com o inacessível de volta
      na lista, o número de tentativas cresce, e a tolerância passa a valer mais.
      """

      assert resultado.unreachable == 3
      assert Ingestion.reload(ctx.sync).repositories_unreachable == 3
    end

    test "o número é gravado a cada falha, não no fim", ctx do
      # A terceira consulta de issues levanta, simulando interrupção no meio da fase. As duas
      # primeiras falhas precisam ter sido contadas **antes** disso.
      {:ok, pid} = Agent.start_link(fn -> 0 end)

      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
        if String.contains?(q, "repositories(") do
          {:ok, resposta(pagina_de_repositorios(["um", "dois", "tres"]))}
        else
          n = Agent.get_and_update(pid, &{&1 + 1, &1 + 1})

          if n >= 3,
            do: raise("interrompida no meio da fase"),
            else: {:error, %{reason: :nxdomain}}
        end
      end)

      assert_raise RuntimeError, fn -> coletar(ctx) end

      assert Ingestion.reload(ctx.sync).repositories_unreachable == 2, """
      A execução foi interrompida e o número ficou em zero — ou não registrou o que já havia
      falhado.

      Gravar só no fim da fase faz uma coleta interrompida afirmar que **tudo** foi alcançado, e
      a interrupção é justamente quando alguém vai olhar o registro para entender o que
      aconteceu. É a mesma regra do checkpoint: registrar depois de processar, por item.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp coletar(ctx) do
    GithubWorkItems.collect(%{
      tenant: ctx.tenant,
      sync: ctx.sync,
      tool: ctx.tool,
      token: "token-de-teste"
    })
  end

  defp responder(fun) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: vars}, _token ->
      case fun.(query, vars) do
        {:ok, data} -> {:ok, resposta(data)}
        {:erros, errors} -> {:ok, %{status: 200, body: %{"errors" => errors}}}
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

  defp issue_node do
    %{
      "id" => "I_1",
      "number" => 1,
      "title" => "uma issue",
      "bodyText" => "",
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

  # Encerra a execução anterior antes de abrir outra: o índice único parcial permite **uma**
  # `running` por ferramenta, e é a defesa que a feature 008 preservou. Abrir a segunda sem
  # encerrar a primeira falharia pela restrição — e não é o que estes testes medem.
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
