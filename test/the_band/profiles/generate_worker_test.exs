defmodule TheBand.Profiles.GenerateWorkerTest do
  @moduledoc """
  A geração em trabalho de fundo — feature 026, T006 e T009.

  ## O que este arquivo protege

  **Nenhum caminho devolve silêncio.** Resposta vazia não vira perfil, falha do provedor não
  apaga o perfil anterior, e recusa do material não vira erro repetido três vezes. É a mesma
  classe de defeito da L26 do projeto: o job completa, nada é gravado, e ninguém percebe.

  E o Mox substitui **só** a borda HTTP. Nada abaixo dela é mockado — mock de domínio
  esconde erro em vez de revelá-lo.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.WorkItemsFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.AI
  alias TheBand.Integrations.LLM.HTTP
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.GenerateWorker
  alias TheBand.WorkItems

  setup :verify_on_exit!

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, _user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "gerada",
        name: "Pessoa Gerada",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/gerada",
        external_id: "U_gerada",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => "gerada"}
      })

    material(tenant, cenario.observed_repository_id, pessoa.id)

    %{tenant: tenant, pessoa: pessoa}
  end

  defp material(tenant, repo_id, person_id) do
    base = ~U[2025-02-10 12:00:00Z]

    for n <- 1..30 do
      fechada = DateTime.add(base, n * 15, :day)

      {:ok, issue} =
        WorkItems.record_collected_issue(tenant, %{
          observed_repository_id: repo_id,
          number: 8000 + n,
          title: "tarefa ##{n}",
          body: String.duplicate("contexto. ", 30),
          state: "CLOSED",
          author_login: "gerada",
          external_created_at: DateTime.add(fechada, -4, :day),
          external_closed_at: fechada,
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "I_worker_#{n}"
        })

      {:ok, _} =
        WorkItems.replace_assignees(tenant, issue.id, [
          %{login: "gerada", external_id: "U_gerada", person_id: person_id}
        ])
    end
  end

  defp job(ctx, person_id \\ nil) do
    %Oban.Job{
      args: %{
        "tenant_id" => ctx.tenant.id,
        "person_id" => person_id || ctx.pessoa.id,
        "requested_by_user_id" => nil
      }
    }
  end

  test "sucesso grava com a proveniência completa e com o veredito", ctx do
    expect(TheBand.LLMHTTPMock, :complete, fn instrucoes, material, _opts ->
      assert instrucoes =~ "linha de base do projeto"
      assert material =~ "CRESCIMENTO DO TEXTO"

      assert material =~ "d aberta",
             """
             O material não trouxe o tempo de cada tarefa.

             É o que permite dizer onde o trabalho trava, comparando contra a mediana da
             própria pessoa — 40 dias é muito para quem fecha em 3, e normal para quem
             fecha em 30.
             """

      {:ok, %{text: Jason.encode!(resposta()), model: "m1", usage: %{}}}
    end)

    assert {:ok, perfil} = GenerateWorker.perform(job(ctx))

    assert perfil.model == "m1"
    assert perfil.tasks_closed == 30
    assert perfil.baseline_verdict =~ "pessoa"

    assert perfil.citations_removed == 1,
           "a limpeza do resumo precisa ser contada, e não acontecer calada"

    refute perfil.content["resumo"]["forcas"] =~ "#42", "a citação do resumo continuou lá"

    assert perfil.content["destaques"] |> hd() |> Map.get("evidencia") == [43],
           """
           A limpeza passou do resumo e comeu a evidência dos destaques.

           `destaques` e `lacunas` têm campo próprio para os números; é lá que a evidência
           mora, e tirá-la deixaria o texto sem lastro.
           """
  end

  # O que o provedor devolve com `strict: true` — estrutura, e não prosa.
  defp resposta do
    %{
      "habilidades" => ["observabilidade com OpenTelemetry"],
      "resumo" => %{
        "forcas" => "Instrumentou a coleta (#42).",
        "evolucao" => "O eixo não mudou.",
        "atencao" => "Registro recente é de terceiros."
      },
      "trajetoria" => [
        %{
          "periodo" => 1,
          "meses" => "2025-02 a 2025-06",
          "titulo" => "t1",
          "texto" => "x",
          "tarefas_citadas" => []
        },
        %{
          "periodo" => 2,
          "meses" => "2025-06 a 2025-11",
          "titulo" => "t2",
          "texto" => "y",
          "tarefas_citadas" => []
        },
        %{
          "periodo" => 3,
          "meses" => "2025-11 a 2026-04",
          "titulo" => "t3",
          "texto" => "z",
          "tarefas_citadas" => []
        }
      ],
      "destaques" => [
        %{
          "dominio" => "observabilidade",
          "demonstrou" => "coletou",
          "tarefas" => 8,
          "periodos" => [1, 2, 3],
          "mais_recente" => "2026-04",
          "evidencia" => [43]
        }
      ],
      "lacunas" => [],
      "do_time_nao_da_pessoa" => "o corpo cresceu com o projeto",
      "alocacao" => [],
      "recomendacoes" => [],
      "nao_alcanca" => "não alcança revisão de código"
    }
  end

  test "200 com texto vazio NÃO vira perfil", ctx do
    expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
      {:error, {:empty_response, "length"}}
    end)

    assert {:cancel, {:empty_response, "length"}} = GenerateWorker.perform(job(ctx))

    assert {:error, :not_found} = EO.current_profile(ctx.tenant, ctx.pessoa.id),
           """
           Um perfil foi gravado a partir de resposta vazia.

           Um perfil vazio é indistinguível de um perfil na tela, e quem lê acreditaria nele.
           """
  end

  test "falha do provedor deixa o perfil anterior intacto", ctx do
    {:ok, anterior} =
      EO.record_profile(ctx.tenant, %{
        person_id: ctx.pessoa.id,
        generated_at: ~U[2026-06-01 10:00:00Z],
        model: "m0",
        content: resposta(),
        tasks_closed: 10,
        tasks_open: 0,
        tasks_with_body: 10,
        tasks_authored_by_other: 0,
        tasks_shared: 0
      })

    expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
      {:error, {:http, 429, "rate limited"}}
    end)

    assert {:cancel, {:http, 429, _}} = GenerateWorker.perform(job(ctx))
    assert {:ok, ^anterior} = EO.current_profile(ctx.tenant, ctx.pessoa.id)
  end

  test "material insuficiente é cancelado, e não repetido três vezes", ctx do
    {:ok, vazia} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: "sem-trabalho",
        name: "Sem Trabalho",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/sem-trabalho",
        external_id: "U_sem_trabalho",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    assert {:cancel, :no_assignment} = GenerateWorker.perform(job(ctx, vazia.id))
  end

  describe "a credencial" do
    # Sem esta asserção, a tela `/ai` seria decoração: a chave estaria gravada, cifrada e
    # conferida — e a geração continuaria pagando pela conta do processo.
    test "gravada pela organização, é ela que a geração usa", ctx do
      chave = "sk-a-chave-desta-organizacao-e-nao-do-processo"

      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:ok, ["gpt-5.4"]} end)

      {:ok, _} = AI.put(ctx.tenant, %{"secret" => chave, "default_model" => "gpt-5.4"})

      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, opts ->
        assert opts[:key] == chave
        assert opts[:model] == "gpt-5.4"
        assert opts[:base_url] == "https://api.openai.com"

        {:ok, %{text: Jason.encode!(resposta()), model: "gpt-5.4", usage: %{}}}
      end)

      assert {:ok, _perfil} = GenerateWorker.perform(job(ctx))
    end

    # Sem credencial gravada a lista vem vazia, e é isso que faz a borda cair no `API_KEY`
    # do ambiente — que é como o desenvolvimento roda.
    test "sem credencial da organização, nenhuma chave é imposta à borda", ctx do
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, opts ->
        refute Keyword.has_key?(opts, :key)

        {:ok, %{text: Jason.encode!(resposta()), model: "m1", usage: %{}}}
      end)

      assert {:ok, _perfil} = GenerateWorker.perform(job(ctx))
    end

    test "não aparece na mensagem de erro devolvida pela borda" do
      chave = "sk-proj-segredo-que-nao-pode-circular"

      vazado =
        HTTP.redigir(
          "Permission denied: Consumer 'api_key:#{chave}' has been suspended.",
          chave
        )

      refute vazado =~ chave,
             """
             A chave circulou dentro de uma mensagem de erro.

             Não é hipótese: medido em 2026-08-15, a resposta de chave suspensa do provedor
             trazia a chave inteira no texto — e essa mensagem vai para o log.
             """

      assert vazado =~ "«API_KEY»"
    end
  end
end
