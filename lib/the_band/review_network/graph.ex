defmodule TheBand.ReviewNetwork.Graph do
  @moduledoc """
  A matemática da rede de revisão, em Elixir puro — feature 073, T012 (research.md R2, R5; D3).

  Sem `Repo`, sem relógio, sem `Logger`. A janela entra como instante recebido, nunca como
  `DateTime.utc_now/0`, e toda saída é ordenada: o mesmo cálculo dá o mesmo resultado (FR-012).

  **A unidade é o par (revisor, solicitação)** (R2): o peso de uma aresta é o número de
  solicitações **distintas** do autor que o revisor revisou na janela, e o total de revisões é a
  soma dos pesos. Uma solicitação com dois revisores conta duas revisões.

  **Sem biblioteca de grafo** (D3): componentes fracos e prefixos de soma somam poucas linhas
  sobre `Map` e `MapSet`, na escala medida (40 nós, 233 arestas). A pergunta volta com medida
  quando a fatia 3 pedir intermediação.

  Depende de: nada além do que recebe.
  """

  @type id :: Ecto.UUID.t()
  @type edge :: %{reviewer: id(), author: id(), change_requests: pos_integer()}
  @type t :: %{
          edges: [edge()],
          received: %{id() => pos_integer()},
          excluded: %{
            self_review: non_neg_integer(),
            bot_or_app: non_neg_integer(),
            unlinked_person: non_neg_integer()
          },
          pairs: non_neg_integer()
        }

  @doc """
  Monta a rede de uma janela a partir dos pares classificados (`Classification.classify/2`).

  Só entram os pares cujo envio mais recente é `>= window_start`: as janelas são aninhadas e
  terminam no mesmo instante, então um par está na janela se o envio mais recente dele está nela.

  Devolve as arestas com peso, as solicitações distintas revisadas de cada autor (o único número
  por pessoa que não se deriva das arestas), as exclusões por motivo e o total de pares. O
  invariante `pairs = soma dos pesos + exclusões` vale por construção, e o teste o confere.
  """
  @spec build([map()], DateTime.t()) :: t()
  def build(pares, %DateTime{} = window_start) do
    na_janela = Enum.filter(pares, &(DateTime.compare(&1.last_submitted_at, window_start) != :lt))

    # A mesma pessoa pode revisar a mesma solicitação por duas contas ligadas a ela: o peso é
    # solicitação distinta, então o par aresta é deduplicado por (revisor, autor, solicitação).
    arestas =
      for %{destino: {:aresta, r, a}, change_request_id: cr} <- na_janela, uniq: true do
        {r, a, cr}
      end

    excluidos = Enum.frequencies_by(na_janela, & &1.destino)

    %{
      edges:
        arestas
        |> Enum.frequencies_by(fn {r, a, _cr} -> {r, a} end)
        |> Enum.map(fn {{r, a}, n} -> %{reviewer: r, author: a, change_requests: n} end)
        |> Enum.sort_by(&{&1.reviewer, &1.author}),
      received:
        arestas
        |> Enum.uniq_by(fn {_r, a, cr} -> {a, cr} end)
        |> Enum.frequencies_by(fn {_r, a, _cr} -> a end),
      excluded: %{
        self_review: Map.get(excluidos, :self_review, 0),
        bot_or_app: Map.get(excluidos, :bot_or_app, 0),
        unlinked_person: Map.get(excluidos, :unlinked_person, 0)
      },
      pairs:
        length(arestas) + Map.get(excluidos, :self_review, 0) +
          Map.get(excluidos, :bot_or_app, 0) + Map.get(excluidos, :unlinked_person, 0)
    }
  end

  @doc """
  Por pessoa, sobre as arestas dadas: revisões feitas e de quantas pessoas, e por quantas pessoas
  foi revisada. Quem não aparece no mapa não tem aresta: a ausência é de quem chama dizer.
  """
  @spec totals_by_person([edge()]) :: %{
          id() => %{
            given_reviews: non_neg_integer(),
            given_people: non_neg_integer(),
            received_people: non_neg_integer()
          }
        }
  def totals_by_person(edges) do
    vazio = %{given_reviews: 0, given_people: 0, received_people: 0}

    Enum.reduce(edges, %{}, fn %{reviewer: r, author: a, change_requests: n}, acc ->
      acc
      |> Map.update(r, %{vazio | given_reviews: n, given_people: 1}, fn t ->
        %{t | given_reviews: t.given_reviews + n, given_people: t.given_people + 1}
      end)
      |> Map.update(a, %{vazio | received_people: 1}, fn t ->
        %{t | received_people: t.received_people + 1}
      end)
    end)
  end

  @doc """
  Os grupos que não se revisam entre si: componentes **fracamente** conexos, só entre pessoas com
  ao menos uma aresta (pessoa sem aresta não é grupo). Ordenados por tamanho decrescente, e depois
  pelo menor id; cada grupo, ordenado.
  """
  @spec groups([edge()]) :: [[id()]]
  def groups(edges) do
    vizinhos =
      Enum.reduce(edges, %{}, fn %{reviewer: r, author: a}, acc ->
        acc
        |> Map.update(r, MapSet.new([a]), &MapSet.put(&1, a))
        |> Map.update(a, MapSet.new([r]), &MapSet.put(&1, r))
      end)

    vizinhos
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce({MapSet.new(), []}, fn no, {vistos, grupos} ->
      if MapSet.member?(vistos, no) do
        {vistos, grupos}
      else
        grupo = largura([no], vizinhos, MapSet.new([no]))
        {MapSet.union(vistos, grupo), [Enum.sort(grupo) | grupos]}
      end
    end)
    |> elem(1)
    |> Enum.sort_by(&{-length(&1), hd(&1)})
  end

  defp largura([], _vizinhos, visitados), do: visitados

  defp largura([no | fila], vizinhos, visitados) do
    novos = vizinhos |> Map.fetch!(no) |> Enum.reject(&MapSet.member?(visitados, &1))
    largura(fila ++ novos, vizinhos, MapSet.union(visitados, MapSet.new(novos)))
  end

  @doc """
  A fração das revisões feitas pelas k pessoas que mais revisaram, para cada k — **sem dizer
  quem**: só os valores, nunca a lista ordenada de pessoas.

  `:no_review_in_window` quando não há revisão, e nunca 0. k maior que o número de revisores é
  `{:ausente, :fewer_reviewers_than_k}` naquele k, e nunca 100%.
  """
  @spec concentration([edge()], [pos_integer()]) ::
          :no_review_in_window
          | [
              %{
                k: pos_integer(),
                value:
                  {:ok, %{reviews: pos_integer(), of: pos_integer()}}
                  | {:ausente, :fewer_reviewers_than_k}
              }
            ]
  def concentration([], _ks), do: :no_review_in_window

  def concentration(edges, ks) do
    feitas =
      edges
      |> Enum.reduce(%{}, fn e, acc ->
        Map.update(acc, e.reviewer, e.change_requests, &(&1 + e.change_requests))
      end)
      |> Map.values()
      |> Enum.sort(:desc)

    total = Enum.sum(feitas)
    revisores = length(feitas)

    Enum.map(ks, fn
      k when k > revisores ->
        %{k: k, value: {:ausente, :fewer_reviewers_than_k}}

      k ->
        %{k: k, value: {:ok, %{reviews: feitas |> Enum.take(k) |> Enum.sum(), of: total}}}
    end)
  end

  @doc "O subgrafo induzido pelas pessoas dadas: só arestas com as duas pontas no conjunto."
  @spec induced([edge()], MapSet.t()) :: [edge()]
  def induced(edges, pessoas) do
    Enum.filter(
      edges,
      &(MapSet.member?(pessoas, &1.reviewer) and MapSet.member?(pessoas, &1.author))
    )
  end
end
