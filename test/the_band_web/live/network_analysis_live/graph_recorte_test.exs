defmodule TheBandWeb.NetworkAnalysisLive.GraphRecorteTest do
  @moduledoc """
  O grafo ponderado com o recorte — feature 076, T033 (US3, cen. 5; FR-011 a FR-016, FR-022,
  FR-025; A4, A5, A6, A7 de `seguranca.md`; protótipo aprovado 3.7.2, 3.7.3, 3.8.1).

  Duas contas na mesma organização: a administração e Lia, conta de membro que alcança Ana e Bia
  pela equipe declarada. As pessoas de fora estão **na mesma comunidade**, em três organizações:
  com 4, com 2 e com 1 de fora.

  - administração vê as 4 de fora por nome, nas posições gravadas;
  - Lia vê **um** nó *"People outside your reach — community B (4)"*, sem nome, sem id, sem
    hash do id; com 1 ou 2 de fora, nenhum nó, só a marca *"has links outside your reach"*;
  - as posições da visão parcial são recalculadas sobre ela, e não as da rede inteira;
  - o id do agregado não depende de quem ele contém (A6): `outside-1` em leituras com pessoas de
    fora diferentes;
  - a lista do telefone é a mesma visão.

  **Defeito a injetar**: renderizar a lista (e o desenho) da rede inteira — `View` devolvendo
  todas as pessoas da leitura com alcance parcial; o caso parcial reprova.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBandWeb.NetworkAnalysisLive.GraphComponents

  # Uma organização com Ana, Bia e Lia (alcançadas por Lia) e `fora` pessoas de fora, todas na
  # comunidade 2, ligadas a Ana numa cadeia. Calculada, e com as comunidades escritas na leitura
  # (a detecção é a T035; aqui o que se testa é o recorte).
  defp organizacao(ctx, fora) do
    %{organization: org} = organizacao_com_repositorio(ctx.tenant)
    de_fora = for i <- 1..fora, do: pessoa(ctx.tenant, "Fora#{i} Pessoa#{fora}")
    [ana, bia, lia] = [ctx.ana, ctx.bia, ctx.lia]

    cadeia = [ana | de_fora]

    arestas =
      [%{source: bia.id, target: ana.id, weight: 2}, %{source: lia.id, target: bia.id, weight: 1}] ++
        for {u, v} <- Enum.zip(cadeia, tl(cadeia)), do: %{source: u.id, target: v.id, weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => 5},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(
        ctx.tenant,
        org,
        DateTime.utc_now(:second),
        Parameters.fetch!(),
        fn _, _, _ -> {:ok, entrada} end
      )

    ids_fora = MapSet.new(de_fora, & &1.id)

    for r <- Repo.all(from r in Reading, where: r.organization_id == ^org.id) do
      nos = Enum.map(r.nodes, &Map.put(&1, "community", comunidade(&1["id"], ids_fora)))

      Repo.update_all(from(x in Reading, where: x.id == ^r.id), set: [nodes: nos])
    end

    %{org: org, fora: de_fora}
  end

  defp comunidade(id, ids_fora), do: if(MapSet.member?(ids_fora, id), do: 2, else: 1)

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    %{organization: org_equipe} = organizacao_com_repositorio(tenant)

    ana = pessoa(tenant, "Ana Alcance")
    bia = pessoa(tenant, "Bia Alcance")
    lia = pessoa(tenant, "Lia Alcance")

    {:ok, equipe} = EO.create_declared_team(tenant, "X", admin.id)

    {:ok, papel} =
      EO.create_role(tenant, org_equipe.id, %{code: "dev", name: "Dev"}, admin.id)

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

    %{conn: conn, tenant: tenant, admin: admin, conta: conta, ana: ana, bia: bia, lia: lia}
  end

  defp abrir(ctx, user, org) do
    {:ok, _view, html} =
      live(
        log_in(ctx.conn, user),
        "/network-analysis/#{org.id}/graph?network=assignment&window=90"
      )

    html
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)

  defp textos(html, sel),
    do: html |> q(sel) |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  defp agregados(html), do: html |> q("svg circle.nd[id*='outside-']") |> Enum.count()

  defp vazamentos(html, pessoas) do
    for p <- pessoas,
        segredo <- [
          p.id,
          p.name,
          :crypto.hash(:sha256, p.id) |> Base.encode16(case: :lower),
          :crypto.hash(:md5, p.id) |> Base.encode16(case: :lower),
          :crypto.hash(:sha256, p.id) |> Base.encode16(),
          :crypto.hash(:md5, p.id) |> Base.encode16()
        ],
        String.contains?(html, segredo),
        do: segredo
  end

  test "administração vê as 4 de fora por nome, nas posições gravadas", ctx do
    %{org: org, fora: fora} = organizacao(ctx, 4)
    html = abrir(ctx, ctx.admin, org)

    nomes = textos(html, "#grafo-ponderado-lista td[data-label=person]")
    for p <- fora, do: assert(Enum.any?(nomes, &String.starts_with?(&1, p.name)))
    assert agregados(html) == 0
    assert Enum.count(q(html, "svg circle.nd")) == 7

    [leitura] =
      Repo.all(
        from r in Reading,
          where:
            r.organization_id == ^org.id and r.network == "assignment" and r.window_days == 90
      )

    # O desenho enquadra as posições gravadas no quadro (T053, D2): o cx de Ana é o dela depois
    # do enquadramento de TODAS as gravadas, e não o de posições recalculadas.
    gravadas =
      leitura.nodes
      |> Enum.filter(&is_number(&1["x"]))
      |> Map.new(&{&1["id"], {&1["x"], &1["y"]}})

    {x_ana, _} = GraphComponents.fit_to_frame(gravadas)[ctx.ana.id]

    assert q(html, "#grafo-ponderado-n-#{ctx.ana.id}") |> LazyHTML.attribute("cx") == [
             :erlang.float_to_binary(x_ana, decimals: 1)
           ]
  end

  test "conta parcial vê um nó sem nome por comunidade, e nenhum id de fora, nem hash", ctx do
    %{org: org, fora: fora} = organizacao(ctx, 4)
    html = abrir(ctx, ctx.conta, org)

    # Mediu: a visão chegou, com os alcançados por nome e o agregado.
    pessoas = textos(html, "#grafo-ponderado-lista td[data-label=person]")
    assert Enum.any?(pessoas, &String.starts_with?(&1, "Ana Alcance"))
    assert agregados(html) == 1
    assert "People outside your reach — community B (4)" in textos(html, "svg text")

    assert textos(html, "#grafo-ponderado-n-outside-1 title") == [
             "4 people outside your reach. No names."
           ]

    assert vazamentos(html, fora) == []
    assert Enum.count(q(html, "#grafo-ponderado-lista tbody tr")) == 4
  end

  test "com 1 ou 2 de fora, nenhum nó: só a marca no alcançado ligado a eles", ctx do
    for n <- [1, 2] do
      %{org: org, fora: fora} = organizacao(ctx, n)
      html = abrir(ctx, ctx.conta, org)

      assert "Ana Alcance" in textos(html, "svg text")
      assert agregados(html) == 0

      [marca] =
        html
        |> textos("#grafo-ponderado-lista td[data-label=person]")
        |> Enum.filter(&String.starts_with?(&1, "Ana Alcance"))

      assert marca =~ "has links outside your reach"
      assert vazamentos(html, fora) == []
    end
  end

  test "A6: o id do agregado é a posição, e não depende de quem ele contém", ctx do
    %{org: org1, fora: fora1} = organizacao(ctx, 3)
    %{org: org2, fora: fora2} = organizacao(ctx, 3)
    assert MapSet.disjoint?(MapSet.new(fora1, & &1.id), MapSet.new(fora2, & &1.id))

    for {org, fora} <- [{org1, fora1}, {org2, fora2}] do
      html = abrir(ctx, ctx.conta, org)
      assert Enum.count(q(html, "#grafo-ponderado-n-outside-1")) == 1
      assert vazamentos(html, fora) == []
    end
  end

  test "as posições da visão parcial não são as da rede inteira", ctx do
    %{org: org} = organizacao(ctx, 4)
    total = abrir(ctx, ctx.admin, org)
    parcial = abrir(ctx, ctx.conta, org)

    cx = fn html, id -> q(html, "#grafo-ponderado-n-#{id}") |> LazyHTML.attribute("cx") end

    refute Enum.map([ctx.ana.id, ctx.bia.id, ctx.lia.id], &cx.(total, &1)) ==
             Enum.map([ctx.ana.id, ctx.bia.id, ctx.lia.id], &cx.(parcial, &1))

    # A mesma visão desenha a mesma figura.
    svg = fn html -> html |> q("#grafo-ponderado-svg") |> LazyHTML.to_html() end
    assert svg.(parcial) == svg.(abrir(ctx, ctx.conta, org))
  end

  test "E4 do #1383: a leitura de revisão desatualizada não vira desenho", ctx do
    %{org: org} = organizacao(ctx, 4)

    # Mediu: a designação, da mesma entrada, desenha.
    assert Enum.count(q(abrir(ctx, ctx.admin, org), "svg circle.nd")) == 7

    # A revisão gravada sem a contagem da conta da organização é desatualizada (E4).
    {:ok, _view, html} =
      live(
        log_in(ctx.conn, ctx.admin),
        "/network-analysis/#{org.id}/graph?network=review&window=90"
      )

    assert textos(html, "#sem-leitura") |> hd() =~ "calculated before the latest change"
    assert Enum.empty?(q(html, "svg"))
    assert Enum.empty?(q(html, "#grafo"))
  end

  test "no telefone, o desenho some e a lista é a mesma visão, empilhada", ctx do
    %{org: org} = organizacao(ctx, 4)
    html = abrir(ctx, ctx.conta, org)

    [caixa] = html |> q("#grafo-ponderado > div.hidden") |> LazyHTML.attribute("class")
    assert caixa =~ "sm:grid"

    assert html |> q("#grafo-ponderado-lista") |> LazyHTML.attribute("class") == [
             "table table-sm stacked"
           ]

    assert textos(html, "#grafo-ponderado p.sm\\:hidden") |> hd() =~ "graph becomes the list"
  end
end
