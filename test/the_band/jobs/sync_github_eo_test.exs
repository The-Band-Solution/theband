defmodule TheBand.Jobs.SyncGitHubEOTest do
  @moduledoc """
  Coleta com a borda HTTP simulada.

  Mox **só** no cliente HTTP; nenhum módulo de domínio é mockado. As respostas
  imitam a forma real do GraphQL do GitHub, capturadas da organização usada na
  verificação e reduzidas ao necessário.
  """

  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Jobs.SyncGitHubEO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  @rate_limit_folgado %{"cost" => 1, "remaining" => 4000, "resetAt" => "2030-01-01T00:00:00Z"}

  defp setup_tool(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme"
      })
      |> Repo.insert()

    {:ok, _credential} =
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

  defp open_sync(tenant, tool) do
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

  defp perform(tenant, sync) do
    SyncGitHubEO.perform(%Oban.Job{
      args: %{"tenant_id" => tenant.id, "sync_id" => sync.id}
    })
  end

  # Responde conforme a query recebida, como o GitHub faria.
  defp responder(fun) do
    stub(TheBand.GitHubHTTPMock, :post, fn _url, %{query: query, variables: vars}, _token ->
      {:ok, %{status: 200, body: %{"data" => fun.(query, vars)}, headers: %{}}}
    end)
  end

  defp org_node, do: %{"id" => "O_1", "login" => "acme", "name" => "Acme"}

  defp pagina(nodes, has_next?, cursor) do
    %{"nodes" => nodes, "pageInfo" => %{"hasNextPage" => has_next?, "endCursor" => cursor}}
  end

  # A conexão de membros de time devolve `edges`, não `nodes`: o nível de acesso
  # na plataforma vive na **aresta**, não no nó. É por isso que ele nunca poderia
  # ser confundido com um atributo da pessoa.
  defp pagina_edges(edges, has_next?, cursor) do
    %{"edges" => edges, "pageInfo" => %{"hasNextPage" => has_next?, "endCursor" => cursor}}
  end

  describe "coleta completa" do
    setup do
      tenant = tenant_fixture()
      tool = setup_tool(tenant)
      %{tenant: tenant, tool: tool, sync: open_sync(tenant, tool)}
    end

    test "grava organização, pessoas e equipes com proveniência", %{tenant: tenant, sync: sync} do
      responder(fn query, _vars ->
        cond do
          String.contains?(query, "membersWithRole") ->
            %{
              "rateLimit" => @rate_limit_folgado,
              "organization" => %{
                "id" => "O_1",
                "membersWithRole" =>
                  pagina(
                    [%{"__typename" => "User", "id" => "U_1", "login" => "ana", "name" => "Ana"}],
                    false,
                    nil
                  )
              }
            }

          String.contains?(query, "team(slug") ->
            %{
              "rateLimit" => @rate_limit_folgado,
              "organization" => %{
                "team" => %{
                  "id" => "T_1",
                  "slug" => "core",
                  "members" =>
                    pagina_edges(
                      [
                        %{
                          "role" => "MAINTAINER",
                          "node" => %{
                            "__typename" => "User",
                            "id" => "U_1",
                            "login" => "ana",
                            "name" => "Ana"
                          }
                        }
                      ],
                      false,
                      nil
                    )
                }
              }
            }

          String.contains?(query, "teams(") ->
            %{
              "rateLimit" => @rate_limit_folgado,
              "organization" => %{
                "id" => "O_1",
                "teams" =>
                  pagina(
                    [
                      %{
                        "id" => "T_1",
                        "name" => "Core",
                        "slug" => "core",
                        "createdAt" => "2025-01-01T00:00:00Z"
                      }
                    ],
                    false,
                    nil
                  )
              }
            }

          true ->
            %{"rateLimit" => @rate_limit_folgado, "organization" => org_node()}
        end
      end)

      assert :ok = perform(tenant, sync)

      assert EO.count_people(tenant) == 1
      assert EO.count_teams(tenant) == 1
      assert EO.count_evidence_pending_role(tenant) == 1

      assert [pessoa] = EO.list_people(tenant)
      assert pessoa.source_system == "github"
      assert pessoa.source_instance == "https://github.com"
      assert pessoa.external_id == "U_1"
      assert pessoa.collected_at

      sync = Ingestion.reload(sync)
      assert sync.status == "completed"
      assert sync.records_created == 3
      assert sync.memberships_pending_role == 1
    end
  end

  describe "rate limit (FR-016, SC-009)" do
    setup do
      tenant = tenant_fixture()
      tool = setup_tool(tenant)
      %{tenant: tenant, tool: tool, sync: open_sync(tenant, tool)}
    end

    test "pausa antes de esgotar a janela e devolve snooze, sem falhar", %{
      tenant: tenant,
      sync: sync
    } do
      # Janela apertada: remaining < cost * 2 na primeira página que tem próxima.
      apertado = %{"cost" => 100, "remaining" => 150, "resetAt" => reset_em(90)}

      responder(fn query, _vars ->
        if String.contains?(query, "membersWithRole") do
          %{
            "rateLimit" => apertado,
            "organization" => %{
              "id" => "O_1",
              "membersWithRole" =>
                pagina(
                  [%{"__typename" => "User", "id" => "U_1", "login" => "ana", "name" => "Ana"}],
                  true,
                  "cursor-1"
                )
            }
          }
        else
          %{"rateLimit" => @rate_limit_folgado, "organization" => org_node()}
        end
      end)

      assert {:snooze, segundos} = perform(tenant, sync)
      assert segundos > 0

      # Pausa não é falha: a sincronização segue em andamento, e o progresso da
      # página já processada está gravado.
      assert Ingestion.reload(sync).status == "running"
      assert Ingestion.resume_cursor(sync, "github.user") == "cursor-1"
      assert EO.count_people(tenant) == 1
    end
  end

  describe "retomada após interrupção (FR-015, SC-006)" do
    setup do
      tenant = tenant_fixture()
      tool = setup_tool(tenant)
      %{tenant: tenant, tool: tool, sync: open_sync(tenant, tool)}
    end

    test "retoma do checkpoint em vez de recomeçar do zero", %{tenant: tenant, sync: sync} do
      # Simula a interrupção: a primeira página já foi processada e o cursor gravado.
      {:ok, _} = Ingestion.checkpoint_page(sync, "github.user", "cursor-1", 1)

      {:ok, _} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_1", %{name: "Ana", login: "ana"})
        )

      cursores = :ets.new(:cursores, [:public, :bag])

      responder(fn query, vars ->
        if String.contains?(query, "membersWithRole") do
          :ets.insert(cursores, {:pedido, vars[:after] || vars["after"]})

          %{
            "rateLimit" => @rate_limit_folgado,
            "organization" => %{
              "id" => "O_1",
              "membersWithRole" =>
                pagina(
                  [
                    %{
                      "__typename" => "User",
                      "id" => "U_2",
                      "login" => "bruno",
                      "name" => "Bruno"
                    }
                  ],
                  false,
                  nil
                )
            }
          }
        else
          %{"rateLimit" => @rate_limit_folgado, "organization" => org_node()}
        end
      end)

      assert :ok = perform(tenant, sync)

      # A retomada pediu a página **seguinte**, não a primeira: é isso que SC-006
      # mede — no máximo uma reconsulta por página em relação à execução íntegra.
      assert [{:pedido, "cursor-1"}] = :ets.lookup(cursores, :pedido)

      # A pessoa da primeira página continua lá, e a da segunda foi acrescentada.
      assert EO.count_people(tenant) == 2
    end
  end

  describe "falha de rede (taxonomia de erro)" do
    setup do
      tenant = tenant_fixture()
      tool = setup_tool(tenant)
      %{tenant: tenant, tool: tool, sync: open_sync(tenant, tool)}
    end

    test "não marca a sincronização como falha — o Oban retenta", %{tenant: tenant, sync: sync} do
      stub(TheBand.GitHubHTTPMock, :post, fn _url, _body, _token ->
        {:error, %Req.TransportError{reason: :nxdomain}}
      end)

      assert {:error, {:transport, :nxdomain}} = perform(tenant, sync)

      # Continua em andamento: marcar como falha levaria alguém a investigar uma
      # coleta que ainda vai ser retentada, e liberaria o índice que impede duas
      # coletas simultâneas da mesma ferramenta.
      assert Ingestion.reload(sync).status == "running"
      refute Ingestion.reload(sync).error_reason
    end

    test "erro terminal marca a falha com mensagem legível", %{tenant: tenant, sync: sync} do
      stub(TheBand.GitHubHTTPMock, :post, fn _url, _body, _token ->
        {:ok, %{status: 200, body: %{"data" => %{"organization" => nil}}, headers: %{}}}
      end)

      assert {:error, {:organization_not_found, "acme"}} = perform(tenant, sync)

      sync = Ingestion.reload(sync)
      assert sync.status == "failed"
      assert sync.error_reason =~ "was not found"
      # A mensagem diz o que fazer, e não expõe o struct.
      assert sync.error_reason =~ "organisation login"
      refute sync.error_reason =~ "%"
    end
  end

  describe "credencial revogada durante a coleta" do
    setup do
      tenant = tenant_fixture()
      tool = setup_tool(tenant)
      %{tenant: tenant, tool: tool, sync: open_sync(tenant, tool)}
    end

    test "interrompe de forma controlada e marca a ferramenta", %{
      tenant: tenant,
      tool: tool,
      sync: sync
    } do
      stub(TheBand.GitHubHTTPMock, :post, fn _url, _body, _token ->
        {:ok, %{status: 401, body: %{}, headers: %{}}}
      end)

      assert {:error, :unauthorized} = perform(tenant, sync)

      sync = Ingestion.reload(sync)
      assert sync.status == "interrupted"
      assert sync.error_reason =~ "credencial recusada"

      {:ok, tool} = TheBand.Sources.fetch_connected_tool(tenant, tool.id)
      # A situação é derivada do fato datado, e não de coluna — issue #178.
      assert TheBand.Sources.situacao(tool) == :needs_attention
      assert tool.needs_attention_since
    end
  end

  describe "credencial ilegível — a chave mestra mudou" do
    setup do
      tenant = tenant_fixture()
      tool = setup_tool(tenant)
      %{tenant: tenant, tool: tool, sync: open_sync(tenant, tool)}
    end

    test "marca a ferramenta e interrompe, em vez de levantar", %{
      tenant: tenant,
      tool: tool,
      sync: sync
    } do
      credential = TheBand.Sources.active_credential(tool)

      # SQL cru: `update_all` passaria pelo tipo do campo, que cifraria o valor com a chave
      # atual — e o caso montado assim seria legível, provando o contrário do que diz.
      Repo.query!(
        "update tool_credentials set secret = $1 where id = $2",
        [
          <<1, 16>> <> "AES.GCM.deadbeef" <> :crypto.strong_rand_bytes(60),
          Ecto.UUID.dump!(credential.id)
        ]
      )

      # Nenhuma chamada HTTP é esperada: a coleta nem começa. Se `perform` levantasse — que
      # é o comportamento que este teste veda —, o `assert` abaixo nunca seria alcançado.
      assert {:error, :unreadable_credential} = perform(tenant, sync)

      sync = Ingestion.reload(sync)
      assert sync.status == "interrupted"
      assert sync.error_reason =~ "ilegível"

      {:ok, tool} = TheBand.Sources.fetch_connected_tool(tenant, tool.id)
      assert TheBand.Sources.situacao(tool) == :needs_attention
      assert tool.needs_attention_reason =~ "chave mestra"
    end
  end

  defp reset_em(segundos) do
    DateTime.utc_now() |> DateTime.add(segundos, :second) |> DateTime.to_iso8601()
  end
end
