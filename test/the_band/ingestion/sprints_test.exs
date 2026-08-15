defmodule TheBand.Ingestion.SprintsTest do
  @moduledoc """
  A coleta das caixas de tempo e a associação das issues (T008, T009, T010).

  ## As três asserções que carregam este arquivo

  1. **a soma dos vínculos é maior que o total de itens** — a sobreposição medida no
     DevOps não pode ser achatada;
  2. **a borda reprova se os itens forem pedidos** para quadro sem campo de iteração —
     "não trouxe caixas" não prova que não pediu;
  3. **a duração gravada é a da iteração**, e não a configurada no campo.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.WorkItemsFixtures

  alias TheBand.Ingestion.GithubSprints
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Ontology.Continuum.SRO.Schemas.SprintIssue
  alias TheBand.Ontology.KnowledgeBase

  setup :verify_on_exit!

  @rate_limit %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)

    ctx = %{
      tenant: tenant,
      tool: cenario.tool,
      sync: sync(tenant, cenario.tool),
      token: "token-de-teste",
      started_at: DateTime.utc_now(:second)
    }

    %{ctx: ctx, tenant: tenant, cenario: cenario}
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

  # O quadro DevOps, com os dois campos que a medida de 2026-08-15 encontrou.
  defp quadro_com_dois_campos do
    %{
      "organization" => %{
        "projectsV2" => %{
          "totalCount" => 1,
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
          "nodes" => [
            %{
              "number" => 31,
              "title" => "DevOps",
              "fields" => %{
                "nodes" => [
                  %{"__typename" => "ProjectV2Field", "name" => "Status"},
                  %{
                    "__typename" => "ProjectV2IterationField",
                    "id" => "PVTIF_sprint",
                    "name" => "Sprint",
                    "configuration" => %{
                      "duration" => 14,
                      "iterations" => [
                        %{
                          "id" => "i40",
                          "title" => "Sprint 40",
                          "startDate" => "2026-07-27",
                          "duration" => 14
                        }
                      ],
                      # `Sprint 10` com 3 dias num campo de 14 — o caso medido.
                      "completedIterations" => [
                        %{
                          "id" => "i10",
                          "title" => "Sprint 10",
                          "startDate" => "2025-05-28",
                          "duration" => 3
                        }
                      ]
                    }
                  },
                  %{
                    "__typename" => "ProjectV2IterationField",
                    "id" => "PVTIF_quarter",
                    "name" => "Quarter",
                    "configuration" => %{
                      "duration" => 90,
                      "iterations" => [
                        %{
                          "id" => "q5",
                          "title" => "Quarter 5",
                          "startDate" => "2026-04-01",
                          "duration" => 90
                        }
                      ],
                      "completedIterations" => []
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }
  end

  defp quadro_sem_iteracao do
    %{
      "organization" => %{
        "projectsV2" => %{
          "totalCount" => 1,
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
          "nodes" => [
            %{
              "number" => 46,
              "title" => "Conecta Fapes - Teste",
              "fields" => %{"nodes" => [%{"__typename" => "ProjectV2Field", "name" => "Status"}]}
            }
          ]
        }
      }
    }
  end

  defp itens(nodes) do
    %{
      "organization" => %{
        "projectV2" => %{
          "items" => %{
            "totalCount" => length(nodes),
            "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
            "nodes" => nodes
          }
        }
      }
    }
  end

  defp item(external_id, valores) do
    %{
      "content" => %{"id" => external_id},
      "fieldValues" => %{
        "nodes" =>
          Enum.map(valores, fn {campo, titulo} ->
            %{"title" => titulo, "field" => %{"name" => campo}}
          end)
      }
    }
  end

  defp responder(fun) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: vars}, _token ->
      case fun.(query, vars) do
        nil -> {:error, :unauthorized}
        data -> {:ok, %{status: 200, body: %{"data" => Map.put(data, "rateLimit", @rate_limit)}}}
      end
    end)
  end

  describe "as caixas de tempo" do
    test "Quarter entra junto com Sprint, e o nome do campo fica", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"), do: quadro_com_dois_campos(), else: itens([])
      end)

      {:ok, resumo} = GithubSprints.collect(ctx.ctx)

      assert resumo.sprints == 3
      caixas = SRO.list_sprints(ctx.tenant, board_number: 31)

      assert Enum.count(caixas, &(&1.field_name == "Quarter")) == 1, """
      O campo `Quarter` foi filtrado.

      Todo campo de iteração vira sprint por decisão da pessoa mantenedora. Filtrar
      pelo nome mediria 3 itens no Produtos Internos, onde `Quarter` tem 15 e `Sprint`
      tem 3.
      """
    end

    test "a duração gravada é a da iteração, e não a do campo", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"), do: quadro_com_dois_campos(), else: itens([])
      end)

      {:ok, _} = GithubSprints.collect(ctx.ctx)

      curto = Enum.find(SRO.list_sprints(ctx.tenant), &(&1.title == "Sprint 10"))

      assert curto.duration_days == 3, """
      A duração do campo (14) foi gravada no lugar da duração da iteração (3).

      Medido em 2026-08-15: `Sprint 10` tem 3 dias num campo configurado para 14, e
      `Quarter 1` tem 61 num de 90. Gravar a do campo faria a série mentir sobre o
      período coberto.
      """

      assert curto.ended_on == ~D[2025-05-30]
    end

    test "a iteração concluída é distinguida da em curso", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"), do: quadro_com_dois_campos(), else: itens([])
      end)

      {:ok, _} = GithubSprints.collect(ctx.ctx)
      caixas = SRO.list_sprints(ctx.tenant)

      assert Enum.count(caixas, & &1.completed) == 1
      assert Enum.count(caixas, &(not &1.completed)) == 2
    end
  end

  describe "as issues dentro das caixas" do
    test "a mesma issue em dois campos produz dois vínculos", ctx do
      issue = ctx.cenario.issues[1].pai

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2") do
          quadro_com_dois_campos()
        else
          # O caso medido: a mesma issue no `Sprint` e no `Quarter`.
          itens([item(issue.external_id, [{"Sprint", "Sprint 40"}, {"Quarter", "Quarter 5"}])])
        end
      end)

      {:ok, resumo} = GithubSprints.collect(ctx.ctx)

      assert resumo.links == 2, """
      Uma issue em duas caixas produziu um vínculo só.

      É a asserção que carrega a feature: no DevOps, 527 + 203 = 730 vínculos sobre
      677 itens. Se a soma não passar do total de itens, alguma issue perdeu uma das
      caixas — e escolher qual não tem regra que justifique.
      """

      assert Repo.aggregate(SprintIssue, :count) == 2
    end

    test "item que não é issue não vira issue inventada", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2") do
          quadro_com_dois_campos()
        else
          # Rascunho do Projects: `content` sem `id` de issue.
          itens([%{"content" => %{}, "fieldValues" => %{"nodes" => []}}])
        end
      end)

      {:ok, resumo} = GithubSprints.collect(ctx.ctx)

      assert resumo.links == 0
      assert Repo.aggregate(SprintIssue, :count) == 0
    end

    test "a issue que saiu do sprint é marcada, e a linha continua", ctx do
      issue = ctx.cenario.issues[1].pai

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"),
          do: quadro_com_dois_campos(),
          else: itens([item(issue.external_id, [{"Sprint", "Sprint 40"}])])
      end)

      {:ok, _} = GithubSprints.collect(ctx.ctx)
      assert Repo.aggregate(SprintIssue, :count) == 1

      # Segunda coleta, e a issue saiu do sprint.
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"),
          do: quadro_com_dois_campos(),
          else: itens([])
      end)

      {:ok, _} = GithubSprints.collect(ctx.ctx)

      assert Repo.aggregate(SprintIssue, :count) == 1, """
      A linha do vínculo foi apagada quando a issue saiu do sprint.

      Ausência marca, nunca apaga: a issue continua tendo estado naquele sprint.
      """

      sprint = Enum.find(SRO.list_sprints(ctx.tenant), &(&1.title == "Sprint 40"))
      assert SRO.list_sprint_issues(ctx.tenant, sprint.id) == []
    end
  end

  describe "falhar em buscar não é o mesmo que não achar" do
    test "consulta que falha não esvazia os sprints", ctx do
      issue = ctx.cenario.issues[1].pai

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"),
          do: quadro_com_dois_campos(),
          else: itens([item(issue.external_id, [{"Sprint", "Sprint 40"}])])
      end)

      {:ok, _} = GithubSprints.collect(ctx.ctx)
      sprint = Enum.find(SRO.list_sprints(ctx.tenant), &(&1.title == "Sprint 40"))
      assert length(SRO.list_sprint_issues(ctx.tenant, sprint.id)) == 1

      # Segunda coleta: os campos vêm, mas a consulta dos itens FALHA.
      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query}, _token ->
        if String.contains?(query, "projectsV2(") do
          {:ok,
           %{
             status: 200,
             body: %{"data" => Map.put(quadro_com_dois_campos(), "rateLimit", @rate_limit)}
           }}
        else
          {:error, {:transport, :timeout}}
        end
      end)

      {:ok, _} = GithubSprints.collect(ctx.ctx)

      assert length(SRO.list_sprint_issues(ctx.tenant, sprint.id)) == 1, """
      Uma falha de rede esvaziou o sprint.

      Sem distinguir "não achei itens" de "não consegui buscar", a marca de ausência
      concluiria que as issues saíram — quando a plataforma é que não conseguiu olhar.

      É a mesma família da L57, e aqui ela apaga trabalho: a issue continuaria no
      sprint na origem, e a plataforma a mostraria como removida.
      """
    end
  end

  describe "a fase não derruba a sincronização" do
    test "resposta de forma inesperada vira erro, e não estouro", ctx do
      # O caso que o teste do job pegou: a borda devolve uma resposta bem formada, mas
      # de outra consulta. Sem tratamento, era `CaseClauseError` — e a fase existe
      # justamente para não derrubar o que já foi coletado.
      responder(fn _query, _vars -> %{"organization" => %{"id" => "O_1", "login" => "acme"}} end)

      assert {:error, {:resposta_inesperada, _}} = GithubSprints.collect(ctx.ctx), """
      Uma resposta de forma inesperada estourou em vez de virar erro.

      Pessoas, repositórios e issues já estão gravados quando esta fase roda. Derrubar
      a sincronização por causa dos quadros perderia tudo isso — e o motivo precisa ir
      para o log em vez de sumir.
      """
    end
  end

  describe "o custo" do
    test "quadro sem campo de iteração não tem itens pedidos", ctx do
      stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query}, _token ->
        if String.contains?(query, "projectsV2(") do
          {:ok,
           %{
             status: 200,
             body: %{"data" => Map.put(quadro_sem_iteracao(), "rateLimit", @rate_limit)}
           }}
        else
          flunk("""
          Os itens foram pedidos para um quadro sem campo de iteração.

          A asserção é sobre o PEDIDO, e não sobre o resultado: consultar e receber
          vazio deixa o banco no mesmo estado de não consultar, e só o custo
          distingue. São 15 dos 26 quadros medidos.
          """)
        end
      end)

      {:ok, resumo} = GithubSprints.collect(ctx.ctx)

      assert resumo.sprints == 0

      assert resumo.boards_without_iteration == 1, """
      O quadro sem caixa de tempo não foi contado.

      "O quadro não usa caixas" e "a coleta falhou nele" são coisas diferentes, e o
      resumo precisa distinguir.
      """
    end
  end
end
