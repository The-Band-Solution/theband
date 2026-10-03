defmodule TheBand.ReviewNetwork.Commands do
  @moduledoc """
  O cálculo da rede de revisão de uma organização observada, e a substituição das leituras —
  feature 073, T014 (FR-010 a FR-012; R3, R7 da segurança; `contracts/review-network.md`).

  **Os parâmetros entram como argumento** (`contracts/review-network.md`, *Os parâmetros entram pela
  fachada*): quem chama em produção é a fachada, que os lê da base. Nenhum valor de janela, de
  estado ou de k está escrito aqui.

  ## O que grava, e o que não grava

  Uma linha por janela, as três numa transação: **apaga** as da organização e **insere** as novas.
  Ou as três ficam, ou nenhuma muda. A anterior não é guardada (R7, decisão de 2026-10-03).

  A linha guarda ids de pessoa e nunca nome, login, nem quem revisou qual solicitação (R3, R7).

  Depende de: CMPO (repositórios da organização), Quality (pares), Changes (autores), EO (tipos de
  conta), sempre pela API pública de cada um (`contracts/fronteiras.md`).
  """

  import Ecto.Query

  alias TheBand.Changes
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Quality
  alias TheBand.Repo
  alias TheBand.ReviewNetwork.Classification
  alias TheBand.ReviewNetwork.Graph
  alias TheBand.ReviewNetwork.Parameters
  alias TheBand.ReviewNetwork.Schemas.Reading
  alias TheBand.Tenants.Tenant

  @dia 86_400

  @type relator :: %{
          readings: [
            %{
              id: Ecto.UUID.t(),
              window_days: pos_integer(),
              reviews: non_neg_integer(),
              excluded: %{
                self_reviews: non_neg_integer(),
                bot_or_app: non_neg_integer(),
                unlinked: non_neg_integer()
              }
            }
          ]
        }

  @doc """
  Calcula com os parâmetros da base. É o que a fachada expõe, e só o job chama.
  """
  @spec compute(Tenant.t(), %{id: Ecto.UUID.t()}, DateTime.t()) :: {:ok, relator()}
  def compute(tenant, organization, now),
    do: compute(tenant, organization, now, Parameters.fetch!())

  @doc """
  Calcula as janelas de `parametros.windows` para a organização, e substitui as leituras dela.

  `now` vem de quem chama: a função não lê relógio, e é isso que torna a FR-012 testável. A
  organização já foi conferida (id e tenant) por quem chama.

  Devolve o relator só com contagens, e é o que o job registra (FR-021). Erro de banco levanta e
  desfaz a transação: não há `{:error, _}` para caso de negócio.
  """
  @spec compute(Tenant.t(), %{id: Ecto.UUID.t()}, DateTime.t(), map()) :: {:ok, relator()}
  def compute(%Tenant{} = tenant, %{id: organization_id}, %DateTime{} = now, parametros) do
    agora = DateTime.truncate(now, :second)
    maior = Enum.max(parametros.windows)
    desde = DateTime.add(agora, -maior * @dia, :second)

    repositorios =
      tenant
      |> CMPO.list_observed(organization_id: organization_id)
      # Repositório tirado da observação não entra na rede, como em `Verification.by_organization/1`.
      |> Enum.filter(&is_nil(&1.excluded_at))
      |> Enum.map(& &1.observed_repository_id)

    pares =
      Quality.review_pairs(tenant, repositorios, since: desde, states: parametros.counted_states)

    autores = Changes.change_request_authors(tenant, repositorios, since: desde)
    tipos = EO.account_types(tenant, ids_de_pessoa(pares, autores))
    classificados = Classification.classify(pares, tipos)

    linhas =
      for dias <- Enum.sort(parametros.windows) do
        inicio = DateTime.add(agora, -dias * @dia, :second)
        rede = Graph.build(classificados, inicio)

        %{
          tenant_id: tenant.id,
          organization_id: organization_id,
          window_days: dias,
          window_start: inicio,
          window_end: agora,
          computed_at: agora,
          edges: Enum.map(rede.edges, &aresta_gravada/1),
          people: pessoas(rede, autores, tipos, inicio),
          reviews_in_network: rede.edges |> Enum.map(& &1.change_requests) |> Enum.sum(),
          excluded_self_reviews: rede.excluded.self_reviews,
          excluded_bot_or_app: rede.excluded.bot_or_app,
          excluded_unlinked: rede.excluded.unlinked,
          knowledge_versions: parametros.knowledge_versions
        }
      end

    {:ok, gravadas} = substituir(tenant, organization_id, linhas)

    {:ok,
     %{
       readings:
         Enum.map(gravadas, fn r ->
           %{
             id: r.id,
             window_days: r.window_days,
             reviews: r.reviews_in_network,
             excluded: %{
               self_reviews: r.excluded_self_reviews,
               bot_or_app: r.excluded_bot_or_app,
               unlinked: r.excluded_unlinked
             }
           }
         end)
     }}
  end

  defp ids_de_pessoa(pares, autores) do
    (Enum.flat_map(pares, &[&1.reviewer_person_id, &1.author_person_id]) ++
       Enum.map(autores, & &1.author_person_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp aresta_gravada(%{reviewer: r, author: a, change_requests: n}),
    do: %{"reviewer" => r, "author" => a, "change_requests" => n}

  # Toda pessoa da lista (US2): quem tem aresta, e quem abriu solicitação na janela e é pessoa. O
  # único número que não se deriva das arestas é o de solicitações distintas revisadas de cada uma;
  # `nil` é "nenhuma solicitação dela revisada", e nunca 0 (FR-009).
  defp pessoas(rede, autores, tipos, inicio) do
    com_aresta = Enum.flat_map(rede.edges, &[&1.reviewer, &1.author])

    abriram =
      for %{author_person_id: id, last_opened_at: quando} <- autores,
          DateTime.compare(quando, inicio) != :lt,
          Map.get(tipos, id) == "person",
          do: id

    (com_aresta ++ abriram)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&%{"id" => &1, "received_change_requests" => Map.get(rede.received, &1)})
  end

  defp substituir(%Tenant{id: tenant_id}, organization_id, linhas) do
    Repo.transaction(fn ->
      Repo.delete_all(
        from r in Reading,
          where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id
      )

      Enum.map(linhas, fn attrs ->
        %Reading{} |> Reading.changeset(attrs) |> Repo.insert!()
      end)
    end)
  end
end
