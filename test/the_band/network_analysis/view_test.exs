defmodule TheBand.NetworkAnalysis.ViewTest do
  @moduledoc """
  O recorte da leitura pelo alcance — feature 076, T016 (FR-015; R10; A4, A5, parte de A6; DS1,
  DS5).

  ## As asserções que carregam este arquivo

  1. **A4**: comunidade com 1, 2 e 3 pessoas de fora dá nenhum nó, nenhum nó e o nó de tamanho 3;
  2. **A5**: só 2 de fora no total dá nenhum agregado e só a marca, sem aresta para fora;
  3. **A6**: nenhum id de agregado deriva de `person_id`; nenhum id de fora aparece na visão;
  4. a administração vê todas as pessoas por id; sem alcance (DS5), o grafo é recortado;
  5. DS1: posição de outra pessoa só com escopo concedido.

  Cada `refute` vem depois de um `assert` de que a visão tem o que medir (L50).

  **Defeitos a injetar**, um por vez: tirar o k; criar *"other communities"* sem conferir k; id do
  agregado por hash do `person_id`. Cada um reprova o seu caso.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.View

  @params %{min_group: 3}

  defp no(id, comunidade, componente \\ 1),
    do: %{
      "id" => id,
      "degree" => 1,
      "out_people" => 1,
      "in_people" => 0,
      "community" => comunidade,
      "component" => componente
    }

  defp aresta(s, t, w \\ 1), do: %{"source" => s, "target" => t, "weight" => w}

  # Uma comunidade 1 com `dentro` alcançados e `fora` pessoas de fora, todos ligados ao primeiro
  # alcançado.
  defp leitura(dentro, fora) do
    ids_dentro = for i <- 1..dentro, do: "dentro-#{i}-#{Ecto.UUID.generate()}"
    ids_fora = for i <- 1..fora//1, do: Ecto.UUID.generate() |> then(&"#{&1}-fora#{i}")
    [ancora | _] = ids_dentro

    %{
      leitura: %{
        "nodes" => Enum.map(ids_dentro ++ ids_fora, &no(&1, 1)),
        "edges" =>
          Enum.map(ids_fora, &aresta(ancora, &1, 2)) ++ [aresta(hd(ids_fora ++ [ancora]), ancora)]
      },
      dentro: ids_dentro,
      fora: ids_fora,
      ancora: ancora
    }
  end

  defp alcance(ids), do: {:algumas, MapSet.new(ids)}

  defp agregados(view) do
    {:ok, g} = view.graph
    Enum.filter(g.nodes, &(&1.kind == :outside))
  end

  describe "A4: o k por comunidade" do
    for {fora, esperado} <- [{1, nil}, {2, nil}, {3, 3}] do
      test "comunidade com #{fora} de fora", do: verificar_a4(unquote(fora), unquote(esperado))
    end
  end

  defp verificar_a4(fora, esperado) do
    c = leitura(2, fora)
    view = View.build(c.leitura, alcance(c.dentro), alcance([]), hd(c.dentro), @params)

    assert view.reach == :parcial
    {:ok, g} = view.graph
    assert length(Enum.filter(g.nodes, &(&1.kind == :person))) == 2

    case esperado do
      nil ->
        assert agregados(view) == []
        assert Enum.find(g.nodes, &(&1.id == c.ancora)).links_outside_reach?
        assert view.people == {:suprimido, :fewer_than_k_outside}
        assert g.components == {:suprimido, :fewer_than_k_outside}

      n ->
        assert [%{id: "outside-1", size: ^n, community: 1}] = agregados(view)
        assert Enum.any?(g.edges, &(&1.to == "outside-1" and &1.weight == 2 * n))
        assert view.people == {:ok, 2 + n}
    end
  end

  test "A5: só 2 de fora no total, em comunidades diferentes: nenhum agregado, só a marca" do
    [a, b, x, y] = for _ <- 1..4, do: Ecto.UUID.generate()

    leitura = %{
      "nodes" => [no(a, 1), no(b, 2), no(x, 1), no(y, 2)],
      "edges" => [aresta(a, x, 5), aresta(b, y, 4), aresta(a, b, 1)]
    }

    view = View.build(leitura, alcance([a, b]), alcance([]), a, @params)
    {:ok, g} = view.graph

    assert length(g.nodes) == 2
    assert Enum.all?(g.nodes, & &1.links_outside_reach?)
    assert agregados(view) == []
    assert g.edges == [%{from: a, to: b, weight: 1}]
    refute inspect(view) =~ "size: 2"
  end

  test "A5: comunidades pequenas que juntam k vão para 'other communities'" do
    [a, x, y, z] = for _ <- 1..4, do: Ecto.UUID.generate()

    leitura = %{
      "nodes" => [no(a, 1), no(x, 2), no(y, 3), no(z, 4)],
      "edges" => [aresta(a, x), aresta(a, y), aresta(z, a)]
    }

    view =
      View.build(
        leitura,
        alcance([a]) |> then(fn {:algumas, s} -> {:algumas, MapSet.put(s, "outra")} end),
        alcance([]),
        nil,
        @params
      )

    assert [%{id: "outside-1", community: :other, size: 3}] = agregados(view)
  end

  test "A6: id do agregado é a posição, e nenhum person_id de fora aparece na visão" do
    c = leitura(2, 4)
    view = View.build(c.leitura, alcance(c.dentro), alcance([]), hd(c.dentro), @params)

    assert [%{id: id}] = agregados(view)
    assert id =~ ~r/^outside-\d+$/
    texto = inspect(view)
    assert texto =~ c.ancora
    for f <- c.fora, do: refute(texto =~ f)
    for f <- c.fora, do: refute(id =~ String.slice(f, 0, 8))
  end

  test "a administração vê todos por id, com o número de pessoas" do
    c = leitura(2, 3)
    view = View.build(c.leitura, :todas, :todas, nil, @params)

    assert view.reach == :total
    assert view.sees_others_positions?
    {:ok, g} = view.graph
    assert Enum.sort(Enum.map(g.nodes, & &1.id)) == Enum.sort(c.dentro ++ c.fora)
    assert view.people == {:ok, 5}
  end

  test "DS5: sem alcance, ou só a própria pessoa, o grafo é recortado" do
    c = leitura(2, 3)
    [eu | _] = c.dentro

    for reach <- [alcance([]), alcance([eu])] do
      view = View.build(c.leitura, reach, alcance([eu]), eu, @params)
      assert view.reach == :nenhum
      assert view.graph == {:recortado, :no_reach}
    end
  end

  test "DS1: posição de outra pessoa só com escopo concedido; a própria, sempre" do
    c = leitura(2, 3)
    [eu, colega] = c.dentro

    so_vinculo = View.build(c.leitura, alcance(c.dentro), alcance([eu]), eu, @params)
    refute so_vinculo.sees_others_positions?
    assert View.ve_posicao_de?(so_vinculo, eu)
    refute View.ve_posicao_de?(so_vinculo, colega)

    concedido = View.build(c.leitura, alcance(c.dentro), alcance(c.dentro), eu, @params)
    assert concedido.sees_others_positions?
    assert View.ve_posicao_de?(concedido, colega)
  end
end
