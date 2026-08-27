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
  alias TheBand.Ontology.Continuum.SRO
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

    # Issue #369: a aba de trabalho só abre para quem a plataforma sabe que é. Sem o elo,
    # nem a própria pessoa alcança o próprio painel — e é de propósito.
    elo_de_identidade(tenant, user, pessoa)

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
  defp caixa(ctx, titulo, inicio, dias) do
    {:ok, s} =
      SRO.record_sprint(ctx.tenant, %{
        connected_tool_id: ctx.cenario.tool.id,
        board_number: 31,
        board_title: "DevOps",
        field_name: "Sprint",
        title: titulo,
        started_on: inicio,
        duration_days: dias,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{titulo}"
      })

    s
  end

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
      assert html =~ "Issues assigned to them, over time"
    end

    # A contradição aparente que a pessoa mantenedora encontrou em 2026-08-27: `fatasy`
    # tem **8** issues designadas e **233** abertas por ele. O gráfico mostrava 8 e o
    # cartão abaixo 233, e as duas legendas diziam "opened" — a mesma palavra para
    # perguntas diferentes.
    #
    # As contas estavam certas; o rótulo estava errado. Abrir uma issue e trabalhar nela
    # são coisas diferentes, e a página já separava as duas no cartão.
    test "o gráfico diz de QUEM são as issues, e não colide com autoria", ctx do
      # Uma designada a ela, e outra que ela abriu sem estar designada.
      trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-01-05 09:00:00Z])

      outra = hd(ctx.cenario.issues[1].partes)

      outra
      |> Ecto.Changeset.change(author_person_id: ctx.pessoa.id)
      |> Repo.update!()

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Issues assigned to them, over time", """
      O título do gráfico não diz de quem são as issues contadas.

      Sem isso ele parece contradizer o cartão de autoria logo abaixo — e o número que
      parece errado é o que a pessoa vai acreditar.
      """

      assert html =~ "are a different number", """
      A tela não diz que autoria é OUTRO número.

      `fatasy`: 8 designadas contra 233 abertas por ele. Os dois estão certos, e sem a
      frase o leitor conclui que um deles está quebrado.
      """

      refute html =~ ">created<" and html =~ "opened by", """
      A palavra "opened" voltou para a série do gráfico.

      Ela é da AUTORIA no cartão abaixo — `opened by`. Reusá-la para designadas foi
      exatamente o defeito de 2026-08-27.
      """
    end

    test "as duas séries vêm juntas, e o período vazio no meio não some", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-01-20 09:00:00Z]
      )

      trabalhar(ctx, hd(ctx.cenario.issues[1].partes),
        criada: ~U[2026-03-01 09:00:00Z],
        fechada: ~U[2026-03-10 09:00:00Z]
      )

      serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, :mes)

      assert Enum.map(serie, & &1.periodo) == ["2026-01", "2026-02", "2026-03"]

      assert Enum.find(serie, &(&1.periodo == "2026-02")) == %{
               periodo: "2026-02",
               criadas: 0,
               fechadas: 0
             }

      assert Enum.find(serie, &(&1.periodo == "2026-01")) == %{
               periodo: "2026-01",
               criadas: 1,
               fechadas: 1
             },
             """
             As duas séries não vieram na mesma linha do período.

             Elas saem de colunas diferentes da mesma tabela, e a união dos dois agrupamentos
             existe para responder em UMA consulta — a página está no teto medido.
             """
    end

    test "a escala muda a série, e as três contam o mesmo total", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-01-20 09:00:00Z]
      )

      trabalhar(ctx, hd(ctx.cenario.issues[1].partes),
        criada: ~U[2026-03-01 09:00:00Z],
        fechada: ~U[2026-03-10 09:00:00Z]
      )

      totais =
        for escala <- WorkItems.escalas() do
          serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, escala)
          {escala, Enum.sum(Enum.map(serie, & &1.criadas)), length(serie)}
        end

      assert [{:semana, 2, semanas}, {:mes, 2, 3}, {:ano, 2, 1}] = totais, """
      Trocar a escala mudou o TOTAL, e não só o agrupamento.

      Duas issues criadas são duas em qualquer escala. Um total que muda com o agrupamento
      significa dupla contagem — uma issue caindo em dois períodos —, e é o defeito clássico
      de janela de tempo com borda mal fechada.
      """

      assert semanas > 3, "a escala semanal não abriu mais períodos que a mensal"
    end

    # `external_created_at` é anulável, e hoje o banco de desenvolvimento não tem nenhuma
    # — medido em 2026-08-27, 0 de 5.216. A guarda existe para o dia em que a origem
    # devolver uma sem data: `to_char(NULL, ...)` é NULL, e um período nulo viraria uma
    # barra sem rótulo no meio da série.
    test "issue sem data de criação não vira período nulo", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-01-20 09:00:00Z]
      )

      trabalhar(ctx, hd(ctx.cenario.issues[1].partes), criada: nil, fechada: nil)

      serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, :mes)

      assert [%{periodo: "2026-01", criadas: 1, fechadas: 1}] = serie, """
      Uma issue sem data de criação entrou na série.

      `to_char(NULL, ...)` é NULL, e ela viraria um período sem rótulo — uma barra que o
      eixo não nomeia e que ninguém consegue situar no tempo.
      """

      refute Enum.any?(serie, &is_nil(&1.periodo))
    end

    test "a semana ISO da virada do ano não colide", ctx do
      # 29/12/2025 é segunda-feira da semana 1 de 2026 pela ISO. Com `YYYY` em vez de
      # `IYYY`, o rótulo sairia `2025-W01` — o mesmo de janeiro de 2025.
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2025-12-29 09:00:00Z],
        fechada: ~U[2025-12-30 09:00:00Z]
      )

      serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, :semana)

      assert [%{periodo: "2026-W01", criadas: 1, fechadas: 1}] = serie, """
      A semana da virada do ano recebeu o rótulo do ano civil.

      A ISO põe 29/12/2025 na semana 1 de 2026. Com `YYYY`, dezembro e janeiro do mesmo ano
      civil dividiriam `2025-W01`, e duas semanas distantes somariam na mesma barra.
      """
    end

    test "escala desconhecida no endereço cai no mês, e não derruba a tela", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?escala=decada")

      assert html =~ "Issues assigned to them, over time", """
      Uma escala inválida no endereço derrubou a página.

      O valor chega até o `to_char` do Postgres, e formato inválido ali é erro de banco numa
      página de leitura. A lista de escalas é fechada, e o que não está nela vira o padrão.
      """
    end

    test "trocar a escala preserva a busca", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?q=agulha")

      live |> element("button[phx-value-escala=semana]") |> render_click()

      assert_patched(live, ~p"/people/#{ctx.pessoa.id}?escala=semana&q=agulha")
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

  describe "burn-up, burn-down e a projeção" do
    test "o acumulado sobe, e o aberto é a diferença das duas linhas", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-03-10 09:00:00Z]
      )

      trabalhar(ctx, hd(ctx.cenario.issues[1].partes), criada: ~U[2026-02-01 09:00:00Z])

      burn =
        ctx.tenant
        |> WorkItems.state_changes_by_period(ctx.pessoa.id, :mes)
        |> WorkItems.burn()

      assert [
               %{periodo: "2026-01", escopo: 1, feito: 0, aberto: 1},
               %{periodo: "2026-02", escopo: 2, feito: 0, aberto: 2},
               %{periodo: "2026-03", escopo: 2, feito: 1, aberto: 1}
             ] = burn,
             """
             O acumulado não bate.

             `escopo` e `feito` só sobem — são acumulados —, e `aberto` é exatamente a diferença
             dos dois. Se `aberto` fosse uma série própria, ela poderia divergir das outras duas e
             a tela mostraria três números que não fecham entre si.
             """
    end

    test "sem trabalho aberto, a projeção diz isso e não uma data", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-01-20 09:00:00Z]
      )

      serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, :mes)
      assert WorkItems.projecao(serie) == :sem_trabalho_aberto
    end

    test "escopo crescendo mais rápido que o fechamento NÃO vira data", ctx do
      # Três criadas, uma fechada: abre mais do que fecha.
      trabalhar(ctx, ctx.cenario.issues[1].pai,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-01-20 09:00:00Z]
      )

      for parte <- Enum.take(ctx.cenario.issues[1].partes, 3) do
        trabalhar(ctx, parte, criada: ~U[2026-02-01 09:00:00Z])
      end

      serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, :mes)

      assert {:nao_converge, criadas, fechadas} = WorkItems.projecao(serie), """
      A projeção deu uma data para quem abre mais do que fecha.

      Dividir o aberto por um líquido negativo ou zero produz número, e apresentá-lo como
      previsão é aritmética disfarçada. A resposta certa é que no ritmo atual não termina.
      """

      assert criadas > fechadas
    end

    # Para cair aqui a JANELA precisa ser menor que a série: escopo antigo pesando sobre um
    # ritmo recente que fecha, mas quase de empate. Se a janela cobrisse a série inteira, o
    # líquido seria exatamente `-aberto`, e a resposta seria sempre `nao_converge`.
    test "ritmo quase empatado NÃO projeta além do observado", ctx do
      partes = Enum.take(ctx.cenario.issues[4].partes, 16)

      # Dezesseis criadas em janeiro, e nenhuma fechada ali.
      for parte <- partes, do: trabalhar(ctx, parte, criada: ~U[2026-01-05 09:00:00Z])

      # Uma fechada por mês, de fevereiro a julho: seis períodos de líquido +1.
      meses = [
        ~U[2026-02-10 09:00:00Z],
        ~U[2026-03-10 09:00:00Z],
        ~U[2026-04-10 09:00:00Z],
        ~U[2026-05-10 09:00:00Z],
        ~U[2026-06-10 09:00:00Z],
        ~U[2026-07-10 09:00:00Z]
      ]

      for {parte, fim} <- Enum.zip(partes, meses) do
        trabalhar(ctx, parte, criada: ~U[2026-01-05 09:00:00Z], fechada: fim)
      end

      serie = WorkItems.state_changes_by_period(ctx.tenant, ctx.pessoa.id, :mes)

      assert {:alem_do_observado, periodos, observados} = WorkItems.projecao(serie), """
      A projeção deu uma data mais longa do que a série observada.

      Medido em 2026-08-27 no banco de desenvolvimento: `CaioLessaSimao` fecharia em 78
      meses a partir de 16 observados, e `tadeuaugustovs` em 171. Os dois "convergem" pela
      conta, e nenhum dos números é informação — é divisão por quase-zero apresentada como
      previsão.
      """

      assert periodos > observados
    end

    # O prazo é do trabalho ABERTO. Incluir a fechada daria a data da caixa dela, e uma
    # caixa que termina depois folgaria o prazo de quem ainda tem trabalho para entregar.
    test "o prazo é da caixa do trabalho ABERTO, e não da caixa da fechada", ctx do
      aberta = ctx.cenario.issues[1].pai
      fechada = hd(ctx.cenario.issues[1].partes)

      trabalhar(ctx, aberta, criada: ~U[2026-01-05 09:00:00Z])

      trabalhar(ctx, fechada,
        criada: ~U[2026-01-05 09:00:00Z],
        fechada: ~U[2026-02-10 09:00:00Z]
      )

      cedo = caixa(ctx, "Sprint 1", ~D[2026-02-01], 14)
      tarde = caixa(ctx, "Sprint 9", ~D[2026-08-01], 14)

      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, cedo.id, aberta.id)
      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, tarde.id, fechada.id)

      assert %{prazo: ~D[2026-02-14], sem_caixa: 0} =
               WorkItems.prazo_do_trabalho_aberto(ctx.tenant, ctx.pessoa.id),
             """
             O prazo veio da caixa de uma issue já fechada.

             A pergunta é até quando o que AINDA está aberto foi planejado. Uma caixa que termina
             em agosto, de trabalho entregue em fevereiro, folgaria o prazo de quem ainda deve.
             """
    end

    test "issue aberta fora de caixa nenhuma conta à parte, e não some", ctx do
      dentro = ctx.cenario.issues[1].pai
      fora = hd(ctx.cenario.issues[1].partes)

      trabalhar(ctx, dentro, criada: ~U[2026-01-05 09:00:00Z])
      trabalhar(ctx, fora, criada: ~U[2026-01-06 09:00:00Z])

      c = caixa(ctx, "Sprint 1", ~D[2026-02-01], 14)
      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, c.id, dentro.id)

      assert %{prazo: ~D[2026-02-14], sem_caixa: 1} =
               WorkItems.prazo_do_trabalho_aberto(ctx.tenant, ctx.pessoa.id),
             """
             A issue aberta sem caixa sumiu, ou foi somada ao prazo.

             Trabalho sem caixa não tem data planejada. Atribuir-lhe a data de outra caixa
             inventaria uma promessa, e omiti-lo faria o prazo falar por trabalho que ele não
             cobre — foi o que o dado real mostrou: 111 de 156 abertas de uma pessoa sem caixa
             nenhuma, com o prazo falando por 45.
             """
    end

    test "a tela mostra o burn e o prazo declarado", ctx do
      trabalhar(ctx, ctx.cenario.issues[1].pai, criada: ~U[2026-01-05 09:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Work assigned to them: accumulated, and what is left"
      assert html =~ "scope (created)" and html =~ "done (closed)"

      assert html =~ "No planned end date", """
      A ausência de prazo não foi nomeada.

      Nenhuma issue desta pessoa está em caixa de tempo, então nada declara quando o
      trabalho deveria terminar. A plataforma não infere um do ritmo — e dizer nada faria
      parecer que o prazo existe e não coube na tela.
      """
    end
  end

  describe "os três papéis na mudança — feature 044" do
    test "os três números aparecem separados, e a soma NÃO aparece", ctx do
      cr = solicitacao_044(ctx, 7001, ctx.pessoa)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "opened" and html =~ "reviewed" and html =~ "integrated"

      refute html =~ ">3<" and html =~ "total", """
      A soma dos três papéis apareceu.

      Abrir, revisar e integrar são participações distintas. `793 + 844 + 627` não
      significa coisa alguma, e oferecer o total convida a lê-lo como volume de trabalho.
      """

      assert cr
    end

    test "o veredito é nomeado pelo conceito, e nunca pelo enum do GitHub", ctx do
      cr = solicitacao_044(ctx, 7002)
      avaliar_044(ctx, cr, ctx.pessoa, "APPROVED")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "endorsed", "o rótulo do conceito não apareceu"

      refute html =~ "APPROVED", """
      O enum do GitHub apareceu na tela.

      A plataforma tem vocabulário próprio desde 2026-08-27 — `qapo.endorsing_verdict` —, e
      mostrar `APPROVED` prenderia a leitura ao enum de um forjador. Gerrit chama a mesma
      posição de `+2`.
      """
    end

    test "a tela NÃO diz que endossar é ausência de problema", ctx do
      cr = solicitacao_044(ctx, 7003)
      avaliar_044(ctx, cr, ctx.pessoa, "APPROVED")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "not blocking", "a frase que separa endosso de conformidade sumiu"

      # O regex mira a AFIRMAÇÃO, e não as palavras. A primeira versão do texto da tela
      # dizia «and never "nothing was found"» — uma negação correta que o `refute` pegava
      # como se fosse a afirmação. A frase foi reescrita, e o padrão continua estreito de
      # propósito: ele existe para pegar quem escrever a afirmação, não quem a negar.
      refute html =~ ~r/no issues found|nothing (was )?found|clean review/i, """
      A tela afirmou que endossar é não ter encontrado problema.

      A rede declara o contrário: `qapo.artifact_evaluation_identified_noncompliance` tem
      `many` no destino porque INCLUI zero e não o exige. Uma avaliação que endossa pode ter
      registrado ressalvas — FR-011.
      """
    end

    test "a diferença entre revisões e vereditos é dita quando existe", ctx do
      cr = solicitacao_044(ctx, 7004)
      avaliar_044(ctx, cr, ctx.pessoa, "COMMENTED", "R_a")
      avaliar_044(ctx, cr, ctx.pessoa, "APPROVED", "R_b")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "positions taken", """
      A tela não explicou por que a soma dos vereditos é maior que as revisões.

      Medido: `vinicius-je` revisou 627 solicitações com 721 avaliações. Sem a frase, quem
      lê conclui que um dos números está quebrado — foi exatamente o que aconteceu com
      `fatasy`, com 8 designadas e 233 abertas.
      """
    end

    test "e NÃO é dita quando os dois números coincidem", ctx do
      cr = solicitacao_044(ctx, 7005)
      avaliar_044(ctx, cr, ctx.pessoa, "APPROVED")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "positions taken", """
      A tela explicou uma diferença que não existe.

      Uma revisão sobre uma solicitação: os dois números são 1. Texto que explica o que não
      aconteceu é ruído, e o olho para de ler o que explica o que aconteceu.
      """
    end

    test "a solicitação revisada aparece na listagem", ctx do
      cr = solicitacao_044(ctx, 7006, nil, "a que ela revisou")
      avaliar_044(ctx, cr, ctx.pessoa, "APPROVED")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Reviewed"
      assert html =~ "a que ela revisou"
    end

    test "a aba fechada NÃO calcula a participação", ctx do
      cr = solicitacao_044(ctx, 7007, ctx.pessoa)
      assert cr

      {:ok, comum} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "membro-044-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      conn = log_in(Phoenix.ConnTest.build_conn(), comum)
      {:ok, _live, html} = live(conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "How they reviewed", """
      A seção de veredito apareceu para quem não pode ver a aba de trabalho.
      """

      # A asserção que importa, e o HTML sozinho NÃO a faz: esconder a seção e calcular
      # tudo passa por qualquer `refute` sobre texto.
      #
      # A CONTAGEM total também não serve aqui: a seção "Changes" é anterior à #369 e vive
      # fora da aba, então `collected_change_requests` é consultada de qualquer jeito. Uma
      # consulta a mais no meio de vinte e cinco não muda a comparação.
      #
      # O que distingue é a ASSINATURA: `collected_artifact_evaluations` é tocada por uma
      # consulta só desta página — a da participação. Se ela aparecer com a aba fechada, a
      # recusa não aconteceu antes da carga (#369 FR-012h).
      consultas =
        TheBand.ContadorDeConsultas.listar(fn ->
          {:ok, _live, _html} = live(conn, ~p"/people/#{ctx.pessoa.id}")
        end)

      abertas =
        TheBand.ContadorDeConsultas.listar(fn ->
          {:ok, _live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
        end)

      conta = fn lista -> Enum.count(lista, &(&1 =~ "collected_change_requests")) end

      assert conta.(consultas) < conta.(abertas), """
      A aba fechada tocou `collected_change_requests` #{conta.(consultas)} vezes, e a aberta
      #{conta.(abertas)} — o mesmo.

      A consulta de participação é a diferença entre as duas, e ela não pode acontecer com a
      aba fechada. Calcular e descartar é fazer o trabalho do vazamento pagando o custo
      dele, e basta uma referência esquecida no template para o número aparecer.

      A contagem TOTAL não serve aqui: a seção "Changes" é anterior à #369, vive fora da
      aba, e consulta essa tabela de qualquer jeito.
      """
    end
  end

  describe "a verificação sobre os commits — feature 044" do
    test "passou e quebrou aparecem separados, e `skipped` não entra em nenhum dos dois",
         ctx do
      commit_044(ctx, "sha_a", ctx.pessoa)
      commit_044(ctx, "sha_b", ctx.pessoa)
      commit_044(ctx, "sha_c", ctx.pessoa)

      execucao_044(ctx, "sha_a", "success")
      execucao_044(ctx, "sha_b", "failure")
      execucao_044(ctx, "sha_c", "skipped")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Checks on their commits"
      assert html =~ "passed" and html =~ "broke"

      assert html =~ ~r/neither.{0,40}skipped/i, """
      A execução pulada não apareceu na terceira posição.

      `skipped` e `cancelled` não são resultado: nenhum código rodou. Somá-los a "passou"
      afirma verificação que não houve, e a "quebrou", defeito que não houve — FR-004.
      """
    end

    test "a parcela sem autoria aparece AO LADO, e não é descontada", ctx do
      commit_044(ctx, "sha_dela", ctx.pessoa)
      execucao_044(ctx, "sha_dela", "success")

      # Duas execuções sobre commit de ninguém: evento sem commit, ou autor não promovido.
      execucao_044(ctx, "sha_de_ninguem_1", "failure")
      execucao_044(ctx, "sha_de_ninguem_2", "success")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ ~r/2 runs in this organisation match no person/, """
      A lacuna da atribuição não foi dita.

      Medido em 2026-08-27: 47% das execuções não casam com pessoa alguma. Mostrar só os
      números atribuídos, sem dizer o tamanho do que ficou de fora, apresenta uma medida
      parcial como se fosse a medida — FR-010.
      """

      assert html =~ ~r/not counted above,\s+and not subtracted\s+from\s+it\s+either/, """
      A frase que diz que a lacuna NÃO foi descontada sumiu.

      Sem ela, quem lê pode supor que os números já descontaram o que não casou — e passar
      a tratar a parcela atribuída como o todo.
      """
    end

    test "sem execução alguma, a tela NOMEIA a ausência em vez de mostrar zero seco", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      # O apóstrofo sai escapado (`person&#39;s`), e a frase quebra em linhas no HEEX —
      # por isso o padrão, e não a string.
      assert html =~ ~r/No check run on this person/, """
      A tela mostrou zero sem dizer por quê.

      Zero aqui tem duas causas distintas — repositório sem workflow, ou commit não
      coletado —, e nenhuma delas é "a pessoa não quebrou nada". A casa não deixa zero
      falar sozinho.
      """
    end

    test "com a aba fechada, a verificação não é NEM consultada", ctx do
      commit_044(ctx, "sha_custo", ctx.pessoa)
      execucao_044(ctx, "sha_custo", "failure")

      {:ok, estranha} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "custo-044@example.test",
          "role" => "member"
        })

      conn = log_in(Phoenix.ConnTest.build_conn(), estranha)

      # `collected_verifications` é tocada por uma consulta só desta página — a de
      # `Verification.por_pessoa/2`. Se ela aparecer com a aba fechada, `se_pode/3` está
      # calculando e jogando fora: paga-se o custo do vazamento sem o vazamento, e basta
      # uma referência esquecida no template para o número aparecer.
      fechada =
        TheBand.ContadorDeConsultas.listar(fn ->
          {:ok, _live, _html} = live(conn, ~p"/people/#{ctx.pessoa.id}")
        end)

      aberta =
        TheBand.ContadorDeConsultas.listar(fn ->
          {:ok, _live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
        end)

      conta = fn lista -> Enum.count(lista, &(&1 =~ "collected_verifications")) end

      assert conta.(fechada) == 0, """
      A aba fechada consultou `collected_verifications` #{conta.(fechada)} vezes.

      A porta da #369 fica ANTES da carga, e não depois: esconder no `:if` deixa o custo
      de pé, e a consulta continua atravessando o tenant de alguém que não pode vê-la.
      """

      assert conta.(aberta) > 0, """
      A aba ABERTA também não consultou `collected_verifications`.

      Sem esta metade, o teste passaria se a consulta tivesse sumido de vez — e diria que a
      recusa funciona quando o que sumiu foi a funcionalidade.
      """
    end

    test "quem não pode ver o trabalho também não vê a verificação", ctx do
      commit_044(ctx, "sha_privado", ctx.pessoa)
      execucao_044(ctx, "sha_privado", "failure")

      # Conta comum do mesmo tenant: não é a pessoa, não lidera o time dela, não responde
      # pela organização, e não é admin.
      {:ok, estranha} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "estranha-044@example.test",
          "role" => "member"
        })

      conn = log_in(Phoenix.ConnTest.build_conn(), estranha)
      {:ok, _live, html} = live(conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "Checks on their commits", """
      A seção de CI apareceu para quem a regra da #369 não autoriza.

      Quebrar a construção é dado de desempenho: quem vê o painel de trabalho de alguém é
      a própria pessoa, quem lidera o time, quem responde pela organização, ou o admin.
      """
    end
  end

  defp commit_044(ctx, sha, autora) do
    {:ok, c} =
      TheBand.Changes.Commands.record_commit(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        sha: sha,
        message_headline: "commit #{sha}",
        external_committed_at: ~U[2026-06-01 10:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "C_044_#{sha}"
      })

    :ok =
      TheBand.Changes.Commands.replace_commit_authors(ctx.tenant, c.id, [
        %{
          author_login: autora.login,
          author_person_id: autora.id,
          author_name: autora.name,
          is_primary: true
        }
      ])

    c
  end

  defp execucao_044(ctx, sha, conclusion) do
    {:ok, v} =
      TheBand.Verification.Commands.record_verification(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        name: "ci",
        head_sha: sha,
        status: "COMPLETED",
        conclusion: conclusion,
        external_started_at: ~U[2026-06-01 11:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "V_044_#{sha}_#{conclusion}"
      })

    v
  end

  defp solicitacao_044(ctx, numero, autora \\ nil, titulo \\ nil) do
    {:ok, cr} =
      TheBand.Changes.Commands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: numero,
        title: titulo || "mudança #{numero}",
        state: "MERGED",
        source_branch: "f-#{numero}",
        target_branch: "main",
        author_person_id: autora && autora.id,
        external_created_at: ~U[2026-06-01 10:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_044_#{numero}"
      })

    cr
  end

  defp avaliar_044(ctx, cr, pessoa, estado, external_id \\ nil) do
    {:ok, _} =
      TheBand.Quality.Commands.record_evaluation(ctx.tenant, %{
        collected_change_request_id: cr.id,
        state: estado,
        body: "corpo",
        external_submitted_at: ~U[2026-06-02 10:00:00Z],
        author_login: pessoa.login,
        author_type: "User",
        author_person_id: pessoa.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: external_id || "R_044_#{cr.number}",
        raw_payload: %{}
      })
  end
end
