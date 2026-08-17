defmodule TheBandWeb.PerfilTest do
  @moduledoc """
  A aba de perfil na página da pessoa — feature 026, T012 a T014.

  ## As três asserções que carregam este arquivo

  1. **os quatro estados dizem coisas diferentes** — nunca gerado, pedido, existente e
     recusado pedem ações diferentes de quem lê, e uma frase só para todos apagaria isso;
  2. **o rótulo "derived" está em texto** — o design system exige, e a razão não é acesso:
     a plataforma existe para separar o que observou do que concluiu, e cor sozinha desfaz
     o produto;
  3. **a recusa é do registro** — a frase não pode sugerir que a pessoa produziu pouco.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "pessoa-de-teste",
        name: "Pessoa de Teste",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/pessoa-de-teste",
        external_id: "U_perfil_teste",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => "pessoa-de-teste"}
      })

    %{
      conn: log_in(conn, user),
      tenant: tenant,
      user: user,
      pessoa: pessoa,
      repo_id: cenario.observed_repository_id
    }
  end

  # Um conteúdo mínimo válido, na forma que o schema garante.
  defp conteudo(extra \\ %{}) do
    Map.merge(
      %{
        "habilidades" => ["observabilidade com OpenTelemetry", "automação com Helm"],
        "resumo" => %{
          "forcas" => "Trabalhou em observabilidade desde o começo do recorte.",
          "evolucao" => "O eixo não mudou; o que mudou foi a amplitude.",
          "atencao" => "A maior parte do registro recente foi escrita por outra pessoa."
        },
        "trajetoria" => [
          %{
            "periodo" => 1,
            "meses" => "2025-04 a 2025-06",
            "titulo" => "Começou em observabilidade",
            "texto" => "Instrumentação e deploys.",
            "tarefas_citadas" => ["Instrumentar OTel"]
          },
          %{
            "periodo" => 2,
            "meses" => "2025-06 a 2025-12",
            "titulo" => "Expandiu para ambientes",
            "texto" => "Kubernetes e DNS.",
            "tarefas_citadas" => []
          },
          %{
            "periodo" => 3,
            "meses" => "2026-01 a 2026-08",
            "titulo" => "Plataforma",
            "texto" => "Helm, Vault e VPS.",
            "tarefas_citadas" => []
          }
        ],
        "destaques" => [
          %{
            "dominio" => "observabilidade com OpenTelemetry",
            "demonstrou" => "instrumentou e operou a coleta",
            "tarefas" => 10,
            "periodos" => [1, 2, 3],
            "mais_recente" => "2026-08",
            "evidencia" => [181, 349]
          }
        ],
        "lacunas" => [],
        "do_time_nao_da_pessoa" => "O corpo das tarefas cresceu junto com o do projeto.",
        "alocacao" => [
          %{
            "dominio" => "observabilidade",
            "tarefas" => 10,
            "de" => "2025-05",
            "ate" => "2026-08",
            "demonstrou" => "instrumentação e coleta"
          }
        ],
        "recomendacoes" => ["Dar destino às tarefas paradas há mais de 90 dias."],
        "nao_alcanca" => "Não alcança revisão de código nem mentoria."
      },
      extra
    )
  end

  defp gravar_perfil(ctx, attrs \\ %{}) do
    {:ok, perfil} =
      EO.record_profile(
        ctx.tenant,
        Map.merge(
          %{
            person_id: ctx.pessoa.id,
            generated_at: DateTime.utc_now(:second),
            model: "gpt-5.4-mini",
            content: conteudo(),
            citations_removed: 7,
            tasks_closed: 97,
            tasks_open: 5,
            tasks_with_body: 97,
            tasks_authored_by_other: 55,
            tasks_shared: 23,
            baseline_verdict: "a pessoa ACOMPANHOU o projeto"
          },
          attrs
        )
      )

    perfil
  end

  describe "quando existe perfil" do
    test "a proveniência aparece antes do texto", ctx do
      gravar_perfil(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "gpt-5.4-mini"
      assert html =~ "97"
      assert html =~ "described by someone else"

      assert html =~ "ACOMPANHOU",
             """
             O veredito da linha de base não apareceu.

             É o que impede quem lê de atribuir à pessoa um crescimento de texto que foi do
             time inteiro — e sem ele o perfil afirma mais do que o registro sustenta.
             """
    end

    test "o rótulo de derivado está em texto, e não só em cor", ctx do
      gravar_perfil(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "written by a language model",
             """
             O bloco derivado não se identifica em texto.

             Cor sozinha reprova em WCAG 1.4.1 e, pior, desfaz o produto: a plataforma existe
             para separar o que observou do que concluiu.
             """
    end

    test "quantas citações saíram do resumo é dito, e zero é medição", ctx do
      gravar_perfil(ctx, %{citations_removed: 0})
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "citations removed from the summary",
             """
             A limpeza aconteceu calada.

             É a mesma classe de defeito que a limpeza existe para conter — e zero aqui é a
             afirmação "nada foi removido", não ausência de medida.
             """
    end

    test "uma geração nova não apaga a anterior", ctx do
      antiga =
        gravar_perfil(ctx, %{generated_at: ~U[2026-06-01 10:00:00Z]})

      nova = gravar_perfil(ctx, %{generated_at: ~U[2026-08-15 10:00:00Z]})

      assert length(EO.list_profiles(ctx.tenant, ctx.pessoa.id)) == 2
      assert {:ok, ^nova} = EO.current_profile(ctx.tenant, ctx.pessoa.id)
      assert Enum.any?(EO.list_profiles(ctx.tenant, ctx.pessoa.id), &(&1.id == antiga.id))
    end
  end

  describe "a evolução por geração — #403" do
    test "com uma geração só, a ausência é nomeada — nunca seção escondida", ctx do
      gravar_perfil(ctx, %{generated_at: ~U[2026-08-15 10:00:00Z]})

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "One generation so far (2026-08)",
             "uma geração só virou seção sumida — a ausência tem que ser nomeada"

      refute html =~ "never regression"
    end

    test "com duas gerações, a série aparece com a tendência e a marca de novo", ctx do
      # A primeira geração tinha observabilidade com 4; a vigente tem 10, e um domínio
      # que não existia (deploy) — que deve sair 0 → N com a marca "new".
      conteudo_antigo =
        Map.put(conteudo(), "destaques", [
          %{
            "dominio" => "observabilidade",
            "demonstrou" => "x",
            "tarefas" => 4,
            "periodos" => [1],
            "mais_recente" => "2026-05",
            "evidencia" => [1]
          }
        ])

      conteudo_novo =
        Map.put(conteudo(), "destaques", [
          %{
            "dominio" => "observabilidade",
            "demonstrou" => "x",
            "tarefas" => 10,
            "periodos" => [1, 2],
            "mais_recente" => "2026-08",
            "evidencia" => [1]
          },
          %{
            "dominio" => "deploy",
            "demonstrou" => "y",
            "tarefas" => 7,
            "periodos" => [2],
            "mais_recente" => "2026-08",
            "evidencia" => [2]
          }
        ])

      gravar_perfil(ctx, %{generated_at: ~U[2026-06-01 10:00:00Z], content: conteudo_antigo})
      gravar_perfil(ctx, %{generated_at: ~U[2026-08-15 10:00:00Z], content: conteudo_novo})

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "4 → 10 ▲", "a série do domínio existente não mostrou a tendência"
      assert html =~ "0 → 7 ▲", "domínio novo não saiu de zero"
      assert html =~ "new", "a marca de domínio novo sumiu"

      assert html =~ "never regression",
             "a frase que impede ler ausência antiga como regressão sumiu"
    end
  end

  describe "gerar de novo" do
    test "o botão continua na tela depois de já existir perfil", ctx do
      gravar_perfil(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Generate again",
             """
             Com perfil na tela não há como pedir outro.

             É a US4: um perfil de agosto e outro de dezembro contam algo que nenhum dos dois
             conta sozinho, e a tabela é somente-acréscimo justamente para isso.
             """

      assert html =~ "external provider again",
             "o egresso precisa ser dito também na regeração — sai o mesmo texto de novo"
    end

    test "o botão some enquanto a geração nova roda", ctx do
      gravar_perfil(ctx)
      {:ok, _job} = TheBand.Profiles.request(ctx.tenant, ctx.pessoa.id, ctx.user.id)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "Generate again", "dois pedidos iguais na fila gastariam duas chamadas"
      assert html =~ "appears here on its own"
    end

    test "a tela diz quantas tarefas fecharam desde o perfil exibido", ctx do
      gravar_perfil(ctx, %{tasks_closed: 27})
      material_suficiente(ctx)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "<strong>3</strong>",
             """
             A tela não disse que o perfil está atrasado em relação ao trabalho.

             São 30 concluídas hoje contra 27 no recorte gravado. Sem esta contagem, um
             perfil de dezembro parece atual em junho, e quem lê decide com texto velho sem
             saber que é velho — FR-016.
             """
    end

    test "sem tarefa nova, a tela diz que o texto sairia igual", ctx do
      material_suficiente(ctx)
      gravar_perfil(ctx, %{tasks_closed: 30})

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "would say the same",
             """
             A tela ofereceu regeração sem dizer que ela não mudaria nada.

             Cada geração custa uma chamada, e oferecer sem avisar convida a gastar por nada.
             """
    end
  end

  describe "a tela recarrega sozinha" do
    test "o perfil aparece sem um novo live/2 quando a geração termina", ctx do
      material_suficiente(ctx)
      {:ok, live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
      refute html =~ "Demonstrated skills"

      # O job termina **depois** de a tela estar aberta, que é o caso real.
      gravar_perfil(ctx)
      TheBand.Profiles.broadcast(ctx.tenant.id, ctx.pessoa.id, :pronto)

      assert render(live) =~ "Demonstrated skills",
             """
             A tela não recarregou quando a geração terminou.

             A geração leva de 25 a 60 segundos. Sem isto a tela manda "reload to see it" —
             a plataforma pedindo à pessoa que faça o trabalho dela.
             """
    end

    test "a falha também chega, e é nomeada", ctx do
      material_suficiente(ctx)
      {:ok, live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      TheBand.Profiles.broadcast(ctx.tenant.id, ctx.pessoa.id, {:falhou, {:http, 429, "rate"}})

      assert render(live) =~ "the provider answered 429",
             """
             A falha não chegou à tela.

             Anunciar só o sucesso transforma erro em espera infinita, e espera infinita é
             indistinguível de "ainda rodando" para quem olha. É a mesma família do defeito
             que mais reincide neste repositório.
             """
    end

    test "a mensagem de falha não despeja o corpo da resposta do provedor", ctx do
      material_suficiente(ctx)
      {:ok, live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      TheBand.Profiles.broadcast(
        ctx.tenant.id,
        ctx.pessoa.id,
        {:falhou, {:http, 500, "corpo enorme com detalhe interno do provedor"}}
      )

      html = render(live)
      assert html =~ "the provider answered 500"
      refute html =~ "detalhe interno do provedor"
    end
  end

  describe "quando não há perfil" do
    test "sem designação alguma, a recusa diz que não há de onde olhar", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "No current assignment observed"
      refute html =~ "Generate profile"
    end

    test "a recusa não sugere que a pessoa produziu pouco", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ ~r/produced (little|few)/i
      refute html =~ "low output"

      assert html =~ "nothing to read from",
             """
             A recusa não disse que a falta é do registro.

             "Não há de onde olhar" e "esta pessoa fez pouco" são frases diferentes, e só a
             primeira é afirmável a partir deste material.
             """
    end
  end

  describe "o egresso de dado" do
    test "a frase acompanha o botão, e não o rodapé", ctx do
      material_suficiente(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Generate profile"

      assert html =~ "external language-model provider",
             """
             A tela oferece a geração sem dizer que o texto das tarefas sai da plataforma.

             Quem decide precisa saber o que sai daqui **no momento de decidir** — depois já
             saiu.
             """
    end
  end

  # Material acima de todos os pisos: 30 tarefas concluídas, todas com corpo, espalhadas.
  defp material_suficiente(ctx) do
    base = ~U[2025-02-10 12:00:00Z]

    for n <- 1..30 do
      fechada = DateTime.add(base, n * 15, :day)

      {:ok, issue} =
        TheBand.WorkItems.record_collected_issue(ctx.tenant, %{
          observed_repository_id: ctx.repo_id,
          number: 7000 + n,
          title: "tarefa ##{n}",
          body: String.duplicate("contexto e decisão. ", 25),
          state: "CLOSED",
          author_login: "pessoa-de-teste",
          external_created_at: DateTime.add(fechada, -4, :day),
          external_closed_at: fechada,
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "I_perfil_tela_#{n}"
        })

      {:ok, _} =
        TheBand.WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: "pessoa-de-teste", external_id: "U_perfil_teste", person_id: ctx.pessoa.id}
        ])
    end
  end
end
