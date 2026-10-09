defmodule TheBand.Ontology.NetworkAnalysisBaseTest do
  @moduledoc """
  A base da análise de rede, carregada — feature 076, T007 (princípio IV; research.md R19).

  `derivation_rule` não tem schema (lacuna da 073), e `mix knowledge.validate` não confere as
  chaves de uma regra. Este teste confere, na base REAL, o que o código vai ler:

  1. as 20 medidas de `network.structure` existem e respondem a ela;
  2. as 20 perguntas de competência `spo_network_analysis.cqNN` existem;
  3. as chaves de `network.analysis.parameters`, `network.position_role` e
     `assignment.network.edge` que a análise lê estão presentes, cada uma com valor.

  A leitura com tipos, ordem e versões é de `NetworkAnalysis.Parameters` (T008), que levanta;
  este teste existe para que a falta apareça na base, com o nome da chave, antes do código.

  **Defeito a injetar**: apagar `small_world.values.seed` da regra; o caso 3 reprova.
  """
  use ExUnit.Case, async: false

  alias TheBand.Ontology.KnowledgeBase

  @chaves %{
    "network.analysis.parameters" => [
      ~w(networks values allowed),
      ~w(networks values windows_from),
      ~w(undirected_projection values weight),
      ~w(connectivity values criterion),
      ~w(hubs_list_size values size),
      ~w(hubs_list_size values tie_break),
      ~w(communities values algorithm),
      ~w(communities values tie_break),
      ~w(community_core_size values size),
      ~w(modularity_reading values random_weights),
      ~w(eigenvector values tolerance_per_node),
      ~w(eigenvector values max_iterations),
      ~w(eigenvector values min_component_size),
      ~w(betweenness values min_people),
      ~w(clustering values min_neighbours),
      ~w(small_world values random_model),
      ~w(small_world values random_graphs),
      ~w(small_world values seed),
      ~w(small_world values min_people),
      ~w(small_world values criterion_threshold),
      ~w(small_world values generator),
      ~w(small_world values sampling),
      ~w(outside_reach values min_group),
      ~w(layout values algorithm),
      ~w(layout values iterations),
      ~w(layout values seed),
      ~w(layout values labelled_nodes),
      ~w(size_limit values max_people),
      ~w(size_limit values max_undirected_edges),
      ~w(size_limit values absent_above),
      ~w(betweenness_color_bands values bands)
    ],
    "network.position_role" => [
      ~w(percentile_method values method),
      ~w(min_people values min_people),
      ~w(cuts values high_above),
      ~w(cuts values median_above),
      ~w(cuts values low_below),
      ~w(cuts values order),
      ~w(labels values)
    ],
    "assignment.network.edge" => [
      ~w(exclusions values order)
    ]
  }

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  test "as 20 medidas de network.structure existem e respondem a ela" do
    {:ok, necessidade} = KnowledgeBase.information_need("network.structure")
    medidas = necessidade["candidate_measurements"]

    assert length(medidas) == 20

    for id <- medidas do
      assert {:ok, medida} = KnowledgeBase.measurement(id), "#{id} ausente da base"
      assert "network.structure" in List.wrap(medida["answers_information_need"])
    end
  end

  test "as 20 perguntas de competência da análise existem" do
    for n <- 1..20 do
      id = "spo_network_analysis.cq" <> String.pad_leading("#{n}", 2, "0")
      assert {:ok, _} = KnowledgeBase.competency_question(id), "#{id} ausente da base"
    end
  end

  test "as chaves que a análise lê estão nas regras, cada uma com valor" do
    for {regra, caminhos} <- @chaves do
      assert {:ok, artefato} = KnowledgeBase.rule(regra), "#{regra} ausente da base"
      assert is_integer(artefato["version"])

      for caminho <- caminhos do
        refute is_nil(get_in(artefato, ["rules" | caminho])),
               "#{regra}: #{Enum.join(caminho, ".")} ausente"
      end
    end
  end
end
