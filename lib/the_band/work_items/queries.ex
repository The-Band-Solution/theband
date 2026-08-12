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
  alias TheBand.WorkItems.Axioms
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.DecompositionLink
  alias TheBand.WorkItems.Schemas.IssueAssignee
  alias TheBand.WorkItems.Schemas.IssueLabel
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

  @doc """
  Quantas issues têm cada **tipo** de divergência.

  Existe porque a frase não responde isto: contar por substring quebraria na primeira vez
  que alguém melhorasse a redação. É o mesmo par de `count_gaps_by_reason/2`, que agrupa
  por motivo e não por texto.
  """
  @spec count_divergences_by_kind(Tenant.t(), keyword()) :: %{String.t() => non_neg_integer()}
  def count_divergences_by_kind(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> join(:inner, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    |> where([_i, p], not is_nil(p.divergence_kind))
    |> group_by([_i, p], p.divergence_kind)
    |> select([_i, p], {p.divergence_kind, count(p.collected_issue_id)})
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
      id: i.id,
      number: i.number,
      title: i.title,
      issue_type: i.issue_type,
      declared_concept: p.declared_concept,
      derived_concept: p.derived_concept,
      divergence_reason: p.divergence_reason,
      divergence_kind: p.divergence_kind
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

  # ------------------------------------------------------- detalhe (feature 006)

  @conceitos_user_story ["sro.epic", "sro.atomic_user_story"]
  @conceito_tarefa "sro.intended_scrum_development_task"

  @doc """
  A issue com tudo o que foi coletado dela, a promoção vigente, designados e rótulos.

  Devolve `{:error, :not_found}` para issue de outro tenant — **nunca** `:unauthorized`.
  Dizer "sem permissão" confirmaria que o recurso existe.
  """
  @spec fetch_issue(Tenant.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, :not_found}
  def fetch_issue(%Tenant{id: tenant_id} = tenant, id) do
    consulta =
      from i in CollectedIssue,
        left_join: p in subquery(promocoes_vigentes(tenant_id)),
        on: p.collected_issue_id == i.id,
        where: i.tenant_id == ^tenant_id and i.id == ^id,
        select: %{
          id: i.id,
          number: i.number,
          title: i.title,
          state: i.state,
          state_reason: i.state_reason,
          body: i.body,
          author_login: i.author_login,
          author_person_id: i.author_person_id,
          milestone_title: i.milestone_title,
          project_titles: i.project_titles,
          comment_count: i.comment_count,
          reaction_count: i.reaction_count,
          issue_type: i.issue_type,
          sub_issue_count: i.sub_issue_count,
          observed_repository_id: i.observed_repository_id,
          external_id: i.external_id,
          external_created_at: i.external_created_at,
          external_updated_at: i.external_updated_at,
          external_closed_at: i.external_closed_at,
          collected_at: i.collected_at,
          last_observed_at: i.last_observed_at,
          no_longer_observed_at: i.no_longer_observed_at,
          derived_concept: p.derived_concept,
          declared_concept: p.declared_concept,
          divergence_reason: p.divergence_reason,
          divergence_kind: p.divergence_kind,
          skip_reason: p.skip_reason,
          skip_detail: p.skip_detail,
          rule_id: p.rule_id,
          rule_version: p.rule_version,
          promoted_at: p.promoted_at
        }

    case Repo.one(consulta) do
      nil ->
        {:error, :not_found}

      issue ->
        {:ok,
         Map.merge(issue, %{
           assignees: assignees(tenant_id, id),
           labels: labels(tenant_id, id),
           classification: classification(tenant, id)
         })}
    end
  end

  defp assignees(tenant_id, issue_id) do
    Repo.all(
      from a in IssueAssignee,
        where: a.tenant_id == ^tenant_id and a.collected_issue_id == ^issue_id,
        order_by: [asc: a.login],
        select: %{login: a.login, person_id: a.person_id}
    )
  end

  defp labels(tenant_id, issue_id) do
    Repo.all(
      from l in IssueLabel,
        where: l.tenant_id == ^tenant_id and l.collected_issue_id == ^issue_id,
        order_by: [asc: l.name],
        select: %{name: l.name, color: l.color}
    )
  end

  @doc """
  As promoções vigentes de um conjunto de issues, para comparar em lote.

  Existe para o recálculo da feature 005 poder gravar **só o que mudou**: sem ela, seriam
  4471 consultas de uma linha para responder "o que já estava decidido".
  """
  @spec current_promotions(Tenant.t(), [Ecto.UUID.t()]) :: [map()]
  def current_promotions(_tenant, []), do: []

  def current_promotions(%Tenant{id: tenant_id}, issue_ids) do
    Repo.all(
      from p in subquery(promocoes_vigentes(tenant_id)),
        where: p.collected_issue_id in ^issue_ids,
        select: %{
          collected_issue_id: p.collected_issue_id,
          derived_concept: p.derived_concept,
          skip_reason: p.skip_reason,
          evidence_source: p.evidence_source,
          mapping_rule_id: p.mapping_rule_id
        }
    )
  end

  @doc """
  As promoções da issue em ordem cronológica, a última marcada como vigente.

  A ordem é por `inserted_at` em microssegundo — a L20 aplicada: duas promoções do mesmo
  segundo tornariam "a vigente" dependente do plano de execução.
  """
  @spec promotion_history(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def promotion_history(%Tenant{id: tenant_id}, issue_id) do
    linhas =
      Repo.all(
        from p in IssuePromotion,
          where: p.tenant_id == ^tenant_id and p.collected_issue_id == ^issue_id,
          order_by: [asc: p.inserted_at],
          select: %{
            derived_concept: p.derived_concept,
            declared_concept: p.declared_concept,
            divergence_reason: p.divergence_reason,
            skip_reason: p.skip_reason,
            skip_detail: p.skip_detail,
            rule_id: p.rule_id,
            rule_version: p.rule_version,
            promoted_at: p.promoted_at,
            inserted_at: p.inserted_at
          }
      )

    ultima = length(linhas) - 1
    Enum.with_index(linhas, fn linha, i -> Map.put(linha, :current, i == ultima) end)
  end

  @doc """
  As partes que **compõem** a issue — promovidas a épico ou a user story atômica.

  Separada de `list_attendance/2` de propósito: `sro.epic_composed_of_user_story` é
  composição, e tarefa **atende** por `sro.intended_task_planned_to_meet_user_story`. Uma
  contagem única de "filhas" apagaria a distinção que a plataforma existe para preservar.
  """
  @spec list_composition(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_composition(%Tenant{} = tenant, issue_id),
    do: partes(tenant, issue_id, {:in, @conceitos_user_story})

  @doc """
  As tarefas que **atendem** a issue.

  Num épico com 3 user stories e 36 tarefas, esta função devolve 36 e
  `list_composition/2` devolve 3. **39 não aparece em lugar nenhum.**
  """
  @spec list_attendance(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_attendance(%Tenant{} = tenant, issue_id),
    do: partes(tenant, issue_id, {:eq, @conceito_tarefa})

  @doc """
  As partes que a plataforma **não promoveu a nada** — nem composição, nem atendimento.

  Existe porque somar composição e atendimento e comparar com `sub_issue_count` daria a
  impressão de que a plataforma perdeu vínculos. Ela não perdeu: as partes estão lá, e
  não foram promovidas — e a razão é a lacuna que a feature 005 resolve.
  """
  @spec list_unpromoted_parts(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_unpromoted_parts(%Tenant{} = tenant, issue_id),
    do: partes(tenant, issue_id, :none)

  defp partes(%Tenant{id: tenant_id}, issue_id, filtro) do
    from(l in DecompositionLink,
      join: c in CollectedIssue,
      on: c.id == l.child_issue_id,
      left_join: p in subquery(promocoes_vigentes(tenant_id)),
      on: p.collected_issue_id == c.id,
      where:
        l.tenant_id == ^tenant_id and l.parent_issue_id == ^issue_id and
          is_nil(l.no_longer_observed_at),
      order_by: [asc: c.number],
      select: %{
        id: c.id,
        number: c.number,
        title: c.title,
        state: c.state,
        issue_type: c.issue_type,
        sub_issue_count: c.sub_issue_count,
        derived_concept: p.derived_concept,
        skip_reason: p.skip_reason,
        skip_detail: p.skip_detail
      }
    )
    |> filtrar_conceito(filtro)
    |> Repo.all()
  end

  defp filtrar_conceito(query, {:in, conceitos}),
    do: where(query, [_l, _c, p], p.derived_concept in ^conceitos)

  defp filtrar_conceito(query, {:eq, conceito}),
    do: where(query, [_l, _c, p], p.derived_concept == ^conceito)

  defp filtrar_conceito(query, :none),
    do: where(query, [_l, _c, p], is_nil(p.derived_concept))

  @doc """
  O pai vigente da issue, com o conceito dele — `nil` quando não tem pai.

  Para uma tarefa é a user story que ela atende; para uma user story dentro de épico é o
  épico. É a mesma consulta, porque é a mesma relação de decomposição vista de baixo.
  """
  @spec fetch_parent(Tenant.t(), Ecto.UUID.t()) :: map() | nil
  def fetch_parent(%Tenant{id: tenant_id}, issue_id) do
    Repo.one(
      from l in DecompositionLink,
        join: c in CollectedIssue,
        on: c.id == l.parent_issue_id,
        left_join: p in subquery(promocoes_vigentes(tenant_id)),
        on: p.collected_issue_id == c.id,
        where:
          l.tenant_id == ^tenant_id and l.child_issue_id == ^issue_id and
            is_nil(l.no_longer_observed_at),
        limit: 1,
        select: %{
          id: c.id,
          number: c.number,
          title: c.title,
          issue_type: c.issue_type,
          derived_concept: p.derived_concept
        }
    )
  end

  @doc """
  As duas formas de violar `sro.rule07`, **separadas** — e nenhuma delas despromove nada.

  A decisão é de `TheBand.WorkItems.Axioms.rule07/2`, a mesma função que a tela de detalhe
  usa numa issue. Aqui muda só como os dados chegam: o grafo inteiro vem numa consulta e a
  decisão é em memória, como em `list_links/1`. Duas implementações do axioma discordariam,
  e a tela do repositório avisaria sobre uma issue que o detalhe dela declara correta.
  """
  @spec rule07_violations(Tenant.t(), keyword()) :: %{
          task_parent_is_epic: [map()],
          task_without_parent: [map()]
        }
  def rule07_violations(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> tarefas_com_pai(opts)
    |> Enum.reduce(%{task_parent_is_epic: [], task_without_parent: []}, fn tarefa, acc ->
      case Axioms.rule07(tarefa.derived_concept, tarefa.parent_concept) do
        :ok -> acc
        {:violation, forma} -> Map.update!(acc, forma, &[tarefa | &1])
      end
    end)
    |> Map.new(fn {forma, lista} -> {forma, Enum.reverse(lista)} end)
  end

  # As tarefas com o conceito do pai ao lado — `nil` quando não tem pai. O `left_join`
  # é o que torna "sem pai" um valor em vez de uma ausência de linha, e é o que permite
  # a mesma função decidir os dois casos.
  defp tarefas_com_pai(%Tenant{} = tenant, opts) do
    tenant
    |> escopo(opts)
    |> join(:inner, [i], p in subquery(vigentes(tenant)), on: p.collected_issue_id == i.id)
    |> where([_i, p], p.derived_concept == ^@conceito_tarefa)
    |> join(:left, [i, _p], l in DecompositionLink,
      on: l.child_issue_id == i.id and is_nil(l.no_longer_observed_at)
    )
    |> join(:left, [_i, _p, l], pp in subquery(vigentes(tenant)),
      on: pp.collected_issue_id == l.parent_issue_id
    )
    |> order_by([i], asc: i.number)
    |> select([i, p, l, pp], %{
      id: i.id,
      number: i.number,
      title: i.title,
      derived_concept: p.derived_concept,
      parent_issue_id: l.parent_issue_id,
      parent_concept: pp.derived_concept
    })
    |> Repo.all()
  end

  @doc """
  Os vínculos recusados na coleta que envolvem esta issue, com motivo e caminho do ciclo.

  Aparece no detalhe das duas issues envolvidas: a recusa é do vínculo, e quem lê o
  detalhe de qualquer uma das duas precisa saber que ele foi recusado.
  """
  @spec list_refused_for(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_refused_for(%Tenant{id: tenant_id}, issue_id) do
    Repo.all(
      from r in RefusedLink,
        where:
          r.tenant_id == ^tenant_id and
            (r.parent_issue_id == ^issue_id or r.child_issue_id == ^issue_id),
        order_by: [desc: r.refused_at],
        select: %{
          reason: r.reason,
          cycle_path: r.cycle_path,
          child_external_id: r.child_external_id,
          parent_issue_id: r.parent_issue_id,
          child_issue_id: r.child_issue_id,
          refused_at: r.refused_at
        }
    )
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
