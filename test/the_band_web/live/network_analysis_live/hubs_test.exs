defmodule TheBandWeb.NetworkAnalysisLive.HubsTest do
  @moduledoc """
  A página Hubs só entre alcançados — feature 076, T040 (US5, cen. 1 a 6; FR-032 a FR-036,
  FR-047; FR-015 regra 5; R1 da segurança, A3, A11; DS1, DS5; protótipo 3.4.1 a 3.4.4).

  A rede: uma estrela cujo centro é **Hub Fora**, de fora do alcance, ligado a Ana, Bia, Lia e a
  três outras pessoas de fora; e Ana — Bia. Hub Fora tem a maior intermediação da rede.

  - a administração vê as quatro listas da rede inteira, com Hub Fora no topo do grau e da
    intermediação, os rótulos de grau por sentido e a frase de não-avaliação;
  - a conta com escopo concedido (Caio) vê só alcançados, *"Among the people you reach"*, e
    *"People outside your reach are not ranked here."*; Hub Fora não tem linha, com ou sem valor,
    e nenhum número de posição na rede inteira aparece (A3);
  - a conta só com vínculo de equipe (Lia) não vê hubs com nome de colega (A11, DS1);
  - a conta sem alcance não vê lista nenhuma (DS5).

  **Defeito a injetar**: renderizar a lista da rede inteira com *"a person outside your reach"*
  (o texto antigo da US5) — a `View` tomando todos os nós como candidatos; o caso A3 reprova.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    %{organization: org_equipe} = organizacao_com_repositorio(tenant)
    %{organization: org} = organizacao_com_repositorio(tenant)

    [ana, bia, lia, caio] = for n <- ~w(Ana Bia Lia Caio), do: pessoa(tenant, "#{n} Hubs")
    hub = pessoa(tenant, "Hub Fora")
    fora = for i <- 1..3, do: pessoa(tenant, "Fora#{i} Hubs")

    {:ok, equipe} = EO.create_declared_team(tenant, "X", admin.id)
    {:ok, papel} = EO.create_role(tenant, org_equipe.id, %{code: "dev", name: "Dev"}, admin.id)

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

    conta = fn email, pessoa ->
      {:ok, c} = Tenants.create_user(tenant, %{"email" => email, "role" => "member"})
      {:ok, c} = Tenants.declare_person(tenant, c.id, pessoa.id, admin.id)
      c
    end

    n = System.unique_integer([:positive])
    lia_conta = conta.("lia-#{n}@example.test", lia)
    caio_conta = conta.("caio-#{n}@example.test", caio)
    {:ok, _} = Tenants.grant_scope(tenant, caio_conta.id, :team, equipe.id, admin)

    {:ok, sem_alcance} =
      Tenants.create_user(tenant, %{"email" => "x-#{n}@example.test", "role" => "member"})

    arestas =
      [%{source: ana.id, target: bia.id, weight: 2}] ++
        for p <- [ana, bia, lia | fora], do: %{source: hub.id, target: p.id, weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => 9},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(tenant, org, DateTime.utc_now(:second), Parameters.fetch!(), fn _, _, _ ->
        {:ok, entrada}
      end)

    %{
      conn: conn,
      org: org,
      admin: admin,
      lia_conta: lia_conta,
      caio_conta: caio_conta,
      sem_alcance: sem_alcance,
      hub: hub,
      fora: fora
    }
  end

  defp abrir(ctx, user) do
    {:ok, _view, html} =
      live(
        log_in(ctx.conn, user),
        "/network-analysis/#{ctx.org.id}/hubs?network=assignment&window=90"
      )

    html
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)
  defp texto(html, sel), do: html |> q(sel) |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

  defp nomes(html, lista),
    do:
      html
      |> q("##{lista} [data-nome]")
      |> Enum.map(&(LazyHTML.text(&1) |> String.trim()))

  test "administração vê a rede inteira, com o centro no topo e os rótulos por sentido", ctx do
    html = abrir(ctx, ctx.admin)

    assert hd(nomes(html, "lista-grau")) == "Hub Fora"
    assert hd(nomes(html, "lista-intermediacao")) == "Hub Fora"
    assert texto(html, "#lista-grau") =~ "opened issues assigned to 6 people"
    assert texto(html, "#lista-grau") =~ "assigned on issues opened by"
    refute html =~ "assigns to"
    assert texto(html, "#lista-proximidade") =~ "to the 6 people they reach"
    assert texto(html, "#nao-avaliacao") =~ "must not be used to evaluate a person"
    assert length(nomes(html, "lista-grau")) == 5
  end

  test "A3: com escopo concedido, só alcançados; quem é de fora não tem linha", ctx do
    html = abrir(ctx, ctx.caio_conta)

    # Mediu: as listas chegaram, com alcançados.
    assert "Ana Hubs" in nomes(html, "lista-intermediacao")
    assert texto(html, "#entre-alcancados") =~ "Among the people you reach."
    assert texto(html, "#entre-alcancados") =~ "People outside your reach are not ranked here."

    refute html =~ "Hub Fora"
    refute html =~ ctx.hub.id
    for p <- ctx.fora, do: refute(html =~ p.name)
    refute html =~ "a person outside your reach"
    refute html =~ ~r/\b\d+(st|nd|rd|th) of \d+/
    refute html =~ "normalized"
  end

  test "A11: só com vínculo de equipe, nenhum hub com nome de colega", ctx do
    html = abrir(ctx, ctx.lia_conta)

    assert texto(html, "#sem-concessao") =~ "Hubs with other people's names are available"
    refute html =~ "Ana Hubs"
    refute html =~ "Bia Hubs"
    assert Enum.empty?(q(html, "#lista-grau"))
  end

  test "DS5: sem alcance, nenhuma lista", ctx do
    html = abrir(ctx, ctx.sem_alcance)

    assert texto(html, "#sem-alcance") =~ "no list of people is shown here"
    assert Enum.empty?(q(html, "#lista-grau"))
  end
end
