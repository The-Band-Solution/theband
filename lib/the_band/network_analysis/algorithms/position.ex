defmodule TheBand.NetworkAnalysis.Algorithms.Position do
  @moduledoc """
  O percentil e o papel na rede, **derivados na leitura** — feature 076, T045 (US8; FR-044 a
  FR-047; R17; `contracts/algoritmos.md`, `Algorithms.Position`; regra `network.position_role`;
  medida `network.position_percentile.percentage`).

  - **percentil por posto médio** sobre as pessoas da rede inteira: 100 × (quantos têm M menor
    que M(u) + metade dos que têm M igual a M(u)) / n. Empate dá o mesmo percentil a todos os
    empatados;
  - **papel** pelos cortes da regra, avaliados na ordem dela, o primeiro que se aplica decide;
    o rótulo e a frase vêm da base, nunca daqui. O papel é uma frase sobre as ligações, e nunca o
    percentil como rótulo de pessoa (decisão Q1 da aprovação);
  - abaixo do mínimo de pessoas da regra, **ninguém** tem papel: `network_too_small_for_roles`.

  Chamado só pelo `Reader`, **nunca** por `Commands`: o papel não é gravado (R17), e muda quando a
  regra muda, sem recalcular a leitura.

  A ordem dos cortes é a que este código implementa, e é **conferida** contra a da base: com
  outra ordem, levanta, em vez de a tela passar a dizer outra coisa sobre as pessoas em silêncio.

  Puro: sem `Repo`, relógio, `Logger` nem processo. Depende de: nenhuma ontologia.
  """

  @ordem_implementada ~w(central_position many_direct_links on_many_paths above_median_in_both
                         few_links_few_paths mixed_position)

  @type regra :: %{
          required(:min_people) => pos_integer(),
          required(:high_above) => number(),
          required(:median_above) => number(),
          required(:low_below) => number(),
          required(:order) => [String.t()],
          required(:labels) => map()
        }

  @doc "A ordem dos cortes que este código implementa, nos códigos da base."
  @spec order() :: [String.t()]
  def order, do: @ordem_implementada

  @doc "O percentil, por posto médio, de cada pessoa na medida dada, sobre todas as pessoas."
  @spec percentiles(%{term() => number()}) :: %{term() => float()}
  def percentiles(valores) when map_size(valores) == 0, do: %{}

  def percentiles(valores) do
    n = map_size(valores)
    ordenados = valores |> Map.values() |> Enum.sort()
    frequencia = Enum.frequencies(ordenados)

    # Quantos valores são estritamente menores que cada valor distinto, numa passada.
    {menores, _} =
      frequencia
      |> Enum.sort()
      |> Enum.reduce({%{}, 0}, fn {v, f}, {acc, antes} -> {Map.put(acc, v, antes), antes + f} end)

    Map.new(valores, fn {id, v} ->
      {id, 100 * (Map.fetch!(menores, v) + Map.fetch!(frequencia, v) / 2) / n}
    end)
  end

  @doc """
  Os papéis de todas as pessoas a partir do grau e da intermediação de cada uma. Abaixo do
  mínimo, ou sem intermediação calculada, todas ficam ausentes com o motivo da base.
  """
  @spec roles(
          %{term() => %{degree: number(), betweenness: {:ok, number()} | {:ausente, atom()}}},
          regra()
        ) ::
          %{term() => {:ok, map()} | {:ausente, :network_too_small_for_roles}}
  def roles(pessoas, %{min_people: minimo} = regra) do
    confere_ordem!(regra)

    intermediacoes = for {id, %{betweenness: {:ok, b}}} <- pessoas, into: %{}, do: {id, b}

    if map_size(pessoas) < minimo or map_size(intermediacoes) < map_size(pessoas) do
      Map.new(pessoas, fn {id, _} -> {id, {:ausente, :network_too_small_for_roles}} end)
    else
      pg = percentiles(Map.new(pessoas, fn {id, p} -> {id, p.degree} end))
      pb = percentiles(intermediacoes)

      Map.new(pessoas, fn {id, _} ->
        {id, {:ok, role(%{degree: pg[id], betweenness: pb[id]}, regra)}}
      end)
    end
  end

  @doc """
  O papel de uma pessoa a partir dos dois percentis, pelos cortes da regra: código, rótulo e frase
  da base, os dois percentis e o corte que decidiu.
  """
  @spec role(%{degree: number(), betweenness: number()}, regra()) :: map()
  def role(%{degree: g, betweenness: b}, regra) do
    confere_ordem!(regra)
    %{high_above: alto, median_above: mediana, low_below: baixo} = regra

    # Os cortes na ordem implementada (`order/0`, conferida contra a base); o primeiro que se
    # aplica decide.
    cortes = [
      {"central_position", g > alto and b > alto, "degree > #{alto} and betweenness > #{alto}"},
      {"many_direct_links", g > alto, "degree > #{alto}"},
      {"on_many_paths", b > alto, "betweenness > #{alto}"},
      {"above_median_in_both", g > mediana and b > mediana,
       "degree > #{mediana} and betweenness > #{mediana}"},
      {"few_links_few_paths", g < baixo and b < baixo,
       "degree < #{baixo} and betweenness < #{baixo}"},
      {"mixed_position", true, "none of the cuts above"}
    ]

    {codigo, true, corte} = Enum.find(cortes, fn {_c, aplica?, _t} -> aplica? end)

    rotulo = Map.fetch!(regra.labels, codigo)

    %{
      code: codigo,
      label: Map.fetch!(rotulo, "en"),
      sentence: Map.fetch!(rotulo, "en_sentence"),
      degree_percentile: g,
      betweenness_percentile: b,
      cut: corte
    }
  end

  defp confere_ordem!(%{order: ordem}) do
    unless ordem == @ordem_implementada,
      do:
        raise("network.position_role inconsistente: cuts.order difere da que o código implementa")
  end
end
