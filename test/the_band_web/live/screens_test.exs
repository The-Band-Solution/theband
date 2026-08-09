defmodule TheBandWeb.ScreensTest do
  @moduledoc """
  As telas que fecham a fatia vertical (US3, e o que US1 expõe).

  Três destas verificações **não** são fazíveis por teste unitário: o segredo
  ausente do HTML, o isolamento entre organizações percorrendo a interface, e a
  contagem do cabeçalho concordando com a listagem. É por isso que existem aqui.
  """

  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.Tenants

  @segredo "ghp_segredo_que_nao_pode_vazar_1234"

  defp povoar(tenant) do
    {:ok, _} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_1", %{name: "Ana Souza", login: "ana"})
      )

    {:ok, _} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_2", %{name: "dependabot", login: "dependabot[bot]", account_type: "bot"})
      )

    {:ok, equipe} =
      EO.upsert_team_from_source(tenant, source_attrs("T_1", %{name: "Core", slug: "core"}))

    equipe
  end

  defp conectar_ferramenta(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme"
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "principal",
        secret: @segredo,
        last_four: ToolCredential.last_four(@segredo),
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    tool
  end

  describe "/pessoas (US3)" do
    setup %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      povoar(tenant)
      %{conn: log_in(conn, user), tenant: tenant}
    end

    test "exibe origem, identificador externo e data de coleta (SC-004)", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/pessoas")

      assert html =~ "Ana Souza"
      assert html =~ "github"
      assert html =~ "https://github.com"
      assert html =~ "U_1"
    end

    test "a contagem do cabeçalho não inclui automação", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/pessoas")

      # Duas contas conhecidas, uma pessoa: o cabeçalho conta pessoas, e a
      # automação aparece contada à parte.
      assert html =~ "1 pessoa"
      assert html =~ "conta de automação"
      assert html =~ "dependabot"
    end

    test "estado vazio explica a causa em vez de só dizer que está vazio", %{conn: conn} do
      {tenant, user} = tenant_with_admin("vazio")
      _ = tenant

      {:ok, _live, html} = live(log_in(build_conn(), user), ~p"/pessoas")

      assert html =~ "Nenhuma sincronização trouxe pessoas ainda"
    end
  end

  describe "/equipes (US3)" do
    setup %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      equipe = povoar(tenant)
      %{conn: log_in(conn, user), tenant: tenant, equipe: equipe}
    end

    test "lista equipes com proveniência e conta pendentes de papel", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/equipes")

      assert html =~ "Core"
      assert html =~ "organizational_team"
      assert html =~ "T_1"
      assert html =~ "pendente"
    end

    test "a tela de integrantes rotula o nível como acesso, nunca como papel", %{
      conn: conn,
      tenant: tenant,
      equipe: equipe
    } do
      [pessoa | _] = EO.list_people(tenant)

      {:ok, _} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: pessoa.id,
          team_id: equipe.id,
          person_external_id: "U_1",
          team_external_id: "T_1",
          platform_access_level: "MAINTAINER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })

      {:ok, _live, html} = live(conn, ~p"/equipes/#{equipe.id}")

      assert html =~ "acesso na plataforma"
      assert html =~ "MAINTAINER"
      assert html =~ "papel organizacional"
      # O rótulo é parte do contrato: chamar o nível de "cargo" na tela desfaria
      # na interface a distinção que o modelo preserva.
      refute html =~ "cargo"
    end
  end

  describe "/ferramentas (US1)" do
    test "exibe a credencial mascarada e nunca o segredo (SC-005)", %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      conectar_ferramenta(tenant)

      {:ok, _live, html} = live(log_in(conn, user), ~p"/ferramentas")

      refute html =~ @segredo
      assert html =~ ToolCredential.last_four(@segredo)
      assert html =~ "••••"
    end

    test "perfil member não alcança a tela", %{conn: conn} do
      {tenant, _admin} = tenant_with_admin()

      {:ok, member} =
        Tenants.create_user(tenant, %{"email" => "member@example.test", "role" => "member"})

      assert {:error, {:redirect, %{to: "/pessoas"}}} =
               live(log_in(conn, member), ~p"/ferramentas")
    end
  end

  describe "isolamento entre organizações (SC-008)" do
    test "percorrendo a interface, uma organização nunca vê a outra", %{conn: conn} do
      {um, usuario_um} = tenant_with_admin("um")
      {outro, usuario_outro} = tenant_with_admin("outro")

      equipe_do_um = povoar(um)
      conectar_ferramenta(um)

      {:ok, _live, html} = live(log_in(conn, usuario_outro), ~p"/pessoas")
      refute html =~ "Ana Souza"
      assert html =~ "Nenhuma sincronização trouxe pessoas ainda"

      {:ok, _live, html} = live(log_in(build_conn(), usuario_outro), ~p"/equipes")
      refute html =~ "Core"

      {:ok, _live, html} = live(log_in(build_conn(), usuario_outro), ~p"/ferramentas")
      refute html =~ "acme"

      # O id da equipe do outro tenant não devolve o registro: devolve redirect.
      assert {:error, {:live_redirect, %{to: "/equipes"}}} =
               live(log_in(build_conn(), usuario_outro), ~p"/equipes/#{equipe_do_um.id}")

      # E a organização dona continua enxergando o que é dela.
      {:ok, _live, html} = live(log_in(build_conn(), usuario_um), ~p"/pessoas")
      assert html =~ "Ana Souza"

      assert EO.count_people(outro) == 0
    end
  end

  describe "sem sessão" do
    test "a interface leva para a entrada", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/entrar"}}} = live(conn, ~p"/pessoas")
    end
  end
end
