defmodule TheBand.NetworkAnalysis.Algorithms.Betweenness do
  @moduledoc """
  A intermediação de Freeman (1977) pelo algoritmo de Brandes (2001) — feature 076, T030 (R6;
  `contracts/algoritmos.md`, `Algorithms.Betweenness`; `network.analysis.parameters.betweenness`).

  Sobre a projeção sem direção, **sem peso**, em passos: a pergunta da tela (*"quem fica entre
  grupos"*) não tem direção, e a referência a calculava no grafo dirigido (S4 da revisão
  semântica).

  Cada fonte soma as dependências das duas pontas de um par, e por isso a soma é dividida por 2
  (pares não ordenados) antes da normalização por (n − 1)(n − 2)/2. Abaixo de `min_people`, e
  sempre abaixo de 3 — onde a normalização não existe —, a medida é ausente para todos, com
  `network_too_small`, e nunca 0.

  Puro: sem `Repo`, relógio, `Logger` nem `:digraph`. Fontes e vizinhos percorridos em ordem de
  id, para que a soma de ponto flutuante seja sempre a mesma (FR-052). Depende de: nenhuma
  ontologia.
  """

  @type id :: String.t()
  @type adjacency :: %{id() => %{id() => pos_integer()}}

  @doc "A intermediação normalizada de cada pessoa, ou ausente para todos numa rede pequena."
  @spec brandes(adjacency(), %{required(:min_people) => pos_integer()}) ::
          %{id() => {:ok, float()} | {:ausente, :network_too_small}}
  def brandes(adjacencia, %{min_people: minimo}) do
    nos = adjacencia |> Map.keys() |> Enum.sort()
    n = length(nos)

    # 3 é o da matemática: com n < 3, (n − 1)(n − 2)/2 é zero.
    if n < max(minimo, 3) do
      Map.new(nos, &{&1, {:ausente, :network_too_small}})
    else
      vizinhos = Map.new(adjacencia, fn {u, m} -> {u, m |> Map.keys() |> Enum.sort()} end)
      inicial = Map.new(nos, &{&1, 0.0})
      bruta = Enum.reduce(nos, inicial, &acumular(vizinhos, &1, &2))
      normalizador = (n - 1) * (n - 2) / 2

      Map.new(nos, fn id -> {id, {:ok, Map.fetch!(bruta, id) / 2 / normalizador}} end)
    end
  end

  # Uma fonte: busca em largura com a contagem de caminhos mais curtos, depois as dependências
  # na ordem inversa da visita.
  defp acumular(vizinhos, fonte, total) do
    {pilha, sigma, pred} =
      bfs(vizinhos, :queue.from_list([fonte]), %{fonte => 0}, %{fonte => 1}, %{}, [])

    {total, _delta} =
      Enum.reduce(pilha, {total, %{}}, fn w, {total, delta} ->
        dw = Map.get(delta, w, 0.0)
        sw = Map.fetch!(sigma, w)

        delta =
          pred
          |> Map.get(w, [])
          |> Enum.reduce(delta, fn v, d ->
            parcela = Map.fetch!(sigma, v) / sw * (1 + dw)
            Map.update(d, v, parcela, &(&1 + parcela))
          end)

        total = if w == fonte, do: total, else: Map.update!(total, w, &(&1 + dw))
        {total, delta}
      end)

    total
  end

  defp bfs(vizinhos, fila, dist, sigma, pred, pilha) do
    case :queue.out(fila) do
      {:empty, _} ->
        {pilha, sigma, pred}

      {{:value, v}, fila} ->
        dv = Map.fetch!(dist, v)

        {fila, dist, sigma, pred} =
          vizinhos
          |> Map.get(v, [])
          |> Enum.reduce({fila, dist, sigma, pred}, &visitar(&1, &2, v, dv))

        bfs(vizinhos, fila, dist, sigma, pred, [v | pilha])
    end
  end

  # O vizinho `w` de `v`: entra na fila na primeira vez; se está um passo além, herda os caminhos
  # de `v` e o tem como predecessor.
  defp visitar(w, {f, d, s, p}, v, dv) do
    {f, d} = if Map.has_key?(d, w), do: {f, d}, else: {:queue.in(w, f), Map.put(d, w, dv + 1)}

    if Map.fetch!(d, w) == dv + 1 do
      sv = Map.fetch!(s, v)
      {f, d, Map.update(s, w, sv, &(&1 + sv)), Map.update(p, w, [v], &(&1 ++ [v]))}
    else
      {f, d, s, p}
    end
  end
end
