defmodule TheBand.NetworkAnalysis.ParametersTest do
  @moduledoc """
  A leitura dos parâmetros da análise — feature 076, T008. **Levanta, e nunca devolve valor de
  reserva**, quando falta regra, chave ou versão, dizendo qual.

  O primeiro caso lê a base REAL (a troca do nome de uma chave lá aparece aqui). Os casos de
  falta partem da mesma base e apagam uma chave por vez: um caso por chave lida.

  **Defeito a injetar**: `Map.get(..., 100)` como reserva para `random_graphs`; o caso da chave
  apagada reprova.
  """
  use ExUnit.Case, async: false

  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase

  @analise "network.analysis.parameters"
  @papel "network.position_role"
  @aresta "assignment.network.edge"
  @janelas "review.network.parameters"

  @chaves [
    {@analise, ~w(networks values allowed)},
    {@analise, ~w(networks values windows_from)},
    {@analise, ~w(outside_reach values min_group)},
    {@analise, ~w(size_limit values max_people)},
    {@analise, ~w(size_limit values max_undirected_edges)},
    {@analise, ~w(hubs_list_size values size)},
    {@analise, ~w(community_core_size values size)},
    {@analise, ~w(betweenness values min_people)},
    {@analise, ~w(clustering values min_neighbours)},
    {@analise, ~w(eigenvector values tolerance_per_node)},
    {@analise, ~w(eigenvector values max_iterations)},
    {@analise, ~w(eigenvector values min_component_size)},
    {@analise, ~w(small_world values random_graphs)},
    {@analise, ~w(small_world values seed)},
    {@analise, ~w(small_world values min_people)},
    {@analise, ~w(small_world values criterion_threshold)},
    {@analise, ~w(small_world values generator)},
    {@analise, ~w(small_world values random_model)},
    {@analise, ~w(modularity_reading values random_weights)},
    {@analise, ~w(layout values seed)},
    {@analise, ~w(layout values iterations)},
    {@analise, ~w(layout values labelled_nodes)},
    {@analise, ~w(betweenness_color_bands values bands)},
    {@papel, ~w(min_people values min_people)},
    {@papel, ~w(cuts values high_above)},
    {@papel, ~w(cuts values median_above)},
    {@papel, ~w(cuts values low_below)},
    {@papel, ~w(cuts values order)},
    {@papel, ~w(labels values)},
    {@aresta, ~w(exclusions values order)},
    {@janelas, ~w(window_days values allowed)},
    {@janelas, ~w(window_days values default)}
  ]

  setup_all do
    {:ok, _} = KnowledgeBase.load()

    regras =
      Map.new([@analise, @papel, @aresta, @janelas], fn id ->
        {:ok, r} = KnowledgeBase.rule(id)
        {id, r}
      end)

    {:ok, necessidade} = KnowledgeBase.information_need("network.structure")

    medidas =
      Map.new(necessidade["candidate_measurements"], fn id ->
        {:ok, m} = KnowledgeBase.measurement(id)
        {id, m}
      end)

    %{regras: regras, medidas: medidas}
  end

  defp sem(regras, regra, caminho) do
    {pai, [ultima]} = Enum.split(["rules" | caminho], -1)
    update_in(regras, [regra | pai], &Map.delete(&1, ultima))
  end

  test "a base real carrega, com os valores que ela declara", ctx do
    p = Parameters.fetch!()

    assert p.networks == ["review", "assignment"]
    assert p.default_network == "review"
    assert p.windows == [30, 90, 180]
    assert p.default_window == 90
    assert p.min_group == 3
    assert p.size_limit == %{max_people: 300, max_undirected_edges: 3000}
    assert p.small_world.random_graphs == 100
    assert p.small_world.seed == 42
    assert p.layout.labelled_nodes == 7

    assert p.exclusion_order ==
             ~w(bot_or_app organization_account unlinked_person self_assignment)

    assert p.knowledge_versions[@analise] == 1
    assert map_size(p.knowledge_versions) == 4 + map_size(ctx.medidas)
  end

  for {regra, caminho} <- @chaves do
    test "levanta sem #{regra}: #{Enum.join(caminho, ".")}", ctx do
      regras = sem(ctx.regras, unquote(regra), unquote(caminho))

      erro =
        assert_raise RuntimeError, fn -> Parameters.from_rules!(regras, ctx.medidas) end

      assert erro.message =~ unquote(regra)
    end
  end

  test "levanta quando a ordem das exclusões difere da implementada", ctx do
    regras =
      put_in(
        ctx.regras,
        [@aresta, "rules", "exclusions", "values", "order"],
        ~w(organization_account bot_or_app unlinked_person self_assignment)
      )

    assert_raise RuntimeError, ~r/exclusions.order/, fn ->
      Parameters.from_rules!(regras, ctx.medidas)
    end
  end

  test "levanta quando o gerador declarado não é o implementado", ctx do
    regras =
      put_in(ctx.regras, [@analise, "rules", "small_world", "values", "generator"], "mt19937")

    assert_raise RuntimeError, ~r/generator/, fn ->
      Parameters.from_rules!(regras, ctx.medidas)
    end
  end

  test "levanta sem a versão de uma regra", ctx do
    regras = update_in(ctx.regras, [@papel], &Map.delete(&1, "version"))

    assert_raise RuntimeError, ~r/#{@papel}/, fn ->
      Parameters.from_rules!(regras, ctx.medidas)
    end
  end
end
