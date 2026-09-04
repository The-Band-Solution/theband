defmodule TheBand.Ingestion.GithubIssueComments do
  @moduledoc """
  Coleta os comentários das issues — feature 030, fase da mesma sincronização.

  Instancia `cmo.comment` pelo mapeamento `github.issue_comment.to.cmo.comment`. Roda
  DEPOIS da fase de issues, e lê as issues da BASE, não da memória da fase anterior
  (L47): issue nova com comentário entra na mesma passada.

  ## O incremental tem dois filtros, e os dois são da origem

  `filterBy.since` na consulta traz só issues ATUALIZADAS desde a última passada
  (`comments_collected_at` do repositório observado), e `comments.totalCount == 0` pula
  a issue sem conversa — 77% delas, medido em 2026-08-14.

  ## Truncamento nunca é silêncio

  `totalCount` de cada issue é conferido contra o que chegou. Página incompleta:
  a issue entra em `truncated` no relatório e o sumiço NÃO é marcado nela — marcar com
  página parcial afirmaria ausência que é só paginação.
  """

  require Logger

  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  alias TheBand.Communication.Commands
  alias TheBand.Ingestion.QueryVersion
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo

  import Ecto.Query

  @page_size 25

  @doc """
  Coleta os comentários, repositório a repositório. Mesmo `ctx` das demais fases.

  Nunca devolve erro: falha num repositório vira `unreachable` no resumo e log — os
  demais seguem, e a próxima coleta tenta de novo (L29).
  """
  @spec collect(map()) :: {:ok, map()}
  def collect(ctx) do
    ctx = Map.put(ctx, :pessoas, EO.person_ids_by_login(ctx.tenant))
    repositorios = repositorios_observados(ctx.tenant.id, ctx.tool.id)

    resultados = Enum.map(repositorios, &coletar_repositorio(ctx, &1))

    {:ok,
     %{
       repositories: length(repositorios),
       comments: Enum.sum(Enum.map(resultados, & &1.coletados)),
       issues_visited: Enum.sum(Enum.map(resultados, & &1.issues)),
       marked_unobserved: Enum.sum(Enum.map(resultados, & &1.marcados)),
       truncated: Enum.sum(Enum.map(resultados, & &1.truncadas)),
       unreachable: Enum.count(resultados, &(&1.alcancado == false))
     }}
  end

  # **Filtra pela FERRAMENTA, não só pelo tenant** — issue #446.
  #
  # Um tenant pode ter mais de uma organização conectada, e o dado sempre soube de quem é
  # cada repositório: `observed_repositories.connected_tool_id` é gravado por
  # `GithubWorkItems` na hora de observar. As fases seguintes ignoravam a coluna e
  # percorriam o tenant inteiro.
  #
  # Medido em 2026-08-19: 3 ferramentas com 121, 25 e 14 repositórios: sincronizar as três
  # percorria 480 em vez de 160, concorrentemente, **e cada uma usava a própria credencial
  # para repositórios das outras duas**. Onde a credencial errada recebia 404, a fase
  # marcava o repositório como percorrido e vazio — ausência de ACESSO lida como ausência
  # de dado, que é a confusão que a casa mais combate.
  defp repositorios_observados(tenant_id, tool_id) do
    # owner/name vêm do repositório-fonte (qualified_name = "owner/name"); a marca de
    # exclusão da observação é excluded_at — exclusão é decisão de quem administra.
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where:
          r.tenant_id == type(^tenant_id, :binary_id) and
            r.connected_tool_id == type(^tool_id, :binary_id) and is_nil(r.excluded_at),
        select: %{
          id: type(r.id, :binary_id),
          qualified_name: f.qualified_name,
          comments_collected_at: r.comments_collected_at,
          query_versions: r.query_versions
        }
    )
  end

  defp coletar_repositorio(ctx, repo) do
    # Issue #452, mesmo motivo que em `GithubChangeRequests`: a consulta que mudou não é a
    # mesma consulta, e o corte não sabe disso sozinho.
    since =
      if QueryVersion.corte_vale?(repo.query_versions, "comments"),
        do:
          repo.comments_collected_at &&
            DateTime.from_naive!(repo.comments_collected_at, "Etc/UTC"),
        else: nil

    inicio = DateTime.utc_now(:second)

    [owner, name] = String.split(repo.qualified_name, "/", parts: 2)

    case paginar(ctx, %{owner: owner, name: name, since: since}) do
      {:ok, issues} ->
        resultado = gravar_issues(ctx, issues)

        # Gravado só quando o repositório foi percorrido POR INTEIRO — é o que o
        # incremental da próxima passada assume, e é o que decide a frase do vazio
        # na tela ("não coletada" × "sem comentários").
        marcar_percorrido(repo.id, inicio, repo.query_versions)

        Map.merge(%{alcancado: true, issues: length(issues)}, resultado)

      {:error, reason} ->
        # Falha transitória não marca estado permanente (L29): sem checkpoint, a
        # próxima coleta percorre de novo. O motivo vai para o log, não para o dado.
        # `qualified_name` já é "owner/name", e é o único nome que este map carrega —
        # `repo.owner` levantava `KeyError` **dentro do tratamento da falha**, e o job
        # inteiro morria. Encontrado na primeira coleta real, em 2026-09-04: cinco
        # tentativas, `discarded`, e com ele foram embora as etapas seguintes do sync.
        #
        # O caminho feliz nunca tocou nesta linha. Só se chega aqui quando a origem
        # falha — e era exatamente aí que a falha transitória virava permanente.
        Logger.warning("comentários de #{repo.qualified_name} não coletados: #{inspect(reason)}")

        %{alcancado: false, issues: 0, coletados: 0, marcados: 0, truncadas: 0}
    end
  end

  defp gravar_issues(ctx, issues) do
    issue_ids = ids_por_external_id(ctx.tenant.id, Enum.map(issues, & &1["id"]))

    Enum.reduce(issues, %{coletados: 0, marcados: 0, truncadas: 0}, fn issue, acc ->
      somar(acc, gravar_issue(ctx, issue, issue_ids[issue["id"]]))
    end)
  end

  # Issue sem conversa (`totalCount: 0`) ou que a fase de issues ainda não gravou não
  # produz nada — e não produzir nada é resposta, não erro.
  defp gravar_issue(_ctx, _issue, nil), do: %{coletados: 0, marcados: 0, truncadas: 0}

  defp gravar_issue(ctx, issue, collected_issue_id) do
    comments = get_in(issue, ["comments", "nodes"]) || []
    total = get_in(issue, ["comments", "totalCount"]) || 0

    if total == 0 do
      %{coletados: 0, marcados: 0, truncadas: 0}
    else
      Enum.each(comments, &gravar_comentario(ctx, collected_issue_id, &1))
      completa? = length(comments) >= total

      %{
        coletados: length(comments),
        marcados: marcar_sumidos(ctx, collected_issue_id, comments, completa?),
        truncadas: if(completa?, do: 0, else: 1)
      }
    end
  end

  # Com página incompleta, NÃO marcar é a resposta honesta: marcar afirmaria ausência
  # que é só paginação.
  defp marcar_sumidos(_ctx, _issue_id, _comments, false), do: 0

  defp marcar_sumidos(ctx, issue_id, comments, true) do
    Commands.mark_unobserved_comments(ctx.tenant, issue_id, Enum.map(comments, & &1["id"]))
  end

  defp somar(a, b) do
    %{
      coletados: a.coletados + b.coletados,
      marcados: a.marcados + b.marcados,
      truncadas: a.truncadas + b.truncadas
    }
  end

  defp gravar_comentario(ctx, collected_issue_id, node) do
    {:ok, _} =
      Commands.record_comment(ctx.tenant, %{
        collected_issue_id: collected_issue_id,
        body: node["bodyText"],
        # Autor nulo é o "ghost" do GitHub — conta apagada. O comentário fica; o login
        # fica nulo; a regra dos designados já cobre login sem pessoa.
        author_login: get_in(node, ["author", "login"]),
        author_person_id: ctx.pessoas[get_in(node, ["author", "login"])],
        external_published_at: parse_datetime(node["createdAt"]),
        external_edited_at: parse_datetime(node["lastEditedAt"]),
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        external_id: node["id"],
        raw_payload: node
      })
  end

  # As issues coletadas deste lote, external_id → id interno, numa consulta só.
  defp ids_por_external_id(_tenant_id, []), do: %{}

  defp ids_por_external_id(tenant_id, external_ids) do
    Repo.all(
      from i in "collected_issues",
        where: i.tenant_id == type(^tenant_id, :binary_id) and i.external_id in ^external_ids,
        select: {i.external_id, type(i.id, :binary_id)}
    )
    |> Map.new()
  end

  defp marcar_percorrido(repo_id, inicio, versoes) do
    Repo.update_all(
      from(r in "observed_repositories", where: r.id == type(^repo_id, :binary_id)),
      set: [
        comments_collected_at: inicio,
        query_versions: QueryVersion.marcar(versoes, "comments")
      ]
    )
  end

  defp paginar(ctx, variables, cursor \\ nil, acumulado \\ []) do
    vars = Map.merge(variables, %{page_size: @page_size, after: cursor})

    case Client.graphql(ctx.tool.instance_url, ctx.token, read_query(), vars) do
      # O ENVELOPE, nunca `{:ok, data}` direto — L26: casar largo devolvia lista vazia
      # sem erro, e o job completava com zero coletados.
      {:ok, %{data: data}} ->
        issues = get_in(data, ["repository", "issues"]) || %{}
        nodes = issues["nodes"] || []
        page_info = issues["pageInfo"] || %{}
        acumulado = acumulado ++ nodes

        if page_info["hasNextPage"],
          do: paginar(ctx, variables, page_info["endCursor"], acumulado),
          else: {:ok, acumulado}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Literal do próprio código, nunca entrada externa — mesma anotação das demais fases.
  @sobelow_skip ["Traversal.FileModule"]
  defp read_query do
    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/issue_comments.graphql")
    |> File.read!()
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(texto) do
    case DateTime.from_iso8601(texto) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
