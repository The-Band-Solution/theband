defmodule TheBand.NetworkAnalysis.Algorithms.SmallWorld do
  @moduledoc """
  Os grafos aleatórios equivalentes e o que se compara com eles — feature 076, T036 (Q_rand; R7,
  R8; `contracts/algoritmos.md`, `Algorithms.SmallWorld`; `network.analysis.parameters`,
  `small_world` e `modularity_reading`).

  ## A sequência, declarada

  `random_graphs` grafos G(n, m) com as mesmas `n` pessoas e as mesmas `m` ligações sem direção
  da rede real, todos da **mesma** sequência do gerador (`Algorithms.Random.new(seed)`): o grafo i
  começa onde o i − 1 parou. Em cada um, depois dos pares, os **pesos reais** da projeção sem
  direção, em ordem crescente do par, são embaralhados por Fisher–Yates e dados aos pares na ordem
  em que foram sorteados (`small_world.values.sampling`).

  ## Q_rand com peso (R8)

  Em cada aleatório roda o **mesmo** guloso com peso da rede real (`Algorithms.Communities`), e
  Q_rand é a média das modularidades. Pesos concentrados aumentam Q; comparar o Q com peso contra
  um Q_rand sem peso enviesaria a favor de *"há estrutura"*.

  Toda média divide pelo número de grafos em que a medida está definida, e esse número volta
  junto.

  Puro: sem `Repo`, relógio, `Logger` nem processo. Depende de: nenhuma ontologia.
  """

  alias TheBand.NetworkAnalysis.Algorithms.Communities
  alias TheBand.NetworkAnalysis.Algorithms.Random

  @type adjacency :: %{term() => %{term() => pos_integer()}}
  @type com_contagem ::
          {:ok, %{value: float(), graphs_defined: pos_integer()}} | {:ausente, atom()}

  @doc """
  As medidas dos `random_graphs` aleatórios equivalentes à rede de `adjacencia`, com a semente
  dada. A rede precisa ter ao menos uma ligação: sem ela não há aleatório equivalente.
  """
  @spec random_battery(adjacency(), %{
          required(:random_graphs) => pos_integer(),
          required(:seed) => integer()
        }) :: %{graphs: pos_integer(), modularity: com_contagem()}
  def random_battery(adjacencia, %{random_graphs: quantos, seed: semente})
      when map_size(adjacencia) > 0 do
    n = map_size(adjacencia)
    pesos = pesos_por_par(adjacencia)
    m = length(pesos)

    {medidas, _estado} =
      Enum.map_reduce(1..quantos, Random.new(semente), fn _i, estado ->
        {pares, estado} = Random.gnm(estado, n, m)
        {sorteados, estado} = Random.shuffle(estado, pesos)
        {medir(adjacencia_de(pares, sorteados)), estado}
      end)

    # Cada aleatório tem as m ≥ 1 ligações da real, e a modularidade está definida em todos.
    %{graphs: quantos, modularity: media(medidas, :modularity, :no_edge_in_window)}
  end

  # Os pesos de cada par sem direção, na ordem crescente do par (`weights_input`).
  defp pesos_por_par(adjacencia) do
    for {u, vizinhos} <- adjacencia, {v, w} <- vizinhos, u < v do
      {{u, v}, w}
    end
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
  end

  defp adjacencia_de(pares, pesos) do
    pares
    |> Enum.zip(pesos)
    |> Enum.reduce(%{}, fn {{u, v}, w}, acc ->
      acc
      |> Map.update(u, %{v => w}, &Map.put(&1, v, w))
      |> Map.update(v, %{u => w}, &Map.put(&1, u, w))
    end)
  end

  defp medir(adjacencia) do
    %{modularity: {:ok, Communities.greedy(adjacencia).modularity}}
  end

  # A média sobre os grafos em que a medida está definida, na ordem em que foram gerados. Sem
  # nenhum, o motivo da base para aquela medida.
  defp media(medidas, chave, motivo) do
    case for(m <- medidas, {:ok, v} <- [Map.fetch!(m, chave)], do: v) do
      [] ->
        {:ausente, motivo}

      valores ->
        {:ok, %{value: Enum.sum(valores) / length(valores), graphs_defined: length(valores)}}
    end
  end
end
