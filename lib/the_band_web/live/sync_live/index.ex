defmodule TheBandWeb.SyncLive.Index do
  @moduledoc """
  `/sincronizacoes` — disparar e acompanhar a coleta (US2).

  O progresso chega por PubSub. A pausa por rate limit aparece como estado
  próprio, com o horário de retomada: não é erro, e não deve se parecer com um.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ingestion
  alias TheBand.Jobs.ReprocessMappings
  alias TheBand.Sources

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Ingestion.subscribe(socket.assigns.current_tenant)

    {:ok, socket |> assign(page_title: "Sincronizações", paused: nil, reprocess: nil) |> load()}
  end

  @impl true
  def handle_event("sync", %{"tool_id" => tool_id}, socket) do
    tenant = socket.assigns.current_tenant

    with {:ok, tool} <- Sources.fetch_connected_tool(tenant, tool_id),
         {:ok, _sync} <- Ingestion.start_sync(tenant, tool) do
      {:noreply, socket |> put_flash(:info, "Sincronização iniciada.") |> load()}
    else
      {:error, :already_running} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Já existe uma sincronização em andamento para esta ferramenta. A segunda não foi iniciada."
         )}

      {:error, :no_active_credential} ->
        {:noreply, put_flash(socket, :error, "Esta ferramenta não tem credencial ativa.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Ferramenta não encontrada.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Não foi possível iniciar: #{inspect(reason)}")}
    end
  end

  def handle_event("reprocess", _params, socket) do
    tenant = socket.assigns.current_tenant

    %{"tenant_id" => tenant.id}
    |> ReprocessMappings.new()
    |> Oban.insert()

    {:noreply,
     socket
     |> assign(reprocess: :running)
     |> put_flash(:info, "Reprocessando os mapeamentos sobre os dados já coletados.")}
  end

  @impl true
  def handle_info({:reprocess_finished, report}, socket) do
    {:noreply, assign(socket, reprocess: report)}
  end

  def handle_info({:sync_progress, _id, entity_type, count}, socket) do
    {:noreply,
     socket
     |> assign(paused: nil)
     |> put_progress(entity_type, count)
     |> load()}
  end

  def handle_info({:sync_paused, _id, seconds}, socket) do
    {:noreply, assign(socket, paused: seconds)}
  end

  def handle_info({:sync_finished, _id}, socket) do
    {:noreply, socket |> assign(paused: nil) |> load()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Sincronizações
        <:subtitle>Trazer da ferramenta o que a plataforma passa a conhecer.</:subtitle>
      </.header>

      <div :if={@paused} class="alert alert-info">
        <div>
          <span class="font-semibold">Aguardando a janela da API.</span>
          <div class="text-sm">
            A coleta pausou antes de esgotar o limite e retoma em cerca de {@paused} segundos.
            Não é erro: o limite do GraphQL é por complexidade de consulta, e pausar
            antes preserva o progresso.
          </div>
        </div>
      </div>

      <div :if={@tools == []} class="alert">
        <p>
          Nenhuma ferramenta conectada. Conecte uma em
          <.link navigate={~p"/ferramentas"} class="link">Ferramentas</.link>
          antes de sincronizar.
        </p>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div
          :for={tool <- @tools}
          class="card bg-base-200 p-4 flex flex-row items-center justify-between"
        >
          <div>
            <div class="font-semibold">{tool.tool_type} · {tool.organization_login}</div>
            <div class="text-xs opacity-70">{tool.instance_url}</div>
          </div>
          <.button phx-click="sync" phx-value-tool_id={tool.id} disabled={running?(@syncs, tool)}>
            {if running?(@syncs, tool), do: "em andamento", else: "Sincronizar"}
          </.button>
        </div>
      </div>

      <div class="card bg-base-200 p-4 space-y-3">
        <div class="flex items-start justify-between gap-4">
          <div>
            <div class="font-semibold">Reprocessar mapeamentos</div>
            <div class="text-sm opacity-70">
              Reaplica os mapeamentos semânticos aos dados <b>já coletados</b>, a partir do
              payload preservado. <b>Não consulta a ferramenta.</b>
              Use depois de corrigir um YAML em <code>priv/knowledge_base/mappings/</code>
              e reiniciar a aplicação — a base é lida uma vez por boot.
            </div>
          </div>
          <.button phx-click="reprocess" disabled={@reprocess == :running}>
            {if @reprocess == :running, do: "reprocessando…", else: "Reprocessar"}
          </.button>
        </div>

        <div
          :if={is_map(@reprocess) and Map.has_key?(@reprocess, :error)}
          class="alert alert-warning text-sm"
        >
          <p>
            Não há dado coletado para reprocessar. Rode uma sincronização primeiro — o
            reprocessamento trabalha sobre o payload preservado, e ainda não existe nenhum.
          </p>
        </div>

        <div :if={is_map(@reprocess) and Map.has_key?(@reprocess, :reprocessed)} class="space-y-2">
          <div class="grid grid-cols-2 sm:grid-cols-5 gap-2 text-sm">
            <div><span class="opacity-60">reprocessados</span> <b>{@reprocess.reprocessed}</b></div>
            <div><span class="opacity-60">criados</span> <b>{@reprocess.created}</b></div>
            <div><span class="opacity-60">atualizados</span> <b>{@reprocess.updated}</b></div>
            <div><span class="opacity-60">sem mudança</span> <b>{@reprocess.unchanged}</b></div>
            <div><span class="opacity-60">ignorados</span> <b>{@reprocess.skipped}</b></div>
          </div>

          <div :if={map_size(@reprocess.skip_reasons) > 0} class="text-xs opacity-70">
            motivos dos ignorados:
            <span :for={{reason, count} <- @reprocess.skip_reasons}>{reason} ({count})&nbsp;</span>
          </div>

          <p class="text-xs opacity-60">
            "atualizados" em zero, logo após um reprocessamento, é o resultado esperado quando
            nenhum mapeamento mudou: o registro só é reescrito quando algum atributo difere.
          </p>
        </div>
      </div>

      <.header>Execuções</.header>

      <div :if={@syncs == []} class="alert">
        <p>Nenhuma sincronização executada ainda.</p>
      </div>

      <div :for={sync <- @syncs} class="card bg-base-200 p-4 space-y-2">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class={[
              "badge",
              sync.status == "completed" && "badge-success",
              sync.status == "running" && "badge-info",
              sync.status == "failed" && "badge-error",
              sync.status == "interrupted" && "badge-warning"
            ]}>
              {status_label(sync.status)}
            </span>
            <span class="text-sm opacity-70">iniciada em {sync.started_at}</span>
          </div>
          <span :if={sync.finished_at} class="text-sm opacity-70">
            concluída em {sync.finished_at}
          </span>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-5 gap-2 text-sm">
          <div><span class="opacity-60">coletados</span> <b>{sync.records_collected}</b></div>
          <div><span class="opacity-60">criados</span> <b>{sync.records_created}</b></div>
          <div><span class="opacity-60">atualizados</span> <b>{sync.records_updated}</b></div>
          <div><span class="opacity-60">ignorados</span> <b>{sync.records_skipped}</b></div>
          <div>
            <span class="opacity-60">pendentes de papel</span>
            <b>{sync.memberships_pending_role}</b>
          </div>
        </div>

        <%!-- O que a coleta trouxe de trabalho. Vem da mesma sincronização — não há
              coleta separada de issues —, e por isso aparece na mesma linha em vez de
              numa tela que ninguém saberia quando foi atualizada. --%>
        <div class="flex flex-wrap gap-4 text-sm border-t border-base-300 pt-2">
          <div>
            <span class="opacity-60">repositórios nesta coleta</span>
            <b>{work_summary(sync).repositorios}</b>
          </div>
          <div>
            <span class="opacity-60">issues nesta coleta</span>
            <b>{work_summary(sync).issues}</b>
          </div>
          <.link navigate={~p"/trabalho"} class="link link-hover">ver o trabalho →</.link>
        </div>

        <div :if={map_size(sync.skip_reasons) > 0} class="text-xs opacity-70">
          motivos dos ignorados:
          <span :for={{reason, count} <- sync.skip_reasons}>{reason} ({count})&nbsp;</span>
        </div>

        <div :if={sync.error_reason} class="text-sm text-error">{sync.error_reason}</div>

        <div class="text-xs opacity-60">
          O número de vínculos pendentes de papel é lacuna de conhecimento, não erro:
          mede quanto da estrutura organizacional o sistema ainda não conhece.
        </div>

        <table :if={sync.status != "running"} class="table table-xs">
          <thead>
            <tr>
              <th>entidade</th><th>páginas</th><th>registros</th><th>última página</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={checkpoint <- checkpoints(sync)}>
              <td class="font-mono text-xs">{checkpoint.entity_type}</td>
              <td>{checkpoint.page_count}</td>
              <td>{checkpoint.record_count}</td>
              <td>{checkpoint.last_page_at}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant

    socket
    |> assign(tools: Sources.list_connected_tools(tenant))
    |> assign(syncs: Ingestion.list_syncs(tenant, limit: 10))
  end

  # Por sync, e não do tenant: o número ao lado de uma execução tem de ser o que **ela**
  # trouxe.
  defp work_summary(sync), do: Ingestion.work_summary(sync)

  defp put_progress(socket, _entity_type, _count), do: socket

  defp running?(syncs, tool) do
    Enum.any?(syncs, &(&1.connected_tool_id == tool.id and &1.status == "running"))
  end

  defp checkpoints(sync), do: Ingestion.list_checkpoints(sync)

  defp status_label("running"), do: "em andamento"
  defp status_label("completed"), do: "concluída"
  defp status_label("failed"), do: "falhou"
  defp status_label("interrupted"), do: "interrompida"
end
