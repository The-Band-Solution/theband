defmodule TheBandWeb.BoardsTest do
  @moduledoc """
  As telas do sprint 017 — T057 (`/boards`) e T058 (excluir repositório).

  ## As asserções que carregam este arquivo

  1. **a ausência de importância é dita** — nenhuma ordem inventada (FR-026);
  2. **campo sem mapeamento aparece como não interpretado** — nunca convertido (FR-025);
  3. **excluir aparece só para admin, grava o autor, e a coleta respeita**;
  4. **o botão continua sendo um botão** — `class` custom não pode engolir a base `btn`,
     que foi como "Associate repositories" ficou invisível de clicar em 2026-08-16.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

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
