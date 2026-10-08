defmodule TheBand.NetworkAnalysis.CommandsComunidadesTest do
  @moduledoc """
  As comunidades e a modularidade dos aleatórios gravadas na leitura — feature 076, T035 e T036
  (FR-027 a FR-029; R8; data-model.md §1.2 e §1.3).

  - dois triângulos ligados por uma aresta: duas comunidades na leitura, cada nó com a sua e o
    grau interno; a modularidade 5/14 com o número de comunidades; o Q_rand dos 100 aleatórios,
    com quantos entraram;
  - sem aresta, a modularidade e os aleatórios ficam **ausentes** com `no_edge_in_window`, e nunca
    0;
  - a impressão digital muda quando o código passa a calcular medida nova (`@calculo`): a leitura
    gravada antes dela é recalculada, e não fica para sempre sem a medida.
  """
  use TheBand.DataCase, async: false

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Ontology.KnowledgeBase

  @agora ~U[2026-10-05 12:00:00Z]

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    org = organization_fixture(tenant)
    ids = for _ <- 1..6, do: Ecto.UUID.generate()
    %{tenant: tenant, org: org, ids: Enum.sort(ids), parametros: Parameters.fetch!()}
  end

  defp entrada(arestas),
    do: %{
      edges: arestas,
      exclusions: %{"issues" => 1},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

  defp dois_triangulos([a, b, c, d, e, f]) do
    for {u, v} <- [{a, b}, {b, c}, {a, c}, {d, e}, {e, f}, {d, f}, {c, d}],
        do: %{source: u, target: v, weight: 1}
  end

  defp leitura(tenant, rede, dias) do
    Repo.one!(
      from r in Reading,
        where: r.tenant_id == ^tenant.id and r.network == ^rede and r.window_days == ^dias
    )
  end

  test "dois triângulos com ponte: duas comunidades, Q = 5/14 e o Q_rand dos aleatórios", ctx do
    [a, b, c, d, e, f] = ctx.ids
    arestas = dois_triangulos(ctx.ids)

    {:ok, _, [_ | _]} =
      Commands.compute(ctx.tenant, ctx.org, @agora, ctx.parametros, fn _, _, _ ->
        {:ok, entrada(arestas)}
      end)

    r = leitura(ctx.tenant, "assignment", 90)
    comunidade = Map.new(r.nodes, &{&1["id"], &1["community"]})

    assert comunidade[a] == comunidade[b] and comunidade[b] == comunidade[c]
    assert comunidade[d] == comunidade[e] and comunidade[e] == comunidade[f]
    refute comunidade[a] == comunidade[d]
    assert Enum.all?(r.nodes, &(&1["internal_degree"] == 2))

    assert [
             %{"index" => 1, "internal_edges" => 3, "outside_edges" => 1},
             %{"index" => 2, "internal_edges" => 3, "outside_edges" => 1}
           ] = r.communities

    assert %{"value" => q, "communities" => 2} = r.measures["modularity"]
    assert_in_delta q, 5 / 14, 1.0e-9

    assert %{"graphs" => 100, "modularity" => %{"value" => q_rand, "graphs_defined" => 100}} =
             r.measures["random"]

    assert is_float(q_rand)
  end

  test "sem aresta, modularidade e aleatórios ausentes com o motivo, nunca 0", ctx do
    {:ok, _, _} =
      Commands.compute(ctx.tenant, ctx.org, @agora, ctx.parametros, fn _, _, _ ->
        {:ok, entrada([])}
      end)

    r = leitura(ctx.tenant, "review", 30)

    assert r.communities == []
    assert r.measures["modularity"] == %{"absent" => "no_edge_in_window"}
    assert r.measures["random"] == %{"absent" => "no_edge_in_window"}
  end

  test "a impressão digital leva o que o código calcula", ctx do
    e = entrada(dois_triangulos(ctx.ids))
    versoes = ctx.parametros.knowledge_versions

    # A impressão é função da entrada, das versões da base e da lista do que o código calcula:
    # com a mesma entrada e as mesmas versões, muda se e só se a lista mudar. A lista não é
    # parâmetro, e por isso a prova é a de que a impressão de hoje não é a da fórmula sem ela.
    sem_calculo =
      :sha256
      |> :crypto.hash(
        :erlang.term_to_binary([
          e.edges |> Enum.map(&"#{&1.source}|#{&1.target}|#{&1.weight}") |> Enum.sort(),
          e.exclusions |> Enum.sort(),
          e.people_without_edges,
          versoes |> Enum.sort()
        ])
      )
      |> Base.encode16(case: :lower)

    refute Commands.impressao_digital(e, versoes) == sem_calculo
  end
end
