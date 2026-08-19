defmodule TheBand.Ingestion.GithubChangeRequests do
  @moduledoc """
  Coleta as solicitações de mudança e os commits delas — feature 032, fase da MESMA
  sincronização.

  Instancia `cmpo.change_request` e `cmpo.commit_artifact_copy`, e materializa as
  participações declaradas em `cmpo.change_traceability` (quem submeteu, quem integrou,
  quem executou) e o atendimento de `sro.scope_traceability`.

  ## O incremental para cedo, e é assim porque a origem obriga

  `pullRequests` não aceita filtro por data — ao contrário de `issues`. A ordenação é
  `UPDATED_AT` decrescente e a paginação **encerra no primeiro PR mais antigo que o
  checkpoint** do repositório. Sem isso, cada passada percorreria centenas de PRs por
  repositório, em 121 repositórios.

  ## Commits vêm pelo PR, e o que fica de fora está dito

  Coletar a história inteira de cada repositório multiplicaria o volume; pelo PR, o
  rastro se mantém. **Commit fora de solicitação não é alcançado** — e a relação
  declarada tem `zero_or_one` no destino justamente para representá-lo quando for.
  """

  require Logger

  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  alias TheBand.Changes.Commands
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo

  import Ecto.Query

  @page_size 25

  @doc """
  Coleta, repositório a repositório. Mesmo `ctx` das demais fases.

  Nunca devolve erro: falha num repositório vira `unreachable` no resumo e log — os
  demais seguem, e a próxima coleta tenta de novo (L29).
  """
  @spec collect(map()) :: {:ok, map()}
  def collect(ctx) do
    ctx = Map.put(ctx, :pessoas, EO.person_ids_by_login(ctx.tenant))
    repositorios = repositorios_observados(ctx.tenant.id)

    resultados = Enum.map(repositorios, &coletar_repositorio(ctx, &1))

    {:ok,
     %{
       repositories: length(repositorios),
       change_requests: soma(resultados, :solicitacoes),
       commits: soma(resultados, :commits),
       attended_issues: soma(resultados, :atendidas),
       # **Nunca zero disfarçando "acabou".** É quanto a origem reconheceu e a plataforma
       # não conseguiu resolver porque a issue ainda não foi coletada — o número que a
       # versão anterior descartava em silêncio (issue #438).
       attended_issues_pending: soma(resultados, :pendentes),
       truncated: soma(resultados, :truncadas),
       unreachable: Enum.count(resultados, &(&1.alcancado == false))
     }}
  end

  defp soma(resultados, chave), do: Enum.sum(Enum.map(resultados, &Map.get(&1, chave, 0)))

  defp repositorios_observados(tenant_id) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where: r.tenant_id == type(^tenant_id, :binary_id) and is_nil(r.excluded_at),
        select: %{
          id: type(r.id, :binary_id),
          qualified_name: f.qualified_name,
          changes_collected_at: r.changes_collected_at
        }
    )
  end

  defp coletar_repositorio(ctx, repo) do
    [owner, name] = String.split(repo.qualified_name, "/", parts: 2)

    corte =
      repo.changes_collected_at && DateTime.from_naive!(repo.changes_collected_at, "Etc/UTC")

    inicio = DateTime.utc_now(:second)

    ctx = Map.merge(ctx, %{owner: owner, name: name})

    case paginar(ctx, %{owner: owner, name: name}, corte) do
      {:ok, solicitacoes} ->
        resultado = gravar(ctx, repo.id, solicitacoes)
        marcar_percorrido(repo.id, inicio)
        Map.put(resultado, :alcancado, true)

      {:error, motivo} ->
        Logger.warning("mudanças de #{repo.qualified_name} não coletadas: #{inspect(motivo)}")
        %{alcancado: false, solicitacoes: 0, commits: 0, atendidas: 0, pendentes: 0, truncadas: 0}
    end
  end

  defp gravar(ctx, repo_id, solicitacoes) do
    Enum.reduce(
      solicitacoes,
      %{solicitacoes: 0, commits: 0, atendidas: 0, pendentes: 0, truncadas: 0},
      fn node, acc ->
        somar(acc, gravar_solicitacao(ctx, repo_id, node))
      end
    )
  end

  defp gravar_solicitacao(ctx, repo_id, node) do
    commits_nodes = get_in(node, ["commits", "nodes"]) || []

    {:ok, solicitacao} =
      Commands.record_change_request(ctx.tenant, %{
        observed_repository_id: repo_id,
        number: node["number"],
        title: node["title"],
        body: node["bodyText"],
        state: node["state"],
        source_branch: node["headRefName"],
        target_branch: node["baseRefName"],
        changed_files: node["changedFiles"],
        commits_total: get_in(node, ["commits", "totalCount"]),
        commits_collected: length(commits_nodes),
        author_login: get_in(node, ["author", "login"]),
        author_person_id: ctx.pessoas[get_in(node, ["author", "login"])],
        merged_by_login: get_in(node, ["mergedBy", "login"]),
        merged_by_person_id: ctx.pessoas[get_in(node, ["mergedBy", "login"])],
        external_created_at: data(node["createdAt"]),
        external_merged_at: data(node["mergedAt"]),
        external_closed_at: data(node["closedAt"]),
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        external_id: node["id"],
        raw_payload: node
      })

    atendidas = vincular_issues(ctx, solicitacao.id, node)
    :ok = Commands.record_attended_provenance(ctx.tenant, solicitacao.id, atendidas)
    {commits, truncado} = gravar_commits(ctx, repo_id, solicitacao.id, node)

    %{
      solicitacoes: 1,
      commits: commits,
      atendidas: atendidas.resolvidas,
      # Nunca zero disfarçando "acabou": é o que diz que há vínculo esperando issue.
      pendentes: length(atendidas.pendentes),
      truncadas: truncado
    }
  end

  # O vínculo é o que a ORIGEM reconheceu — `closingIssuesReferences`, nunca o texto.
  #
  # **O que não resolve fica registrado, e isso é o conserto da issue #438.** A versão
  # anterior gravava só o que casou com uma issue já coletada e devolvia `map_size(ids)` —
  # o que casou, nunca o que a origem disse. A diferença entre os dois é o buraco, e ela
  # não ia para lugar nenhum: um painel chegou a mostrar "83% das solicitações sem issue"
  # quando dois de cada três amostrados fechavam issue sim.
  #
  # A causa é de ordem, não de modelo: a coleta de issues fica atrás da de solicitações, e
  # a solicitação já mergeada não volta a ser percorrida. Guardar os identificadores
  # externos pendentes é o que permite resolvê-los depois **sem tocar na API**.
  defp vincular_issues(ctx, solicitacao_id, node) do
    externos = Enum.map(get_in(node, ["closingIssuesReferences", "nodes"]) || [], & &1["id"])
    ids = issue_ids_por_external(ctx.tenant.id, externos)

    :ok = Commands.replace_attended_issues(ctx.tenant, solicitacao_id, Map.values(ids))

    %{
      resolvidas: map_size(ids),
      # O total da ORIGEM, e não o tamanho da lista que chegou: `closingIssuesReferences`
      # pagina, e `totalCount` é o único número que revela truncamento da própria consulta.
      total: get_in(node, ["closingIssuesReferences", "totalCount"]) || length(externos),
      pendentes: Enum.reject(externos, &Map.has_key?(ids, &1))
    }
  end

  defp gravar_commits(ctx, repo_id, solicitacao_id, node) do
    primeira = get_in(node, ["commits", "nodes"]) || []
    total = get_in(node, ["commits", "totalCount"]) || 0
    info = get_in(node, ["commits", "pageInfo"]) || %{}

    # **Pagina os restantes em vez de declarar limitação.** A API permite, então "não
    # coletado" seria buraco nosso. Só os PRs truncados pagam a consulta extra — 509 das
    # 5.032 na primeira coleta real.
    nodes = primeira ++ restantes(ctx, node, info)

    Enum.each(nodes, fn %{"commit" => c} ->
      {:ok, commit} =
        Commands.record_commit(ctx.tenant, %{
          observed_repository_id: repo_id,
          change_request_id: solicitacao_id,
          sha: c["oid"],
          message_headline: c["messageHeadline"],
          message_body: c["messageBody"],
          additions: c["additions"],
          deletions: c["deletions"],
          changed_files: c["changedFilesIfAvailable"],
          external_committed_at: data(c["committedDate"]),
          source_system: "github",
          source_instance: ctx.tool.instance_url,
          external_id: c["oid"],
          raw_payload: c
        })

      :ok = Commands.replace_commit_authors(ctx.tenant, commit.id, autores(ctx, c))
    end)

    {length(nodes), if(length(nodes) >= total, do: 0, else: 1)}
  end

  # As páginas seguintes de commits de um PR. Falhar aqui não perde o que já veio: o
  # truncamento fica registrado, e a próxima coleta tenta de novo.
  defp restantes(ctx, node, %{"hasNextPage" => true, "endCursor" => cursor}) do
    paginar_commits(ctx, node, cursor, [])
  end

  defp restantes(_ctx, _node, _info), do: []

  defp paginar_commits(ctx, node, cursor, acumulado) do
    vars = %{
      owner: ctx.owner,
      name: ctx.name,
      number: node["number"],
      commit_size: 100,
      after: cursor
    }

    case Client.graphql(
           ctx.tool.instance_url,
           ctx.token,
           read_query("pull_request_commits"),
           vars
         ) do
      {:ok, %{data: data}} ->
        commits = get_in(data, ["repository", "pullRequest", "commits"]) || %{}
        nodes = commits["nodes"] || []
        info = commits["pageInfo"] || %{}
        acumulado = acumulado ++ nodes

        if info["hasNextPage"],
          do: paginar_commits(ctx, node, info["endCursor"], acumulado),
          else: acumulado

      {:error, motivo} ->
        Logger.warning(
          "commits restantes do PR ##{node["number"]} não coletados: #{inspect(motivo)}"
        )

        acumulado
    end
  end

  # `authors` no plural: o primeiro é o autor que o Git registra, os demais vêm do
  # trailer Co-Authored-By. `is_primary` guarda a distinção.
  defp autores(ctx, commit) do
    commit
    |> get_in(["authors", "nodes"])
    |> Kernel.||([])
    |> Enum.with_index()
    |> Enum.map(fn {autor, i} ->
      login = get_in(autor, ["user", "login"])

      %{
        author_login: login,
        author_person_id: ctx.pessoas[login],
        author_name: autor["name"],
        author_email: autor["email"],
        is_primary: i == 0
      }
    end)
  end

  defp issue_ids_por_external(_tenant_id, []), do: %{}

  defp issue_ids_por_external(tenant_id, externos) do
    Repo.all(
      from i in "collected_issues",
        where: i.tenant_id == type(^tenant_id, :binary_id) and i.external_id in ^externos,
        select: {i.external_id, type(i.id, :binary_id)}
    )
    |> Map.new()
  end

  defp marcar_percorrido(repo_id, inicio) do
    Repo.update_all(
      from(r in "observed_repositories", where: r.id == type(^repo_id, :binary_id)),
      set: [changes_collected_at: inicio]
    )
  end

  defp somar(a, b) do
    Map.merge(a, b, fn _k, x, y -> x + y end)
  end

  # A paginação para no primeiro PR mais antigo que o checkpoint: `pullRequests` não
  # aceita filtro por data, e parar cedo é o equivalente.
  defp paginar(ctx, variables, corte, cursor \\ nil, acumulado \\ []) do
    vars = Map.merge(variables, %{page_size: @page_size, after: cursor})

    case Client.graphql(ctx.tool.instance_url, ctx.token, read_query("change_requests"), vars) do
      # O ENVELOPE, nunca `{:ok, data}` direto — L26.
      {:ok, %{data: data}} ->
        prs = get_in(data, ["repository", "pullRequests"]) || %{}
        nodes = prs["nodes"] || []
        page_info = prs["pageInfo"] || %{}

        {novos, parou?} = ate_o_corte(nodes, corte)
        acumulado = acumulado ++ novos

        if page_info["hasNextPage"] and not parou?,
          do: paginar(ctx, variables, corte, page_info["endCursor"], acumulado),
          else: {:ok, acumulado}

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  defp ate_o_corte(nodes, nil), do: {nodes, false}

  defp ate_o_corte(nodes, corte) do
    novos = Enum.take_while(nodes, &atualizado_depois?(&1, corte))
    {novos, length(novos) < length(nodes)}
  end

  defp atualizado_depois?(node, corte) do
    case data(node["updatedAt"]) do
      nil -> true
      quando -> DateTime.compare(quando, corte) == :gt
    end
  end

  # O nome vem de literal do próprio código, nunca de entrada externa.
  @sobelow_skip ["Traversal.FileModule"]
  defp read_query(nome) do
    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{nome}.graphql")
    |> File.read!()
  end

  defp data(nil), do: nil

  defp data(texto) do
    case DateTime.from_iso8601(texto) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
