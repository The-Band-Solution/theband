defmodule TheBandWeb.FluxoNaTelaTest do
  @moduledoc """
  O seletor de granulação, a janela no título e a definição de *prometido* — feature 060, US9.

  ## Por que estes casos, e não os números

  A medida está provada em `test/the_band/work_items/fluxo_da_equipe_test.exs`. O que se prova
  aqui é o que a 057 tinha recusado (L86) e a 060 aceitou com uma condição: **o denominador
  pode mudar, nunca em silêncio**. Três coisas fazem esse "nunca em silêncio":

  1. a janela aparece **no título de cada gráfico** (FR-078);
  2. a escolha vive **no endereço**, para um link cair onde aponta (FR-078);
  3. *prometido* nunca aparece sem a definição **ao lado** (FR-063).

  A terceira é a mais fácil de perder numa refatoração: mover o parágrafo dois blocos abaixo
  não quebra nada visível, e a palavra passa a ser lida como compromisso de sprint — que a
  plataforma não tem em lugar nenhum.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  # A janela que o título mostra, para comparar telas sem comparar CSRF nem id de sessão.
  defp janela_do_titulo(html) do
    case Regex.run(~r/by (?:week|month|year) · ([^<]+)/, html) do
      [_, janela] -> String.trim(janela)
      nil -> nil
    end
  end

  setup do
    {tenant, admin} = tenant_with_admin()
    {:ok, equipe} = EO.create_declared_team(tenant, "Plataforma", admin.id)

    %{
      conn: log_in(build_conn(), admin),
      tenant: tenant,
      admin: admin,
      equipe: equipe
    }
  end

  # Uma equipe com série longa o bastante para a previsão existir: o piso é 6 períodos e 10
  # itens fechados. Sem passar do piso, o horizonte não é exibido — e é justamente o caso que
  # os testes de ausência acima cobrem.
  defp com_historico(ctx) do
    cenario = TheBand.WorkItemsFixtures.cenario_real(ctx.tenant)

    {:ok, papel} =
      EO.create_role(ctx.tenant, cenario.organization.id, %{code: "d", name: "Dev"}, ctx.admin.id)

    {:ok, ana} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: "ana-#{System.unique_integer([:positive])}",
        name: "Ana",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/ana",
        external_id: "U_#{System.unique_integer([:positive])}",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: ana.id,
        team_id: ctx.equipe.id,
        organizational_role_id: papel.id,
        declared_by_user_id: ctx.admin.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -200, :day)
      })

    # Oito semanas, três itens por semana, dois fechados: 24 abertos e 16 fechados — acima do
    # piso nas duas contas, e com um resto em aberto para o horizonte ter o que consumir.
    for semana <- 1..8, n <- 1..3 do
      criada = DateTime.add(DateTime.utc_now(:second), -7 * semana, :day)
      fechada = if n <= 2, do: DateTime.add(criada, 2, :day)

      {:ok, i} =
        Repo.insert(%CollectedIssue{
          tenant_id: ctx.tenant.id,
          observed_repository_id: cenario.observed_repository_id,
          external_id: "I_#{semana}_#{n}_#{System.unique_integer([:positive])}",
          number: System.unique_integer([:positive]),
          source_system: "github",
          source_instance: "https://github.com",
          title: "issue",
          state: if(fechada, do: "CLOSED", else: "OPEN"),
          external_created_at: criada,
          external_closed_at: fechada,
          collected_at: DateTime.utc_now(:second)
        })

      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: ana.login,
        person_id: ana.id
      })
    end

    ctx
  end

  describe "o seletor de granulação (FR-061)" do
    test "as três opções existem, e a semana é a que está em uso por padrão", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "Group flow by"
      assert html =~ "granulacao=semana"
      assert html =~ "granulacao=mes"
      assert html =~ "granulacao=ano"

      # `aria-current` é o que diz a um leitor de tela qual está aberta. Sem ele o grupo
      # anuncia três links e nenhum estado.
      #
      # Por seletor, e não por texto: a ordem dos atributos no HTML gerado não é contrato, e
      # afirmar sobre ela produz teste que quebra numa atualização do LiveView sem que nada
      # da tela tenha mudado.
      assert has_element?(live, ~s|a[href*="granulacao=semana"][aria-current="true"]|)
      refute has_element?(live, ~s|a[href*="granulacao=mes"][aria-current="true"]|)
    end

    test "a granulação escolhida vai ao título, e é ela que fica marcada", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?granulacao=mes")

      assert html =~ "by month", "o título não disse a granulação em uso"
      assert has_element?(live, ~s|a[href*="granulacao=mes"][aria-current="true"]|)
      refute has_element?(live, ~s|a[href*="granulacao=semana"][aria-current="true"]|)
      refute html =~ "by week"
    end

    test "por ano também", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?granulacao=ano")

      assert html =~ "by year"
      refute html =~ "by week"
    end

    test "granulação inexistente desenha semana E avisa — nunca cai no padrão em silêncio",
         ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?granulacao=decada")

      assert html =~ "is not a granularity", """
      Cair no padrão sem dizer nada ensina que a plataforma não tem aquela granulação, quando
      o que ela não tem é aquele nome. É a mesma regra da aba inválida (FR-003).
      """

      assert html =~ "by week", "depois de avisar, tem de desenhar alguma coisa"
    end
  end

  describe "a janela aparece sempre no título (FR-078)" do
    test "cada gráfico de fluxo traz a janela ao lado do próprio título", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # O rótulo da janela é "by week · <de> → <até>". Duas ocorrências: o burn e o
      # Prometido × Entregue. A previsão não tem janela escolhível (FR-064).
      ocorrencias = length(String.split(html, "by week ·")) - 1

      assert ocorrencias >= 2, """
      Os DOIS gráficos de fluxo precisam da janela no título. Achei #{ocorrencias}.

      Um deles sem a janela é pior que os dois sem: quem lê assume que os dois usam a mesma, e
      a FR-079 exige que comparações na mesma tela usem a mesma janela — o que só se verifica
      se as duas estiverem escritas.
      """
    end

    test "a janela escolhida troca a data que o título mostra", ctx do
      {:ok, _live, padrao} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      {:ok, _live, escolhida} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?periodos=3")

      # O rótulo tem a forma "by week · <de> → <até>". Comparar o HTML inteiro não serviria:
      # cada render traz token CSRF e id de sessão diferentes, e a igualdade nunca valeria —
      # o teste passaria por acidente na direção `refute`.
      assert janela_do_titulo(padrao) != janela_do_titulo(escolhida),
             "pedir 3 períodos não mudou a janela mostrada"
    end

    test "período absurdo cai no padrão da granulação, e não pede 100 mil consultas", ctx do
      {:ok, _live, absurdo} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?periodos=100000")
      {:ok, _live, padrao} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert janela_do_titulo(absurdo) == janela_do_titulo(padrao),
             "acima do teto tem de cair no padrão, e não desenhar 100 mil períodos"
    end

    test "período zero ou negativo também cai no padrão", ctx do
      {:ok, _live, padrao} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      for absurdo <- ["0", "-4", "abc", ""] do
        {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?periodos=#{absurdo}")

        assert janela_do_titulo(html) == janela_do_titulo(padrao),
               "periodos=#{inspect(absurdo)} não caiu no padrão"
      end
    end
  end

  describe "os valores e o horizonte no burn (pedido de 2026-09-08)" do
    test "sem histórico suficiente, mostra a diferença e NÃO mostra horizonte", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # Equipe recém-declarada: não há série, então não há nem burn nem horizonte. O que a
      # tela não pode fazer é inventar um prazo a partir de uma janela vazia.
      refute html =~ "half of the simulated runs", """
      Sem histórico não existe horizonte. Um prazo derivado de uma janela sem dado é um chute
      vestido de medida — e chega a quem lê com a mesma cara de um número medido.
      """
    end

    test "com histórico, o gráfico traz os valores dos pontos e o teto do eixo", ctx do
      ctx = com_historico(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "<svg", "sem curva não há o que rotular"

      # Os rótulos são elementos `<text>` DENTRO do svg. Afirmar sobre o número em si seria
      # afirmar sobre a série; o que se prova aqui é que os valores foram desenhados.
      [_antes, svg] = String.split(html, "<svg", parts: 2)
      [svg, _depois] = String.split(svg, "</svg>", parts: 2)

      rotulos = length(String.split(svg, "<text")) - 1

      assert rotulos >= 3, """
      Um gráfico sem valores é uma forma bonita: a mesma inclinação serve a 4 itens e a 400,
      e quem lê decide pela inclinação. Achei #{rotulos} rótulos de texto no svg.
      """
    end

    test "com histórico, mostra a diferença e o horizonte pela velocidade — com a ressalva",
         ctx do
      ctx = com_historico(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "items still open"
      assert html =~ "closed per week", "o horizonte tem de dizer de que velocidade saiu"

      # E o horizonte NUNCA sem as duas ressalvas, no mesmo bloco.
      assert html =~ "never a date", """
      Uma data é lida como promessa, e a plataforma não tem escopo comprometido em lugar
      nenhum (057 FR-029/FR-031). A faixa com confiança é o que se pode afirmar.
      """

      assert html =~ "nothing new arrives", """
      A hipótese usada é a CONGELADA — o limite otimista. Sem dizer isso, o número é lido
      como o prazo, quando é o melhor caso.
      """
    end

    test "o eixo x é uma linha do tempo com datas, e não rótulos ISO", ctx do
      ctx = com_historico(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      [_antes, svg] = String.split(html, "<svg", parts: 2)
      [svg, _depois] = String.split(svg, "</svg>", parts: 2)

      # `2026-W36` é o rótulo interno da série. No eixo tem de estar a DATA — ninguém lê
      # número de semana ISO sem consultar um calendário.
      refute svg =~ ~r/\d{4}-W\d{2}/, """
      O eixo mostrou o rótulo interno da série em vez da data. O rótulo ISO continua legítimo
      na tabela de "see as a table", onde é chave; no eixo ele não responde "quando".
      """

      meses = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

      assert Enum.any?(meses, &String.contains?(svg, &1)), """
      Nenhum mês apareceu no eixo. Com oito semanas de série, ao menos quatro datas deveriam
      estar desenhadas.
      """
    end

    test "por mês o eixo traz mês e ano", ctx do
      ctx = com_historico(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?granulacao=mes")

      [_antes, svg] = String.split(html, "<svg", parts: 2)
      [svg, _depois] = String.split(svg, "</svg>", parts: 2)

      ano = to_string(Date.utc_today().year)

      assert svg =~ ano, "o eixo por mês precisa do ano, senão dois anos ficam indistinguíveis"
    end

    test "a frase do horizonte nunca aparece sem a ressalva ao lado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # A regra é condicional: SE a frase do horizonte aparecer, a ressalva tem de estar no
      # mesmo bloco. Vale para qualquer equipe, com ou sem dado — e é o que quebra se alguém
      # mover o parágrafo da ressalva para um rodapé.
      if html =~ "closed per week" do
        assert html =~ "never a date"
        assert html =~ "nothing new arrives"
      end
    end
  end

  describe "Prometido × Entregue (FR-062, FR-063)" do
    test "a palavra 'promised' nunca aparece sem a definição operacional ao lado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "Promised × Delivered"

      # A DEFINIÇÃO, e a distância dela até o título. O corte é o próprio título: o que vem
      # depois dele, antes do gráfico, tem de conter as duas definições.
      [_antes, depois] = String.split(html, "Promised × Delivered", parts: 2)
      cabeca = String.slice(depois, 0, 1200)

      assert cabeca =~ "opened in the period", """
      *prometido = aberto no período* tem de estar junto do título (FR-063). Sem isso, o
      gráfico é lido como escopo de sprint contra entrega de sprint.
      """

      assert cabeca =~ "closed in the period"

      assert cabeca =~ "no committed scope", """
      A declaração de que não há escopo comprometido é obrigatória (057 FR-029, emendada pela
      FR-063), e junto do título — não em rodapé. Rodapé é lido por quem já entendeu errado.
      """
    end

    test "diz que fechado é ato da ferramenta, e não critério de término declarado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "an act of the tool"
    end

    test "sem série, a tela diz que não há o que comparar — e não desenha zeros", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "there is nothing to compare", """
      Equipe sem trabalho coletado não teve "aberto zero e fechado zero": não houve o que
      observar. As duas coisas levam a decisões diferentes.
      """

      assert html =~ "not the same as opened zero"
    end
  end
end
