defmodule TheBand.NetworkAnalysis.Algorithms.RandomTest do
  @moduledoc """
  O sorteio reproduzível — feature 076, T011 (R7; FR-052, SC-003).

  ## As asserções que carregam este arquivo

  1. a primeira saída de `gnm(new(42), 10, 15)` é a fixada aqui: trocar gerador, semente ou
     procedimento muda o número, e o teste diz que mudou (é versão nova da regra);
  2. G(n, m) tem exatamente m pares distintos, sem laço, dentro de 1..n;
  3. mesmo estado, mesma saída; e uma chamada a `:rand.uniform/0` no meio do processo **não** muda
     a saída — o estado é explícito, e não o do dicionário do processo.

  **Defeito a injetar**: `:rand.seed(:exsss, seed)` e `:rand.uniform/1` (estado no dicionário); o
  caso da chamada intercalada reprova.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.Algorithms.Random

  # Medido em 2026-10-04, OTP 29, com a implementação desta tarefa.
  @primeira_gnm [
    {1, 4},
    {5, 8},
    {1, 8},
    {2, 4},
    {1, 2},
    {6, 10},
    {4, 9},
    {2, 8},
    {6, 8},
    {5, 7},
    {4, 8},
    {1, 6},
    {1, 3},
    {4, 10},
    {7, 8}
  ]

  test "a primeira saída de gnm(new(42), 10, 15) é a fixada" do
    assert {@primeira_gnm, _} = Random.gnm(Random.new(42), 10, 15)
  end

  test "G(n, m) tem exatamente m pares distintos, sem laço, dentro de 1..n" do
    {pares, _} = Random.gnm(Random.new(7), 12, 40)

    assert length(pares) == 40
    assert length(Enum.uniq(pares)) == 40

    for {u, v} <- pares do
      assert u < v
      assert u >= 1 and v <= 12
    end

    {completo, _} = Random.gnm(Random.new(7), 5, 10)
    assert Enum.sort(completo) == for(u <- 1..5, v <- (u + 1)..5//1, do: {u, v})
  end

  test "mesmo estado dá a mesma saída, e o estado devolvido continua a sequência" do
    s = Random.new(42)
    {a, s1} = Random.gnm(s, 10, 15)
    {b, _} = Random.gnm(s, 10, 15)
    assert a == b

    {c, _} = Random.gnm(s1, 10, 15)
    refute c == a
  end

  test "uma chamada a :rand.uniform/0 no meio do processo não muda a saída" do
    {antes, _} = Random.gnm(Random.new(42), 10, 15)
    {lista_antes, _} = Random.shuffle(Random.new(42), Enum.to_list(1..20))

    :rand.seed(:exsss, 999)

    s = Random.new(42)
    _ = :rand.uniform()
    {depois, _} = Random.gnm(s, 10, 15)
    _ = :rand.uniform()
    {lista_depois, _} = Random.shuffle(Random.new(42), Enum.to_list(1..20))

    assert depois == antes
    assert depois == @primeira_gnm
    assert lista_depois == lista_antes
  end

  test "Fisher–Yates devolve uma permutação, reproduzível pelo estado" do
    {l, _} = Random.shuffle(Random.new(42), [1, 2, 3, 4, 5])
    assert l == [5, 2, 1, 3, 4]
    assert Enum.sort(l) == [1, 2, 3, 4, 5]
    assert {[], _} = Random.shuffle(Random.new(1), [])
    assert {[:a], _} = Random.shuffle(Random.new(1), [:a])
  end
end
