defmodule TheBandWeb.BoardsTest do
  @moduledoc """
  As telas do sprint 017 — T057 (`/boards`) e T058 (excluir repositório).

  ## As asserções que carregam este arquivo

  1. **a ausência de importância é dita** — nenhuma ordem inventada (FR-026);
  2. **campo sem mapeamento aparece como não interpretado** — nunca convertido (FR-025);
  3. **excluir aparece só para admin, grava o autor, e a coleta respeita**;
  4. **o botão continua sendo um botão** — `class` custom não pode engolir a base `btn`,
     que foi como "Associate repositories" ficou invisível de clicar em 2026-08-16;
  5. **nenhum campo de iteração vem com papel sugerido** — a tela mostra duração e volume,
     e quem decide é a organização (issue #514);
  6. **as origens de prazo se somam** — declarar a segunda não apaga a primeira, porque uma
     tarefa dentro de um sprint e ligada a um marco tem os dois prazos (issue #368).
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.Continuum.SMPO
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Projects
  alias TheBand.Tenants

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, cenario: cenario}
  end

  defp quadro(ctx) do
    {:ok, quadro} =
      Projects.record_observed_project(ctx.tenant, %{
        connected_tool_id: ctx.cenario.tool.id,
        number: 31,
        title: "DevOps",
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_b31",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      Projects.record_field_definition(ctx.tenant, %{
        observed_project_id: quadro.id,
        field_external_id: "PVTF_status",
        name: "Status",
        data_type: "SINGLE_SELECT",
        options: [%{"id" => "o1", "name" => "Done"}],
        collected_at: DateTime.utc_now(:second)
      })

    quadro
  end

  # Um campo de iteração de verdade, pelo caminho de produção: `record_iteration/2`
  # promove a `sro.sprint` sozinho. Gravar a caixa à parte criaria uma segunda porta que
  # a coleta não usa, e o teste passaria a provar um caminho que ninguém percorre.
  defp campo_de_iteracao(ctx, quadro, nome, titulo, dias, inicio) do
    agora = DateTime.utc_now(:second)
    id_do_campo = "PVTIF_#{nome}"

    {:ok, _} =
      Projects.record_field_definition(ctx.tenant, %{
        observed_project_id: quadro.id,
        field_external_id: id_do_campo,
        name: nome,
        data_type: "ITERATION",
        collected_at: agora
      })

    {:ok, %{promoted_to: {:sprint, _}}} =
      Projects.record_iteration(ctx.tenant, %{
        observed_project_id: quadro.id,
        connected_tool_id: ctx.cenario.tool.id,
        board_number: quadro.number,
        board_title: quadro.title,
        field_name: nome,
        field_external_id: id_do_campo,
        iteration_external_id: "PVTI_#{titulo}",
        title: titulo,
        start_date: inicio,
        duration_days: dias,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{titulo}",
        collected_at: agora,
        last_observed_at: agora
      })

    :ok
  end

  defp ocorrencias(texto, agulha),
    do: texto |> String.split(agulha) |> length() |> Kernel.-(1)

  defp campo_de_data(ctx, quadro, nome, data) do
    agora = DateTime.utc_now(:second)

    {:ok, d} =
      Projects.record_field_definition(ctx.tenant, %{
        observed_project_id: quadro.id,
        field_external_id: "PVTF_#{nome}",
        name: nome,
        data_type: "DATE",
        collected_at: agora
      })

    {:ok, item} =
      Projects.record_item(ctx.tenant, %{
        observed_project_id: quadro.id,
        is_draft: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{nome}",
        collected_at: agora,
        last_observed_at: agora
      })

    {:ok, _} =
      Projects.record_item_field_value(ctx.tenant, %{
        project_item_id: item.id,
        project_field_definition_id: d.id,
        raw_value: %{"date" => Date.to_iso8601(data)},
        collected_at: agora,
        last_observed_at: agora
      })

    d
  end

  describe "de onde vem o prazo — issue #368" do
    test "sem origem declarada, a tela diz que não sabe — e não que está no prazo", ctx do
      q = quadro(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{q.id}")

      assert html =~ "Where the deadline comes from"

      assert html =~ "no known deadline", """
      A ausência de prazo não foi nomeada.

      43% das issues não alcançam origem alguma. "Não sabemos o prazo" é diferente de
      "está no prazo", e a segunda leitura produziria pontualidade inventada.
      """

      refute html =~ "suggested", "a tela sugeriu uma origem de prazo"
    end

    test "os campos de data aparecem com quantos itens preenchem cada um", ctx do
      q = quadro(ctx)
      campo_de_data(ctx, q, "Target date", ~D[2026-12-30])
      campo_de_data(ctx, q, "Start date", ~D[2026-06-12])

      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{q.id}")

      assert html =~ "Target date"
      assert html =~ "Start date"
      assert html =~ "items filled"
    end

    test "declarar sprint E marco mantém as duas — a segunda não apaga a primeira", ctx do
      q = quadro(ctx)
      {:ok, live, _html} = live(ctx.conn, ~p"/boards/#{q.id}")

      html = live |> element("form", "also use the end of the time box") |> render_submit()
      assert html =~ "the end of the time box"

      html = live |> element("form", "also use the milestone's due date") |> render_submit()

      assert html =~ "the end of the time box" and html =~ "the milestone&#39;s due date", """
      Declarar a segunda origem apagou a primeira.

      A decisão de 2026-08-26 é explícita: se a tarefa está dentro do sprint, o prazo dela é
      do sprint E do marco. 304 issues têm as duas.
      """

      assert length(SPO.deadline_criteria_for(ctx.tenant, {:board, q.id})) == 2
    end

    test "revogar uma origem deixa a outra de pé", ctx do
      q = quadro(ctx)
      {:ok, live, _html} = live(ctx.conn, ~p"/boards/#{q.id}")

      live |> element("form", "also use the end of the time box") |> render_submit()
      live |> element("form", "also use the milestone's due date") |> render_submit()

      html =
        live
        |> element("button[phx-value-source=sprint]")
        |> render_click()

      # O texto do badge e o do botão de acrescentar são o mesmo — contar é o que
      # distingue. Antes de revogar a frase aparece duas vezes; depois, só no botão.
      assert ocorrencias(html, "the end of the time box") == 1, """
      A origem revogada continuou listada, ou a outra caiu junto.

      Revogar `sprint` não pode alcançar `milestone`: as duas foram declaradas separadamente
      e valem ao mesmo tempo.
      """

      assert [%{source: "milestone"}] = SPO.deadline_criteria_for(ctx.tenant, {:board, q.id})
    end

    # Revogar `sprint` não prova o caminho do campo: ali o `field_name` já é nulo, e
    # forçá-lo a nulo não muda nada. O caso que prova é revogar UM campo de data entre
    # dois — que é o que os 33 pares (quadro, campo) tornam comum.
    test "revogar um campo de data deixa o outro campo de pé", ctx do
      q = quadro(ctx)
      campo_de_data(ctx, q, "End date", ~D[2026-07-31])
      campo_de_data(ctx, q, "Target date", ~D[2026-12-30])

      {:ok, live, _html} = live(ctx.conn, ~p"/boards/#{q.id}")

      live
      |> form("#prazo-por-campo", %{"field_name" => "End date"})
      |> render_submit()

      live
      |> form("#prazo-por-campo", %{"field_name" => "Target date"})
      |> render_submit()

      assert length(SPO.deadline_criteria_for(ctx.tenant, {:board, q.id})) == 2

      html = live |> element(~s(button[phx-value-field_name="End date"])) |> render_click()

      assert [%{source: "board_field", field_name: "Target date"}] =
               SPO.deadline_criteria_for(ctx.tenant, {:board, q.id}),
             """
             Revogar um campo de data alcançou o outro, ou não alcançou nenhum.

             Há 33 pares (quadro, campo) de data, e o mesmo quadro tem mais de um. O campo faz
             parte da identidade do critério: sem ele a revogação mira no lugar errado.
             """

      assert html =~ "the board field Target date"
    end
  end

  describe "papel do campo de iteração — issue #514" do
    test "a tela mostra a evidência e não sugere papel nenhum", ctx do
      q = quadro(ctx)
      campo_de_iteracao(ctx, q, "Sprint", "Sprint 38", 14, ~D[2026-06-29])
      campo_de_iteracao(ctx, q, "Quarter", "Q3", 92, ~D[2026-07-01])

      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{q.id}")

      assert html =~ "What each iteration field means"
      assert html =~ "Quarter"
      assert html =~ "92" and html =~ "14"

      assert html =~ "not declared — read as sprint", """
      A ausência de declaração não foi nomeada.

      Enquanto ninguém declara, a leitura trata como sprint — e é isso que a #514 aponta.
      Um traço no lugar diria "não se aplica", que é outra coisa.
      """

      refute html =~ "suggested", """
      A tela sugeriu um papel.

      `Quarter` parece trimestre, e classificar por padrão de nome publicaria a suposição
      como medida. O erro cai para o lado barato: o reconhecido errado vira número.
      """
    end

    test "declarar horizonte tira a iteração da lista de sprint sem sumir com ela", ctx do
      q = quadro(ctx)
      campo_de_iteracao(ctx, q, "Sprint", "Sprint 38", 14, ~D[2026-06-29])
      campo_de_iteracao(ctx, q, "Quarter", "Q3", 92, ~D[2026-07-01])

      {:ok, live, html} = live(ctx.conn, ~p"/boards/#{q.id}")
      assert html =~ "Q3 · sprint backlog"

      html =
        live
        |> form("#papel-Quarter", %{
          "field_name" => "Quarter",
          "role" => "planning_horizon"
        })
        |> render_submit()

      assert html =~ "Planning horizons — not sprints"
      assert html =~ "Sprint 38 · sprint backlog"

      refute html =~ "Q3 · sprint backlog", """
      O trimestre continuou sendo lido como sprint depois de declarado horizonte.

      A declaração vale sobre o que JÁ foi coletado: nada é copiado, e a mesma linha de
      `sro_sprints` muda de leitura. Se precisasse de recoleta, a declaração pareceria
      sem efeito justo no momento em que alguém a faz.
      """

      assert SMPO.horizon_field?(ctx.tenant, q.id, "Quarter")
    end

    test "revogar devolve a iteração à leitura de sprint", ctx do
      q = quadro(ctx)
      campo_de_iteracao(ctx, q, "Quarter", "Q3", 92, ~D[2026-07-01])

      {:ok, live, _html} = live(ctx.conn, ~p"/boards/#{q.id}")

      live
      |> form("#papel-Quarter", %{
        "field_name" => "Quarter",
        "role" => "planning_horizon"
      })
      |> render_submit()

      html = live |> element("button", "revoke") |> render_click()

      assert html =~ "Q3 · sprint backlog"
      refute html =~ "Planning horizons — not sprints"
    end

    test "quadro sem campo de iteração não mostra a seção", ctx do
      q = quadro(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{q.id}")

      refute html =~ "What each iteration field means"
    end
  end

  describe "/boards — T057" do
    test "sem quadro coletado, a ausência é nomeada", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/boards")

      assert html =~ "No board collected"
      assert html =~ "does not use Projects v2"
    end

    test "o quadro aparece, e os campos com a interpretação dita", ctx do
      q = quadro(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{q.id}")

      assert html =~ "DevOps"
      assert html =~ "Status"
      assert html =~ "not interpreted — stored raw"

      assert html =~ "No field is mapped to importance",
             "a ausência de importância não foi dita — FR-026: ausência declarada, nunca ordem inventada"
    end

    test "quadro de outra organização devolve não encontrado", ctx do
      q = quadro(ctx)
      {outro, admin2} = tenant_with_admin("outra")

      conn2 = log_in(Phoenix.ConnTest.build_conn(), admin2)
      {:ok, _live, html} = live(conn2, ~p"/boards/#{q.id}") |> follow_redirect(conn2)

      assert html =~ "Board not found"
      assert outro.id != ctx.tenant.id
    end
  end

  describe "excluir repositório — T058" do
    test "admin exclui, o autor fica gravado, e a coleta respeita", ctx do
      repo_id = ctx.cenario.observed_repository_id

      {:ok, live, html} = live(ctx.conn, ~p"/work/repositories/#{repo_id}")
      assert html =~ "Exclude from observation"

      html = live |> element("button", "Exclude from observation") |> render_click()

      assert html =~ "excluded from observation"

      {:ok, repositorio} = CMPO.fetch_observed(ctx.tenant, repo_id)
      assert repositorio.excluded_at != nil

      # A coleta respeita: o excluído sai da lista coletável.
      coletaveis = CMPO.list_collectable(ctx.tenant, ctx.cenario.tool.id)
      refute Enum.any?(coletaveis, &(&1.observed_repository_id == repo_id))

      # E o caminho de volta existe, como ato separado.
      html = live |> element("button", "Observe again") |> render_click()
      refute html =~ "Exclude this repository?"

      {:ok, de_volta} = CMPO.fetch_observed(ctx.tenant, repo_id)
      assert de_volta.excluded_at == nil
    end

    test "member não vê o controle", ctx do
      {:ok, member} =
        Tenants.create_user(ctx.tenant, %{"email" => "m@example.test", "role" => "member"})

      conn = log_in(Phoenix.ConnTest.build_conn(), member)

      {:ok, _live, html} =
        live(conn, ~p"/work/repositories/#{ctx.cenario.observed_repository_id}")

      refute html =~ "Exclude from observation",
             "o controle de excluir apareceu para member — a decisão é de admin"
    end
  end

  describe "o botão é um botão" do
    test "class custom não engole a base btn" do
      # Foi assim que "Associate repositories" e "New project" viraram texto puro:
      # `assign_new` deixava o `class` do chamador SUBSTITUIR a lista, e sem `btn` o
      # daisyUI não estiliza nada. A base entra sempre.
      html =
        render_component(&TheBandWeb.CoreComponents.button/1,
          class: "btn-outline btn-sm",
          inner_block: [%{inner_block: fn _, _ -> "Associate" end}]
        )

      assert html =~ ~r/class="[^"]*\bbtn\b/,
             "o botão perdeu a classe base `btn` quando o chamador passou class custom"

      assert html =~ "btn-outline"
    end
  end
end
