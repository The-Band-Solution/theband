defmodule TheBand.NetworkAnalysis.ProfileTest do
  @moduledoc """
  O perfil abre só para quem se alcança — feature 076, T047 (US9, cen. 2 a 4; FR-013, FR-014,
  FR-049; A10 de `seguranca.md`; `contracts/network-analysis.md`, `profile/5`).

  - pessoa de outro tenant, inexistente, fora do alcance e `abc` dão o **mesmo** `not_found`;
  - pessoa alcançada sem aresta na rede dá `no_edges_in_window` (A10), e não zeros;
  - os pares com pessoas de fora só somados, sem nome nem número por pessoa;
  - com uma **liderança declarada** (que `pode_ver/3` aceita e `pessoas_alcancadas/2` não), o
    perfil e o grafo concordam: a liderada não está no grafo do líder, e o perfil dela é
    `not_found`.

  **Defeito a injetar**: usar `pode_ver/3` no perfil; o caso da liderança declarada reprova pela
  divergência.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis
  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @selecao %{network: "assignment", window: 90, view: "weighted"}

  defp equipe(tenant, admin, nome, organization_id) do
    {:ok, t} = EO.create_declared_team(tenant, nome, admin.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^t.id, :binary_id),
        update: [set: [organization_id: type(^organization_id, :binary_id)]]
      ),
      []
    )

    t
  end

  defp aloca(tenant, admin, pessoa, equipe, papel) do
    {:ok, _} =
      EO.allocate(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -86_400),
        declared_by_user_id: admin.id
      })
  end

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    {outro_tenant, _} = tenant_with_admin()
    %{organization: org} = organizacao_com_repositorio(tenant)

    lider = pessoa(tenant, "Lider Perfil")
    liderada = pessoa(tenant, "Liderada Perfil")
    colega = pessoa(tenant, "Colega Perfil")
    fora = pessoa(tenant, "Fora Perfil")
    sem_aresta = pessoa(tenant, "Sem Aresta Perfil")
    de_outro = pessoa(outro_tenant, "Outro Tenant Perfil")

    delivery = equipe(tenant, admin, "Delivery", org.id)
    discovery = equipe(tenant, admin, "Discovery", org.id)
    {:ok, lideranca} = EO.create_role(tenant, org.id, %{code: "head", name: "Head"}, admin.id)
    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    for p <- [lider, colega, sem_aresta], do: aloca(tenant, admin, p, delivery, dev)
    aloca(tenant, admin, lider, delivery, lideranca)
    aloca(tenant, admin, liderada, discovery, dev)
    {:ok, _} = EO.declare_grant(tenant, lideranca.id, "organization", admin.id)

    {:ok, conta} =
      Tenants.create_user(tenant, %{
        "email" => "lider-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    conta = elo_de_identidade(tenant, conta, lider)

    arestas = [
      %{source: lider.id, target: colega.id, weight: 3},
      %{source: lider.id, target: fora.id, weight: 2},
      %{source: lider.id, target: liderada.id, weight: 1},
      %{source: colega.id, target: lider.id, weight: 1}
    ]

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => 7},
      people_without_edges: 1,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(tenant, org, DateTime.utc_now(:second), Parameters.fetch!(), fn _, _, _ ->
        {:ok, entrada}
      end)

    %{
      tenant: tenant,
      org: org,
      conta: conta,
      lider: lider,
      liderada: liderada,
      colega: colega,
      fora: fora,
      sem_aresta: sem_aresta,
      de_outro: de_outro
    }
  end

  defp perfil(ctx, id),
    do: NetworkAnalysis.profile(ctx.tenant, ctx.conta, ctx.org.id, id, @selecao)

  test "o próprio perfil abre, com os pares por peso e os de fora só somados", ctx do
    assert {:ok, p} = perfil(ctx, ctx.lider.id)
    assert {:ok, r} = p.networks["assignment"]

    assert r.out_people == 3
    assert r.in_people == 1
    assert [%{name: "Colega Perfil", weight: 3}] = r.to
    assert r.to_outside_reach == {:agregado, 3}
    assert r.to_total == 6
    assert [%{name: "Colega Perfil", weight: 1}] = r.from
  end

  test "outro tenant, inexistente, fora do alcance e abc dão o mesmo not_found", ctx do
    # Controle: o alcance existe, e o colega abre.
    assert {:ok, _} = perfil(ctx, ctx.colega.id)

    for id <- [ctx.de_outro.id, Ecto.UUID.generate(), ctx.fora.id, "abc", nil] do
      assert perfil(ctx, id) == {:error, :not_found}
    end
  end

  test "alcançada sem aresta: no_edges_in_window, e não zeros", ctx do
    assert {:ok, p} = perfil(ctx, ctx.sem_aresta.id)
    assert p.networks["assignment"] == {:ausente, :no_edges_in_window}
  end

  test "com liderança declarada, perfil e grafo concordam", ctx do
    # A liderança declarada abre a página da pessoa (`pode_ver/3`)…
    assert {:ok, _} = Tenants.pode_ver(ctx.tenant, ctx.conta, ctx.liderada.id)

    # …mas não o alcance da área: a liderada não está no grafo do líder…
    {:ok, visao} = NetworkAnalysis.read(ctx.tenant, ctx.conta, ctx.org.id, @selecao)
    {:ok, grafo} = visao.graph
    assert Enum.any?(grafo.nodes, &(&1[:id] == ctx.colega.id))
    refute Enum.any?(grafo.nodes, &(&1[:id] == ctx.liderada.id))

    # …e o perfil dela também não abre.
    assert perfil(ctx, ctx.liderada.id) == {:error, :not_found}
  end
end
