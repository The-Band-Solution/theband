defmodule TheBand.NetworkAnalysis.RedesConhecidasTest do
  @moduledoc """
  As cinco redes conhecidas, a reprodutibilidade e as ausências — feature 076, T049 (SC-002,
  SC-003, SC-005; research.md R6, tolerâncias 1e-9 e 1e-6 relativa).

  `Commands.compute/5` sobre estrela, caminho, dois grupos com ponte, bipartida e desconexa; cada
  valor com a conta à mão ao lado. A mesma leitura calculada **dez vezes**, em organizações
  diferentes (para nenhuma ser `:unchanged`), comparada por `==` — nós com posições, comunidades,
  σ e Q_rand. E, numa rede sem aresta, na desconexa e na bipartida, nenhum `0`, `0.01` nem
  infinito onde o fato é ausência, na leitura e no HTML da página de distância.

  **Defeito a injetar**: somar os pesos de um mapa sem ordenar as chaves em `Communities`. Se a
  igualdade das dez não reprovar, a issue diz por que a ordem do mapa não muda o resultado.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import TheBand.DataCase, only: [organization_fixture: 1]
  import Phoenix.LiveViewTest

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Ontology.KnowledgeBase

  @agora ~U[2026-10-05 12:00:00Z]

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant, parametros: Parameters.fetch!()}
  end

  # Ids ordenáveis e estáveis: o nome diz a posição na rede.
  defp ids(n),
    do:
      for(
        i <- 1..n,
        do: "00000000-0000-0000-0000-#{String.pad_leading(Integer.to_string(i), 12, "0")}"
      )

  defp ler(ctx, pares, n_ids \\ nil) do
    org = organization_fixture(ctx.tenant)
    i = ids(n_ids || 12)

    arestas = for {u, v} <- pares, do: %{source: Enum.at(i, u), target: Enum.at(i, v), weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => length(arestas)},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(ctx.tenant, org, @agora, ctx.parametros, fn _, _, _ -> {:ok, entrada} end)

    r =
      Repo.one!(
        from r in Reading,
          where:
            r.organization_id == ^org.id and r.network == "assignment" and r.window_days == 90
      )

    {r, Map.new(r.nodes, &{&1["id"], &1}), i, org}
  end

  defp v(%{"value" => x}), do: x

  test "estrela de 6", ctx do
    {r, nos, i, _} = ler(ctx, for(f <- 1..5, do: {0, f}))
    centro = nos[Enum.at(i, 0)]

    assert_in_delta v(centro["betweenness"]), 1.0, 1.0e-9
    assert_in_delta v(centro["closeness"]), 1.0, 1.0e-9
    assert_in_delta v(centro["distance_mean"]), 1.0, 1.0e-9
    assert v(nos[Enum.at(i, 1)]["betweenness"]) == 0.0
    # 15 pares: 5 a 1 passo e 10 a 2 → 25/15; eficiência (5 + 10·½)/15 = 2/3.
    assert_in_delta v(r.measures["average_distance"]), 5 / 3, 1.0e-9
    assert v(r.measures["diameter"]) == 2
    assert_in_delta v(r.measures["global_efficiency"]), 2 / 3, 1.0e-9
  end

  test "caminho de 4", ctx do
    {r, nos, i, _} = ler(ctx, [{0, 1}, {1, 2}, {2, 3}])

    # Brandes: b está no caminho de (a, c) e de (a, d): 2 / ((4−1)(4−2)/2) = 2/3.
    assert_in_delta v(nos[Enum.at(i, 1)]["betweenness"]), 2 / 3, 1.0e-9
    assert_in_delta v(r.measures["average_distance"]), 5 / 3, 1.0e-9
    assert v(r.measures["diameter"]) == 3
    assert_in_delta v(r.measures["global_efficiency"]), 13 / 18, 1.0e-9
  end

  test "dois grupos com ponte", ctx do
    {r, nos, i, _} = ler(ctx, [{0, 1}, {1, 2}, {0, 2}, {3, 4}, {4, 5}, {3, 5}, {2, 3}])

    assert length(r.communities) == 2
    assert nos[Enum.at(i, 0)]["community"] == nos[Enum.at(i, 2)]["community"]
    refute nos[Enum.at(i, 0)]["community"] == nos[Enum.at(i, 3)]["community"]
    # W = 7; cada triângulo L = 3, S = 7: Q = 2·(3/7 − 1/4) = 5/14.
    assert_in_delta v(r.measures["modularity"]), 5 / 14, 1.0e-9
  end

  test "bipartida K(1,3): o autovetor converge sobre A + I", ctx do
    {_r, nos, i, _} = ler(ctx, [{0, 1}, {0, 2}, {0, 3}])

    rel = fn a, b -> abs(a - b) / b end
    assert rel.(v(nos[Enum.at(i, 0)]["eigenvector"]), 1 / :math.sqrt(2)) < 1.0e-6
    assert rel.(v(nos[Enum.at(i, 1)]["eigenvector"]), 1 / :math.sqrt(6)) < 1.0e-6
  end

  test "desconexa: média sobre os pares que se alcançam, com a fração", ctx do
    {r, _nos, _i, _} = ler(ctx, [{0, 1}, {1, 2}, {3, 4}])

    assert_in_delta v(r.measures["average_distance"]), 5 / 4, 1.0e-9
    assert_in_delta r.measures["average_distance"]["reachable_share"], 0.4, 1.0e-9
    assert r.measures["components"] == [3, 2]
  end

  # Dois K5 com uma ponte: 10 pessoas, para o σ existir.
  defp dois_k5,
    do: for(g <- [0, 5], a <- g..(g + 4), b <- g..(g + 4), a < b, do: {a, b}) ++ [{4, 5}]

  test "a mesma leitura dez vezes é idêntica, inclusive comunidades, σ, Q_rand e posições", ctx do
    leituras =
      for _ <- 1..10 do
        {r, _, _, _} = ler(ctx, dois_k5())
        {r.nodes, r.communities, r.measures, r.fingerprint}
      end

    {nos, comunidades, medidas, _} = hd(leituras)
    # Mediu: as medidas que a igualdade compara existem.
    assert %{"value" => _} = medidas["sigma"]
    assert %{"modularity" => %{"value" => _}} = medidas["random"]
    assert length(comunidades) == 2
    assert Enum.all?(nos, &is_float(&1["x"]))

    assert Enum.uniq(leituras) |> length() == 1
  end

  @proibidos [~r/\b0\.01\b/, ~r/infinity/i, ~r/\binf\b/i, ~r/NaN/]

  defp sem_valor_falso!(medidas) do
    texto = inspect(medidas)
    for p <- @proibidos, do: refute(texto =~ p, "a leitura tem #{inspect(p)}: #{texto}")
  end

  test "ausência nunca é 0, 0,01 nem infinito: sem aresta, desconexa e bipartida", ctx do
    {vazia, _, _, org} = ler(ctx, [])

    for chave <-
          ~w(average_distance diameter global_efficiency modularity clustering random sigma) do
      assert %{"absent" => _} = vazia.measures[chave], "#{chave} deveria ser ausente"
    end

    sem_valor_falso!(vazia.measures)

    {desconexa, _, _, _} = ler(ctx, [{0, 1}, {1, 2}, {3, 4}])
    sem_valor_falso!(desconexa.measures)
    {bipartida, _, _, _} = ler(ctx, [{0, 1}, {0, 2}, {0, 3}])
    sem_valor_falso!(bipartida.measures)

    {:ok, _view, html} =
      live(ctx.conn, "/network-analysis/#{org.id}/distance?network=assignment&window=90")

    assert html =~ "no link in this window" or html =~ "no assignment between people"
    for p <- @proibidos, do: refute(html =~ p)
    refute html =~ ~r/>\s*0\s*<span[^>]*>\s*steps/
  end
end
