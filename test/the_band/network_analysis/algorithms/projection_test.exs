defmodule TheBand.NetworkAnalysis.Algorithms.ProjectionTest do
  @moduledoc """
  A projeção sem direção, os componentes e os graus — feature 076, T012 (FR-010, FR-019, FR-033).

  ## As asserções que carregam este arquivo

  1. A → B (5) e B → A (1) dão {A, B} com peso **6**, e grau 1 para cada (o par recíproco conta
     uma vez), com 1 pessoa em cada sentido;
  2. componentes fracos, por tamanho decrescente e, no empate, pelo menor id;
  3. a ordem de entrada das arestas não muda nada.

  **Defeito a injetar**: guardar o peso de um sentido só (o `to_undirected()` da referência); o
  caso do par recíproco reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Projection

  defp e(s, t, w), do: %{source: s, target: t, weight: w}

  test "o par recíproco soma os pesos dos dois sentidos e conta uma vez no grau" do
    arestas = [e("a", "b", 5), e("b", "a", 1)]

    assert %{nodes: ["a", "b"], adjacency: adj, edges: 1} = Projection.undirected(arestas)
    assert adj["a"]["b"] == 6
    assert adj["b"]["a"] == 6

    graus = Projection.degrees(arestas)

    assert graus["a"] == %{out_people: 1, in_people: 1, degree: 1, out_weight: 5, in_weight: 1}
    assert graus["b"] == %{out_people: 1, in_people: 1, degree: 1, out_weight: 1, in_weight: 5}
  end

  test "a ordem de entrada não muda a projeção" do
    arestas = [e("a", "b", 5), e("b", "a", 1), e("b", "c", 2)]
    assert Projection.undirected(arestas) == Projection.undirected(Enum.reverse(arestas))
    assert Projection.degrees(arestas) == Projection.degrees(Enum.reverse(arestas))
  end

  test "componentes fracos por tamanho decrescente e, no empate, pelo menor id" do
    arestas = [
      e("x", "y", 1),
      # direção ignorada: c → b → a ainda é um componente só
      e("c", "b", 1),
      e("b", "a", 1),
      e("m", "n", 1)
    ]

    %{adjacency: adj} = Projection.undirected(arestas)

    assert Projection.components(adj) == [["a", "b", "c"], ["m", "n"], ["x", "y"]]
  end

  test "grau em pessoas distintas, e não em arestas" do
    arestas = [e("a", "b", 3), e("a", "c", 1), e("c", "a", 2)]
    graus = Projection.degrees(arestas)

    assert graus["a"].degree == 2
    assert graus["a"].out_people == 2
    assert graus["a"].in_people == 1
    assert graus["a"].out_weight == 4
  end
end
