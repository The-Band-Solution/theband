defmodule TheBand.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # FR-005a — a chave mestra é verificada antes de qualquer supervisor subir.
    # Uma aplicação que sobe sem chave gravaria credenciais em claro e ninguém
    # perceberia; recusar o boot é o comportamento correto.
    case TheBand.Vault.master_key() do
      {:ok, _key} -> start_supervisor()
      {:error, reason} -> refuse_boot(reason)
    end
  end

  defp start_supervisor do
    children = [
      TheBandWeb.Telemetry,
      TheBand.Repo,
      TheBand.Vault,
      TheBand.Ontology.KnowledgeBase,
      {Oban, Application.fetch_env!(:the_band, Oban)},
      {DNSCluster, query: Application.get_env(:the_band, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TheBand.PubSub},
      # As tarefas da coleta rodam SOB SUPERVISOR, e não linkadas ao job — ADR 0006.
      #
      # `Task.async_stream` linka a tarefa a quem a criou: uma exceção num repositório
      # derrubaria o job inteiro, que é exatamente o acoplamento de destino que a ADR
      # existe para quebrar. Foi assim que um `KeyError` num único repositório matou a
      # coleta em 2026-09-04, levando junto as etapas seguintes.
      #
      # Com `async_stream_nolink`, a tarefa que morre vira `{:exit, motivo}` no fluxo, e
      # os outros repositórios seguem.
      {Task.Supervisor, name: TheBand.Ingestion.TaskSupervisor},
      TheBandWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TheBand.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TheBandWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp refuse_boot(reason) do
    Logger.emergency("""

    ══════════════════════════════════════════════════════════════════════
    The Band não pode iniciar: chave mestra #{motivo(reason)}.

    FR-005a — a plataforma recusa iniciar sem a chave mestra configurada,
    em vez de operar gravando credenciais de ferramentas sem proteção.

    Defina THE_BAND_MASTER_KEY com 32 bytes em Base64:

        export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)

    Ver .env.example.
    ══════════════════════════════════════════════════════════════════════
    """)

    {:error, reason}
  end

  defp motivo(:missing_master_key), do: "ausente"
  defp motivo(:invalid_master_key), do: "inválida — esperados 32 bytes em Base64"
end
