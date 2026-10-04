defmodule TheBand.NetworkAnalysis.CommandsDuasRedesTest do
  @moduledoc """
  As duas redes nas três janelas, pela fachada — feature 076, T028 (FR-005 a FR-009; research.md
  R2, R12).

  - o job grava **seis** leituras: a de revisão com as arestas da 073 da mesma janela e o instante
    dela; a de designação com as contagens da classificação;
  - sem leitura da 073, a revisão fica `{:ausente, :not_computed}` e a designação é gravada;
  - a janela da designação é a da **abertura** da issue: aberta antes da janela e atualizada
    dentro dela, não entra;
  - a pessoa da organização sem aresta conta em `people_without_edges`, e não é nó; a conta
    declarada da organização não conta como pessoa sem aresta.
  """
  use TheBand.DataCase, async: false

  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork
  alias TheBand.Tenants
  alias TheBand.WorkItems

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n * 86_400, :second)

  defp issue(tenant, repo, autor, designados, aberta_em, atualizada_em \\ nil) do
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
        external_updated_at: atualizada_em || aberta_em,
        author_login: "login-#{autor.name}",
        author_person_id: autor.id,
        author_account_type: "person"
      })

    {:ok, _} =
      WorkItems.replace_assignees(
        tenant,
        issue.id,
        Enum.map(
          designados,
          &%{login: "login-#{&1.name}", person_id: &1.id, account_type: "person"}
        )
      )

    issue
  end

  # As pessoas de uma organização são as das equipes dela, pela evidência de vínculo (EO).
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

  defp ordenadas(arestas), do: Enum.sort_by(arestas, &{&1["source"], &1["target"]})

  defp leituras(tenant) do
    Repo.all(
      from r in Reading,
        where: r.tenant_id == ^tenant.id,
        order_by: [r.network, r.window_days]
    )
    |> Map.new(&{{&1.network, &1.window_days}, &1})
  end

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    admin = user_fixture(tenant, "admin")
    org = organizacao_com_repositorio(tenant)
    repo = org.observed_repository_id

    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    caio = pessoa(tenant, "Caio")
    dora = pessoa(tenant, "Dora Sem Aresta")
    leds = pessoa(tenant, "LEDS")

    na_organizacao(tenant, org.organization, [ana, bia, caio, dora, leds])
    {:ok, _} = Tenants.declare_organization_account(tenant, leds.id, "shared", admin)

    # Designação: Ana → Bia 2 (dentro de 30), Ana → Caio 1 (aberta há 60), Ana → LEDS (excluída),
    # e uma aberta há 100 dias e atualizada há 10: só entra na de 180.
    issue(tenant, repo, ana, [bia], dias_atras(5))
    issue(tenant, repo, ana, [bia], dias_atras(10))
    issue(tenant, repo, ana, [caio], dias_atras(60))
    issue(tenant, repo, ana, [leds], dias_atras(5))
    issue(tenant, repo, caio, [ana], dias_atras(100), dias_atras(10))

    %{
      tenant: tenant,
      admin: admin,
      org: org,
      ana: ana,
      bia: bia,
      caio: caio,
      dora: dora,
      leds: leds
    }
  end

  test "sem leitura da 073, a revisão fica ausente e a designação é gravada", ctx do
    assert {:ok, relator} =
             NetworkAnalysis.compute(ctx.tenant, ctx.org.organization, DateTime.utc_now(:second))

    por = Map.new(relator.readings, &{{&1.network, &1.window_days}, &1})
    assert por[{"review", 90}].outcome == {:ausente, :not_computed}
    assert por[{"assignment", 90}].outcome == :computed

    l = leituras(ctx.tenant)

    assert Map.keys(l) |> Enum.sort() == [
             {"assignment", 30},
             {"assignment", 90},
             {"assignment", 180}
           ]
  end

  test "com a 073, seis leituras; a revisão é a da 073 da mesma janela", ctx do
    for {revisor, autor, n} <- [{ctx.ana, ctx.bia, 3}, {ctx.bia, ctx.caio, 1}], i <- 1..n do
      cr = solicitacao(ctx.tenant, ctx.org.observed_repository_id, autor, dias_atras(20 + i))
      revisao(ctx.tenant, cr, revisor, dias_atras(19 + i))
    end

    {:ok, _} = ReviewNetwork.compute(ctx.tenant, ctx.org.organization, DateTime.utc_now(:second))
    da_073 = ReviewNetwork.current_edges(ctx.tenant, ctx.org.organization.id)

    assert {:ok, _} =
             NetworkAnalysis.compute(ctx.tenant, ctx.org.organization, DateTime.utc_now(:second))

    l = leituras(ctx.tenant)
    assert map_size(l) == 6

    for dias <- [30, 90, 180] do
      revisao = l[{"review", dias}]

      esperado =
        Enum.map(
          da_073[dias].edges,
          &%{"source" => &1.source, "target" => &1.target, "weight" => &1.weight}
        )

      assert revisao.edges == esperado
      assert revisao.source_computed_at == da_073[dias].computed_at
      assert revisao.exclusions["organization_account"] == 0
    end

    assert ordenadas(l[{"review", 90}].edges) ==
             ordenadas([
               %{"source" => ctx.ana.id, "target" => ctx.bia.id, "weight" => 3},
               %{"source" => ctx.bia.id, "target" => ctx.caio.id, "weight" => 1}
             ])
  end

  test "a designação pela abertura da issue, com as contagens da classificação", ctx do
    {:ok, _} =
      NetworkAnalysis.compute(ctx.tenant, ctx.org.organization, DateTime.utc_now(:second))

    l = leituras(ctx.tenant)

    trinta = l[{"assignment", 30}]
    assert trinta.edges == [%{"source" => ctx.ana.id, "target" => ctx.bia.id, "weight" => 2}]
    assert trinta.exclusions["organization_account"] == 1
    assert trinta.exclusions["issues"] == 3
    assert trinta.exclusions["pairs"] == 3

    noventa = l[{"assignment", 90}]

    assert ordenadas(noventa.edges) ==
             ordenadas([
               %{"source" => ctx.ana.id, "target" => ctx.bia.id, "weight" => 2},
               %{"source" => ctx.ana.id, "target" => ctx.caio.id, "weight" => 1}
             ])

    # Aberta há 100 dias e atualizada há 10: só na de 180.
    cento_e_oitenta = l[{"assignment", 180}]

    assert %{"source" => ctx.caio.id, "target" => ctx.ana.id, "weight" => 1} in cento_e_oitenta.edges

    refute Enum.any?(noventa.edges, &(&1["source"] == ctx.caio.id))
  end

  test "pessoa da organização sem aresta conta à parte, e não é nó; a conta declarada não", ctx do
    {:ok, _} =
      NetworkAnalysis.compute(ctx.tenant, ctx.org.organization, DateTime.utc_now(:second))

    trinta = leituras(ctx.tenant)[{"assignment", 30}]

    nos = Enum.map(trinta.nodes, & &1["id"])
    assert Enum.sort(nos) == Enum.sort([ctx.ana.id, ctx.bia.id])
    refute ctx.dora.id in nos
    refute ctx.leds.id in nos

    # Caio e Dora: da organização, pessoas, sem aresta na janela. LEDS é conta da organização.
    assert trinta.people_without_edges == 2
  end
end
