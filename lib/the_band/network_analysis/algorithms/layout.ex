defmodule TheBand.NetworkAnalysis.Algorithms.Layout do
  @moduledoc """
  As posições do desenho, calculadas no servidor — feature 076, T031 (FR-022, FR-052; R9;
  `contracts/algoritmos.md`, `Algorithms.Layout`; `network.analysis.parameters.layout`).

  Fruchterman e Reingold (1991), como `networkx.spring_layout`: posições iniciais uniformes em
  [0, 1)², sorteadas em ordem crescente de id por um estado **próprio** (`Random.new(seed)`, à
  parte do de `small_world`); k = 1/√n; temperatura inicial 0,1, decrescida linearmente a cada
  iteração; atração multiplicada pelo peso da projeção sem direção; deslocamento limitado pela
  temperatura. Ao fim, reescala para [40, 960]², preservando a proporção, com uma casa.

  A posição **não é medida**: duas pessoas próximas no desenho não estão "mais ligadas" do que a
  aresta diz. O mesmo grafo dá as mesmas posições, em qualquer processo (FR-052).

  Usado no cálculo, sobre a rede inteira, e na leitura, sobre o grafo da visão com alcance
  parcial — as posições da rede inteira diriam onde estão as pessoas de fora (R2 da segurança).

  Puro: sem `Repo`, relógio, `Logger` nem o `:rand` do dicionário do processo. Depende de:
  nenhuma ontologia.
  """

  alias TheBand.NetworkAnalysis.Algorithms.Random

  @type node_id :: String.t()

  # A caixa do `viewBox` 0 0 1000 1000, com margem de 40 para o raio e o rótulo.
  @centro 500.0
  @meia_caixa 460.0
  @temperatura_inicial 0.1
  # Piso numérico da distância e do deslocamento, o do `networkx`: evita dividir por zero
  # quando dois nós caem no mesmo ponto. Não é valor de medida.
  @piso 0.01

  @doc "As posições de cada nó, em [40, 960]², uma casa. Mesma entrada, mesma saída."
  @spec fruchterman_reingold([node_id()], %{node_id() => %{node_id() => number()}}, %{
          required(:seed) => integer(),
          required(:iterations) => pos_integer()
        }) :: %{node_id() => {float(), float()}}
  def fruchterman_reingold(ids, adjacencia, %{seed: seed, iterations: iteracoes}) do
    case Enum.sort(Enum.uniq(ids)) do
      [] -> %{}
      [so] -> %{so => {@centro, @centro}}
      ordenados -> calcular(ordenados, adjacencia, seed, iteracoes)
    end
  end

  defp calcular(ids, adjacencia, seed, iteracoes) do
    n = length(ids)
    indice = ids |> Enum.with_index() |> Map.new()

    {iniciais, _estado} =
      Enum.map_reduce(ids, Random.new(seed), fn _id, st ->
        {x, st} = Random.uniform(st)
        {y, st} = Random.uniform(st)
        {{x, y}, st}
      end)

    # Pesos por índice, só entre nós do desenho.
    pesos =
      ids
      |> Enum.map(fn id ->
        for {v, w} <- Map.get(adjacencia, id, %{}),
            Map.has_key?(indice, v),
            into: %{},
            do: {Map.fetch!(indice, v), w}
      end)
      |> List.to_tuple()

    k = 1 / :math.sqrt(n)
    passo = @temperatura_inicial / (iteracoes + 1)

    {finais, _t} =
      Enum.reduce(1..iteracoes, {iniciais, @temperatura_inicial}, fn _, {pos, t} ->
        {iterar(pos, pesos, k, t), t - passo}
      end)

    ids |> Enum.zip(reescalar(finais)) |> Map.new()
  end

  # Uma iteração síncrona: todos os deslocamentos com as posições da anterior.
  defp iterar(pos, pesos, k, t) do
    k2 = k * k
    indexadas = Enum.with_index(pos)

    Enum.map(indexadas, fn {{xi, yi}, i} ->
      vizinhos = elem(pesos, i)

      {dx, dy} =
        Enum.reduce(indexadas, {0.0, 0.0}, fn
          {_, ^i}, acc ->
            acc

          {{xj, yj}, j}, {ax, ay} ->
            ex = xi - xj
            ey = yi - yj
            d = max(:math.sqrt(ex * ex + ey * ey), @piso)
            f = k2 / (d * d) - Map.get(vizinhos, j, 0) * d / k
            {ax + ex * f, ay + ey * f}
        end)

      comprimento = max(:math.sqrt(dx * dx + dy * dy), @piso)
      {xi + dx * t / comprimento, yi + dy * t / comprimento}
    end)
  end

  defp reescalar(pos) do
    n = length(pos)
    mx = (pos |> Enum.map(&elem(&1, 0)) |> Enum.sum()) / n
    my = (pos |> Enum.map(&elem(&1, 1)) |> Enum.sum()) / n
    limite = pos |> Enum.flat_map(fn {x, y} -> [abs(x - mx), abs(y - my)] end) |> Enum.max()

    Enum.map(pos, fn {x, y} ->
      if limite == 0.0,
        do: {@centro, @centro},
        else: {caixa((x - mx) / limite), caixa((y - my) / limite)}
    end)
  end

  defp caixa(v), do: Float.round(@centro + @meia_caixa * v, 1)
end
