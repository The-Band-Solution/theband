defmodule TheBand.Ingestion.GithubCommitFiles do
  @moduledoc """
  Coleta os arquivos que cada commit tocou — feature 035, `cmpo.artifact_copy`.

  ## O escopo foi medido, não escolhido por gosto

  Medido em 2026-08-18: são **16.416 commits** coletados, a lista de arquivos só existe
  na REST (uma requisição por commit) e o rate limit é de **5.000 por hora**. Coletar
  todos custaria mais de três horas só esperando a janela.

  Coleta-se dos commits de solicitações **com vínculo a issue** — 3.558 —, e a razão não
  é só custo: é onde a pergunta que os arquivos destravam tem resposta. *"Quem mexeu
  neste arquivo, e por qual issue?"* — sem issue no fim da cadeia, o arquivo não responde
  nada que o commit já não respondesse.

  Os demais ficam com a contagem que já temos (`changed_files`) e a ausência declarada na
  tela — nunca com zero.
  """

  require Logger

  alias TheBand.Changes.Commands
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Repo

  import Ecto.Query

  @doc """
  Coleta os arquivos dos commits ainda não percorridos.

  `limite` protege a janela de rate limit: a fase para no número pedido e a próxima
  sincronização continua de onde parou — `files_collected_at` é o checkpoint.
  """
  @spec collect(map(), keyword()) :: {:ok, map()}
  def collect(ctx, opts \\ []) do
    limite = Keyword.get(opts, :limit, 1_000)
    pendentes = commits_pendentes(ctx.tenant.id, limite)

    resultados = Enum.map(pendentes, &coletar_commit(ctx, &1))

    {:ok,
     %{
       commits_visited: length(pendentes),
       files: Enum.sum(Enum.map(resultados, &elem(&1, 1))),
       gone_from_source: Enum.count(resultados, &(elem(&1, 0) == :gone)),
       unreachable: Enum.count(resultados, &(elem(&1, 0) == :error))
     }}
  end

  # Os commits de solicitações COM vínculo a issue, que ainda não tiveram arquivos
  # percorridos. A ordem é do mais recente: se a janela acabar, o que ficou de fora é o
  # mais antigo — e é o menos consultado.
  defp commits_pendentes(tenant_id, limite) do
    Repo.all(
      from c in "collected_commits",
        join: cr in "collected_change_requests",
        on: cr.id == c.change_request_id,
        join: v in "change_request_issues",
        on: v.collected_change_request_id == cr.id and is_nil(v.no_longer_observed_at),
        join: o in "observed_repositories",
        on: o.id == c.observed_repository_id,
        join: f in "cmpo_source_repositories",
        on: f.id == o.source_repository_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            is_nil(c.no_longer_observed_at) and is_nil(c.files_collected_at),
        distinct: c.id,
        order_by: [desc: c.external_committed_at],
        limit: ^limite,
        select: %{
          id: type(c.id, :binary_id),
          sha: c.sha,
          repositorio: f.qualified_name
        }
    )
  end

  defp coletar_commit(ctx, commit) do
    case Client.commit_files(ctx.tool.instance_url, ctx.token, commit.repositorio, commit.sha) do
      {:ok, arquivos} ->
        :ok =
          Commands.replace_commit_files(ctx.tenant, commit.id, Enum.map(arquivos, &traduzir/1))

        {:ok, length(arquivos)}

      # Force-push reescreve história: o commit que a plataforma coletou pode não existir
      # mais na origem. É fato sobre o repositório, e marcar o checkpoint evita tentar de
      # novo para sempre.
      {:error, :not_found_at_source} ->
        :ok = Commands.replace_commit_files(ctx.tenant, commit.id, [])
        {:gone, 0}

      {:error, motivo} ->
        Logger.warning("arquivos de #{commit.sha} não coletados: #{inspect(motivo)}")
        {:error, 0}
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
