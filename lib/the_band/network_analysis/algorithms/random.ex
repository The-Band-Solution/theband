defmodule TheBand.NetworkAnalysis.Algorithms.Random do
  @moduledoc """
  O sorteio reproduzível da análise de rede — feature 076, T011 (R7; FR-052, SC-003;
  `contracts/algoritmos.md`, `Algorithms.Random`).

  Gerador `:exsss` do `:rand` com **estado explícito**: cada função recebe o estado e devolve o
  novo. Nunca o estado no dicionário do processo — qualquer outra chamada a `:rand` no mesmo
  processo mudaria a sequência, e a mesma leitura deixaria de dar o mesmo número (R14 da
  segurança).

  O gerador, a semente e os dois procedimentos (rejeição e Fisher–Yates) estão declarados em
  `network.analysis.parameters.small_world`; trocar qualquer um é versão nova da regra.

  Puro: sem `Repo`, relógio, `Logger` nem processo. Depende de: nenhuma ontologia.
  """

  @opaque state :: :rand.state()

  @doc "Estado novo, semeado com `seed` pelo `:exsss`."
  @spec new(integer()) :: state()
  def new(seed) when is_integer(seed), do: :rand.seed_s(:exsss, seed)

  @doc "Um real uniforme em [0, 1), e o estado novo (as posições iniciais do layout, R9)."
  @spec uniform(state()) :: {float(), state()}
  def uniform(state), do: :rand.uniform_real_s(state)

  @doc """
  Um grafo G(n, m): `m` pares `{u, v}` distintos, `1 <= u < v <= n`, sem laço, sorteados por
  **rejeição** (u e v uniformes em 1..n; recusa u = v e par já sorteado). Os pares saem na ordem
  em que foram sorteados. Levanta se `m` passa do número de pares possíveis: é bug de quem chama.
  """
  @spec gnm(state(), pos_integer(), non_neg_integer()) ::
          {[{pos_integer(), pos_integer()}], state()}
  def gnm(state, n, m) when is_integer(n) and n > 0 and is_integer(m) and m >= 0 do
    if m > div(n * (n - 1), 2), do: raise(ArgumentError, "m=#{m} passa dos pares de n=#{n}")
    sortear(state, n, m, %{}, [])
  end

  defp sortear(state, _n, 0, _vistos, acc), do: {Enum.reverse(acc), state}

  defp sortear(state, n, faltam, vistos, acc) do
    {u, state} = :rand.uniform_s(n, state)
    {v, state} = :rand.uniform_s(n, state)
    par = {min(u, v), max(u, v)}

    if u == v or Map.has_key?(vistos, par),
      do: sortear(state, n, faltam, vistos, acc),
      else: sortear(state, n, faltam - 1, Map.put(vistos, par, true), [par | acc])
  end

  @doc "A lista embaralhada por Fisher–Yates, do último índice para o primeiro."
  @spec shuffle(state(), list()) :: {list(), state()}
  def shuffle(state, lista) when is_list(lista) do
    tupla = List.to_tuple(lista)

    {tupla, state} =
      Enum.reduce((tuple_size(tupla) - 1)..1//-1, {tupla, state}, fn i, {t, st} ->
        {j, st} = :rand.uniform_s(i + 1, st)
        j = j - 1
        a = elem(t, i)
        b = elem(t, j)
        {t |> put_elem(i, b) |> put_elem(j, a), st}
      end)

    {Tuple.to_list(tupla), state}
  end
end
