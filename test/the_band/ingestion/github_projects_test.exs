defmodule TheBand.Ingestion.GithubProjectsTest do
  @moduledoc """
  A coleta dos quadros inteiros — sprint 017, T047 a T056. Porta os testes da 024
  (`SprintsTest`) e acrescenta o que a F7 trouxe.

  ## As asserções que carregam este arquivo

  1. **a soma dos vínculos é maior que o total de itens** — a sobreposição medida no
     DevOps não pode ser achatada;
  2. **a duração gravada é a da iteração**, e não a configurada no campo;
  3. **iteração futura vira processo pretendido, nunca sprint** — FR-030, o defeito
     que a 024 teve (26 sprints futuros corrigidos em 2026-08-16);
  4. **o rascunho é registrado** como item sem trabalho, nunca descartado — FR-022.

  ## Uma inversão declarada em relação à 024

  A 024 afirmava que quadro sem campo de iteração **não** tinha itens pedidos — era
  asserção de custo. A F7 inverte: o product backlog deriva dos itens (FR-032), então
  **todo** quadro tem itens pedidos. O custo continua medido, mas o teste agora afirma
  a cobertura.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.WorkItemsFixtures

  alias TheBand.Ingestion.GithubProjects
  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Ontology.Continuum.SRO.Schemas.SprintIssue
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Projects

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
              "id" => "PVT_board31",
              "number" => 31,
              "title" => "DevOps",
              "closed" => false,
              "fields" => %{
                "nodes" => [
                  %{
                    "__typename" => "ProjectV2Field",
                    "id" => "PVTF_status",
                    "name" => "Status",
                    "dataType" => "SINGLE_SELECT"
                  },
                  %{
                    "__typename" => "ProjectV2IterationField",
                    "id" => "PVTIF_sprint",
                    "name" => "Sprint",
                    "dataType" => "ITERATION",
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
                    "dataType" => "ITERATION",
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
              "id" => "PVT_board46",
              "number" => 46,
              "title" => "Conecta Fapes - Teste",
              "closed" => false,
              "fields" => %{
                "nodes" => [
                  %{
                    "__typename" => "ProjectV2Field",
                    "id" => "PVTF_status46",
                    "name" => "Status",
                    "dataType" => "SINGLE_SELECT"
                  }
                ]
              }
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

  # `valores` é uma lista de {field_external_id, iteration_id, titulo}.
  defp item(external_id, valores) do
    %{
      "id" => "PVTI_#{external_id}",
      "content" => %{"__typename" => "Issue", "id" => external_id},
      "fieldValues" => %{
        "nodes" =>
          Enum.map(valores, fn {campo_id, iteracao_id, titulo} ->
            %{
              "__typename" => "ProjectV2ItemFieldIterationValue",
              "title" => titulo,
              "iterationId" => iteracao_id,
              "startDate" => "2026-07-27",
              "duration" => 14,
              "field" => %{"id" => campo_id, "name" => campo_id}
            }
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

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)

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

      {:ok, _} = GithubProjects.collect(ctx.ctx)

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

      {:ok, _} = GithubProjects.collect(ctx.ctx)
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
          itens([
            item(issue.external_id, [
              {"PVTIF_sprint", "i40", "Sprint 40"},
              {"PVTIF_quarter", "q5", "Quarter 5"}
            ])
          ])
        end
      end)

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)

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
          # Rascunho do Projects: `DraftIssue`, sem issue por trás.
          itens([
            %{
              "id" => "PVTI_draft1",
              "content" => %{"__typename" => "DraftIssue", "title" => "ideia solta"},
              "fieldValues" => %{"nodes" => []}
            }
          ])
        end
      end)

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)

      assert resumo.links == 0
      assert Repo.aggregate(SprintIssue, :count) == 0
    end

    test "a issue que saiu do sprint é marcada, e a linha continua", ctx do
      issue = ctx.cenario.issues[1].pai

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"),
          do: quadro_com_dois_campos(),
          else: itens([item(issue.external_id, [{"PVTIF_sprint", "i40", "Sprint 40"}])])
      end)

      {:ok, _} = GithubProjects.collect(ctx.ctx)
      assert Repo.aggregate(SprintIssue, :count) == 1

      # Segunda coleta, e a issue saiu do sprint.
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2"),
          do: quadro_com_dois_campos(),
          else: itens([])
      end)

      {:ok, _} = GithubProjects.collect(ctx.ctx)

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
          else: itens([item(issue.external_id, [{"PVTIF_sprint", "i40", "Sprint 40"}])])
      end)

      {:ok, _} = GithubProjects.collect(ctx.ctx)
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

      {:ok, _} = GithubProjects.collect(ctx.ctx)

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

      assert {:error, {:resposta_inesperada, _}} = GithubProjects.collect(ctx.ctx), """
      Uma resposta de forma inesperada estourou em vez de virar erro.

      Pessoas, repositórios e issues já estão gravados quando esta fase roda. Derrubar
      a sincronização por causa dos quadros perderia tudo isso — e o motivo precisa ir
      para o log em vez de sumir.
      """
    end
  end

  describe "a cobertura que a 024 não tinha" do
    test "quadro sem campo de iteração agora EXISTE, com campos e itens", ctx do
      # A inversão declarada: a 024 não pedia os itens destes quadros — eram 15 dos 26
      # invisíveis. O product backlog deriva dos itens (FR-032), então todo quadro tem
      # entidade, campos e itens.
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2("), do: quadro_sem_iteracao(), else: itens([])
      end)

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)

      assert resumo.projects == 1
      assert resumo.sprints == 0
      assert resumo.fields == 1

      assert [quadro] = Projects.list_projects(ctx.tenant)
      assert quadro.number == 46
      assert [campo] = Projects.list_field_definitions(ctx.tenant, quadro.id)
      assert campo.name == "Status"
      assert campo.data_type == "SINGLE_SELECT"
    end

    test "a entidade de quadro nasce sem promoção, e os campos com a identidade da origem",
         ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2("), do: quadro_com_dois_campos(), else: itens([])
      end)

      {:ok, _} = GithubProjects.collect(ctx.ctx)

      assert [quadro] = Projects.list_projects(ctx.tenant)
      assert quadro.title == "DevOps"

      # FR-020: nenhum campo de promoção existe no schema — a asserção é estrutural.
      refute Map.has_key?(quadro, :spo_project_id)

      campos = Projects.list_field_definitions(ctx.tenant, quadro.id)
      assert length(campos) == 3

      # FR-027: a identidade é o id da origem, e o nome vai junto para leitura humana.
      status = Enum.find(campos, &(&1.name == "Status"))
      assert status.field_external_id == "PVTF_status"
    end

    test "o rascunho é registrado como item sem trabalho, nunca descartado", ctx do
      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2(") do
          quadro_com_dois_campos()
        else
          itens([
            %{
              "id" => "PVTI_draft2",
              "content" => %{"__typename" => "DraftIssue", "title" => "ideia"},
              "fieldValues" => %{"nodes" => []}
            }
          ])
        end
      end)

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)

      assert resumo.items == 1
      assert resumo.drafts == 1

      [quadro] = Projects.list_projects(ctx.tenant)
      assert [item] = Projects.list_items(ctx.tenant, quadro.id)
      assert item.is_draft
      assert item.collected_issue_id == nil, "rascunho não aponta para issue"
    end

    test "o valor de campo entra cru, e sem mapeamento fica não interpretado", ctx do
      issue = ctx.cenario.issues[1].pai

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2(") do
          quadro_com_dois_campos()
        else
          itens([
            %{
              "id" => "PVTI_v1",
              "content" => %{"__typename" => "Issue", "id" => issue.external_id},
              "fieldValues" => %{
                "nodes" => [
                  %{
                    "__typename" => "ProjectV2ItemFieldSingleSelectValue",
                    "name" => "Done",
                    "optionId" => "opt9",
                    "field" => %{"id" => "PVTF_status", "name" => "Status"}
                  }
                ]
              }
            }
          ])
        end
      end)

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)
      assert resumo.values == 1

      [quadro] = Projects.list_projects(ctx.tenant)
      valores = Projects.item_values(ctx.tenant, quadro.id)
      assert [valor] = valores |> Map.values() |> List.flatten()

      assert valor.raw_value == %{"name" => "Done", "optionId" => "opt9"}

      assert valor.interpreted_as == nil, """
      Um valor sem mapeamento declarado foi interpretado.

      `Priority` não é `importance` — converter por semelhança de nome é o antipadrão
      de AGENTS §7.7, e a FR-025 manda guardar cru e exibir como não interpretado.
      """
    end

    test "iteração futura vira processo pretendido, nunca sprint — e transiciona na coleta",
         ctx do
      amanha = Date.utc_today() |> Date.add(30) |> Date.to_iso8601()

      quadro_com_futura = fn ->
        %{
          "organization" => %{
            "projectsV2" => %{
              "totalCount" => 1,
              "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil},
              "nodes" => [
                %{
                  "id" => "PVT_board50",
                  "number" => 50,
                  "title" => "Futuro",
                  "closed" => false,
                  "fields" => %{
                    "nodes" => [
                      %{
                        "__typename" => "ProjectV2IterationField",
                        "id" => "PVTIF_f",
                        "name" => "Sprint",
                        "dataType" => "ITERATION",
                        "configuration" => %{
                          "duration" => 14,
                          "iterations" => [
                            %{
                              "id" => "if1",
                              "title" => "Sprint Futuro",
                              "startDate" => amanha,
                              "duration" => 14
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

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2("), do: quadro_com_futura.(), else: itens([])
      end)

      {:ok, resumo} = GithubProjects.collect(ctx.ctx)

      assert resumo.intended == 1

      assert resumo.sprints == 0, """
      Uma iteração futura virou sprint.

      É a FR-030, e é o defeito que a 024 teve: 26 de 220 sprints com início no futuro,
      corrigidos em 2026-08-16. Sprint é complex_action — algo que OCORREU.
      """

      # A transição: a mesma iteração, agora com início no passado (a coleta seguinte).
      ontem = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()

      quadro_iniciada =
        quadro_com_futura.()
        |> update_in(
          [
            "organization",
            "projectsV2",
            "nodes",
            Access.at(0),
            "fields",
            "nodes",
            Access.at(0),
            "configuration",
            "iterations",
            Access.at(0),
            "startDate"
          ],
          fn _ -> ontem end
        )

      responder(fn query, _vars ->
        if String.contains?(query, "projectsV2("), do: quadro_iniciada, else: itens([])
      end)

      {:ok, resumo2} = GithubProjects.collect(ctx.ctx)

      assert resumo2.sprints == 1, "a iteração iniciada não virou sprint na coleta seguinte"

      [quadro] = Projects.list_projects(ctx.tenant)
      [iteracao] = Projects.list_iterations(ctx.tenant, quadro.id)

      assert iteracao.sro_sprint_id != nil

      assert iteracao.spo_intended_process_id == nil, """
      A iteração aponta para os dois destinos ao mesmo tempo.

      SC-009c: exatamente um registro vigente — sprint OU pretendido, nunca os dois.
      """
    end
  end
end
