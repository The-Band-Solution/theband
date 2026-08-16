defmodule TheBandWeb.GestaoDoProjetoTest do
  @moduledoc """
  A tela `/projects` com o ciclo de vida — feature 028, a fatia vertical.

  A asserção central é a SC-002: **o seletor diz qual caso está acontecendo** — filtrado
  pelas organizações do projeto, ou sem filtro por não haver associação. Deduzir pelo
  tamanho da lista é o que a tela não pode exigir de quem lê.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    {:ok, projeto} = SPO.create_project(tenant, %{name: "Alfa"}, admin.id)

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, projeto: projeto, cenario: cenario}
  end

  test "editar muda o nome na tela, e o autor fica no banco", ctx do
    {:ok, live, _} = live(ctx.conn, ~p"/projects")

    live |> element("button[phx-value-project_id='#{ctx.projeto.id}']", "edit") |> render_click()

    html =
      live
      |> form("#editar-#{ctx.projeto.id}", %{"name" => "Alfa Renomeado"})
      |> render_submit()

    assert html =~ "Alfa Renomeado"

    projeto = Repo.get!(TheBand.Ontology.SEON.SPO.Schemas.Project, ctx.projeto.id)
    assert projeto.updated_by_user_id == ctx.admin.id
  end

  test "remover tira da tela; com partes, recusa com a frase", ctx do
    {:ok, parte} = SPO.create_project(ctx.tenant, %{name: "Parte"}, ctx.admin.id)
    {:ok, _} = SPO.set_parent(ctx.tenant, parte.id, ctx.projeto.id)

    {:ok, live, _} = live(ctx.conn, ~p"/projects")

    html =
      live
      |> element("button[phx-value-project_id='#{ctx.projeto.id}']", "remove")
      |> render_click()

    assert html =~ "has parts", "a recusa não disse o motivo"
    assert html =~ "Alfa"

    # Sem partes, remove — e a tela deixa de mostrar.
    html2 =
      live |> element("button[phx-value-project_id='#{parte.id}']", "remove") |> render_click()

    refute html2 =~ ">Parte<"
  end

  test "SC-002: o seletor diz se está filtrado ou não", ctx do
    {:ok, live, _} = live(ctx.conn, ~p"/projects")

    # Sem organização associada: o seletor declara a ausência do filtro.
    html =
      live
      |> element("button[phx-click='abrir_picker'][phx-value-project_id='#{ctx.projeto.id}']")
      |> render_click()

    assert html =~ "unfiltered — no organisation associated"

    # Associa a organização do cenário: o seletor passa a declarar o filtro.
    org_id = ctx.cenario.organization.id

    live
    |> form("#org-#{ctx.projeto.id}", %{"organization_id" => org_id})
    |> render_change()

    # O seletor continua aberto depois da associação — re-renderizar basta, e é o que a
    # pessoa vê: a frase troca de "unfiltered" para "filtered" sem fechar nada.
    html2 = render(live)
    assert html2 =~ "filtered by the project&#39;s organisations"
    refute html2 =~ "unfiltered — no organisation associated"
  end

  test "criar equipe declara, associa, e a marca diz a proveniência", ctx do
    {:ok, live, _} = live(ctx.conn, ~p"/projects")

    live
    |> element("button[phx-value-project_id='#{ctx.projeto.id}']", "create a team")
    |> render_click()

    html =
      live
      |> form("#nova-equipe-#{ctx.projeto.id}", %{"name" => "Time Gama"})
      |> render_submit()

    assert html =~ "Time Gama"
    assert html =~ ">declared<", "a proveniência da equipe declarada não apareceu"

    assert [equipe] = SPO.list_project_teams(ctx.tenant, ctx.projeto.id)
    assert equipe.declared
  end
end
