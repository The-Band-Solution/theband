defmodule TheBandWeb.LayoutsNavTest do
  @moduledoc """
  O menu por entidades — spec 046.

  US1: a barra carrega as entidades e o Settings; os nove itens antigos moram no
  menu, e Operação só existe para quem administra. US2: as visões de trabalho são
  sub-abas de Work. A área ativa vem do caminho (FR-006), por mapa puro — testado
  aqui sem LiveView nenhuma.
  """

  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TheBandWeb.Layouts

  describe "nav_area/1 — o caminho decide a área (FR-006)" do
    test "cada tela existente resolve para exatamente uma área" do
      esperado = [
        {"/people", :people},
        {"/people/123", :people},
        {"/teams", :teams},
        {"/teams/abc", :teams},
        {"/projects", :projects},
        {"/organizations", :organization},
        {"/work", :settings},
        {"/work/changes", :settings},
        {"/work/files", :settings},
        {"/work/verifications", :settings},
        {"/work/repositories/9", :settings},
        {"/roles", :settings},
        {"/syncs", :settings},
        {"/tools", :settings},
        {"/boards", :settings},
        {"/process", :settings},
        {"/ai", :settings},
        {"/profiles", :settings}
      ]

      for {caminho, area} <- esperado do
        assert Layouts.nav_area(caminho) == area,
               "#{caminho} deveria pertencer a #{inspect(area)}"
      end
    end

    test "caminho desconhecido devolve nil, nunca levanta" do
      assert Layouts.nav_area("/sign-in") == nil
      assert Layouts.nav_area("/") == nil
      assert Layouts.nav_area(nil) == nil
    end

    test "prefixo não engole rota vizinha — /profiles não é /projects" do
      assert Layouts.nav_area("/profiles") == :settings
      assert Layouts.nav_area("/projects") == :projects
    end
  end

  describe "a barra (US1)" do
    setup do
      {tenant, admin} = tenant_with_admin()

      {:ok, member} =
        TheBand.Tenants.create_user(tenant, %{
          "email" => "member-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      %{tenant: tenant, admin: admin, member: member}
    end

    test "carrega as entidades e o Settings, e nenhum item antigo", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in(admin) |> live(~p"/people")

      assert html =~ ~s(href="/people")
      assert html =~ ~s(href="/teams")
      assert html =~ ~s(href="/projects")
      assert html =~ "Settings"

      # Os antigos saíram da BARRA: fora do dropdown não há link de trabalho.
      # Changes/Files/Checks/Boards/Process não aparecem nem no dropdown — são
      # sub-abas de Work (US2), não itens de menu.
      refute html =~ ~s(href="/work/changes")
      refute html =~ ~s(href="/boards")
      refute html =~ ~s(href="/process")
    end

    test "a área ativa carrega aria-current na tela aberta", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in(admin) |> live(~p"/people")

      # "true", e não "page": a barra marca a seção; "page" é da migalha.
      assert html =~
               ~r/aria-current="true"[^>]*>\s*People|href="\/people"[^>]*aria-current="true"/s
    end

    test "admin vê Operação com Syncs e Tools no Settings", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in(admin) |> live(~p"/people")

      assert html =~ "Operação"
      assert html =~ ~s(href="/syncs")
      assert html =~ ~s(href="/tools")
      assert html =~ ~s(href="/work")
      assert html =~ ~s(href="/roles")
    end

    test "member não vê vestígio de Operação (FR-003, SC-003)", %{conn: conn, member: member} do
      {:ok, _view, html} = conn |> log_in(member) |> live(~p"/people")

      refute html =~ "Operação"
      refute html =~ ~s(href="/syncs")
      refute html =~ ~s(href="/tools")

      # Trabalho e Vocabulário continuam para todo escopo.
      assert html =~ ~s(href="/work")
      assert html =~ ~s(href="/roles")
    end

    test "numa tela movida, Settings é a área marcada", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in(admin) |> live(~p"/roles")
      assert html =~ ~r/<summary[^>]*aria-current="true"/s
    end
  end

  describe "work_tabs/1 (US2)" do
    test "as seis sub-abas apontam para as rotas de hoje, e a ativa se marca" do
      for {ativa, rota} <- [
            issues: "/work",
            changes: "/work/changes",
            files: "/work/files",
            checks: "/work/verifications",
            boards: "/boards",
            process: "/process"
          ] do
        html = render_component(&Layouts.work_tabs/1, active: ativa)

        for r <- [
              "/work",
              "/work/changes",
              "/work/files",
              "/work/verifications",
              "/boards",
              "/process"
            ] do
          assert html =~ ~s(href="#{r}"), "faltou #{r} com active=#{ativa}"
        end

        assert html =~ ~r/href="#{Regex.escape(rota)}"[^>]*class="[^"]*tab-active/s,
               "a aba ativa de #{ativa} deveria ser #{rota}"
      end
    end
  end
end
