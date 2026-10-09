defmodule TheBandWeb.NetworkAnalysisLive.GraphCountsTest do
  @moduledoc """
  As contagens da rede de designação na página Graph — feature 076, T029 (US2; FR-005 a FR-009;
  protótipo aprovado 3.2.6 a 3.2.8).

  - quem administra lê pessoas, arestas, issues, a conectividade (*"1 group"*), as exclusões por
    motivo, as pessoas sem aresta e o número de contas declaradas, e a frase do que a aresta liga;
  - a conta de alcance parcial **não** lê as exclusões nem as pessoas sem aresta: são da
    organização inteira;
  - a rede sem aresta diz que não houve designação entre pessoas, sem 0.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.WorkItems

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n * 86_400, :second)

  defp issue(tenant, repo, autor, designados, aberta_em) do
    {:ok, issue} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: repo,
        number: System.unique_integer([:positive]),
        title: "t",
        state: "OPEN",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{System.unique_integer([:positive])}",
        external_created_at: aberta_em,
        author_login: "login-#{autor.name}",
        author_person_id: autor.id,
        author_account_type: "person"
      })

    {:ok, _} =
      WorkItems.replace_assignees(
        tenant,
        issue.id,
        Enum.map(designados, fn
          {:robo, login} -> %{login: login, person_id: nil, account_type: "bot"}
          p -> %{login: "login-#{p.name}", person_id: p.id, account_type: "person"}
        end)
      )
  end

  defp na_organizacao(tenant, organization, pessoas) do
    equipe =
      team_fixture(tenant, "T_#{System.unique_integer([:positive])}", %{
        organization: organization
      })

    for p <- pessoas do
      {:ok, _} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: p.id,
          team_id: equipe.id,
          person_external_id: "U_#{p.login}",
          team_external_id: equipe.external_id,
          platform_access_level: "MEMBER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })
    end
  end

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    org = organizacao_com_repositorio(tenant)
    repo = org.observed_repository_id

    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    caio = pessoa(tenant, "Caio")
    dora = pessoa(tenant, "Dora")
    lia = pessoa(tenant, "Lia")
    zeca = pessoa(tenant, "Zeca")

    na_organizacao(tenant, org.organization, [ana, bia, caio, dora, lia, zeca])

    # Ana → Bia (2), Bia → Caio (1), Zeca → Ana (1); uma auto-designação, uma de bot, e uma
    # issue sem responsável. Dora e Lia: da organização, sem aresta.
    issue(tenant, repo, ana, [bia], dias_atras(5))
    issue(tenant, repo, ana, [bia, ana], dias_atras(6))
    issue(tenant, repo, bia, [caio], dias_atras(7))
    issue(tenant, repo, zeca, [ana], dias_atras(8))
    issue(tenant, repo, caio, [{:robo, "renovate-sem-sufixo"}], dias_atras(9))
    issue(tenant, repo, caio, [], dias_atras(10))

    {:ok, _} = NetworkAnalysis.compute(tenant, org.organization, DateTime.utc_now(:second))

    # Lia, conta de membro, na mesma equipe declarada de Ana e Bia: alcance parcial.
    {:ok, equipe} = EO.create_declared_team(tenant, "X", admin.id)

    {:ok, papel} =
      EO.create_role(tenant, org.organization.id, %{code: "dev", name: "Dev"}, admin.id)

    for p <- [lia, ana, bia] do
      {:ok, _} =
        EO.declare_team_membership(
          tenant,
          equipe.id,
          p.id,
          %{organizational_role_id: papel.id},
          admin.id
        )
    end

    {:ok, conta} =
      Tenants.create_user(tenant, %{
        "email" => "lia-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, conta} = Tenants.declare_person(tenant, conta.id, lia.id, admin.id)

    %{conn: conn, tenant: tenant, admin: admin, conta: conta, org: org}
  end

  defp abrir(ctx, user, query \\ "?network=assignment&window=90") do
    live(log_in(ctx.conn, user), "/network-analysis/#{ctx.org.organization.id}/graph#{query}")
  end

  defp texto(html, seletor) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(seletor)
    |> LazyHTML.text()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  test "quem administra lê as contagens, a conectividade e as exclusões por motivo", ctx do
    {:ok, _view, html} = abrir(ctx, ctx.admin)

    assert texto(html, "#resumo") ==
             "4 people, 3 directed links, 6 issues opened in this window, including those " <>
               "counted below and not drawn."

    assert texto(html, "#conectividade") =~ "(1 group)"
    assert texto(html, "#contagens h2") =~ "derived"

    exclusoes = texto(html, "#exclusoes")
    assert exclusoes =~ "bot or app 1"
    assert exclusoes =~ "self-assignments 1"
    assert exclusoes =~ "issues without an assignee 1"
    assert exclusoes =~ "organisation account 0"

    assert texto(html, "#sem-aresta") =~
             "2 observed people of this organisation had no assignment"

    # 3.2.7 (T053): a frase leva a marca tracejada da ausência, com o texto ao lado.
    assert texto(html, "#sem-aresta") =~ "not drawn"

    assert html
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("#sem-aresta .border-dashed")
           |> Enum.count() == 1

    assert texto(html, "#o-que-a-aresta-liga") =~
             "It does not say who made the assignment, nor who did the work."

    assert texto(html, "#contas-declaradas") =~ "No account of this organisation is declared"

    refute html =~ ~r/collaborat/i
    refute html =~ ~r/delegat/i
  end

  test "com alcance parcial, nem as exclusões nem as pessoas sem aresta", ctx do
    {:ok, _view, html} = abrir(ctx, ctx.conta)

    # A página leu a rede: o aviso de alcance e as arestas estão lá.
    assert texto(html, "#aviso-de-alcance") =~ "Names appear only for the people you reach."
    assert texto(html, "#resumo") =~ "3 directed links"

    exclusoes = texto(html, "#exclusoes")
    assert exclusoes =~ "shown only to those who reach everyone"
    refute exclusoes =~ ~r/\d/
    refute texto(html, "#sem-aresta") =~ ~r/\d/
  end

  test "rede sem aresta diz que não houve designação entre pessoas, sem 0", ctx do
    vazia = organizacao_com_repositorio(ctx.tenant)
    {:ok, _} = NetworkAnalysis.compute(ctx.tenant, vazia.organization, DateTime.utc_now(:second))

    {:ok, _view, html} =
      live(
        log_in(ctx.conn, ctx.admin),
        "/network-analysis/#{vazia.organization.id}/graph?network=assignment&window=30"
      )

    contagens = texto(html, "#contagens")
    assert contagens =~ "no assignment between people in this window"
    refute contagens =~ ~r/\b0\b/
    refute texto(html, "#exclusoes") =~ ~r/\b0\b/
  end

  test "sem leitura da 073, a rede de revisão é ausente, e não a de outra rede", ctx do
    {:ok, _view, html} = abrir(ctx, ctx.admin, "?network=review&window=90")
    assert texto(html, "#sem-leitura") =~ "not calculated"
    refute html =~ ~s(id="resumo")
  end

  test "outro tenant e id malformado dão o mesmo Not found", ctx do
    {outro, _} = tenant_with_admin()
    de_fora = organizacao_com_repositorio(outro)

    for id <- [de_fora.organization.id, "abc"] do
      assert {:error,
              {:live_redirect, %{to: "/network-analysis", flash: %{"error" => "Not found."}}}} =
               live(log_in(ctx.conn, ctx.admin), "/network-analysis/#{id}/graph")
    end
  end
end
