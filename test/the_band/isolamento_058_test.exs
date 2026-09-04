defmodule TheBand.Isolamento058Test do
  @moduledoc """
  O isolamento entre tenants nas funções novas da feature 058 — T017, SC-010.

  **Consulta sem tenant é bug de segurança, e não de correção.** Um número errado
  alguém contesta; o dado da outra organização aparecendo na tela não tem
  contestação possível, e a plataforma existe para servir mais de uma.

  ## Os dois tenants têm os MESMOS nomes, de propósito

  Equipe "Dados", projeto "Alfa" e pessoa "ana" existem nos dois. Um teste com
  nomes diferentes passa mesmo quando o filtro por tenant sumiu, porque o dado do
  outro lado é reconhecível e ninguém o confunde com o certo — aqui, se o filtro
  cair, a asserção quebra.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Quality
  alias TheBand.Verification

  setup do
    %{um: montar("um"), outro: montar("outro")}
  end

  # Um mundo completo por tenant: organização, equipe "Dados", pessoa "ana"
  # dentro dela, projeto "Alfa" ligado à equipe.
  defp montar(sufixo) do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme-#{sufixo}")
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, %{
        login: "ana",
        name: "ana",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/ana",
        external_id: "U_ana_#{sufixo}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => "ana"}
      })

    {:ok, _} =
      EO.allocate(tenant, %{
        person_id: ana.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -100, :day)
      })

    {:ok, projeto} = SPO.create_project(tenant, %{name: "Alfa"}, admin.id)
    {:ok, _} = SPO.link_team(tenant, projeto.id, equipe.id, admin.id)

    %{tenant: tenant, admin: admin, org: org, equipe: equipe, pessoa: ana, projeto: projeto}
  end

  defp janela do
    agora = DateTime.utc_now()
    %{inicio: DateTime.add(agora, -56, :day), fim: agora}
  end

  test "team_memberships_with_period_many/2 não atravessa a fronteira", ctx do
    ids = [ctx.um.equipe.id, ctx.outro.equipe.id]

    do_um = EO.team_memberships_with_period_many(ctx.um.tenant, ids)

    assert Map.keys(do_um) == [ctx.um.equipe.id], """
    A consulta devolveu vínculos da equipe do outro tenant. O id foi passado de fora, e o
    filtro por tenant é a única coisa entre um pedido malicioso e o dado alheio.
    """
  end

  test "project_teams_with_period_many/2 não atravessa a fronteira", ctx do
    ids = [ctx.um.projeto.id, ctx.outro.projeto.id]

    projetos =
      ctx.um.tenant |> SPO.project_teams_with_period_many(ids) |> Enum.map(& &1.project_id)

    assert projetos == [ctx.um.projeto.id]
  end

  test "who_worked_on_many/3 não atravessa a fronteira", ctx do
    ids = [ctx.um.projeto.id, ctx.outro.projeto.id]

    resposta = SPO.who_worked_on_many(ctx.um.tenant, ids, janela())

    assert Map.keys(resposta) == [ctx.um.projeto.id]
    assert [%{person_id: pessoa_id}] = resposta[ctx.um.projeto.id]
    assert pessoa_id == ctx.um.pessoa.id
    refute pessoa_id == ctx.outro.pessoa.id
  end

  test "team_projects_ever/2 e team_project_links_with_period/2 não atravessam", ctx do
    assert [%{project_id: id}] = SPO.team_projects_ever(ctx.um.tenant, ctx.um.equipe.id)
    assert id == ctx.um.projeto.id

    assert SPO.team_projects_ever(ctx.um.tenant, ctx.outro.equipe.id) == []
    assert SPO.team_project_links_with_period(ctx.um.tenant, ctx.outro.equipe.id) == []
  end

  test "project_repositories_in/3 não atravessa a fronteira", ctx do
    assert SPO.project_repositories_in(ctx.um.tenant, ctx.outro.projeto.id, janela()) == []
  end

  test "team_time_to_first_review/3 e a versão por pessoa não atravessam", ctx do
    assert Quality.team_time_to_first_review(ctx.um.tenant, ctx.outro.equipe.id) == []
    assert Quality.team_time_to_first_review_by_person(ctx.um.tenant, ctx.outro.equipe.id) == []
  end

  test "team_pipeline_rate/3 recusa a equipe do outro tenant", ctx do
    # A equipe do outro tenant TEM projeto ligado — lá. Vista daqui, ela não tem
    # nenhum, e a resposta é a recusa: nunca a taxa do vizinho.
    assert {:sem_projeto, _} =
             Verification.team_pipeline_rate(ctx.um.tenant, ctx.outro.equipe.id)
  end
end
