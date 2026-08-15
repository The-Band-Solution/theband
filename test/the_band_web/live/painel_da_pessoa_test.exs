defmodule TheBandWeb.PainelDaPessoaTest do
  @moduledoc """
  O painel de trabalho na página da pessoa — feature 023.

  ## A asserção que carrega a feature é a da cobertura

  Medido em 2026-08-15: 5 de 53 repositórios têm timeline. Uma pessoa com 152 issues abertas
  pode ter **nenhuma** observada, e mostrar `0 atividades` ali diria que ela não trabalhou —
  quando a mesma pessoa concluiu 199 issues.

  Por isso o teste que mais importa aqui **não** é o que confere um número: é o que afirma
  que a tela **avisa** quando não olhou, e que os gráficos **continuam valendo** porque não
  dependem da timeline.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    {:ok, pessoa} = pessoa(tenant, "ana")
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario, pessoa: pessoa}
  end

  defp pessoa(tenant, login) do
    EO.upsert_person_from_source(tenant, %{
      login: login,
      name: String.capitalize(login),
      account_type: "person",
      source_system: "github",
      source_instance: "https://github.com",
      external_id: "U_#{login}",
      collected_at: DateTime.utc_now(:second)
    })
  end

  # Designa a issue à pessoa e opcionalmente a fecha, mexendo nas datas da origem — que é de
  # onde os dois gráficos saem.
  defp trabalhar(ctx, issue, opts) do
    {:ok, _} =
      WorkItems.replace_assignees(ctx.tenant, issue.id, [
        %{login: ctx.pessoa.login, person_id: ctx.pessoa.id}
      ])

    issue
    |> Ecto.Changeset.change(
      external_created_at: opts[:criada],
      external_closed_at: opts[:fechada]
    )
    |> Repo.update!()
  end

  describe "a cobertura da observação" do
    test "sem timeline coletada, a tela avisa em vez de mostrar zero", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-05-01 09:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "has not collected the timeline", """
      A tela não avisou que a plataforma não olhou o trabalho desta pessoa.

      Sem esse aviso, qualquer zero na tela lê como "não trabalhou". A ambiguidade recai
      sobre uma pessoa, e é o custo mais alto que a L57 já teve neste projeto.
      """

      assert html =~ "do not depend on this", """
      A tela avisou da lacuna sem dizer o que continua valendo.

      Os dois gráficos saem das datas da própria issue e têm cobertura completa. Um aviso
      que não distingue isso faz alguém descartar a tela inteira.
      """
    end

    test "sem trabalho aberto, a tela não acusa lacuna nenhuma", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "has not collected the timeline", """
      A tela acusou lacuna de cobertura numa pessoa sem trabalho aberto.

      `0 de 0` e `0 de 152` são situações diferentes. Avisar na primeira é ruído, e ruído
      treina quem lê a ignorar o aviso da segunda.
      """
    end
  end

  describe "os gráficos" do
    test "as concluídas aparecem por mês, e o mês vazio no meio não some", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-01-20 09:00:00Z]
      )

      trabalhar(ctx, hd(ctx.cenario.issues[1].partes),
        criada: ~U[2026-03-01 09:00:00Z],
        fechada: ~U[2026-03-10 09:00:00Z]
      )

      meses = WorkItems.closed_by_month(ctx.tenant, ctx.pessoa.id)

      assert Enum.map(meses, & &1.month) == ["2026-01", "2026-02", "2026-03"], """
      Fevereiro sumiu da série.

      Ele é um zero real: a pessoa não fechou nada naquele mês. Omiti-lo comprime o tempo e
      faz janeiro parecer colado em março — a série passaria a mentir sobre o ritmo.
      """

      assert Enum.find(meses, &(&1.month == "2026-02")).count == 0

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
      assert html =~ "Issues completed over time"
    end

    test "as faixas de idade vêm todas, inclusive as vazias", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai, criada: DateTime.utc_now(:second))

      faixas = WorkItems.open_age_buckets(ctx.tenant, ctx.pessoa.id)

      assert Enum.map(faixas, & &1.label) ==
               ["até 7d", "7–30d", "30–90d", "90–180d", "mais de 180d"],
             """
             Uma faixa sumiu da lista porque estava vazia.

             Com faixas variáveis, o eixo muda de pessoa para pessoa, e comparar duas telas vira
             ilusão de ótica: a mesma barra ocuparia posições diferentes.
             """

      assert Enum.find(faixas, &(&1.label == "até 7d")).count == 1
      assert Enum.find(faixas, &(&1.label == "mais de 180d")).count == 0
    end
  end

  describe "o lead time" do
    test "aparece como lead time, e diz que não é cycle time", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-01 09:00:00Z],
        fechada: ~U[2026-01-11 09:00:00Z]
      )

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Lead time of completed issues"

      assert html =~ "This is lead time, not cycle time", """
      A tela exibiu um tempo sem dizer qual tempo é.

      Lead time inclui o período em que ninguém tocou na issue. Sem a frase, quem lê assume
      cycle time e decide sobre um número que responde outra pergunta — FR-009 da 022.
      """

      assert html =~ "never the mean", """
      A tela não disse por que mostra mediana e p85.

      Uma issue parada por 400 dias move a média e não move a mediana, e quem não sabe disso
      pede a média de volta.
      """
    end

    test "sem issue concluída, a seção não aparece com zeros", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-05-01 09:00:00Z])

      assert WorkItems.lead_time(ctx.tenant, ctx.pessoa.id) == nil, """
      Sem nenhuma issue concluída, o lead time devolveu um número.

      `nil` e `0 dias` são coisas diferentes: o segundo afirma que as issues fecham no mesmo
      dia, quando nenhuma fechou.
      """

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
      refute html =~ "Lead time of completed issues"
    end
  end

  describe "os antipadrões da pessoa" do
    test "sem movimentação coletada, diz que não avaliou — e não que nada achou", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-05-01 09:00:00Z])

      resultado = Antipatterns.detect_for_person(ctx.tenant, ctx.pessoa.id)

      assert resultado.avaliadas == 0
      assert resultado.nao_avaliadas == 1
      assert resultado.achados == []

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "nothing was evaluated", """
      A tela disse "nada encontrado" onde a detecção disse "não olhei".

      As duas produzem a mesma seção vazia e afirmam o oposto. Medido em 2026-08-15: para
      quase toda pessoa, a maioria das issues cai no primeiro caso — então esta é a frase
      que mais aparece, e a que mais engana se estiver errada.
      """

      assert html =~ "not the same as finding nothing"
    end

    test "com movimentação, o achado aparece contado e sem julgar ninguém", ctx do
      issue = trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-05-01 09:00:00Z])

      {:ok, _} =
        SPO.record_activity(ctx.tenant, %{
          activity_type: "ProjectV2ItemStatusChangedEvent",
          occurred_at: ~U[2026-05-02 09:00:00Z],
          subject_type: "issue",
          subject_id: issue.id,
          source_system: "github",
          source_instance: "https://github.com",
          performer_login: "github-project-automation",
          payload: %{"previousStatus" => "Backlog", "status" => "Done"}
        })

      resultado = Antipatterns.detect_for_person(ctx.tenant, ctx.pessoa.id)

      assert resultado.avaliadas == 1
      assert resultado.nao_avaliadas == 0

      assert Enum.any?(resultado.achados, &(&1.id == "process.ap03.assigned_and_never_started")),
             """
             A issue foi designada, está aberta, e só o robô a moveu — e o ap03 não apareceu.

             Movimentação de automação não conta como início: um cartão que o robô moveu diz que a
             issue mudou de estado, não que alguém trabalhou nela.
             """

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Assigned and never started"

      assert html =~ "not judgements about people", """
      O achado apareceu sem a frase que o enquadra.

      Sem ela, "designada e nunca iniciada" lê como acusação de quem está designado.
      """
    end

    test "as duas contagens convivem, e a tela diz sobre quantas avaliou", ctx do
      avaliada = trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-05-01 09:00:00Z])
      trabalhar(ctx, hd(ctx.cenario.issues[1].partes), criada: ~U[2026-05-01 09:00:00Z])

      {:ok, _} =
        SPO.record_activity(ctx.tenant, %{
          activity_type: "ProjectV2ItemStatusChangedEvent",
          occurred_at: ~U[2026-05-02 09:00:00Z],
          subject_type: "issue",
          subject_id: avaliada.id,
          source_system: "github",
          source_instance: "https://github.com",
          performer_login: "alguem",
          payload: %{"previousStatus" => "Backlog", "status" => "Done"}
        })

      resultado = Antipatterns.detect_for_person(ctx.tenant, ctx.pessoa.id)

      assert resultado.avaliadas == 1

      assert resultado.nao_avaliadas == 1, """
      A cobertura parcial foi achatada numa contagem só.

      Somar avaliadas e não avaliadas e mostrar "0 antipadrões em 2 issues" afirmaria saúde
      de processo sobre uma issue que ninguém olhou.
      """

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
      # Trecho contíguo: o HEEx quebra o parágrafo, e a frase inteira nunca aparece junta.
      assert html =~ "collected movement and were not evaluated"
    end
  end

  describe "o isolamento entre tenants" do
    test "o painel de outro tenant não é alcançável", ctx do
      {outro, outro_user} = tenant_with_admin()
      _ = outro
      conn = log_in(Phoenix.ConnTest.build_conn(), outro_user)

      assert {:error, {:live_redirect, %{to: destino}}} =
               live(conn, ~p"/people/#{ctx.pessoa.id}")

      assert destino == ~p"/people"
    end
  end
end
