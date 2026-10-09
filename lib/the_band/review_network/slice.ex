defmodule TheBand.ReviewNetwork.Slice do
  @moduledoc """
  O alcance de quem consulta aplicado a uma leitura — feature 073, T015, T023, T025 (FR-015; R1,
  R2 da segurança; decisões de 2026-10-03, Q4 e Q5).

  Separado de `Graph` porque muda quando a **regra de acesso** muda, e não quando a matemática
  muda (D4, princípio X). Puro: recebe a leitura, o alcance e os parâmetros, e devolve a visão sem
  nomes; os nomes são do `Reader`.

  ## As duas populações, de propósito

  - **o recorte** — o subgrafo induzido pelas pessoas alcançadas (com `:todas`, a rede inteira):
    revisões, revisores, pessoas revisadas, concentração e **grupos** (Q4). Nada calculado sobre
    ele fala de quem está fora;
  - **a linha da pessoa alcançada** — o total **dela** na janela, sobre a rede inteira (R2, item
    1): o total é fato sobre ela, e duas contas vendo números diferentes com o mesmo rótulo é a
    L67. Os pares dela fora do alcance não viram linha nem número: só `pairs_outside_reach?`.

  ## O que nunca sai daqui

  Nenhuma contagem do que ficou fora do alcance, em forma nenhuma (decisão de 2026-10-03 sobre
  R2). As exclusões, as três, bot inclusive, só com `:todas` (R12, Q5).

  Depende de: nada além do que recebe, e de `Graph`.
  """

  alias TheBand.ReviewNetwork.Graph

  @doc """
  A visão de uma leitura para um alcance, sem nomes.

  `organization_person_ids` são as pessoas `person` da organização (`EO.organization_person_ids/2`),
  para a contagem de quem não teve atividade de revisão; ela é sobre as alcançadas.
  """
  @spec view(map(), :todas | {:algumas, MapSet.t()}, map(), [Ecto.UUID.t()]) :: map()
  def view(leitura, alcance, parametros, organization_person_ids) do
    arestas = Enum.map(leitura.edges, &aresta/1)
    alcancada? = alcancada_fn(alcance)
    recorte = recortar(arestas, alcance)
    revisoes = recorte |> Enum.map(& &1.change_requests) |> Enum.sum()
    pessoas = Enum.filter(leitura.people, &alcancada?.(&1["id"]))
    na_lista = MapSet.new(leitura.people, & &1["id"])

    %{
      organization_id: leitura.organization_id,
      window_days: leitura.window_days,
      window_start: leitura.window_start,
      window_end: leitura.window_end,
      computed_at: leitura.computed_at,
      reach: if(alcance == :todas, do: :total, else: :parcial),
      reviews: contagem(revisoes),
      reviewers: recorte |> Enum.map(& &1.reviewer) |> Enum.uniq() |> length() |> contagem(),
      authors: recorte |> Enum.map(& &1.author) |> Enum.uniq() |> length() |> contagem(),
      concentration: concentracao(recorte, revisoes, parametros),
      people: Enum.map(pessoas, &linha(&1, arestas, alcancada?)),
      groups: grupos(recorte),
      people_without_review_activity:
        Enum.count(
          organization_person_ids,
          &(alcancada?.(&1) and not MapSet.member?(na_lista, &1))
        ),
      exclusions: exclusoes(leitura, alcance, revisoes),
      provenance: %{knowledge_versions: leitura.knowledge_versions}
    }
  end

  # Recorte sem revisão: as contagens são AUSENTES, e nunca 0 (FR-009, SC-002). Zero aqui seria
  # a plataforma afirmar que contou e não achou, quando o que houve foi nada a contar.
  defp contagem(0), do: {:ausente, :no_review_in_window}
  defp contagem(n), do: {:ok, n}

  defp aresta(%{"reviewer" => r, "author" => a, "change_requests" => n}),
    do: %{reviewer: r, author: a, change_requests: n}

  defp alcancada_fn(:todas), do: fn _ -> true end
  defp alcancada_fn({:algumas, pessoas}), do: &MapSet.member?(pessoas, &1)

  defp recortar(arestas, :todas), do: arestas
  defp recortar(arestas, {:algumas, pessoas}), do: Graph.induced(arestas, pessoas)

  defp concentracao([], _revisoes, _parametros), do: {:ausente, :no_review_in_window}

  # Abaixo da amostra mínima, a fração é AUSENTE, e não mostrada com aviso (decidido em
  # 2026-10-03): "75% de 4 revisões" convida a leitura que o aviso tenta desfazer. A amostra é
  # contada em revisões, a unidade do denominador.
  defp concentracao(_recorte, revisoes, %{minimum_sample: minimo}) when revisoes < minimo,
    do: {:ausente, {:sample_below_minimum, minimo}}

  defp concentracao(recorte, _revisoes, %{ks: ks}), do: {:ok, Graph.concentration(recorte, ks)}

  defp grupos([]), do: {:ausente, :no_review_in_window}
  defp grupos(recorte), do: {:ok, recorte |> Graph.groups() |> Enum.map(&length/1)}

  # Janela sem revisão nenhuma, nem na rede nem fora dela: as três contagens são AUSENTES, e não
  # 0, 0, 0 (FR-009, SC-002; issue #1308). Com alguma revisão na janela, a contagem de um motivo
  # que não ocorreu é zero de verdade: houve o que contar, e aquele motivo não apareceu.
  defp exclusoes(
         %{
           excluded_self_review: 0,
           excluded_bot_or_app: 0,
           excluded_unlinked: 0,
           excluded_organization_account: conta
         },
         :todas,
         0
       )
       when conta in [0, nil],
       do: {:ausente, :no_review_in_window}

  defp exclusoes(leitura, :todas, _revisoes) do
    {:ok,
     %{
       self_review: leitura.excluded_self_review,
       bot_or_app: leitura.excluded_bot_or_app,
       # Nulo na leitura da versão 1 da regra, que não avaliou o motivo (076, T027): a tela diz
       # que não foi avaliado, e nunca mostra 0.
       organization_account: leitura.excluded_organization_account,
       unlinked_person: leitura.excluded_unlinked
     }}
  end

  defp exclusoes(_leitura, {:algumas, _}, _revisoes), do: {:recortado, :regra}

  defp linha(%{"id" => id, "received_change_requests" => recebidas}, arestas, alcancada?) do
    feitas = Enum.filter(arestas, &(&1.reviewer == id))
    recebidas_de = Enum.filter(arestas, &(&1.author == id))
    # Por lado, porque a tela diz "some pairs are outside your reach" DENTRO da coluna que tem
    # par de fora (régua 3.8, issue #1308). Um booleano por lado, e nenhum número.
    feitas_fora? = Enum.any?(feitas, &(not alcancada?.(&1.author)))
    recebidas_fora? = Enum.any?(recebidas_de, &(not alcancada?.(&1.reviewer)))

    %{
      person_id: id,
      given: total(feitas, :did_not_review_in_window, &%{reviews: &1, people: &2}),
      received:
        case recebidas do
          nil -> {:ausente, :no_change_request_reviewed_in_window}
          n -> {:ok, %{change_requests: n, people: length(recebidas_de)}}
        end,
      reviews_of: pares(feitas, & &1.author, alcancada?),
      reviewed_by: pares(recebidas_de, & &1.reviewer, alcancada?),
      pairs_outside_reach?: feitas_fora? or recebidas_fora?,
      reviews_of_outside_reach?: feitas_fora?,
      reviewed_by_outside_reach?: recebidas_fora?
    }
  end

  defp total([], motivo, _forma), do: {:ausente, motivo}

  defp total(arestas, _motivo, forma),
    do: {:ok, forma.(arestas |> Enum.map(& &1.change_requests) |> Enum.sum(), length(arestas))}

  defp pares(arestas, outra_ponta, alcancada?) do
    for a <- arestas, alcancada?.(outra_ponta.(a)) do
      %{person_id: outra_ponta.(a), reviews: a.change_requests}
    end
  end
end
