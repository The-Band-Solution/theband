defmodule TheBand.NetworkAnalysis.Algorithms.EigenvectorTest do
  @moduledoc """
  O autovetor por componente — feature 076, T039 (FR-036; R6; `contracts/algoritmos.md`,
  `Algorithms.Eigenvector`; medida `network.eigenvector.score`). Tolerância 1e-6 relativa (R6).

  - a rede bipartida converge (sobre A + I), e os dois lados têm os valores da conta à mão;
  - o componente de 2 dá 1/√2 aos dois;
  - com `max_iterations: 1`, o componente que não converge fica **ausente** com
    `did_not_converge`, e os outros não mudam; nenhum valor de reserva.

  **Defeitos a injetar**: iterar sobre A sem I (a bipartida não converge e reprova); e devolver o
  grau como reserva quando não converge (o caso da não convergência reprova).
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Eigenvector
  alias TheBand.NetworkAnalysis.Algorithms.Projection

  @params %{tolerance_per_node: 1.0e-6, max_iterations: 1000, min_component_size: 2}

  defp adj(pares),
    do:
      pares
      |> Enum.map(fn {u, v} -> %{source: u, target: v, weight: 1} end)
      |> Projection.undirected()
      |> Map.fetch!(:adjacency)

  defp relativo(a, b), do: abs(a - b) / abs(b)

  test "a bipartida K(1,3) converge sobre A + I, com os valores da conta à mão" do
    # Centro c com três folhas. Autovalor de A + I: 1 + √3. x_c = √3·x_f; norma 1:
    # 3 x_f² + 3 x_f² = 1 → x_f = 1/√6, x_c = √3/√6 = 1/√2.
    a = adj([{"c", "f1"}, {"c", "f2"}, {"c", "f3"}])
    r = Eigenvector.by_component(a, Projection.components(a), @params)

    {:ok, xc} = r["c"]
    {:ok, xf} = r["f1"]
    assert relativo(xc, 1 / :math.sqrt(2)) < 1.0e-6
    assert relativo(xf, 1 / :math.sqrt(6)) < 1.0e-6
  end

  test "componente de 2 dá 1/√2 aos dois" do
    a = adj([{"a", "b"}])
    r = Eigenvector.by_component(a, Projection.components(a), @params)

    for id <- ~w(a b) do
      {:ok, x} = r[id]
      assert relativo(x, 1 / :math.sqrt(2)) < 1.0e-6
    end
  end

  test "sem convergência, o componente inteiro fica ausente, e os outros não mudam" do
    # Um K(1,3) e um par: com uma iteração só, nenhum converge a partir de x = 1 — e o par
    # converge na segunda. Com duas, o par converge e a estrela não.
    a = adj([{"c", "f1"}, {"c", "f2"}, {"c", "f3"}, {"p", "q"}])
    comps = Projection.components(a)

    um = Eigenvector.by_component(a, comps, %{@params | max_iterations: 1})
    assert Enum.all?(Map.values(um), &(&1 == {:ausente, :did_not_converge}))

    dois = Eigenvector.by_component(a, comps, %{@params | max_iterations: 2})
    for id <- ~w(c f1 f2 f3), do: assert(dois[id] == {:ausente, :did_not_converge})
    assert {:ok, xp} = dois["p"]
    assert relativo(xp, 1 / :math.sqrt(2)) < 1.0e-6
  end
end
