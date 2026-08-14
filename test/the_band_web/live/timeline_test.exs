defmodule TheBandWeb.TimelineTest do
  @moduledoc """
  A timeline na página da issue, e o cycle time que a plataforma recusa (T009, T010).

  ## O que estes testes protegem

  Não é que a sequência apareça — é que **nada seja escondido nem substituído**:

    * o evento de robô é exibido dizendo que não houve executor humano, e não omitido;
    * o tipo que a rede não nomeia aparece com o nome da origem;
    * onde o cycle time não pode ser calculado, **lead time não entra no lugar**.

  O último é o que mais importa. As duas medidas respondem perguntas diferentes, e
  trocá-las em silêncio produziria um número plausível sobre o qual alguém decidiria.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    issue = cenario.issues[1].pai
    %{conn: log_in(conn, user), tenant: tenant, issue: issue}
  end

  defp atividade(tenant, issue, attrs) do
    {:ok, atividade} =
      SPO.record_activity(
        tenant,
        Map.merge(
          %{
            activity_type: "ClosedEvent",
            occurred_at: ~U[2026-08-12 20:54:47Z],
            subject_type: "issue",
            subject_id: issue.id,
            source_system: "github",
            source_instance: "https://github.com"
          },
          attrs
        )
      )

    atividade
  end

  describe "a sequência" do
    test "os eventos aparecem em ordem, com autor e instante", ctx do
      atividade(ctx.tenant, ctx.issue, %{
        activity_type: "AssignedEvent",
        occurred_at: ~U[2026-08-10 09:00:00Z],
        performer_login: "alguem"
      })

      atividade(ctx.tenant, ctx.issue, %{
        activity_type: "ClosedEvent",
        occurred_at: ~U[2026-08-14 13:01:06Z],
        performer_login: "alguem"
      })

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      assert html =~ "Timeline"
      assert html =~ "AssignedEvent"
      assert html =~ "ClosedEvent"

      posicao_designacao = :binary.match(html, "AssignedEvent") |> elem(0)
      posicao_fechamento = :binary.match(html, "ClosedEvent") |> elem(0)

      assert posicao_designacao < posicao_fechamento, """
      A sequência apareceu fora de ordem cronológica.

      É a história do que aconteceu com a issue, e invertê-la faz a tela contá-la de trás
      para frente.
      """
    end

    test "o evento de automação é exibido dizendo que não houve pessoa", ctx do
      atividade(ctx.tenant, ctx.issue, %{
        activity_type: "ProjectV2ItemStatusChangedEvent",
        performer_login: "github-project-automation",
        payload: %{"previousStatus" => "", "status" => "Done"}
      })

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      assert html =~ "github-project-automation", """
      A movimentação de robô sumiu da tela.

      160 das 357 movimentações medidas em 2026-08-14 são de automação. Escondê-las
      contaria uma história falsa: a issue pareceria ter sido movida por ninguém, ou não
      ter sido movida.
      """

      assert html =~ "not a known person"
    end

    test "o tipo que a rede não nomeia aparece com o nome da origem", ctx do
      atividade(ctx.tenant, ctx.issue, %{activity_type: "LabeledEvent", concept_id: nil})

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      assert html =~ "LabeledEvent"

      assert html =~ "unnamed by the network", """
      O tipo sem conceito apareceu sem dizer que a rede não o nomeia.

      Nulo aqui é INFORMAÇÃO — é o que diz o que falta mapear —, e exibi-lo como um
      evento qualquer perderia exatamente essa informação.
      """
    end

    test "a movimentação mostra o estado anterior e o novo", ctx do
      atividade(ctx.tenant, ctx.issue, %{
        activity_type: "ProjectV2ItemStatusChangedEvent",
        payload: %{"previousStatus" => "", "status" => "Done"}
      })

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      assert html =~ "no state", """
      O estado anterior vazio virou uma seta saindo do nada.

      `previousStatus` vem VAZIO na primeira transição, e dizer "no state" é o que
      informa: o cartão não estava em estado nenhum antes.
      """

      assert html =~ "Done"
    end

    test "issue sem atividade diz que nada foi coletado, e não que nada aconteceu", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      # O trecho é curto de propósito: o HEEx quebra parágrafos longos em várias linhas,
      # e a frase inteira nunca aparece contígua no HTML.
      assert html =~ "That is not the same as nothing having", """
      A tela mostrou lista vazia sem distinguir "não olhei" de "não houve".

      É a L57 na exibição: ausência de dado lida como ausência de fato.
      """
    end
  end

  describe "o cycle time que a plataforma recusa" do
    test "sem movimentação, diz que não coletou — e não que o processo está bem", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      assert html =~ "Cycle time"
      assert html =~ "No board movement has been collected"
      assert html =~ "the platform has not looked"
    end

    test "com movimentação e sem estado de andamento, aponta o antipadrão do quadro", ctx do
      atividade(ctx.tenant, ctx.issue, %{
        activity_type: "ProjectV2ItemStatusChangedEvent",
        payload: %{"previousStatus" => "Backlog", "status" => "Done"}
      })

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      assert html =~ "no state that means work in progress"

      assert html =~ "process.ap05", """
      A tela não nomeou o antipadrão estrutural.

      A consequência é o que importa: a medida é impossível para TODA issue do quadro, e
      quem lê precisa saber que o conserto é no quadro, e não nesta issue.
      """

      assert html =~ "every issue on this board"
    end

    test "nunca mostra lead time no lugar do cycle time", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{ctx.issue.id}")

      [_inteiro, bloco] = String.split(html, "Cycle time", parts: 2)
      bloco = String.slice(bloco, 0, 1200)

      refute bloco =~ "Lead time", """
      A tela ofereceu lead time onde o cycle time foi pedido — FR-009.

      São medidas diferentes: o lead time inclui o tempo em que ninguém tocou na issue.
      Trocá-las em silêncio faz a organização decidir sobre um número que responde outra
      pergunta, e ninguém percebe porque o número parece plausível.
      """
    end
  end
end
