defmodule TheBandWeb.ScreensTest do
  @moduledoc """
  As telas que fecham a fatia vertical (US3, e o que US1 expõe).

  Três destas verificações **não** são fazíveis por teste unitário: o segredo
  ausente do HTML, o isolamento entre organizações percorrendo a interface, e a
  contagem do cabeçalho concordando com a listagem. É por isso que existem aqui.
  """

  use TheBandWeb.ConnCase, async: false

  import Mox

  setup :verify_on_exit!

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Sources
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

    # A organização é obrigatória para equipe organizacional desde a feature 002, e
    # a tela passa a exibi-la — então os dados de teste precisam tê-la.
    team_fixture(tenant, "T_1", %{name: "Core", slug: "core"})
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

    test "estado vazio explica a causa em vez de só dizer que está vazio" do
      {_tenant, user} = tenant_with_admin("vazio")

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

  describe "organização nas telas (T012, FR-015, SC-001)" do
    setup %{conn: conn} do
      {tenant, user} = tenant_with_admin()

      alfa = organization_fixture(tenant, "alfa")
      beta = organization_fixture(tenant, "beta")

      time_alfa = team_fixture(tenant, "T_alfa", %{name: "Core", organization: alfa})
      time_beta = team_fixture(tenant, "T_beta", %{name: "Plataforma", organization: beta})

      {:ok, sobreposta} =
        EO.upsert_person_from_source(tenant, source_attrs("U_ab", %{name: "Ana", login: "ana"}))

      {:ok, so_alfa} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_a", %{name: "Bruno", login: "bruno"})
        )

      {:ok, sem_equipe} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_x", %{name: "Carla", login: "carla"})
        )

      for {pessoa, time, sufixo} <- [
            {sobreposta, time_alfa, "-a"},
            {sobreposta, time_beta, "-b"},
            {so_alfa, time_alfa, "-a"}
          ] do
        {:ok, _} =
          EO.record_team_membership_evidence(tenant, %{
            person_id: pessoa.id,
            team_id: time.id,
            person_external_id: pessoa.external_id <> sufixo,
            team_external_id: time.external_id,
            platform_access_level: "MEMBER",
            source_system: "github",
            source_instance: "https://github.com",
            observed_at: DateTime.utc_now(:second)
          })
      end

      %{conn: log_in(conn, user), tenant: tenant, sem_equipe: sem_equipe}
    end

    test "/pessoas mostra as organizações de cada pessoa", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/pessoas")

      assert html =~ "organizações"
      assert html =~ "alfa"
      assert html =~ "beta"
    end

    test "a pessoa em duas organizações aparece uma vez, com as duas", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/pessoas")

      # Uma linha, não duas: a distinção é por pessoa, não por vínculo. Duas linhas
      # fariam a contagem do cabeçalho discordar da listagem, que é o defeito que
      # esta tela existe para tornar visível.
      assert html |> String.split("Ana") |> length() == 2
      assert html =~ "em 2 organizações"
    end

    test "quem não está em equipe alguma aparece, dizendo por que não tem organização", %{
      conn: conn
    } do
      {:ok, _live, html} = live(conn, ~p"/pessoas")

      # Aparecer é o ponto: some da lista faria parecer que a pessoa não foi
      # coletada. O que falta é o vínculo, e a tela diz isso.
      assert html =~ "Carla"
      assert html =~ "sem equipe — organização desconhecida"
    end

    test "a tela avisa que a soma por organização é maior que o total", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/pessoas")

      # Sem este aviso, o primeiro a somar as contagens por organização conclui que
      # há defeito onde há sobreposição correta.
      assert html =~ "soma das pessoas por organização é maior que o total"
    end

    test "/equipes mostra a organização de cada equipe", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/equipes")

      assert html =~ "organização"
      assert html =~ "alfa"
      assert html =~ "beta"
    end

    test "nenhuma equipe aparece sem organização", %{conn: conn, tenant: tenant} do
      {:ok, _live, _html} = live(conn, ~p"/equipes")

      # A restrição do banco garante isto para equipe organizacional; o teste guarda
      # a tela contra o caso de alguém passar a exibir equipe de projeto sem dizer
      # que a organização está ausente de propósito.
      assert Enum.all?(EO.list_teams(tenant), & &1.organization_id)
    end
  end

  describe "equipe derivada na tela (T024, FR-011, SC-010)" do
    setup %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      org = organization_fixture(tenant, "ifesserra-lab")
      team_fixture(tenant, "T_obs", %{name: "Core", organization: org})
      {:ok, derivada} = EO.upsert_derived_team(tenant, org)

      %{conn: log_in(conn, user), tenant: tenant, derivada: derivada}
    end

    test "o selo aparece sempre que a equipe aparece", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/equipes")

      # Selo visível, não nota de rodapé: esconder é pior que marcar, porque quem não
      # vê a equipe não explica por que a contagem de pessoas não fecha.
      assert html =~ "derivada"
      assert html =~ "não existe na ferramenta de origem"
    end

    test "a contagem separa observadas de derivadas", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/equipes")

      assert html =~ "1 derivada"
      assert html =~ "1 na origem"
    end

    test "descontadas as derivadas, a contagem bate com a origem", %{
      conn: conn,
      tenant: tenant
    } do
      {:ok, _live, _html} = live(conn, ~p"/equipes")

      # A origem tem 1 time; a plataforma mostra 2 equipes, e diz por quê.
      assert EO.count_teams(tenant) == 2
      assert EO.count_teams(tenant, origin: :observed) == 1
    end
  end

  describe "encerrar a observação pela tela (T018, T022)" do
    setup %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      tool = conectar_ferramenta(tenant)

      alfa = organization_fixture(tenant, "acme")
      beta = organization_fixture(tenant, "outra-org-fonte")
      t_alfa = team_fixture(tenant, "T_a", %{organization: alfa})
      t_beta = team_fixture(tenant, "T_b", %{organization: beta})

      {:ok, sobreposta} =
        EO.upsert_person_from_source(tenant, source_attrs("U_s", %{name: "Sobreposta"}))

      {:ok, exclusiva} =
        EO.upsert_person_from_source(tenant, source_attrs("U_e", %{name: "Exclusiva"}))

      for {p, t, sufixo} <- [
            {sobreposta, t_alfa, "-a"},
            {sobreposta, t_beta, "-b"},
            {exclusiva, t_alfa, "-a"}
          ] do
        {:ok, _} =
          EO.record_team_membership_evidence(tenant, %{
            person_id: p.id,
            team_id: t.id,
            person_external_id: p.external_id <> sufixo,
            team_external_id: t.external_id,
            platform_access_level: "MEMBER",
            source_system: "github",
            source_instance: "https://github.com",
            observed_at: DateTime.utc_now(:second)
          })
      end

      %{conn: log_in(conn, user), tenant: tenant, tool: tool}
    end

    test "o impacto aparece antes de confirmar, e nomeia quem permanece", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/ferramentas")

      html = live |> element("button", "encerrar observação") |> render_click()

      assert html =~ "Encerrar a observação de acme"
      assert html =~ "Permanecem vigentes"
      # O nome, e não um contador: "1 pessoa permanece" não deixa reconhecer quem é.
      assert html =~ "Sobreposta"
      assert html =~ "NÃO serão apagados"
      assert html =~ "Para confirmar, digite"
    end

    test "confirmação errada não encerra", %{conn: conn, tool: tool} do
      {:ok, live, _html} = live(conn, ~p"/ferramentas")
      live |> element("button", "encerrar observação") |> render_click()

      html =
        live
        |> form("form[phx-submit=end_observation]", %{"confirmation" => "acm"})
        |> render_submit()

      assert html =~ "não corresponde"
      refute Sources.observation_ended?(tool)
    end

    test "confirmação certa encerra, e o resumo diz que nada foi apagado", %{
      conn: conn,
      tool: tool
    } do
      {:ok, live, _html} = live(conn, ~p"/ferramentas")
      live |> element("button", "encerrar observação") |> render_click()

      html =
        live
        |> form("form[phx-submit=end_observation]", %{"confirmation" => "acme"})
        |> render_submit()

      assert html =~ "encerrada"
      assert html =~ "Nada foi apagado"
      assert html =~ "observação encerrada"
      assert Sources.observation_ended?(tool)
    end

    test "o segredo não aparece em nenhum momento do fluxo (SC-011)", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/ferramentas")
      refute html =~ @segredo

      html = live |> element("button", "encerrar observação") |> render_click()
      refute html =~ @segredo

      html =
        live
        |> form("form[phx-submit=end_observation]", %{"confirmation" => "acme"})
        |> render_submit()

      # A violação: procura o segredo e exige não encontrar, nas três telas do fluxo.
      refute html =~ @segredo
    end
  end

  describe "retomar a observação pela tela (US2)" do
    setup %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      tool = conectar_ferramenta(tenant)
      org = organization_fixture(tenant, "acme")
      team_fixture(tenant, "T_a", %{organization: org})

      {:ok, _} = Sources.end_observation(tenant, tool, %{"confirmation" => "acme"})

      %{conn: log_in(conn, user), tenant: tenant, tool: tool}
    end

    test "o botão de retomar aparece só na encerrada", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/ferramentas")

      assert html =~ "retomar observação"
      refute html =~ "encerrar observação"
    end

    test "o formulário diz que a coleta é que devolve vigência", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/ferramentas")

      html = live |> element("button", "retomar observação") |> render_click()

      assert html =~ "credencial anterior foi destruída"
      # A frase existe para impedir o mal-entendido: retomar não ressuscita nada por si.
      assert html =~ "não voltam a ser vigentes agora"
    end

    test "credencial recusada não retoma, e a tela diz", %{conn: conn, tool: tool} do
      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok, %{status: 401, body: %{}, headers: %{}}}
      end)

      {:ok, live, _html} = live(conn, ~p"/ferramentas")
      live |> element("button", "retomar observação") |> render_click()

      html =
        live
        |> form("form[phx-submit=resume_observation]", %{"secret" => "ghp_ruim"})
        |> render_submit()

      assert html =~ "recusada pela ferramenta"
      assert Sources.observation_ended?(tool)
    end

    test "credencial válida retoma, e o aviso diz o que a coleta fará", %{
      conn: conn,
      tool: tool
    } do
      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      {:ok, live, _html} = live(conn, ~p"/ferramentas")
      live |> element("button", "retomar observação") |> render_click()

      html =
        live
        |> form("form[phx-submit=resume_observation]", %{
          "secret" => "ghp_boa",
          "label" => "nova"
        })
        |> render_submit()

      assert html =~ "retomada"
      assert html =~ "só os que a origem ainda mostrar"
      refute Sources.observation_ended?(tool)
    end

    test "o segredo novo não aparece no HTML (SC-011)", %{conn: conn} do
      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      {:ok, live, _html} = live(conn, ~p"/ferramentas")
      live |> element("button", "retomar observação") |> render_click()

      html =
        live
        |> form("form[phx-submit=resume_observation]", %{"secret" => "ghp_segredo_novo_12345"})
        |> render_submit()

      refute html =~ "ghp_segredo_novo_12345"
    end
  end

  describe "histórico de observação (US2, AC4)" do
    test "depois de retomar, o histórico guarda o encerramento e a retomada", %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      tool = conectar_ferramenta(tenant)
      conn = log_in(conn, user)

      {:ok, _} = Sources.end_observation(tenant, tool, %{"confirmation" => "acme"})

      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      {:ok, _} = Sources.resume_observation(tenant, tool, %{"secret" => "ghp_nova"})

      {:ok, live, html} = live(conn, ~p"/ferramentas")

      # A ferramenta voltou a parecer ativa — é o histórico que preserva o que houve.
      refute html =~ "observação encerrada"
      assert html =~ "histórico de observação (2)"

      aberto = live |> element("button", "histórico de observação") |> render_click()

      assert aberto =~ "encerrada"
      assert aberto =~ "retomada"
    end

    test "ferramenta que nunca encerrou não mostra histórico", %{conn: conn} do
      {tenant, user} = tenant_with_admin()
      conectar_ferramenta(tenant)

      {:ok, _live, html} = live(log_in(conn, user), ~p"/ferramentas")

      refute html =~ "histórico de observação"
    end
  end
end
