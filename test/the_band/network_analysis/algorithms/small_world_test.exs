defmodule TheBand.NetworkAnalysis.Algorithms.SmallWorldTest do
  @moduledoc """
  O clustering e o σ — feature 076, T043 (US7; FR-039 a FR-042; `contracts/algoritmos.md`,
  `Algorithms.Clustering`, `SmallWorld.sigma/4`; medidas `network.clustering.ratio` e
  `network.small_world_sigma.score`).

  - clustering: o triângulo com uma ponta dá a média da conta à mão, e quem tem grau < 2 fica
    **fora da média e contado**, nunca como 0;
  - todo aleatório gerado entra, inclusive o desconexo, e a média divide pelo que entrou;
  - abaixo de 10 pessoas, σ ausente com `network_too_small`; C_rand médio zero dá
    `random_clustering_undefined`; o mesmo dado dá o mesmo σ.

  **Defeitos a injetar**, um por vez: descartar os aleatórios desconexos; dividir sempre por 100;
  contar 0 para grau < 2. Cada um reprova o seu caso.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Clustering
  alias TheBand.NetworkAnalysis.Algorithms.Paths
  alias TheBand.NetworkAnalysis.Algorithms.Projection
  alias TheBand.NetworkAnalysis.Algorithms.SmallWorld

  @params %{random_graphs: 100, seed: 42}

  defp adj(pares),
    do:
      pares
      |> Enum.map(fn {u, v} -> %{source: u, target: v, weight: 1} end)
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

  test "clustering: grau < 2 fora da média e contado, nunca 0" do
    # Triângulo a, b, c e a ponta c — d: a e b têm 1,0; c tem 1 de 3 pares; d tem grau 1.
    {:ok, c} = Clustering.average(adj([{"a", "b"}, {"b", "c"}, {"a", "c"}, {"c", "d"}]))

    assert_in_delta c.value, (1 + 1 + 1 / 3) / 3, 1.0e-9
    assert c.excluded_degree_below_two == 1
  end

  test "sem ninguém com dois vizinhos, clustering ausente" do
    assert Clustering.average(adj([{"a", "b"}])) == {:ausente, :no_person_with_two_neighbours}
  end

  # 12 pessoas em dois triângulos encadeados por um caminho: esparsa, e muitos aleatórios dela
  # ficam desconexos.
  defp esparsa do
    adj([
      {"p01", "p02"},
      {"p02", "p03"},
      {"p01", "p03"},
      {"p03", "p04"},
      {"p04", "p05"},
      {"p05", "p06"},
      {"p06", "p07"},
      {"p07", "p08"},
      {"p08", "p09"},
      {"p07", "p09"},
      {"p09", "p10"},
      {"p10", "p11"},
      {"p11", "p12"}
    ])
  end

  test "todo aleatório entra, inclusive o desconexo, e a média divide pelo que entrou" do
    b = SmallWorld.random_battery(esparsa(), @params)

    # Controle: a rede é esparsa o bastante para haver aleatórios desconexos.
    assert b.reachable_share < 1
    assert {:ok, %{graphs_defined: 100}} = b.average_distance

    # O clustering não está definido em todo aleatório (sem ninguém com dois vizinhos ligados é
    # 0, que é definido; indefinido é sem ninguém com dois vizinhos): a média divide pelo que
    # entrou, e diz quantos.
    assert {:ok, %{value: c_rand, graphs_defined: k}} = b.clustering
    assert k == 100
    assert c_rand >= 0
  end

  test "a média do clustering divide pelos grafos em que está definido" do
    # 6 pessoas e 3 ligações: o sorteio dá três pares (clustering indefinido: ninguém tem dois
    # vizinhos), um triângulo (1,0) ou outra forma (0). Cada aleatório vale 0 ou 1, e a média
    # sobre os k definidos vezes k é o número de triângulos — inteiro. Dividida por 100, não é.
    b = SmallWorld.random_battery(adj([{"a", "b"}, {"c", "d"}, {"e", "f"}]), @params)

    assert {:ok, %{value: c, graphs_defined: k}} = b.clustering
    assert k > 0 and k < 100
    assert c > 0, "o sorteio precisa ter ao menos um triângulo para o caso medir"
    assert_in_delta c * k, round(c * k), 1.0e-9
  end

  test "abaixo de 10 pessoas, σ ausente com network_too_small" do
    a = adj([{"a", "b"}, {"b", "c"}, {"a", "c"}])
    real = %{clustering: {:ok, 1.0}, average_distance: {:ok, 1.0}}

    assert SmallWorld.sigma(real, SmallWorld.random_battery(a, @params), 3, %{min_people: 10}) ==
             {:ausente, :network_too_small}
  end

  test "C_rand médio zero dá random_clustering_undefined, e nunca σ infinito" do
    real = %{clustering: {:ok, 0.5}, average_distance: {:ok, 2.0}}

    aleatorios = %{
      clustering: {:ok, %{value: 0.0, graphs_defined: 100}},
      average_distance: {:ok, %{value: 2.0, graphs_defined: 100}}
    }

    assert SmallWorld.sigma(real, aleatorios, 20, %{min_people: 10}) ==
             {:ausente, :random_clustering_undefined}
  end

  test "o mesmo dado dá o mesmo σ, e o σ é a razão das razões" do
    a = esparsa()
    {:ok, %{value: c}} = Clustering.average(a)
    {:ok, l} = a |> Paths.all_pairs() |> Paths.network(12) |> Map.fetch!(:average)
    real = %{clustering: {:ok, c}, average_distance: {:ok, l}}

    s1 = SmallWorld.sigma(real, SmallWorld.random_battery(a, @params), 12, %{min_people: 10})
    s2 = SmallWorld.sigma(real, SmallWorld.random_battery(a, @params), 12, %{min_people: 10})
    assert s1 == s2

    {:ok, %{value: s, clustering_ratio: rc, distance_ratio: rl}} = s1
    assert_in_delta s, rc / rl, 1.0e-12
  end
end
