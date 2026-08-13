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

  @doc """
  Quantas issues o escopo alcança — **com a mesma busca da listagem**.

  O total e a lista precisam sair da mesma pergunta: um total que ignora a busca faria a paginação
  numerada oferecer páginas vazias, e o número no rodapé desmentir o que está na tela.
  """
  @spec count_collected(Tenant.t(), keyword()) :: non_neg_integer()
  def count_collected(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> por_texto(Keyword.get(opts, :search))
    |> select([i], count(i.id))
    |> Repo.one()
  end

  @doc """
  Quantas issues **vigentes** cada repositório tem, numa consulta agrupada.

  Existe porque a tela chamava `count_collected/2` uma vez por repositório — 135
  consultas para desenhar `/work` — e a marca de trabalho precisa do mesmo número.
  Ler de novo faria 270; agrupar faz 1.

  **Repositório sem nenhuma issue não aparece no mapa.** Quem chama usa
  `Map.get(mapa, id, 0)`, e o zero ali significa "nenhuma issue vigente", nunca "não
  sei" — distinguir os dois é papel de `observed_repositories.issues_collected_at`, e
  não desta função.

  **Vigente é `no_longer_observed_at` nulo.** Issue marcada como ausente não conta
  como trabalho presente. A coluna de contagem da tela lê deste mesmo mapa, então as
  duas nunca divergem — FR-010.
  """
  @spec count_collected_by_repository(Tenant.t(), [Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => non_neg_integer()
        }
  def count_collected_by_repository(%Tenant{}, []), do: %{}

  def count_collected_by_repository(%Tenant{id: tenant_id}, repository_ids)
      when is_list(repository_ids) do
    from(i in CollectedIssue,
      where:
        i.tenant_id == ^tenant_id and
          i.observed_repository_id in ^repository_ids and
          is_nil(i.no_longer_observed_at),
      group_by: i.observed_repository_id,
      select: {i.observed_repository_id, count(i.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Quais destes repositórios têm issue marcada como **não mais observada**.

  Existe para o quarto texto da marca de trabalho, que não é um quarto estado dela:
  repositório sem issue vigente **mas** com issue ausente exibe `no current work`, e não
  `collected, no issues`. Houve trabalho e ele não está presente — são fatos diferentes, e
  "no issues" apagaria o fato de que existiram.

  Devolve `MapSet`, e não contagem: a pergunta é de existência, e uma contagem convidaria
  alguém a exibi-la ao lado como se fosse trabalho vigente.

  **Não estava no contrato original desta feature.** Ele declarava duas funções, e a
  implementação mostrou que o quarto texto não é derivável delas: a contagem de vigentes
  não distingue "nunca teve issue" de "teve e não tem mais".
  """
  @spec repositories_with_absent_issues(Tenant.t(), [Ecto.UUID.t()]) :: MapSet.t(Ecto.UUID.t())
  def repositories_with_absent_issues(%Tenant{}, []), do: MapSet.new()

  def repositories_with_absent_issues(%Tenant{id: tenant_id}, repository_ids)
      when is_list(repository_ids) do
    from(i in CollectedIssue,
      where:
        i.tenant_id == ^tenant_id and
          i.observed_repository_id in ^repository_ids and
          not is_nil(i.no_longer_observed_at),
      distinct: true,
      select: i.observed_repository_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Em quantas issues **vigentes** a pessoa está designada, com designação **vigente**.

  ## A issue manda sobre a designação

  Há duas marcas de ausência em jogo, e o cruzamento delas precisava de regra:

  | issue | designação | conta? |
  |---|---|---|
  | vigente | vigente | **sim** |
  | vigente | ausente | não — deixou de ser designada |
  | **ausente** | vigente | **não** |
  | ausente | ausente | não |

  A terceira linha é a que a análise achou sem definição. **A pessoa não trabalha no que a
  plataforma não observa mais**: designação vigente numa issue ausente é resíduo, porque a marca
  de ausência é por repositório coletado e não desce para a designação.

  ## Por que não existe uma função só, com parâmetro de papel

  `count_issues_of_person/2` obrigaria quem chama a explicar qual sentido queria, e quem lê a
  descobrir. **A soma das duas é proibida na tela** — FR-009 —, e nenhuma função aqui a produz.
  """
  @spec count_assigned_to(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def count_assigned_to(%Tenant{id: tenant_id}, person_id) do
    Repo.one(
      from a in IssueAssignee,
        join: i in CollectedIssue,
        on: i.id == a.collected_issue_id,
        where:
          a.tenant_id == ^tenant_id and a.person_id == ^person_id and
            is_nil(a.no_longer_observed_at) and is_nil(i.no_longer_observed_at),
        select: count(a.id)
    )
  end

  @doc """
  Quantas issues **vigentes** a pessoa abriu.

  A soma disto sobre todas as pessoas do tenant fecha com o total de issues vigentes que têm
  autor — **4 241** no dado real de 2026-08-12. As **288** sem autor não pertencem a pessoa
  nenhuma, e a invariante é o que prova que elas não foram atribuídas a alguém por engano.
  """
  @spec count_authored_by(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def count_authored_by(%Tenant{id: tenant_id}, person_id) do
    Repo.one(
      from i in CollectedIssue,
        where:
          i.tenant_id == ^tenant_id and i.author_person_id == ^person_id and
            is_nil(i.no_longer_observed_at),
        select: count(i.id)
    )
  end

  @doc """
  Em quais repositórios a pessoa aparece, e **por qual evidência**.

  Uma consulta agrupada, com as **duas** contagens por repositório — designadas e abertas por ela
  — e **nunca a soma**.

  **Não devolve o nome do repositório**, e é de propósito: o nome é de CMPO, e juntar
  `cmpo_source_repositories` aqui quebraria a fronteira que o princípio IX protege. Quem chama
  resolve com **uma** consulta a `CMPO.list_observed/1`, virando mapa — consultar por repositório
  seria o defeito que a feature 007 pagou com 135 consultas por render.

  O vínculo pessoa-repositório é **derivado**: a origem nunca o declarou, e a tela precisa dizer
  isso.
  """
  @spec repositories_of_person(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def repositories_of_person(%Tenant{id: tenant_id}, person_id) do
    designadas =
      from i in CollectedIssue,
        join: a in IssueAssignee,
        on: a.collected_issue_id == i.id,
        where:
          i.tenant_id == ^tenant_id and a.person_id == ^person_id and
            is_nil(a.no_longer_observed_at) and is_nil(i.no_longer_observed_at),
        group_by: i.observed_repository_id,
        select: %{repo: i.observed_repository_id, assigned: count(i.id), authored: 0}

    abertas =
      from i in CollectedIssue,
        where:
          i.tenant_id == ^tenant_id and i.author_person_id == ^person_id and
            is_nil(i.no_longer_observed_at),
        group_by: i.observed_repository_id,
        select: %{repo: i.observed_repository_id, assigned: 0, authored: count(i.id)}

    # Uma consulta, com as duas contagens somadas **por papel** e nunca entre papéis: o `union
    # all` junta as linhas, e o agrupamento de fora soma cada coluna separadamente.
    from(linha in subquery(union_all(designadas, ^abertas)),
      group_by: linha.repo,
      # `type(..., :integer)` porque `sum/1` devolve `Decimal`, e a tela compararia número com
      # struct sem perceber. O teste pegou: `left: Decimal.new("1")`, `right: 1`.
      select: %{
        observed_repository_id: linha.repo,
        assigned: type(sum(linha.assigned), :integer),
        authored: type(sum(linha.authored), :integer)
      }
    )
    |> Repo.all()
  end

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
    |> join(:left_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
    |> por_texto(Keyword.get(opts, :search))
    |> ordenar(Keyword.get(opts, :order_by))
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
      divergence_kind: p.divergence_kind,
      skip_reason: p.skip_reason,
      skip_detail: p.skip_detail,
      # A proveniência viaja com a issue porque a tela a mostra em toda linha: sem ela, a
      # listagem trataria decisão por campo declarado e inferência sobre texto livre como a
      # mesma coisa — que é o que o princípio III proíbe.
      evidence_source: p.evidence_source,
      confidence: p.confidence
    })
    |> Repo.all()
  end

  # A busca vai ao **banco**, e não à página já carregada.
  #
  # Buscar em memória filtraria as 25 linhas exibidas e pareceria busca: quem procurasse uma issue
  # que está na página 40 receberia "nada encontrado" — e a tela não teria como saber que mentiu.
  #
  # `ilike` sem índice varre, e a medida diz que aqui isso custa **4,9 ms** sobre 4 529 linhas. Em
  # base maior o certo é índice de trigrama, e o momento de decidir isso é quando a medida mudar —
  # não agora, por previsão.
  defp por_texto(query, nil), do: query
  defp por_texto(query, ""), do: query

  defp por_texto(query, texto) do
    padrao = "%#{String.trim(texto)}%"
    where(query, [i], ilike(i.title, ^padrao) or ilike(fragment("?::text", i.number), ^padrao))
  end

  # A ordem escolhida vem **antes** do desempate, e o desempate nunca sai.
  #
  # Ordenar só pela coluna escolhida daria páginas que se sobrepõem: `number` repete entre
  # repositórios — esta organização tem 121 —, e `derived_concept` repete em 3 346 issues. Sem o
  # desempate, a mesma issue aparece em duas páginas e outra não aparece em nenhuma, **sem erro**.
  defp ordenar(query, nil), do: ordem_estavel(query)

  defp ordenar(query, {:conceito, dir}) do
    query
    |> order_by([_i, p], [{^dir, p.derived_concept}])
    |> ordem_estavel()
  end

  defp ordenar(query, {campo, dir}) when campo in [:number, :title, :state, :issue_type] do
    query
    |> order_by([i], [{^dir, field(i, ^campo)}])
    |> ordem_estavel()
  end

  defp ordem_estavel(query),
    do: order_by(query, [i], asc: i.observed_repository_id, asc: i.number, asc: i.id)

  @spec count_by_promotion(Tenant.t(), keyword()) :: %{String.t() => non_neg_integer()}
  def count_by_promotion(%Tenant{} = tenant, opts \\ []) do
    tenant
    |> escopo(opts)
    |> join(:inner_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
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
    |> join(:inner_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
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
    |> join(:inner_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
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
    |> join(:inner_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
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
    |> join(:inner_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
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
          as: :issue,
          on: c.id == l.child_issue_id,
          inner_lateral_join: p in subquery(vigente_da_issue(tenant_id)),
          on: true,
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
        as: :issue,
        left_lateral_join: p in subquery(vigente_da_issue(tenant_id)),
        on: true,
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
          evidence_source: p.evidence_source,
          confidence: p.confidence,
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

  # Vigentes na tela. O designado que saiu continua no banco — nunca se apaga dados — e a
  # tela mostra quem está nisto agora, que é a pergunta que ela responde.
  defp assignees(tenant_id, issue_id) do
    Repo.all(
      from a in IssueAssignee,
        where:
          a.tenant_id == ^tenant_id and a.collected_issue_id == ^issue_id and
            is_nil(a.no_longer_observed_at),
        order_by: [asc: a.login],
        select: %{login: a.login, person_id: a.person_id}
    )
  end

  defp labels(tenant_id, issue_id) do
    Repo.all(
      from l in IssueLabel,
        where:
          l.tenant_id == ^tenant_id and l.collected_issue_id == ^issue_id and
            is_nil(l.no_longer_observed_at),
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
      from p in subquery(promocoes_vigentes(tenant_id, issue_ids)),
        select: %{
          collected_issue_id: p.collected_issue_id,
          derived_concept: p.derived_concept,
          skip_reason: p.skip_reason,
          evidence_source: p.evidence_source,
          mapping_rule_id: p.mapping_rule_id,
          divergence_kind: p.divergence_kind
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
      as: :issue,
      on: c.id == l.child_issue_id,
      left_lateral_join: p in subquery(vigente_da_issue(tenant_id)),
      on: true,
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
        skip_detail: p.skip_detail,
        evidence_source: p.evidence_source,
        confidence: p.confidence
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
        as: :issue,
        on: c.id == l.parent_issue_id,
        left_lateral_join: p in subquery(vigente_da_issue(tenant_id)),
        on: true,
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
  Os pais de **um conjunto** de issues, numa consulta, agrupados por filha.

  ## Por que não é `fetch_parent/2` num `Enum.map`

  A lista do repositório mostra 50 issues por página, e o repositório maior desta organização tem
  2 514. Uma consulta por linha seriam 50 por render — o defeito que a feature 007 pagou com 135.

  ## Devolve **todos** os pais, e é aí que ela difere da que já existia

  **36** issues têm mais de um pai vigente. `fetch_parent/2` responde com `limit: 1` **sem
  `order_by`**: escolhe um em silêncio, e a escolha pode mudar entre execuções. Aqui a lista vem
  inteira, com ordem `number` e depois `id` — o desempate não é enfeite, porque `number` repete
  entre repositórios e **57** vínculos têm pai em outro.

  ## Vínculo ausente vem, marcado

  `no_longer_observed_at` viaja no resultado. Ausência é marcada, nunca removida — e quem chama
  precisa saber que "mais de um pai" conta só os **vigentes**: um pai vigente mais um vínculo que
  acabou é **um** pai, não dois.

  ## A fronteira não é cruzada

  Devolve `observed_repository_id`, **não** o nome do repositório. O nome é de CMPO, e juntar a
  tabela dele aqui quebraria a ADR 0003.

  Issue sem pai **não** aparece no mapa — quem chama nomeia a ausência, e `Map.get/3` com `[]` é
  o acesso certo.
  """
  @spec list_parents(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [map()]}
  def list_parents(%Tenant{}, []), do: %{}

  def list_parents(%Tenant{id: tenant_id}, issue_ids) when is_list(issue_ids) do
    from(l in DecompositionLink,
      join: c in CollectedIssue,
      as: :issue,
      on: c.id == l.parent_issue_id,
      left_lateral_join: p in subquery(vigente_da_issue(tenant_id)),
      on: true,
      where: l.tenant_id == ^tenant_id and l.child_issue_id in ^issue_ids,
      order_by: [asc: c.number, asc: c.id],
      select: %{
        child_issue_id: l.child_issue_id,
        id: c.id,
        number: c.number,
        title: c.title,
        observed_repository_id: c.observed_repository_id,
        derived_concept: p.derived_concept,
        no_longer_observed_at: l.no_longer_observed_at
      }
    )
    |> Repo.all()
    |> Enum.group_by(& &1.child_issue_id)
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
    |> join(:inner_lateral, [i], p in subquery(vigente_da_issue(tenant.id)), on: true)
    |> where([_i, p], p.derived_concept == ^@conceito_tarefa)
    |> join(:left, [i, _p], l in DecompositionLink,
      as: :vinculo,
      on: l.child_issue_id == i.id and is_nil(l.no_longer_observed_at)
    )
    # A vigente **do pai**, e por isso a lateral aponta para o vínculo, não para a issue da linha.
    # O binding nomeado é o que torna isso legível — e é a L39: contar posição aqui, com quatro
    # bindings em jogo, é como o `select` passa a ler o campo errado sem nada falhar.
    |> join(:left_lateral, [_i, _p, l], pp in subquery(vigente_do_pai(tenant.id)), on: true)
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
    # `as: :issue` é o que permite `parent_as(:issue)` na junção lateral. Nomear o binding zero não
    # desloca nada — quem compõe por cima continua enxergando a issue na mesma posição.
    query = from i in CollectedIssue, as: :issue, where: i.tenant_id == ^tenant_id

    query
    |> por_repositorio(Keyword.get(opts, :observed_repository_id))
    |> por_designacao(Keyword.get(opts, :assigned_to))
    |> por_autoria(Keyword.get(opts, :authored_by))
  end

  defp por_repositorio(query, nil), do: query
  defp por_repositorio(query, id), do: where(query, [i], i.observed_repository_id == ^id)

  # **Duas opções, e nunca uma `person_id`**: "as issues da pessoa" são três conjuntos — as que
  # ela foi designada, as que ela abriu, e a união —, e a união é a que não corresponde a nada.
  # O nome da opção é onde a distinção sobrevive, e é a L34 aplicada antes de doer.
  defp por_designacao(query, nil), do: query

  # **Subconsulta, e não `join`**: `list_issues/2` compõe sobre este escopo com um `join` próprio e
  # um `select` por posição — `[i, p]`. Um `join` aqui deslocaria os bindings, e o `select` passaria
  # a ler campo de designação onde espera promoção. O teste pegou isso, e a mensagem era
  # `field derived_concept in select does not exist in schema IssueAssignee`.
  defp por_designacao(query, person_id) do
    designadas =
      from a in IssueAssignee,
        where: a.person_id == ^person_id and is_nil(a.no_longer_observed_at),
        select: a.collected_issue_id

    where(query, [i], i.id in subquery(designadas))
  end

  defp por_autoria(query, nil), do: query
  defp por_autoria(query, person_id), do: where(query, [i], i.author_person_id == ^person_id)

  @doc false
  # A promoção vigente **da issue que está sendo lida**, resolvida por junção lateral.
  #
  # ## Por que não é mais uma subconsulta única
  #
  # A versão anterior calculava a vigente de **todas** as issues do tenant e cruzava o resultado
  # com as que a tela mostra. Medido em 2026-08-12, no dado real: 44 289 promoções varridas para
  # decorar 25 linhas — e o custo não vinha da página, vinha do histórico.
  #
  # A mesma consulta custava **0,09 s para uma pessoa e 6,12 s para outra**, porque o planejador
  # escolhia estratégias diferentes: uma ordenação só, ou dezenas de milhares de ordenações em
  # grupo. Uma tela cujo tempo depende dessa escolha não é sintonizável.
  #
  # Resolvida por issue, com `limit: 1` sobre o índice `(collected_issue_id, inserted_at)` que já
  # existia: **6 326 ms → 3,2 ms**, sem varredura no plano.
  #
  # ## O desempate por `id`
  #
  # `inserted_at` é `utc_datetime_usec`, e a medida no dado real dá **zero** empates. O desempate
  # entra como seguro barato: tira a ordem da dependência de o carimbo continuar tendo essa
  # precisão.
  #
  # ## `parent_as(:issue)` exige o binding nomeado
  #
  # Quem compõe sobre `escopo/2` recebe `as: :issue` no binding zero. Nomear em vez de contar
  # posição é a **L39**: um `join` novo desloca os bindings posicionais de quem compõe por cima, e
  # o `select` passa a ler o campo errado sem que nada falhe.
  defp vigente_da_issue(tenant_id) do
    from p in IssuePromotion,
      where: p.tenant_id == ^tenant_id and p.collected_issue_id == parent_as(:issue).id,
      order_by: [desc: p.inserted_at, desc: p.id],
      limit: 1
  end

  # A mesma resolução, olhando o **pai** do vínculo em vez da issue da linha.
  defp vigente_do_pai(tenant_id) do
    from p in IssuePromotion,
      where:
        p.tenant_id == ^tenant_id and
          p.collected_issue_id == parent_as(:vinculo).parent_issue_id,
      order_by: [desc: p.inserted_at, desc: p.id],
      limit: 1
  end

  # As vigentes de um conjunto **conhecido** de issues. Não decora linha nenhuma: quem chama já
  # tem os ids e quer comparar em lote. Aqui a lateral não se aplica — o que se corrige é o
  # alcance, restringindo a subconsulta aos ids recebidos em vez de varrer o tenant.
  defp promocoes_vigentes(tenant_id, issue_ids) do
    from p in IssuePromotion,
      where: p.tenant_id == ^tenant_id and p.collected_issue_id in ^issue_ids,
      distinct: p.collected_issue_id,
      order_by: [asc: p.collected_issue_id, desc: p.inserted_at, desc: p.id]
  end
end
