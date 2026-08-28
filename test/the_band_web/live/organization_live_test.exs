defmodule TheBandWeb.OrganizationLiveTest do
  @moduledoc """
  A tela Organization — feature 046, US3 (FR-007, SC-006).

  ## As asserções que carregam este arquivo

  1. **um tenant não vê o outro** — a violação primeiro (L03);
  2. **projeto sem organização identificada aparece em grupo nomeado** — a
     limitação do vínculo por `source_instance` virou ramo e frase (L61, R3);
  3. **ausência tem frase própria em cada nível** — organização sem equipe não
     some, tenant sem organização diz o que alimentaria a tela;
  4. a barra marca Organization como área ativa.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [ferramenta: 2]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Projects

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, org: org}
  end

  # O vínculo projeto→organização é a cadeia declarada pela ferramenta conectada
  # (research R3): o projeto aponta a ferramenta, a ferramenta aponta o login.
  defp projeto(tenant, titulo, numero, login_da_org) do
    tool = ferramenta(tenant, login_da_org)

    {:ok, p} =
      Projects.record_observed_project(tenant, %{
        connected_tool_id: tool.id,
        title: titulo,
        number: numero,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_#{numero}_#{System.unique_integer([:positive])}",
        collected_at: DateTime.utc_now(:second)
      })

    p
  end

  test "mostra organização com equipes e projetos, e nada do outro tenant", ctx do
    {:ok, equipe} = EO.create_declared_team(ctx.tenant, "Plataforma", ctx.admin.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^equipe.id, :binary_id),
        update: [set: [organization_id: type(^ctx.org.id, :binary_id)]]
      ),
      []
    )

    projeto(ctx.tenant, "Quadro da Acme", 1, "acme")

    outro = tenant_fixture()
    organization_fixture(outro, "intrusa")
    projeto(outro, "Quadro Intruso", 9, "intrusa")

    {:ok, _view, html} = live(ctx.conn, ~p"/organizations")

    assert html =~ "acme"
    assert html =~ "Plataforma"
    assert html =~ "Quadro da Acme"

    refute html =~ "intrusa"
    refute html =~ "Quadro Intruso"
  end

  test "projeto cujo source_instance não casa entra no grupo nomeado", ctx do
    projeto(ctx.tenant, "Quadro Perdido", 2, "org-que-ninguem-observa")

    {:ok, _view, html} = live(ctx.conn, ~p"/organizations")

    assert html =~ "Projects without an identified organisation"
    assert html =~ "Quadro Perdido"
    assert html =~ "org-que-ninguem-observa"
  end

  test "organização sem equipe, responsável ou projeto não some — cada ausência tem frase",
       ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/organizations")

    assert html =~ "acme"
    assert html =~ "No team observed for this organisation."
    assert html =~ "Nobody declared responsible"
    assert html =~ "No project identified for this organisation."
  end

  test "tenant sem organização diz o que alimentaria a tela", %{conn: _} do
    {tenant, admin} = tenant_with_admin()
    conn = log_in(build_conn(), admin)
    _ = tenant

    {:ok, _view, html} = live(conn, ~p"/organizations")

    assert html =~ "No organisation observed yet."
    assert html =~ "connect a tool"
  end

  test "a barra marca Organization como área ativa", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/organizations")

    assert html =~
             ~r/href="\/organizations"[^>]*aria-current="true"|aria-current="true"[^>]*>\s*Organization/s
  end
end
