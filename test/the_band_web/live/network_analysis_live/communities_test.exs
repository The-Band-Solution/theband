defmodule TheBandWeb.NetworkAnalysisLive.CommunitiesTest do
  @moduledoc """
  A página Communities com o recorte — feature 076, T037 (US4, cen. 2 a 5; FR-015 regras 2, 4 e
  6; FR-028 a FR-031; DS1; A4, A5 de `seguranca.md`; protótipo aprovado 3.3.1 a 3.3.4 e 3.7.4).

  Três contas na mesma organização: a administração; Lia, conta de membro que alcança Ana e Bia
  pela equipe declarada (vínculo derivado, sem escopo concedido); e Caio, a quem a administração
  concedeu o escopo da equipe (alcança os mesmos, por concessão). A comunidade A tem Ana, Bia,
  Lia e `fora` pessoas de fora; a comunidade B tem só 3 pessoas de fora.

  - a administração vê os membros por nome, o tamanho e os três mais ligados da comunidade
    inteira;
  - com 1 ou 2 de fora, o tamanho e as ligações da comunidade **não aparecem**, com a frase do
    porquê; com 3, aparecem, e os de fora são agregados (*"3 outside your reach"*);
  - a comunidade B, sem ninguém alcançado, não tem cartão; o número de comunidades aparece,
    porque ela tem 3 pessoas;
  - sem escopo concedido (Lia), os mais ligados não aparecem (DS1); com ele (Caio), aparecem
    **entre os alcançados** (*"among the members you reach"*), e nenhuma pessoa de fora entra;
  - a tela diz que comunidade não é equipe, diz o método, e cita as faixas com a fonte;
  - nenhum nome nem id de fora chega ao HTML.

  **Defeito a injetar**: mostrar o tamanho mesmo suprimido; o caso de 2 de fora reprova.
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

  # A comunidade A (Ana, Bia, Lia e os de fora) e a B (só de fora). O cálculo é o real; as
  # comunidades e os graus internos são escritos na leitura, porque o que se testa é o recorte.
  defp organizacao(ctx, fora) do
    %{organization: org} = organizacao_com_repositorio(ctx.tenant)
    de_fora = for i <- 1..fora, do: pessoa(ctx.tenant, "Fora#{i} Comunidade#{fora}")
    de_b = for i <- 1..3, do: pessoa(ctx.tenant, "Bfora#{i} Comunidade#{fora}")
    [ana, bia, lia] = [ctx.ana, ctx.bia, ctx.lia]

    cadeia = [ana | de_fora]
    cadeia_b = [ana | de_b]

    arestas =
      [%{source: bia.id, target: ana.id, weight: 2}, %{source: lia.id, target: bia.id, weight: 1}] ++
        for {u, v} <- Enum.zip(cadeia, tl(cadeia)) ++ Enum.zip(cadeia_b, tl(cadeia_b)),
            do: %{source: u.id, target: v.id, weight: 1}

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

    membros_a = [ana.id, bia.id, lia.id | Enum.map(de_fora, & &1.id)]
    membros_b = Enum.map(de_b, & &1.id)
    # Os de fora são os mais ligados dentro: só a administração pode vê-los no núcleo.
    grau = fn id -> if id in [ana.id, bia.id, lia.id], do: 1, else: 5 end
    grau = fn id -> if id == ana.id, do: 4, else: grau.(id) end

    for r <- Repo.all(from r in Reading, where: r.organization_id == ^org.id) do
      nos =
        Enum.map(r.nodes, fn n ->
          Map.merge(n, %{
            "community" => if(n["id"] in membros_b, do: 2, else: 1),
            "internal_degree" => grau.(n["id"])
          })
        end)

      comunidades = [
        %{
          "index" => 1,
          "members" => Enum.sort(membros_a),
          "internal_edges" => 7,
          "outside_edges" => 1
        },
        %{
          "index" => 2,
          "members" => Enum.sort(membros_b),
          "internal_edges" => 2,
          "outside_edges" => 1
        }
      ]

      Repo.update_all(from(x in Reading, where: x.id == ^r.id),
        set: [nodes: nos, communities: comunidades]
      )
    end

    %{org: org, fora: de_fora ++ de_b}
  end

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    %{organization: org_equipe} = organizacao_com_repositorio(tenant)

    ana = pessoa(tenant, "Ana Comunidade")
    bia = pessoa(tenant, "Bia Comunidade")
    lia = pessoa(tenant, "Lia Comunidade")
    caio = pessoa(tenant, "Caio Comunidade")

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

    %{
      conn: conn,
      tenant: tenant,
      admin: admin,
      lia_conta: lia_conta,
      caio_conta: caio_conta,
      ana: ana,
      bia: bia,
      lia: lia
    }
  end

  defp abrir(ctx, user, org) do
    {:ok, _view, html} =
      live(
        log_in(ctx.conn, user),
        "/network-analysis/#{org.id}/communities?network=assignment&window=90"
      )

    html
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)
  defp texto(html, sel), do: html |> q(sel) |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

  defp vazamentos(html, pessoas) do
    for p <- pessoas, segredo <- [p.id, p.name], String.contains?(html, segredo), do: segredo
  end

  test "administração vê os membros por nome, o tamanho e os mais ligados da comunidade", ctx do
    %{org: org, fora: fora} = organizacao(ctx, 3)
    html = abrir(ctx, ctx.admin, org)

    cartao = texto(html, "#comunidade-1")
    assert cartao =~ "6 people"
    assert cartao =~ "7 links inside · 1 to other communities"
    assert cartao =~ "Most linked inside:"
    refute cartao =~ "among the members you reach"
    for p <- Enum.take(fora, 3), do: assert(cartao =~ p.name)
    assert texto(html, "#comunidade-2") =~ "3 people"
    assert texto(html, "#numero-de-comunidades") =~ "2"
  end

  test "conta parcial: com 3 de fora, tamanho e agregado; a comunidade só de fora sem cartão",
       ctx do
    %{org: org, fora: fora} = organizacao(ctx, 3)
    html = abrir(ctx, ctx.caio_conta, org)

    cartao = texto(html, "#comunidade-1")
    assert cartao =~ "6 people"
    assert cartao =~ "3 outside your reach"
    assert cartao =~ "Ana Comunidade"
    assert Enum.empty?(q(html, "#comunidade-2"))
    assert texto(html, "#numero-de-comunidades") =~ "2"
    assert vazamentos(html, fora) == []
  end

  test "conta parcial: com 1 ou 2 de fora, tamanho e ligações não aparecem, e diz por quê", ctx do
    for n <- [1, 2] do
      %{org: org, fora: fora} = organizacao(ctx, n)
      html = abrir(ctx, ctx.caio_conta, org)
      cartao = texto(html, "#comunidade-1")

      # Mediu: o cartão chegou, com os alcançados.
      assert cartao =~ "Ana Comunidade"
      refute cartao =~ ~r/\b#{n + 3} people\b/
      assert cartao =~ "size not shown: it would count fewer than 3 people outside your reach"
      assert cartao =~ "Links not shown"
      refute cartao =~ ~r/\d+ outside your reach/
      assert vazamentos(html, fora) == []
    end
  end

  test "DS1: sem escopo concedido, os mais ligados não aparecem; com ele, entre os alcançados",
       ctx do
    %{org: org, fora: fora} = organizacao(ctx, 3)

    lia = texto(abrir(ctx, ctx.lia_conta, org), "#comunidade-1")
    assert lia =~ "Ana Comunidade"
    refute lia =~ "Most linked inside"
    assert lia =~ "shown only to those granted a scope"

    caio = abrir(ctx, ctx.caio_conta, org)
    cartao = texto(caio, "#comunidade-1")
    assert cartao =~ "Most linked inside, among the members you reach: Ana Comunidade (4)"
    assert vazamentos(caio, fora) == []
  end

  test "a página diz que comunidade não é equipe, o método e as faixas com a fonte", ctx do
    %{org: org} = organizacao(ctx, 3)
    html = abrir(ctx, ctx.admin, org)

    assert texto(html, "#nao-sao-equipes") =~ "Not the declared teams"
    assert texto(html, "#metodo") =~ "greedy modularity method of Clauset, Newman and Moore"
    refute html =~ "Louvain"
    assert texto(html, "#faixas-citadas") =~ "(Clauset, Newman and Moore, 2004)"
    assert texto(html, "#q-rand") =~ "100 networks"
    # FR-021: a cor nunca é o único sinal — a letra está no cartão e na lista.
    assert texto(html, "#comunidade-1 h3") =~ "A"
    assert html =~ "Community A"
  end

  test "a vista de comunidades do grafo alterna na página Graph, sem recalcular", ctx do
    %{org: org} = organizacao(ctx, 3)

    {:ok, _view, html} =
      live(
        log_in(ctx.conn, ctx.admin),
        "/network-analysis/#{org.id}/graph?network=assignment&window=90&view=communities"
      )

    assert texto(html, "#grafo h2") =~ "Community graph"
    assert html =~ "Community A"
    assert Enum.count(q(html, "#grafo-ponderado-svg polygon")) == 2
  end
end
