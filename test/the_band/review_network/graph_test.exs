defmodule TheBand.ReviewNetwork.GraphTest do
  @moduledoc """
  A matemática da rede — feature 073, T012 (research.md R2, R5).

  ## As asserções que carregam este arquivo

  1. o cenário 1 da US1: 30 de 40 revisões numa pessoa → `%{k: 1, reviews: 30, of: 40}`;
  2. rede vazia é `:sem_revisao`, **nunca 0**;
  3. k maior que o número de revisores é ausente, nunca 100%;
  4. o peso é solicitação distinta: rodadas não inflam;
  5. o invariante: pares = soma dos pesos + exclusões;
  6. a mesma entrada embaralhada dá a mesma saída (FR-012).
  """
  use ExUnit.Case, async: true

  alias TheBand.ReviewNetwork.Graph

  @inicio ~U[2026-07-05 00:00:00Z]
  @dentro ~U[2026-09-01 10:00:00Z]

  defp aresta(r, a, cr, quando \\ @dentro),
    do: %{change_request_id: cr, last_submitted_at: quando, destino: {:aresta, r, a}}

  defp fora(destino, cr),
    do: %{change_request_id: cr, last_submitted_at: @dentro, destino: destino}

  # Ana revisa 30 solicitações de Bia; Ciro revisa 6 de Bia e 4 de Ana.
  defp cenario_us1 do
    for(i <- 1..30, do: aresta("ana", "bia", "b#{i}")) ++
      for(i <- 1..6, do: aresta("ciro", "bia", "b#{i}")) ++
      for(i <- 1..4, do: aresta("ciro", "ana", "a#{i}"))
  end

  test "US1, cenário 1: a que mais revisou fez 30 de 40, sem nome" do
    rede = Graph.build(cenario_us1(), @inicio)

    assert [
             %{k: 1, value: {:ok, %{reviews: 30, of: 40}}},
             %{k: 2, value: {:ok, %{reviews: 40, of: 40}}},
             %{k: 3, value: {:ausente, :fewer_reviewers_than_k}}
           ] = Graph.concentration(rede.edges, [1, 2, 3])

    # Nenhum valor carrega quem.
    refute inspect(Graph.concentration(rede.edges, [1, 2, 3])) =~ "ana"
  end

  test "rede vazia é :sem_revisao, e nunca 0" do
    assert Graph.concentration([], [1, 2, 3]) == :sem_revisao
    assert Graph.groups([]) == []
  end

  test "as frações crescem com k e nunca passam do total" do
    edges = Graph.build(cenario_us1(), @inicio).edges
    valores = for %{value: {:ok, v}} <- Graph.concentration(edges, [1, 2]), do: v.reviews

    assert valores == Enum.sort(valores)
    assert Enum.all?(valores, &(&1 <= 40))
  end

  test "o peso é solicitação distinta, e a mesma pessoa por duas contas não dobra" do
    pares = [
      aresta("ana", "bia", "cr1"),
      aresta("ana", "bia", "cr1"),
      aresta("ana", "bia", "cr2")
    ]

    rede = Graph.build(pares, @inicio)

    assert rede.edges == [%{reviewer: "ana", author: "bia", change_requests: 2}]
    assert rede.received == %{"bia" => 2}
  end

  test "solicitações recebidas contam a solicitação uma vez, mesmo com dois revisores" do
    rede = Graph.build([aresta("ana", "bia", "cr1"), aresta("ciro", "bia", "cr1")], @inicio)

    assert rede.received == %{"bia" => 1}
    assert Graph.totals_by_person(rede.edges)["bia"].received_people == 2
  end

  test "o par antes da janela não entra" do
    rede = Graph.build([aresta("ana", "bia", "cr1", ~U[2026-07-04 23:59:59Z])], @inicio)
    assert rede.edges == []
    assert rede.pairs == 0
  end

  test "o invariante: pares = soma dos pesos + as três exclusões" do
    pares =
      cenario_us1() ++
        [
          fora(:auto_revisao, "x1"),
          fora(:bot_ou_aplicativo, "x2"),
          fora(:nao_ligada, "x3"),
          fora(:nao_ligada, "x4")
        ]

    rede = Graph.build(pares, @inicio)
    pesos = rede.edges |> Enum.map(& &1.change_requests) |> Enum.sum()

    assert rede.excluded == %{self_reviews: 1, bot_or_app: 1, unlinked: 2}
    assert rede.pairs == length(pares)
    assert rede.pairs == pesos + 1 + 1 + 2
  end

  test "totais por pessoa: feitas, de quantas, e por quantas foi revisada" do
    totais = Graph.build(cenario_us1(), @inicio).edges |> Graph.totals_by_person()

    assert totais["ciro"] == %{given_reviews: 10, given_people: 2, received_people: 0}
    assert totais["bia"] == %{given_reviews: 0, given_people: 0, received_people: 2}
  end

  test "dois grupos sem aresta entre eles dão dois tamanhos, ordenados" do
    edges =
      Graph.build(
        [aresta("ana", "bia", "1"), aresta("bia", "ciro", "2"), aresta("dani", "eva", "3")],
        @inicio
      ).edges

    assert Graph.groups(edges) == [["ana", "bia", "ciro"], ["dani", "eva"]]
  end

  test "o subgrafo induzido tem só arestas com as duas pontas no conjunto" do
    edges = Graph.build(cenario_us1(), @inicio).edges

    assert Graph.induced(edges, MapSet.new(["bia", "ciro"])) ==
             [%{reviewer: "ciro", author: "bia", change_requests: 6}]
  end

  test "FR-012: a entrada embaralhada dez vezes dá a mesma saída" do
    pares = cenario_us1() ++ [fora(:nao_ligada, "x")]
    esperado = Graph.build(pares, @inicio)

    for semente <- 1..10 do
      :rand.seed(:exsss, {semente, semente, semente})
      embaralhado = Enum.shuffle(pares)
      rede = Graph.build(embaralhado, @inicio)
      assert rede == esperado
      assert Graph.groups(rede.edges) == Graph.groups(esperado.edges)

      assert Graph.concentration(rede.edges, [1, 2, 3]) ==
               Graph.concentration(esperado.edges, [1, 2, 3])
    end
  end
end
