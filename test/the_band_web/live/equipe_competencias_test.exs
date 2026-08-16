defmodule TheBandWeb.EquipeCompetenciasTest do
  @moduledoc """
  A tela da equipe com as competências e os projetos — feature 029, T005 e T007.

  ## As asserções que carregam este arquivo

  1. a seção é marcada **derivada**, com hachura e rótulo em texto;
  2. quem não tem perfil aparece nomeado na matriz — nunca somado como zero;
  3. associar a um projeto pela tela da equipe usa o MESMO vínculo da 028 — o projeto
     passa a listar a equipe, porque é uma tabela só com dois caminhos até ela.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    {:ok, equipe} = EO.create_declared_team(tenant, "Plataforma", admin.id)

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, equipe: equipe}
  end

  defp pessoa_com_perfil(tenant, login, destaques) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    if destaques != [] do
      {:ok, _} =
        EO.record_profile(tenant, %{
          person_id: p.id,
          generated_at: DateTime.utc_now(:second),
          model: "m1",
          content: %{
            "habilidades" => Enum.map(destaques, &elem(&1, 0)),
            "destaques" =>
              Enum.map(destaques, fn {d, t} ->
                %{
                  "dominio" => d,
                  "demonstrou" => "x",
                  "tarefas" => t,
                  "periodos" => [1],
                  "mais_recente" => "2026-08",
                  "evidencia" => [1]
                }
              end),
            "lacunas" => [],
            "resumo" => %{"forcas" => "f", "evolucao" => "e", "atencao" => "a"},
            "trajetoria" => [],
            "alocacao" => [],
            "recomendacoes" => []
          },
          tasks_closed: 30,
          tasks_open: 0,
          tasks_with_body: 30,
          tasks_authored_by_other: 0,
          tasks_shared: 0
        })
    end

    p
  end

  defp membro(tenant, equipe, pessoa) do
    agora = DateTime.utc_now(:second)

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        team_id: equipe.id,
        person_id: pessoa.id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        person_external_id: "U_#{pessoa.login}",
        team_external_id: "T_#{equipe.id}",
        collected_at: agora,
        observed_at: agora,
        last_observed_at: agora
      })
  end

  test "a seção existe, marcada derivada, com a matriz e quem falta", ctx do
    ana = pessoa_com_perfil(ctx.tenant, "ana", [{"observabilidade", 14}])
    zeta = pessoa_com_perfil(ctx.tenant, "zeta", [])
    membro(ctx.tenant, ctx.equipe, ana)
    membro(ctx.tenant, ctx.equipe, zeta)

    {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

    assert html =~ "derived — counted over model-written profiles"
    assert html =~ "observabilidade"
    assert html =~ "1/2"
    assert html =~ "no profile yet — no row is not no skill"
    assert html =~ "zeta"
    assert html =~ "completed tasks"
  end

  test "sem perfil algum, a ausência é nomeada e nada é contado", ctx do
    ana = pessoa_com_perfil(ctx.tenant, "ana", [])
    membro(ctx.tenant, ctx.equipe, ana)

    {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

    assert html =~ "No member of this team has a profile yet"
  end

  test "associar a projeto pela equipe é o mesmo vínculo que o projeto lista", ctx do
    {:ok, projeto} = SPO.create_project(ctx.tenant, %{name: "Alfa"}, ctx.admin.id)

    {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
    assert html =~ "not associated with any project"

    html =
      live
      |> form("#associar-projeto", %{"project_id" => projeto.id})
      |> render_change()

    assert html =~ "Alfa"

    # O outro lado enxerga: é uma tabela só, com dois caminhos até ela.
    assert [vinculada] = SPO.list_project_teams(ctx.tenant, projeto.id)
    assert vinculada.team_id == ctx.equipe.id
    assert vinculada.declared

    # Desassociar daqui também marca — nunca apaga.
    html2 =
      live
      |> element("button[phx-value-link_id='#{vinculada.id}']")
      |> render_click()

    # "Alfa" volta ao SELECT de disponíveis — o que some é a marca de vínculo.
    assert html2 =~ "not associated with any project"
    assert SPO.list_project_teams(ctx.tenant, projeto.id) == []
    assert SPO.list_team_projects(ctx.tenant, ctx.equipe.id) == []
  end
end
