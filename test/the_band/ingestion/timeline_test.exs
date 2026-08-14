defmodule TheBand.Ingestion.TimelineTest do
  @moduledoc """
  A coleta da timeline, e o que ela recusa descartar (T005, T006, T007, T008).

  ## A asserção que importa neste arquivo

  Não é "os eventos apareceram" — é **a soma**. Cinco eventos recebidos produzem cinco
  linhas, contando juntos os que a rede nomeia e os que ela não nomeia.

  A diferença é a SC-003, e ela existe porque *"os eventos apareceram"* passaria igual
  se metade tivesse sido descartada: a asserção olharia para o que sobrou e o
  encontraria. É o defeito da L57.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  # Cinco eventos: três que a rede nomeia, dois que ela não nomeia. A proporção é o
  # ponto — se a coleta descartasse os sem conceito, sobrariam três, e uma asserção
  # sobre "apareceram eventos" continuaria passando.
  @eventos [
    %{
      "__typename" => "AssignedEvent",
      "createdAt" => "2026-08-10T09:00:00Z",
      "actor" => %{"login" => "alguem"}
    },
    %{
      "__typename" => "ProjectV2ItemStatusChangedEvent",
      "createdAt" => "2026-08-12T20:54:47Z",
      "actor" => %{"login" => "github-project-automation"},
      "previousStatus" => "",
      "status" => "Done"
    },
    %{
      "__typename" => "ClosedEvent",
      "createdAt" => "2026-08-14T13:01:06Z",
      "actor" => %{"login" => "alguem"}
    },
    %{
      "__typename" => "LabeledEvent",
      "createdAt" => "2026-08-11T10:00:00Z",
      "actor" => %{"login" => "alguem"},
      "label" => %{"name" => "bug"}
    },
    %{
      "__typename" => "CrossReferencedEvent",
      "createdAt" => "2026-08-11T11:00:00Z",
      "actor" => %{"login" => "alguem"}
    }
  ]

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    organization = organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, organization: organization, tool: tool, sync: sync(tenant, tool)}
  end

  describe "nada é descartado" do
    test "a soma dos classificados e dos sem conceito é o total recebido", ctx do
      responder_com(@eventos)
      assert {:ok, _} = coletar(ctx)

      atividades = Repo.all(Activity)

      assert length(atividades) == length(@eventos), """
      A coleta recebeu #{length(@eventos)} eventos e gravou #{length(atividades)}.

      É a SC-003, e a asserção é a SOMA — não a presença. Descartar os tipos que a rede
      não nomeia deixaria os três classificados na tabela, e qualquer asserção sobre
      "os eventos foram gravados" passaria com dois eventos perdidos e nenhum erro.
      """

      com_conceito = Enum.count(atividades, & &1.concept_id)
      sem_conceito = Enum.count(atividades, &is_nil(&1.concept_id))

      assert com_conceito + sem_conceito == length(@eventos)
      assert sem_conceito == 2, "LabeledEvent e CrossReferencedEvent não têm conceito na rede"
    end

    test "o tipo é gravado como a origem o nomeia", ctx do
      responder_com(@eventos)
      assert {:ok, _} = coletar(ctx)

      tipos = Activity |> Repo.all() |> Enum.map(& &1.activity_type) |> Enum.sort()

      assert tipos == Enum.sort(Enum.map(@eventos, & &1["__typename"])), """
      Os tipos gravados não batem com os que a origem mandou.

      O tipo é dado da origem, e traduzi-lo para vocabulário próprio esconderia o que ela
      disse — a proveniência exige o oposto.
      """
    end

    test "a página que não cobre a issue grita", ctx do
      # O caso mais caro que esta feature tem: a origem tem mais eventos do que a página
      # trouxe. A soma da SC-003 **bateria** — porque ela compara com o que chegou —, e a
      # issue ficaria com metade da história sem nada indicar.
      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query}, _token ->
        data =
          if String.contains?(query, "repositories(") do
            repositorios()
          else
            no = no_de_issue(@eventos)

            truncado =
              put_in(no, ["timelineItems"], %{
                "totalCount" => 200,
                "pageInfo" => %{"hasNextPage" => true},
                "nodes" => @eventos
              })

            issues([truncado])
          end

        {:ok, %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}}
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, _} = coletar(ctx)
        end)

      assert log =~ "timeline truncada", """
      A coleta truncou a timeline em silêncio.

      A contagem de linhas gravadas bateria com a de eventos recebidos, e a asserção da
      SC-003 passaria: ela compara com o que CHEGOU. O que falta é a comparação com o que
      a origem disse existir — `totalCount` —, e sem o aviso ninguém descobre.
      """

      assert log =~ "de 200 itens", "o aviso diz quanto faltou, e não só que faltou"
    end

    test "recoletar não duplica", ctx do
      responder_com(@eventos)
      assert {:ok, _} = coletar(ctx)
      primeira = Repo.aggregate(Activity, :count)

      assert {:ok, _} = coletar(ctx)

      assert Repo.aggregate(Activity, :count) == primeira, """
      A segunda coleta duplicou as ocorrências.

      O `internal_id` sai do critério de identidade da ontologia, e o índice único o
      garante. É a FR-003.
      """
    end
  end

  describe "quem executou" do
    test "o robô é gravado com login e sem pessoa", ctx do
      responder_com(@eventos)
      assert {:ok, _} = coletar(ctx)

      robo = Repo.get_by(Activity, performer_login: "github-project-automation")

      assert robo, """
      A movimentação de automação não foi gravada.

      160 das 357 movimentações medidas em 2026-08-14 são de robô. Omiti-las daria uma
      história falsa da issue — e o `ap02` depende justamente de distinguir as duas.
      """

      assert is_nil(robo.performer_id), """
      A coleta criou uma pessoa a partir de um ator de timeline.

      Criar sem proveniência é o que a plataforma recusa, e `github-project-automation`
      não é pessoa nenhuma.
      """
    end

    test "o payload da origem é preservado", ctx do
      responder_com(@eventos)
      assert {:ok, _} = coletar(ctx)

      movimentacao = Repo.get_by(Activity, activity_type: "ProjectV2ItemStatusChangedEvent")

      assert movimentacao.payload["status"] == "Done"

      assert movimentacao.payload["previousStatus"] == "", """
      O estado anterior vazio virou nulo.

      Medido em 2026-08-14: `previousStatus` vem VAZIO na primeira transição, e não nulo.
      Achatar os dois faria "nunca esteve em estado nenhum" virar "não sei qual era".
      """
    end
  end

  describe "o custo" do
    test "repositório sem push desde a revisão não tem timeline pedida", ctx do
      # A primeira coleta pede a timeline, e deve mesmo: o repositório nunca foi revisto.
      responder_com(@eventos)
      {:ok, _} = coletar(ctx)
      assert Repo.aggregate(Activity, :count) == length(@eventos)

      # A segunda encontra `issues_collected_at` posterior ao `pushedAt`, e a borda agora
      # **reprova** qualquer consulta de issues.
      #
      # A asserção é sobre o PEDIDO, e não sobre o resultado: uma coleta que consulta e
      # recebe vazio deixa o banco idêntico à que não consultou, e só o custo distingue as
      # duas. Verificar a tabela depois não provaria nada.
      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query}, _token ->
        if String.contains?(query, "repositories(") do
          {:ok,
           %{status: 200, body: %{"data" => Map.put(repositorios(), "rateLimit", @rate_limit)}}}
        else
          flunk("""
          A timeline foi pedida para um repositório sem push desde a última revisão.

          FR-011: repositório que a coleta pula não tem timeline consultada. A janela da
          feature 020 pulou 106 de 121 repositórios medidos, e pedir timeline neles
          desfaria a economia inteira.
          """)
        end
      end)

      {:ok, resultado} = coletar(ctx)

      assert resultado.skipped[:sem_push_desde_a_revisao] == 1
    end
  end

  describe "a leitura pela fronteira" do
    test "a sequência da issue sai em ordem cronológica", ctx do
      responder_com(@eventos)
      assert {:ok, _} = coletar(ctx)

      [issue_id] = Activity |> Repo.all() |> Enum.map(& &1.subject_id) |> Enum.uniq()

      instantes =
        ctx.tenant
        |> SPO.list_activities("issue", issue_id)
        |> Enum.map(& &1.occurred_at)

      assert instantes == Enum.sort(instantes, DateTime)
      assert length(instantes) == length(@eventos)
    end
  end

  # ------------------------------------------------------------------ a borda simulada

  defp coletar(ctx) do
    GithubWorkItems.collect(%{
      tenant: ctx.tenant,
      sync: ctx.sync,
      tool: ctx.tool,
      token: "token-de-teste"
    })
  end

  defp responder_com(eventos) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: _vars}, _token ->
      data =
        if String.contains?(query, "repositories("),
          do: repositorios(),
          else: issues([no_de_issue(eventos)])

      {:ok, %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}}
    end)
  end

  defp repositorios do
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
  end

  defp issues(nodes) do
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

  defp no_de_issue(eventos) do
    %{
      "id" => "I_1",
      "number" => 1,
      "title" => "uma issue",
      "bodyText" => "",
      "state" => "CLOSED",
      "stateReason" => "COMPLETED",
      "issueType" => %{"id" => "IT_Task", "name" => "Task"},
      "createdAt" => "2026-08-01T00:00:00Z",
      "updatedAt" => "2026-08-14T00:00:00Z",
      "closedAt" => "2026-08-14T13:01:06Z",
      "author" => nil,
      "assignees" => %{"nodes" => []},
      "labels" => %{"nodes" => []},
      "milestone" => nil,
      "projectItems" => %{"nodes" => []},
      "comments" => %{"totalCount" => 0},
      "reactions" => %{"totalCount" => 0},
      "repository" => %{"id" => "R_um", "nameWithOwner" => "acme/um"},
      "subIssues" => %{"totalCount" => 0, "nodes" => []},
      "parent" => nil,
      "timelineItems" => %{
        "totalCount" => length(eventos),
        "pageInfo" => %{"hasNextPage" => false},
        "nodes" => eventos
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
