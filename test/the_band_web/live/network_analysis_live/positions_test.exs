defmodule TheBandWeb.NetworkAnalysisLive.PositionsTest do
  @moduledoc """
  A página Positions and profiles — feature 076, T046 (US8, cen. 3 a 5; FR-044 a FR-047;
  FR-015 regra 7; DS1, A11; protótipo 3.6.1 a 3.6.3).

  Rede de 12 pessoas (acima do mínimo de 10 da base). Três contas: a administração; Lia, com
  vínculo de equipe e sem escopo concedido; Caio, com o escopo da mesma equipe concedido.

  - a administração vê a posição de todos, em frase, com os percentis e o corte;
  - Lia vê a **própria** posição e não a do colega (A11);
  - Caio vê a posição dos alcançados e nenhuma linha nem contagem de quem é de fora;
  - a frase de não-avaliação e a regra a um clique.

  **Defeito a injetar**: usar `pessoas_alcancadas/2` sem a opção concedida (o alcance derivado no
  lugar do concedido); o caso do vínculo derivado reprova.
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

    [ana, bia, lia, caio] = for n <- ~w(Ana Bia Lia Caio), do: pessoa(tenant, "#{n} Posicao")
    fora = for i <- 1..8, do: pessoa(tenant, "Fora#{i} Posicao")

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

    # Uma cadeia com 12 pessoas: Ana no meio, ligada a todos de fora.
    todos = [lia, bia, ana | fora] ++ [caio]

    arestas =
      for({u, v} <- Enum.zip(todos, tl(todos)), do: %{source: u.id, target: v.id, weight: 1}) ++
        for p <- fora, do: %{source: ana.id, target: p.id, weight: 2}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => 20},
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
      fora: fora
    }
  end

  defp abrir(ctx, user) do
    {:ok, _view, html} =
      live(
        log_in(ctx.conn, user),
        "/network-analysis/#{ctx.org.id}/positions?network=assignment&window=90"
      )

    html
  end

  defp q(html, sel), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(sel)
  defp texto(html, sel), do: html |> q(sel) |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

  defp linha(html, nome) do
    html
    |> q("#posicoes tbody tr")
    |> Enum.map(&(LazyHTML.text(&1) |> String.replace(~r/\s+/, " ")))
    |> Enum.find(&String.contains?(&1, nome))
  end

  test "administração vê a posição de todos, em frase, com os percentis e o corte", ctx do
    html = abrir(ctx, ctx.admin)

    assert linha(html, "Ana Posicao") =~ "Central position."
    assert linha(html, "Ana Posicao") =~ ~r/percentile \d+/
    assert linha(html, "Ana Posicao") =~ "cut: degree > 80 and betweenness > 80"
    assert linha(html, "Fora1 Posicao")
    assert texto(html, "#nao-avaliacao") =~ "must not be used to evaluate a person"
    assert texto(html, "#regra-da-posicao") =~ "How the position is decided"
  end

  test "A11: só com vínculo de equipe, vê a própria posição e não a do colega", ctx do
    html = abrir(ctx, ctx.lia_conta)

    # Mediu: a lista chegou, com Lia e o colega.
    assert linha(html, "Lia Posicao") =~ ~r/percentile \d+/
    assert linha(html, "Ana Posicao") =~ "shown only to those granted a scope"
    refute linha(html, "Ana Posicao") =~ "Central position"
  end

  test "com escopo concedido, posição dos alcançados, e nada de quem é de fora", ctx do
    html = abrir(ctx, ctx.caio_conta)

    assert linha(html, "Ana Posicao") =~ "Central position."
    for p <- ctx.fora, do: refute(html =~ p.name)
    refute html =~ ~r/people outside your reach (are|is) /i
  end
end
