defmodule TheBand.Ingestion.GithubWorkItems do
  @moduledoc """
  Coleta repositórios e issues de uma organização observada (feature 004, F2 e F3).

  ## Por que não é um worker Oban próprio

  Era, e virou fase da sincronização existente. Decisão da pessoa mantenedora:
  **sincronizar traz tudo**.

  Dois workers produziriam dois registros de `sync` para uma única ação de quem opera, e
  a pergunta "o que esta sincronização trouxe" passaria a ter duas respostas parciais.
  Pior: a tela de sincronizações mostraria duas linhas por coleta, e quem lesse
  concluiria que houve duas.

  Uma fase da mesma execução mantém um registro, um relatório, e a ordem garantida —
  pessoas e equipes antes de repositórios e issues, o que importa porque a organização
  precisa existir para o repositório apontar para ela.

  ## A ordem, e ela é a regra

  1. **repositórios** — descobertos a partir da organização, sem exigir conectar cada um;
  2. **issues, por repositório** — e o repositório é o **escopo da marca de ausência**;
  3. **vínculos de decomposição** — depois de todas as issues existirem, porque uma parte
     pode ser coletada depois do pai;
  4. **promoção** — por último, porque ela depende dos vínculos: épico é derivado das
     partes, e classificar antes de conhecê-las daria atômica para tudo.

  Inverter 3 e 4 é o defeito silencioso desta coleta: cada issue funcionaria, e a
  classificação sairia errada em todas as que têm partes.

  ## A marca de ausência é por repositório

  `mark_issues_no_longer_observed/3` é chamada **uma vez por repositório coletado**, com
  o id dele. Chamar por tenant marcaria as issues dos repositórios que esta execução
  nunca olhou — a L19 numa organização de 14 repositórios atingiria 13.

  Repositório excluído pelo tenant ou inacessível **não é coletado e não é marcado**: a
  plataforma parou de olhar, e isso não é o mesmo que o dado ter sumido.
  """
  require Logger

  alias TheBand.Ingestion
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.WorkItems

  @page_size 50
  @tenant_rule "github.issue_type_routing.the_band_solution"

  @doc """
  Coleta repositórios e issues, como fase da sincronização em andamento.

  Recebe o mesmo `ctx` da coleta de EO — tenant, sync, tool e token — e devolve o que
  coletou, para o relatório. **Não** encerra o `sync`: quem encerra é a sincronização,
  uma vez só.
  """
  @spec collect(map()) :: {:ok, map()} | {:error, term()}
  def collect(ctx) do
    run(Map.put_new(ctx, :started_at, ctx.sync.started_at))
  end

  defp run(ctx) do
    with {:ok, organization} <- organizacao(ctx),
         {:ok, repositorios} <- coletar_repositorios(ctx, organization) do
      resultado = Enum.map(repositorios, &coletar_issues(ctx, &1))

      promover(ctx)

      {:ok,
       %{
         organization_id: organization.id,
         repositories: length(repositorios),
         issues: Enum.sum(Enum.map(resultado, & &1.coletadas))
       }}
    end
  end

  # A organização já foi coletada pela ingestão de EO. Aqui ela é só localizada — criar
  # outra faria a mesma organização existir duas vezes.
  defp organizacao(ctx) do
    case EO.fetch_organization_by_login(ctx.tenant.id, ctx.tool.organization_login) do
      nil -> {:error, {:organization_not_found, ctx.tool.organization_login}}
      organization -> {:ok, organization}
    end
  end

  # ------------------------------------------------------------------ repositórios

  defp coletar_repositorios(ctx, organization) do
    with {:ok, nodes} <-
           paginar(ctx, "repositories", %{organization: ctx.tool.organization_login}) do
      repositorios =
        Enum.map(nodes, fn node ->
          {:ok, repo} = gravar_repositorio(ctx, organization, node)
          {:ok, observado} = CMPO.observe_repository(ctx.tenant, ctx.tool.id, repo.id)
          ctx.sync |> Ingestion.reload() |> Ingestion.tally(:unchanged)
          %{repo: repo, observed_repository_id: observado.id, node: node}
        end)

      # Checkpoint **depois** de processar, nunca antes — e é o que a tela lê para dizer
      # em que fase a coleta está. Sem ele, o progresso seria um spinner sem informação.
      Ingestion.checkpoint_page(ctx.sync, "github.repository", nil, length(nodes))
      Ingestion.broadcast(ctx.tenant.id, {:sync_progress, ctx.sync.id, "github.repository"})

      # Só os coletáveis seguem: excluído e inacessível ficam de fora, e nenhum dos dois
      # tem a ausência marcada por causa disso.
      coletaveis =
        ctx.tenant
        |> CMPO.list_collectable(ctx.tool.id)
        |> MapSet.new(& &1.observed_repository_id)

      {:ok, Enum.filter(repositorios, &MapSet.member?(coletaveis, &1.observed_repository_id))}
    end
  end

  defp gravar_repositorio(ctx, organization, node) do
    now = DateTime.utc_now(:second)

    RawData.store(%{
      tenant_id: ctx.tenant.id,
      sync_id: ctx.sync.id,
      raw_entity_type: "github.repository",
      external_id: node["id"],
      payload: node,
      mapping_id: "github.repository.to.cmpo.source_repository",
      mapping_version: 3,
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      collected_at: now
    })

    CMPO.upsert_source_repository_from_source(ctx.tenant, %{
      organization_id: organization.id,
      name: node["name"],
      qualified_name: node["nameWithOwner"],
      url: node["url"],
      description: node["description"],
      primary_language: get_in(node, ["primaryLanguage", "name"]),
      default_branch: get_in(node, ["defaultBranchRef", "name"]),
      archived_at: parse_datetime(node["archivedAt"]),
      external_created_at: parse_datetime(node["createdAt"]),
      last_pushed_at: parse_datetime(node["pushedAt"]),
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      external_id: node["id"]
    })
  end

  # ------------------------------------------------------------------------ issues

  defp coletar_issues(ctx, %{repo: repo, observed_repository_id: observado_id, node: node}) do
    [owner, name] = String.split(node["nameWithOwner"], "/", parts: 2)

    case paginar(ctx, "issues", %{owner: owner, name: name}) do
      {:ok, nodes} ->
        gravadas = Enum.map(nodes, &gravar_issue(ctx, observado_id, &1))
        vincular(ctx, nodes)

        Ingestion.checkpoint_page(ctx.sync, "github.issue", nil, length(nodes))

        # A tela recebe o nome do repositório: "coletando issues" sem dizer de qual, numa
        # organização de 121 repositórios, não informa nada.
        Ingestion.broadcast(
          ctx.tenant.id,
          {:sync_progress, ctx.sync.id, "github.issue:#{repo.name}"}
        )

        # Por repositório, e é a L19 impedida: só o que foi olhado é marcado.
        {:ok, _} =
          WorkItems.mark_issues_no_longer_observed(ctx.tenant, observado_id, ctx.started_at)

        %{repositorio: repo.name, coletadas: length(gravadas)}

      {:error, reason} ->
        # Perder alcance não é o dado ter sumido: marca a ferramenta e NÃO marca as
        # issues (FR-006).
        {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, observado_id, Client.describe_error(reason))
        Logger.warning("repositório inacessível: #{repo.name}")
        %{repositorio: repo.name, coletadas: 0}
    end
  end

  defp gravar_issue(ctx, observado_id, node) do
    now = DateTime.utc_now(:second)

    RawData.store(%{
      tenant_id: ctx.tenant.id,
      sync_id: ctx.sync.id,
      raw_entity_type: "github.issue",
      external_id: node["id"],
      payload: node,
      mapping_id: "github.issue.user_story.to.sro.atomic_user_story",
      mapping_version: 2,
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      collected_at: now
    })

    ctx.sync |> Ingestion.reload() |> Ingestion.tally(:unchanged)

    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: observado_id,
        number: node["number"],
        title: node["title"],
        state: node["state"],
        issue_type: get_in(node, ["issueType", "name"]),
        issue_type_external_id: get_in(node, ["issueType", "id"]),
        external_parent_id: get_in(node, ["parent", "id"]),
        sub_issue_count: get_in(node, ["subIssues", "totalCount"]) || 0,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        external_id: node["id"],
        external_created_at: parse_datetime(node["createdAt"])
      })

    issue
  end

  # ---------------------------------------------------------------------- vínculos

  # Depois de todas as issues existirem: uma parte pode ser coletada depois do pai, e
  # ligar durante a paginação perderia os vínculos das partes ainda não gravadas.
  defp vincular(ctx, nodes) do
    # Por `external_id`, e **não** por `number`. O número é único dentro do repositório,
    # e esta organização tem 14 — dois repositórios têm issue #1. Chavear por número
    # ligou partes de um repositório ao pai de outro, e o efeito foi silencioso: a
    # classificação saiu errada em vez de dar erro.
    #
    # É a mesma lição que `collected_issues` já carrega no índice único, e eu a violei
    # no código de ligação.
    por_externo = Map.new(WorkItems.list_by_external_id(ctx.tenant), &{&1.external_id, &1.id})

    for node <- nodes,
        parte <- get_in(node, ["subIssues", "nodes"]) || [] do
      pai_id = por_externo[node["id"]]
      parte_id = por_externo[parte["id"]]

      cond do
        is_nil(pai_id) ->
          :ignora

        is_nil(parte_id) ->
          # Parte fora do escopo observado: a relação existe e é registrada; a parte não
          # é promovida (FR-018).
          WorkItems.recusar(ctx.tenant, %{
            parent_issue_id: pai_id,
            child_external_id: parte["id"],
            reason: "out_of_scope"
          })

        true ->
          WorkItems.record_decomposition_link(ctx.tenant, %{
            parent_issue_id: pai_id,
            child_issue_id: parte_id
          })
      end
    end
  end

  # ---------------------------------------------------------------------- promoção

  # Por último, porque a classificação épico/atômica depende dos vínculos já gravados.
  defp promover(ctx) do
    issues = WorkItems.list_issues(ctx.tenant, limit: 100_000)
    tipos_das_partes = tipos_das_partes(ctx, issues)

    Ingestion.checkpoint_page(ctx.sync, "promocao", nil, length(issues))
    Ingestion.broadcast(ctx.tenant.id, {:sync_progress, ctx.sync.id, "promocao"})

    for issue <- issues do
      decisao =
        WorkItems.decide(
          %{
            issue_type: issue.issue_type,
            sub_issue_types: Map.get(tipos_das_partes, issue.id, [])
          },
          tenant_rule_id: @tenant_rule
        )

      WorkItems.record_promotion(ctx.tenant, %{
        collected_issue_id: issue.id,
        declared_concept: decisao.declared,
        derived_concept: decisao.derived,
        divergence_reason: decisao.divergence,
        skip_reason: decisao.skip_reason,
        skip_detail: decisao.skip_detail,
        rule_id: decisao.rule_id,
        rule_version: decisao.rule_version
      })
    end
  end

  defp tipos_das_partes(ctx, issues) do
    por_id = Map.new(issues, &{&1.id, &1.issue_type})
    _ = ctx

    ctx.tenant
    |> WorkItems.list_links()
    |> Enum.group_by(& &1.parent_issue_id, &por_id[&1.child_issue_id])
  end

  # ----------------------------------------------------------------------- comuns

  defp paginar(ctx, query_name, variables, cursor \\ nil, acumulado \\ []) do
    vars = Map.merge(variables, %{page_size: @page_size, after: cursor})

    case Client.graphql(ctx.tool.instance_url, ctx.token, read_query(query_name), vars) do
      # O cliente devolve o ENVELOPE — `%{data: ..., rate_limit: ...}` —, e não o `data`
      # direto. Casar com `{:ok, data}` compilava, rodava, e devolvia lista vazia sem
      # erro: o job completava com zero coletados. Foi o que aconteceu na primeira
      # execução contra o dado real.
      {:ok, %{data: data}} ->
        {nodes, page_info} = extrair(data, query_name)
        acumulado = acumulado ++ nodes

        if page_info["hasNextPage"],
          do: paginar(ctx, query_name, variables, page_info["endCursor"], acumulado),
          else: {:ok, acumulado}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extrair(data, "repositories") do
    repos = get_in(data, ["organization", "repositories"]) || %{}
    {repos["nodes"] || [], repos["pageInfo"] || %{}}
  end

  defp extrair(data, "issues") do
    issues = get_in(data, ["repository", "issues"]) || %{}
    {issues["nodes"] || [], issues["pageInfo"] || %{}}
  end

  defp read_query(name) do
    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{name}.graphql")
    |> File.read!()
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
