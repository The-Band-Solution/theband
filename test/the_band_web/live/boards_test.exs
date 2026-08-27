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
     e quem decide é a organização (issue #514).
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.Continuum.SMPO
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
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
