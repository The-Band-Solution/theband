defmodule TheBand.WorkItems.Queries do
  @moduledoc """
  Leituras de WorkItems. A fronteira é `TheBand.WorkItems`.

  **Nenhuma função devolve `Ecto.Query`.** Quem recebe query compõe sobre ela e, ao
  compor, contorna o filtro de tenant.

  ## A invariante que a tela usa

      count_collected == soma(count_by_promotion) + soma(count_gaps_by_reason)

  Nenhuma issue desaparece entre a coleta e a classificação. Se não fechar, alguma
  promoção não foi registrada — e o número que a tela mostra passa a ser menor que a
  realidade sem avisar.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.DecompositionLink
  alias TheBand.WorkItems.Schemas.IssuePromotion
  alias TheBand.WorkItems.Schemas.RefusedLink

  @spec count_collected(Tenant.t(), keyword()) :: non_neg_integer()
  def count_collected(%Tenant{} = tenant, opts \\ []),
    do: tenant |> escopo(opts) |> select([i], count(i.id)) |> Repo.one()

  @doc """
  Issues com a promoção vigente de cada uma.

  A promoção vigente é a **última** — `inserted_at` em microssegundo desempata, e é a
  L20 aplicada aqui: duas promoções do mesmo segundo tornariam a "vigente" dependente do
  plano de execução.
  """
  @spec list_issues(Tenant.t(), keyword()) :: [map()]
  def list_issues(%Tenant{} = tenant, opts \\ []) do
    limite = Keyword.get(opts, :limit, 100)
    deslocamento = Keyword.get(opts, :offset, 0)

    tenant
    |> escopo(opts)
    |> join(:left, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    # Ordem estável, e é o que torna a paginação confiável: ordenar só por `number`
    # daria páginas que se sobrepõem, porque o número repete entre repositórios — esta
    # organização tem 121 deles, e vários `#1`.
    |> order_by([i], asc: i.observed_repository_id, asc: i.number, asc: i.id)
    |> limit(^limite)
    |> offset(^deslocamento)
    |> select([i, p], %{
      id: i.id,
      number: i.number,
      observed_repository_id: i.observed_repository_id,
      title: i.title,
      state: i.state,
      issue_type: i.issue_type,
      sub_issue_count: i.sub_issue_count,
      no_longer_observed_at: i.no_longer_observed_at,
      derived_concept: p.derived_concept,
      declared_concept: p.declared_concept,
      divergence_reason: p.divergence_reason,
      skip_reason: p.skip_reason,
      skip_detail: p.skip_detail
    })
    |> Repo.all()
  end

  @spec count_by_promotion(Tenant.t(), keyword()) :: %{String.t() => non_neg_integer()}
  def count_by_promotion(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> join(:inner, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    |> where([_i, p], not is_nil(p.derived_concept))
    |> group_by([_i, p], p.derived_concept)
    |> select([_i, p], {p.derived_concept, count(p.collected_issue_id)})
    |> Repo.all()
    |> Map.new()
  end

  @spec count_gaps_by_reason(Tenant.t(), keyword()) :: %{String.t() => non_neg_integer()}
  def count_gaps_by_reason(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> join(:inner, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    |> where([_i, p], not is_nil(p.skip_reason))
    |> group_by([_i, p], p.skip_reason)
    |> select([_i, p], {p.skip_reason, count(p.collected_issue_id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Os tipos não reconhecidos, com **o nome de cada um** e quantas issues o usam.

  Sem o nome, a lacuna não diz onde a regra precisa mudar: "tipo desconhecido: 14" não
  responde nada, e "Spike (9), Chore (5)" responde.
  """
  @spec unknown_types(Tenant.t(), keyword()) :: [{String.t(), non_neg_integer()}]
  def unknown_types(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> join(:inner, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    |> where([_i, p], p.skip_reason == "type_unknown" and not is_nil(p.skip_detail))
    |> group_by([_i, p], p.skip_detail)
    |> select([_i, p], {p.skip_detail, count(p.collected_issue_id)})
    |> order_by([_i, p], desc: count(p.collected_issue_id))
    |> Repo.all()
  end

  @doc """
  As divergências entre tipo declarado e conceito derivado.

  Não é erro a corrigir na plataforma: é sinal sobre o processo do time — épico
  abandonado sem decomposição, ou user story que cresceu e virou épico sem retipagem.
  """
  @spec list_divergences(Tenant.t(), keyword()) :: [map()]
  def list_divergences(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> join(:inner, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    |> where([_i, p], not is_nil(p.divergence_reason))
    |> order_by([i], asc: i.number)
    |> select([i, p], %{
      number: i.number,
      title: i.title,
      issue_type: i.issue_type,
      declared_concept: p.declared_concept,
      derived_concept: p.derived_concept,
      divergence_reason: p.divergence_reason
    })
    |> Repo.all()
  end

  @doc """
  Épico ou user story atômica, **derivado das partes** — nunca lido de coluna.

  Um caminho só: a tela, a consulta de escopo e o teste usam esta função. Dois caminhos
  discordariam, e a tela mostraria como épico o que a consulta trata como atômica.
  """
  @spec classification(Tenant.t(), Ecto.UUID.t()) :: :epic | :atomic_user_story
  def classification(%Tenant{id: tenant_id}, collected_issue_id) do
    partes_user_story =
      Repo.one(
        from l in DecompositionLink,
          join: c in CollectedIssue,
          on: c.id == l.child_issue_id,
          join: p in subquery(promocoes_vigentes(tenant_id)),
          on: p.collected_issue_id == c.id,
          where:
            l.tenant_id == ^tenant_id and l.parent_issue_id == ^collected_issue_id and
              is_nil(l.no_longer_observed_at) and
              p.derived_concept in ["sro.epic", "sro.atomic_user_story"],
          select: count(l.id)
      )

    if partes_user_story > 0, do: :epic, else: :atomic_user_story
  end

  @doc """
  Identificador interno por identificador externo, para ligar partes a pais.

  Existe porque ligar por `number` é errado: o número é único **dentro** do repositório,
  e uma organização com 14 repositórios tem vários `#1`. Chavear por número liga a parte
  de um repositório ao pai de outro, e o erro é silencioso — a classificação sai errada
  em vez de falhar.
  """
  @spec list_by_external_id(Tenant.t()) :: [%{external_id: String.t(), id: Ecto.UUID.t()}]
  def list_by_external_id(%Tenant{id: tenant_id}) do
    Repo.all(
      from i in CollectedIssue,
        where: i.tenant_id == ^tenant_id,
        select: %{external_id: i.external_id, id: i.id}
    )
  end

  @doc """
  Os vínculos de decomposição vigentes, para derivar a classificação em lote.

  Existe porque promover issue por issue chamando `classification/2` faria uma consulta
  por issue — 95 consultas numa organização pequena, e o custo cresce com o tamanho do
  repositório. Aqui o grafo vem numa consulta, e a decisão é em memória.
  """
  @spec list_links(Tenant.t()) :: [
          %{parent_issue_id: Ecto.UUID.t(), child_issue_id: Ecto.UUID.t()}
        ]
  def list_links(%Tenant{id: tenant_id}) do
    Repo.all(
      from l in DecompositionLink,
        where: l.tenant_id == ^tenant_id and is_nil(l.no_longer_observed_at),
        select: %{parent_issue_id: l.parent_issue_id, child_issue_id: l.child_issue_id}
    )
  end

  @spec count_refused(Tenant.t(), keyword()) :: %{String.t() => non_neg_integer()}
  def count_refused(%Tenant{id: tenant_id}, _opts \\ []) do
    Repo.all(
      from r in RefusedLink,
        where: r.tenant_id == ^tenant_id,
        group_by: r.reason,
        select: {r.reason, count(r.id)}
    )
    |> Map.new()
  end

  # ------------------------------------------------------------------- privados

  defp escopo(%Tenant{id: tenant_id}, opts) do
    query = from i in CollectedIssue, where: i.tenant_id == ^tenant_id

    case Keyword.get(opts, :observed_repository_id) do
      nil -> query
      id -> where(query, [i], i.observed_repository_id == ^id)
    end
  end

  defp vigentes(%Tenant{id: tenant_id}), do: promocoes_vigentes(tenant_id)

  # A vigente é a última por `inserted_at`. `distinct` com `order_by` desc devolve uma
  # linha por issue, e é a mais recente.
  defp promocoes_vigentes(tenant_id) do
    from p in IssuePromotion,
      where: p.tenant_id == ^tenant_id,
      distinct: p.collected_issue_id,
      order_by: [asc: p.collected_issue_id, desc: p.inserted_at]
  end
end
