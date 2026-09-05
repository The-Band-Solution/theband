defmodule TheBand.Ingestion.GithubCommitFiles do
  @moduledoc """
  Coleta os arquivos que cada commit tocou — feature 035, `cmpo.artifact_copy`.

  ## Todos os commits, e a limitação que existia era nossa

  A primeira versão coletava só dos commits de solicitações com vínculo a issue — 3.558
  de 16.416 —, e a tela ia declarar "não coletado" para o resto. **Mas a limitação era
  nossa, não da origem**: a REST entrega os arquivos de qualquer commit; o que faltava
  era esperar a janela de rate limit.

  É a mesma lição que a paginação dos commits ensinou na 032: quando a tela vai declarar
  uma limitação que dá para remover, o certo é remover a limitação.

  Então percorre-se **todos**. O rate limit é de 5.000 requisições por hora e são 16.416
  commits: a coleta **pausa até a janela reabrir** em vez de desistir, e o checkpoint por
  commit (`files_collected_at`) faz cada execução continuar de onde a anterior parou.
  """

  require Logger

  alias TheBand.Changes.Commands
  alias TheBand.Ingestion.Janela
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Repo

  import Ecto.Query

  @doc """
  Coleta os arquivos dos commits ainda não percorridos.

  `limit` existe para quem quiser uma fatia (a fase de sincronização usa, para não
  prender a coleta inteira numa espera de rate limit). Sem ele, percorre **todos** os
  pendentes, pausando quando a janela esgota.
  """
  @spec collect(map(), keyword()) :: {:ok, map()}
  def collect(ctx, opts \\ []) do
    limite = Keyword.get(opts, :limit)
    pendentes = commits_pendentes(ctx.tenant.id, ctx.tool.id, limite)

    # PARA na janela fechada, e não dorme (ADR 0007): antes, esta etapa era a única que
    # segurava o processo com `Process.sleep` até o reset. A espera agora é do Oban, como
    # nas outras etapas — e os commits que ficaram continuam pendentes para a retomada.
    case Janela.ate_fechar(pendentes, &coletar_commit(ctx, &1)) do
      {:sem_janela, reset} ->
        {:snooze, Janela.segundos_ate(reset)}

      resultados ->
        {:ok,
         %{
           commits_visited: length(pendentes),
           files: Enum.sum(Enum.map(resultados, & &1.arquivos)),
           gone_from_source: Enum.count(resultados, &(&1.estado == :gone)),
           unreachable: Enum.count(resultados, &(&1.estado == :error))
         }}
    end
  end

  # Cada commit ainda não percorrido — sem filtro por vínculo com issue. A ordem é
  # do mais recente: se a execução for interrompida, o que ficou de fora é o mais antigo,
  # que é o menos consultado.
  # **Filtra pela FERRAMENTA** — issue #446. Aqui a junção já passa por
  # `observed_repositories`, e faltava só usar a coluna que ela traz.
  #
  # O caso desta fase é o mais direto de todos: ela chama a REST com
  # `ctx.tool.instance_url` e `ctx.token` para o `qualified_name` do repositório. Sem o
  # filtro, a credencial de uma organização pedia o commit de outra — e o 404 resultante
  # marcava o commit como percorrido sem arquivo nenhum.
  defp commits_pendentes(tenant_id, tool_id, limite) do
    consulta =
      from c in "collected_commits",
        join: o in "observed_repositories",
        on: o.id == c.observed_repository_id,
        join: f in "cmpo_source_repositories",
        on: f.id == o.source_repository_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            o.connected_tool_id == type(^tool_id, :binary_id) and
            is_nil(c.no_longer_observed_at) and is_nil(c.files_collected_at),
        order_by: [desc: c.external_committed_at],
        select: %{
          id: type(c.id, :binary_id),
          sha: c.sha,
          repositorio: f.qualified_name
        }

    consulta = if limite, do: from(c in consulta, limit: ^limite), else: consulta
    Repo.all(consulta)
  end

  defp coletar_commit(ctx, commit) do
    case Client.commit_files(ctx.tool.instance_url, ctx.token, commit.repositorio, commit.sha,
           cota: ctx[:cota]
         ) do
      {:ok, arquivos} ->
        :ok =
          Commands.replace_commit_files(ctx.tenant, commit.id, Enum.map(arquivos, &traduzir/1))

        %{estado: :ok, arquivos: length(arquivos)}

      # Force-push reescreve história: o commit que a plataforma coletou pode não existir
      # mais na origem. É fato sobre o repositório, e marcar o checkpoint evita tentar de
      # novo para sempre.
      {:error, :not_found_at_source} ->
        :ok = Commands.replace_commit_files(ctx.tenant, commit.id, [])
        %{estado: :gone, arquivos: 0}

      # **Rate limit esgotado não é falha: é a janela.** O commit fica pendente
      # (`files_collected_at` nulo) e a retomada o traz.
      {:error, {:rate_limited, reset}} ->
        %{estado: :sem_janela, sem_janela: true, reset: reset, arquivos: 0}

      {:error, motivo} ->
        Logger.warning("arquivos de #{commit.sha} não coletados: #{inspect(motivo)}")
        %{estado: :error, arquivos: 0}
    end
  end

  defp traduzir(arquivo) do
    %{
      path: arquivo["filename"],
      change: arquivo["status"],
      additions: arquivo["additions"],
      deletions: arquivo["deletions"],
      previous_path: arquivo["previous_filename"]
    }
  end
end
