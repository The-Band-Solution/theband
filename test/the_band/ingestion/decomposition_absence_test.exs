defmodule TheBand.Ingestion.DecompositionAbsenceTest do
  @moduledoc """
  A marca do vínculo ausente, de ponta a ponta pela coleta (T005, T006, T007 — issue #263).

  ## Por que não bastam os testes de unidade

  "A função marca" e "a coleta marca" são afirmações diferentes — é a L28, e é o defeito
  que esta feature corrige: `no_longer_observed_at` existia na tabela desde 2026-08-11,
  com toda a leitura pronta, e **nenhum caminho de escrita** chegava até ela.

  Por isso o estado é montado por **duas coletas** com a borda HTTP simulada — a primeira
  declarando as partes, a segunda sem uma delas —, e as asserções vão ao banco.

  ## E metade dos casos assere que **nada** aconteceu

  Marcar demais tem a mesma assinatura de marcar de menos: nada falha. Um `:nxdomain` de
  um instante já tirou 38 repositórios e 899 issues de circulação — é a L29, e aqui ela é
  a US3 inteira.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import Ecto.Query
  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.DecompositionLink
  alias TheBand.WorkItems.Schemas.RefusedLink

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    organization = organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, organization: organization, tool: tool, sync: sync(tenant, tool)}
  end

  describe "a origem deixa de declarar a parte" do
    test "o vínculo daquela parte fica ausente, e o da outra continua vigente", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)
      assert [_, _] = vinculos()
      assert Enum.all?(vinculos(), &is_nil(&1.no_longer_observed_at))

      # Segunda coleta: a origem declara **uma** parte. A outra sumiu.
      tempo_passou(30)
      responder(["um"], partes: [2])
      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 1, """
      A fase não relatou o vínculo que deixou de ser declarado.

      O número existe para que a execução consiga dizer o que deixou de ver — sem ele, uma
      coleta que apaga metade da decomposição conclui com a mesma cara de uma que não mudou
      nada.
      """

      por_filha = Map.new(vinculos(), &{&1.child_issue_id, &1})
      [ausente] = Enum.filter(vinculos(), & &1.no_longer_observed_at)

      assert map_size(por_filha) == 2, "o vínculo foi apagado — ausência marca, nunca remove"
      assert ausente.child_issue_id == id_da_issue(3)
      refute por_filha[id_da_issue(2)].no_longer_observed_at
    end

    test "a parte que volta a ser declarada volta a vigente", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      tempo_passou(30)
      responder(["um"], partes: [2])
      assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})
      assert [_] = Enum.filter(vinculos(), & &1.no_longer_observed_at)

      tempo_passou(30)
      responder(["um"], partes: [2, 3])
      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 0
      assert Enum.all?(vinculos(), &is_nil(&1.no_longer_observed_at)), "a coleta devolve vigência"
    end

    test "coleta sem mudança na origem não marca nada", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      tempo_passou(30)
      responder(["um"], partes: [2, 3])
      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 0
      assert Enum.all?(vinculos(), &is_nil(&1.no_longer_observed_at))
    end
  end

  describe "coleta que não olhou não marca" do
    test "falha transitória deixa os vínculos daquele repositório vigentes", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      tempo_passou(30)

      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
        if String.contains?(q, "repositories("),
          do: {:ok, resposta(pagina_de_repositorios(["um"]))},
          else: {:error, %{reason: :nxdomain}}
      end)

      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 0
      assert resultado.unreachable == 1

      assert Enum.all?(vinculos(), &is_nil(&1.no_longer_observed_at)), """
      Uma falha de rede de um instante apagou a decomposição observada.

      É a L29 no nível do vínculo: a leitura não aconteceu, e "não consegui olhar" não é o
      mesmo que "a origem parou de declarar". Marcar aqui afirmaria a segunda coisa tendo
      observado a primeira.
      """
    end

    test "falha permanente marca o repositório e não marca vínculo nenhum", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      tempo_passou(30)

      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
        if String.contains?(q, "repositories(") do
          {:ok, resposta(pagina_de_repositorios(["um"]))}
        else
          {:ok,
           %{
             status: 200,
             body: %{"errors" => [%{"type" => "NOT_FOUND", "message" => "sumiu"}]}
           }}
        end
      end)

      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 0
      assert [_] = Enum.filter(CMPO.list_observed(ctx.tenant), & &1.inaccessible_since)
      assert Enum.all?(vinculos(), &is_nil(&1.no_longer_observed_at))
    end

    test "o repositório inacessível não é coletado nem marcado", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      [observado] = CMPO.list_observed(ctx.tenant)
      {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, observado.observed_repository_id, "manual")

      # A origem não devolve nenhum repositório: o inacessível está fora de
      # `list_collectable/2`, e nada mais é coletado nesta execução.
      tempo_passou(30)
      responder([], partes: [])
      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 0
      assert Enum.all?(vinculos(), &is_nil(&1.no_longer_observed_at))
    end

    test "coletar o repositório da filha não marca o vínculo declarado por outro", ctx do
      # `um` declara a parte, que **mora** em `dois`. Depois só `dois` responde.
      #
      # **São duas coletas para o vínculo existir**, e não é detalhe do teste: `vincular/2`
      # roda por repositório, e quando `um` é processado a issue de `dois` ainda não foi
      # gravada — a relação vira recusa `out_of_scope`. Na coleta seguinte a filha já
      # existe, e aí o vínculo é registrado. É assim que os 57 vínculos entre repositórios
      # do dado real vieram a existir.
      responder_cruzado()
      assert {:ok, _} = coletar(ctx)
      assert [] = vinculos()

      tempo_passou(30)
      responder_cruzado()
      assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert [vinculo] = vinculos()
      refute vinculo.no_longer_observed_at

      tempo_passou(30)

      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q, variables: v}, _token ->
        cond do
          String.contains?(q, "repositories(") ->
            {:ok, resposta(pagina_de_repositorios(["dois"]))}

          v[:name] == "dois" ->
            {:ok, resposta(pagina_de_issues([no_de_issue(9, [])]))}

          true ->
            {:ok, resposta(pagina_de_issues([]))}
        end
      end)

      assert {:ok, resultado} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert resultado.decomposition_links_absent == 0

      refute recarregar(vinculo).no_longer_observed_at, """
      Coletar o repositório da **filha** marcou um vínculo que ela não declara.

      Quem declara a decomposição é o pai: as partes vêm dentro dele. São 57 os vínculos
      cuja filha está em outro repositório, e cada coleta do repositório dela os apagaria.
      """
    end

    test "a recusa registrada não é tocada pela marca", ctx do
      # A parte está fora do escopo observado: vira recusa, nunca vínculo.
      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
        if String.contains?(q, "repositories(") do
          {:ok, resposta(pagina_de_repositorios(["um"]))}
        else
          {:ok, resposta(pagina_de_issues([no_de_issue(1, [{"I_fora", 99}])]))}
        end
      end)

      assert {:ok, _} = coletar(ctx)
      assert [recusa] = Repo.all(RefusedLink)
      assert recusa.reason == "out_of_scope"

      tempo_passou(30)
      responder(["um"], partes: [])
      assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})

      assert [depois] = Repo.all(RefusedLink)

      assert depois.refused_at == recusa.refused_at, """
      A marca de ausência alcançou `refused_links`.

      Recusa **nunca foi vínculo afirmado** — a plataforma se negou a registrar a relação.
      Marcá-la como ausente afirmaria que algo deixou de existir, quando nada nunca existiu.
      """
    end
  end

  describe "o log" do
    # A suíte roda em `:warning`, e esta linha é `:info` de propósito: ela relata o que a
    # execução fez, não um problema. Baixar o nível aqui é o que torna a linha observável
    # sem promovê-la a aviso — e o nível volta ao que era ao fim de cada caso.
    setup do
      nivel = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: nivel) end)
      :ok
    end

    test "nomeia o repositório e o número quando marca", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      tempo_passou(30)
      responder(["um"], partes: [2])

      log =
        capture_log(fn ->
          assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})
        end)

      assert log =~ "um: 1 vínculo(s) de decomposição que a origem não declara mais"
    end

    test "cala quando não marcou nada", ctx do
      responder(["um"], partes: [2, 3])
      assert {:ok, _} = coletar(ctx)

      tempo_passou(30)
      responder(["um"], partes: [2, 3])

      log =
        capture_log(fn ->
          assert {:ok, _} = coletar(%{ctx | sync: sync(ctx.tenant, ctx.tool)})
        end)

      refute log =~ "vínculo(s) de decomposição", """
      A coleta que não marcou nada escreveu a linha assim mesmo.

      É a mesma razão pela qual a tela esconde "0 unreachable": a linha que aparece em toda
      execução treina quem lê a ignorá-la, e é justamente ela que importa quando não é zero.
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

  defp vinculos, do: Repo.all(from(l in DecompositionLink, order_by: l.child_issue_id))

  # Duas coletas seguidas na suíte caem no **mesmo segundo**, e o corte é estrito: nada
  # ficaria anterior ao início da segunda execução. Recuar o carimbo do que a primeira
  # coleta gravou é o que separa "duas coletas" de "duas chamadas no mesmo instante" — no
  # dado real, entre uma e outra passam horas.
  defp tempo_passou(minutos) do
    antes = DateTime.add(DateTime.utc_now(:second), -minutos * 60, :second)

    Repo.update_all(from(l in DecompositionLink), set: [last_observed_at: antes])
    Repo.update_all(from(i in CollectedIssue), set: [last_observed_at: antes])
  end

  defp recarregar(%DecompositionLink{id: id}), do: Repo.get!(DecompositionLink, id)

  defp id_da_issue(numero) do
    Repo.one!(
      from(i in CollectedIssue,
        where: i.external_id == ^"I_#{numero}",
        select: i.id
      )
    )
  end

  # O repositório `um` tem a issue 1, cujas partes são as issues informadas. As partes
  # existem no mesmo repositório, como sub-issues declaradas pelo pai.
  defp responder(nomes, partes: numeros) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q}, _token ->
      if String.contains?(q, "repositories(") do
        {:ok, resposta(pagina_de_repositorios(nomes))}
      else
        filhas = Enum.map(numeros, &{"I_#{&1}", &1})
        nodes = [no_de_issue(1, filhas)] ++ Enum.map(numeros, &no_de_issue(&1, []))
        {:ok, resposta(pagina_de_issues(nodes))}
      end
    end)
  end

  # `um` declara a parte, e ela mora em `dois` — é a forma dos 57 vínculos que cruzam
  # repositório no dado real.
  defp responder_cruzado do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: q, variables: v}, _token ->
      cond do
        String.contains?(q, "repositories(") ->
          {:ok, resposta(pagina_de_repositorios(["um", "dois"]))}

        v[:name] == "um" ->
          {:ok, resposta(pagina_de_issues([no_de_issue(1, [{"I_9", 9}])]))}

        true ->
          {:ok, resposta(pagina_de_issues([no_de_issue(9, [])]))}
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
      # Push no futuro para o repositório ser **sempre** percorrido: a partir da feature
      # 020, um `pushedAt` anterior à última revisão faz a coleta pular o repositório — e
      # estes casos coletam duas vezes de propósito, para medir marca e contagem.
      #
      # O pulo tem teste próprio em `pular_sem_atividade_test.exs`.
      "pushedAt" => "2030-01-01T00:00:00Z"
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
