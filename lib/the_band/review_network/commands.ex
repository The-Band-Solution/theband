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
  alias TheBand.ReviewNetwork.Notices
  alias TheBand.ReviewNetwork.Parameters
  alias TheBand.ReviewNetwork.Schemas.Reading
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant

  @dia 86_400

  @type relator :: %{
          readings: [
            %{
              id: Ecto.UUID.t(),
              window_days: pos_integer(),
              reviews: non_neg_integer(),
              excluded: %{
                self_review: non_neg_integer(),
                bot_or_app: non_neg_integer(),
                organization_account: non_neg_integer() | nil,
                unlinked_person: non_neg_integer()
              }
            }
          ]
        }

  @doc """
  Calcula com os parâmetros da base e avisa, só com ids, que há leituras novas. É o que a fachada
  expõe, e só o job chama.
  """
  @spec compute(Tenant.t(), map(), DateTime.t()) ::
          {:ok, relator()} | {:error, {:reading_rejected, [atom()]}}
  def compute(tenant, organization, now) do
    # `with`, e não `{:ok, relator} =`: o `MatchError` imprime o termo que não casou (076, R10).
    with {:ok, relator} <- compute(tenant, organization, now, Parameters.fetch!()) do
      # Depois do commit (a transação já fechou dentro de compute/4), e só com ids: A11.
      Notices.broadcast(tenant.id, organization.id, Enum.map(relator.readings, & &1.id))
      {:ok, relator}
    end
  end

  @doc """
  Calcula as janelas de `parametros.windows` para a organização, e substitui as leituras dela.

  `now` vem de quem chama: a função não lê relógio, e é isso que torna a FR-012 testável. A
  organização já foi conferida (id e tenant) por quem chama.

  Devolve o relator só com contagens, e é o que o job registra (FR-021).

  **Leitura recusada pelo banco** (a organização apagada entre a busca do job e a inserção, por
  exemplo) desfaz a transação e devolve `{:error, {:reading_rejected, campos}}`, só com os **nomes**
  dos campos recusados — feature 076, T004 (R10 da segurança, A18). `Repo.insert!` levantaria
  `Ecto.InvalidChangesetError`, cuja mensagem traz os parâmetros inteiros, isto é, cada par de
  `person_id` da rede; o Oban gravaria essa mensagem em `oban_jobs.errors`.
  """
  @spec compute(Tenant.t(), map(), DateTime.t(), map()) ::
          {:ok, relator()} | {:error, {:reading_rejected, [atom()]}}
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
    # A conta da organização declarada sai também desta rede (076, T027; A7).
    contas = Tenants.organization_account_ids(tenant)
    classificados = Classification.classify(pares, tipos, contas)

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
          excluded_self_review: rede.excluded.self_review,
          excluded_bot_or_app: rede.excluded.bot_or_app,
          excluded_unlinked: rede.excluded.unlinked_person,
          excluded_organization_account: rede.excluded.organization_account,
          knowledge_versions: parametros.knowledge_versions
        }
      end

    with {:ok, gravadas} <- substituir(tenant, organization_id, linhas) do
      {:ok, relator(gravadas)}
    end
  end

  defp relator(gravadas) do
    %{
      readings:
        Enum.map(gravadas, fn r ->
          %{
            id: r.id,
            window_days: r.window_days,
            reviews: r.reviews_in_network,
            excluded: %{
              self_review: r.excluded_self_review,
              bot_or_app: r.excluded_bot_or_app,
              organization_account: r.excluded_organization_account,
              unlinked_person: r.excluded_unlinked
            }
          }
        end)
    }
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

  @doc """
  Apaga as leituras da organização — 076, T052 (R18 da segurança; `contracts/fronteiras.md`).

  Chamada por `Sources.end_observation/3` dentro da transação do encerramento: a observação
  encerrada não deixa leitura com ids de pessoa para trás. Filtra por tenant **e** organização;
  devolve quantas apagou.
  """
  @spec discard_organization(Tenant.t(), Ecto.UUID.t()) :: {:ok, non_neg_integer()}
  def discard_organization(%Tenant{id: tenant_id}, organization_id) do
    {apagadas, _} =
      Repo.delete_all(
        from r in Reading,
          where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id
      )

    {:ok, apagadas}
  end

  defp substituir(%Tenant{id: tenant_id}, organization_id, linhas) do
    Repo.transaction(fn ->
      Repo.delete_all(
        from r in Reading,
          where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id
      )

      Enum.map(linhas, &inserir/1)
    end)
  end

  # Dentro da transação: a recusa desfaz tudo, e o motivo leva só nomes de campo.
  defp inserir(attrs) do
    case %Reading{} |> Reading.changeset(attrs) |> Repo.insert() do
      {:ok, gravada} -> gravada
      {:error, changeset} -> Repo.rollback({:reading_rejected, campos_recusados(changeset)})
    end
  end

  # Só os nomes: o changeset carrega `params` e `changes` com as arestas, e nenhum dos dois pode
  # chegar ao termo que o job devolve ao Oban (076, R10; A18).
  defp campos_recusados(%Ecto.Changeset{errors: errors}),
    do: errors |> Keyword.keys() |> Enum.uniq() |> Enum.sort()
end
