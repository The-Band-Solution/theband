defmodule TheBandWeb.SyncLive.Index do
  @moduledoc """
  `/syncs` — disparar e acompanhar a coleta (US2).

  O progresso chega por PubSub. A pausa por rate limit aparece como estado
  próprio, com o horário de retomada: não é erro, e não deve se parecer com um.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ingestion
  alias TheBand.Jobs.ReprocessMappings
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Sources
  alias TheBand.Tenants

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Ingestion.subscribe(socket.assigns.current_tenant)

    {:ok,
     socket
     |> assign(
       page_title: "Syncs",
       fase: nil,
       paused: nil,
       reprocess: nil,
       mapeamento: nil
     )
     |> load()}
  end

  @impl true
  # O acesso parte da **organização cuja coleta produziu a lacuna** — FR-052. Uma lista
  # global obrigaria escolher a organização duas vezes: uma para ver a coleta, outra para
  # ver as regras.
  def handle_event("abrir_mapeamento", %{"tool_id" => tool_id}, socket) do
    {:noreply, assign(socket, mapeamento: tool_id)}
  end

  def handle_event("fechar_mapeamento", _params, socket) do
    {:noreply, assign(socket, mapeamento: nil)}
  end

  def handle_event("sync", %{"tool_id" => tool_id}, socket) do
    tenant = socket.assigns.current_tenant

    with {:ok, tool} <- Sources.fetch_connected_tool(tenant, tool_id),
         {:ok, _sync} <- Ingestion.start_sync(tenant, tool) do
      {:noreply, socket |> put_flash(:info, "Sync started.") |> load()}
    else
      {:error, :already_running} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "A sync is already running for this tool. The second one was not started."
         )}

      {:error, :no_active_credential} ->
        {:noreply, put_flash(socket, :error, "This tool has no active credential.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not start: #{inspect(reason)}")}
    end
  end

  # A tela não é a defesa: `interrupt_sync/3` reconfere se há trabalho vivo. Entre desenhar o
  # botão e alguém clicar, a coleta pode ter voltado a executar.
  def handle_event("encerrar", %{"sync_id" => sync_id}, socket) do
    tenant = socket.assigns.current_tenant

    case Ingestion.interrupt_sync(tenant, sync_id, socket.assigns.current_user) do
      {:ok, _sync} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sync closed. The tool accepts a new collection now.")
         |> load()}

      {:error, :job_alive} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "This sync still has work running. Closing it would drop a collection in progress."
         )
         |> load()}

      {:error, :not_running} ->
        {:noreply, socket |> put_flash(:info, "This sync was already closed.") |> load()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Sync not found.")}
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
     |> put_flash(:info, "Reprocessing the mappings over the data already collected.")}
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

  # A fase de trabalho emite sem contagem: o que ela informa é **onde está**, e a
  # contagem já vem do checkpoint que a tela lê.
  def handle_info({:sync_progress, _id, entity_type}, socket) do
    {:noreply, socket |> assign(paused: nil, fase: entity_type) |> load()}
  end

  def handle_info({:sync_paused, _id, seconds}, socket) do
    {:noreply, assign(socket, paused: seconds)}
  end

  def handle_info({:sync_finished, _id}, socket) do
    {:noreply, socket |> assign(paused: nil) |> load()}
  end

  # O componente de regras não tem flash próprio: manda a mensagem ao processo pai, que é
  # dono do `@flash`. Precisa vir **antes** da cláusula que ignora o resto.
  def handle_info({:mapping_flash, tipo, mensagem}, socket) do
    {:noreply, put_flash(socket, tipo, mensagem)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Syncs
        <:subtitle>Bring in from the tool what the platform comes to know.</:subtitle>
      </.header>

      <div :if={@paused} class="alert alert-info">
        <div>
          <span class="font-semibold">Waiting for the API window.</span>
          <div class="text-sm">
            The collection paused before exhausting the limit and resumes in about {@paused} seconds. Not an error: the GraphQL limit is per query complexity, and pausing early
            preserves the progress.
          </div>
        </div>
      </div>

      <div :if={@tools == []} class="alert">
        <p>
          No tool connected. Connect one in <.link navigate={~p"/tools"} class="link">Tools</.link>
          before syncing.
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
            <%!-- Dizer o que o botão traz é o que impede alguém procurar uma coleta
                  separada de issues. Ela não existe: é uma sincronização, em fases. --%>
            <div class="text-xs opacity-70 mt-1">
              people, teams, repositories and issues — in one run
            </div>
          </div>
          <div class="flex flex-col gap-2 items-end">
            <.button phx-click="sync" phx-value-tool_id={tool.id} disabled={running?(@syncs, tool)}>
              {if running?(@syncs, tool), do: "running", else: "Sync"}
            </.button>
            <%!-- A lacuna nasce da coleta, e o acesso parte da organização que a produziu. --%>
            <.button
              phx-click="abrir_mapeamento"
              phx-value-tool_id={tool.id}
              class="btn-outline btn-xs"
            >
              Mapping rules
            </.button>
          </div>
        </div>
      </div>

      <div class="card bg-base-200 p-4 space-y-3">
        <div class="flex items-start justify-between gap-4">
          <div>
            <div class="font-semibold">Reprocess mappings</div>
            <div class="text-sm opacity-70">
              Reapplies the semantic mappings to data <b>already collected</b>, from the
              preserved payload. <b>It does not call the tool.</b>
              Use it after fixing a YAML in <code>priv/knowledge_base/mappings/</code>
              and restarting the app — the knowledge base is read once per boot.
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
            There is no collected data to reprocess. Run a sync first — reprocessing works over
            the preserved payload, and none exists yet.
          </p>
        </div>

        <div :if={is_map(@reprocess) and Map.has_key?(@reprocess, :reprocessed)} class="space-y-2">
          <div class="grid grid-cols-2 sm:grid-cols-5 gap-2 text-sm">
            <div><span class="opacity-60">reprocessed</span> <b>{@reprocess.reprocessed}</b></div>
            <div><span class="opacity-60">created</span> <b>{@reprocess.created}</b></div>
            <div><span class="opacity-60">updated</span> <b>{@reprocess.updated}</b></div>
            <div><span class="opacity-60">unchanged</span> <b>{@reprocess.unchanged}</b></div>
            <div><span class="opacity-60">skipped</span> <b>{@reprocess.skipped}</b></div>
          </div>

          <div :if={map_size(@reprocess.skip_reasons) > 0} class="text-xs opacity-70">
            reasons for skipping:
            <span :for={{reason, count} <- @reprocess.skip_reasons}>{reason} ({count})&nbsp;</span>
          </div>

          <p class="text-xs opacity-60">
            "updated" at zero right after a reprocess is the expected result when no mapping
            changed: a record is only rewritten when some attribute differs.
          </p>
        </div>
      </div>

      <%!-- O componente é hospedado aqui e fica **visivelmente separado** do relatório de
            execução — FR-051. Misturá-lo ao cartão de cada sync repetiria o erro do resumo
            de trabalho, cujo número parecia da execução e era do tenant. --%>
      <.live_component
        :if={organizacao_do_mapeamento(@tools, @mapeamento)}
        module={TheBandWeb.SyncLive.MappingRules}
        id="regras-de-mapeamento"
        tenant={@current_tenant}
        actor_id={@current_user.id}
        organization_id={organizacao_do_mapeamento(@tools, @mapeamento).id}
        organization_login={organizacao_do_mapeamento(@tools, @mapeamento).login}
      />

      <.header>Runs</.header>

      <div :if={@syncs == []} class="alert">
        <p>No sync has run yet.</p>
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
            <%!-- A organização, e não só o horário. Numa tela com execuções de duas
                  organizações, "iniciada em 15:10" não diz qual delas. --%>
            <span class="font-semibold">{organizacao(@tools, sync)}</span>
            <span class="text-sm opacity-70">started {sync.started_at}</span>
          </div>
          <div class="flex items-center gap-3">
            <span :if={sync.finished_at} class="text-sm opacity-70">
              finished {sync.finished_at}
            </span>
            <%!-- A ação só aparece onde a plataforma não consegue provar que o trabalho está
                  vivo. Encerrar coleta viva derruba trabalho em andamento, e é pior que o
                  bloqueio que esta ação existe para resolver. O texto diz o que acontece:
                  encerra o REGISTRO, e não cancela o que já foi coletado. --%>
            <button
              :if={Ingestion.interruptible?(sync)}
              class="btn btn-xs btn-outline btn-warning"
              phx-click="encerrar"
              phx-value-sync_id={sync.id}
              data-confirm={confirmacao(sync)}
            >
              Close stuck sync
            </button>
          </div>
        </div>

        <%!-- Quem encerrou, por extenso — e nunca um travessão para os dois casos: o autor
              ausente AFIRMA que foi a plataforma, e apagar a afirmação é o que o design
              system proíbe. --%>
        <div :if={sync.status == "interrupted"} class="text-sm">
          <span class="opacity-70">closed by</span>
          <span class="font-medium">{quem_encerrou(sync, @usuarios)}</span>
          <span :if={sync.error_reason} class="opacity-70">— {sync.error_reason}</span>
        </div>

        <%!-- Percentual quando a origem informa o total — `repositories.totalCount` e
              `issues.totalCount`, guardados no checkpoint. Onde ela não informa, a barra
              mostra a CONTAGEM e o estado da fase: inventar o denominador produziria
              número que parece informação e não é. --%>
        <%!-- Percentual quando a origem informa o total — `repositories.totalCount` e
              `issues.totalCount`, guardados no checkpoint. Onde ela não informa, a linha
              mostra a CONTAGEM: inventar o denominador produziria número que parece
              informação e não é. --%>
        <div :if={sync.status in ["running", "completed"]} class="space-y-3">
          <div :if={progresso(sync)} class="flex items-center gap-3">
            <progress
              class="progress progress-success flex-1"
              value={progresso(sync).feitos}
              max={progresso(sync).total}
            ></progress>
            <span class="text-sm font-mono w-12 text-right">{progresso(sync).percentual}%</span>
            <span class="text-xs opacity-70 w-28 text-right">
              {progresso(sync).feitos} de {progresso(sync).total}
            </span>
          </div>

          <%!-- Uma fase por linha, e a razão não é estética: lado a lado, as seis barras
                tinham a mesma largura e pareciam comparar 1 organização com 4474
                promoções. Não comparam — cada barra é o progresso **daquela** fase, e
                empilhar deixa isso legível.

                Os rótulos também deixam de brigar: `flex-1` os espalhava e o número
                acabava sob a barra vizinha. --%>
          <div class="space-y-1">
            <div :for={fase <- fases(sync)} class="flex items-center gap-3 text-xs">
              <span class="w-40 shrink-0 opacity-70">{fase.rotulo}</span>
              <div class="flex-1 h-2 rounded bg-base-300 overflow-hidden">
                <div
                  class={[
                    "h-full rounded",
                    estado_fase(fase.id, sync, @fase) == :feita && "bg-success",
                    estado_fase(fase.id, sync, @fase) == :em_curso && "bg-info animate-pulse",
                    estado_fase(fase.id, sync, @fase) == :pendente && "bg-base-300"
                  ]}
                  style={"width: #{largura(fase, estado_fase(fase.id, sync, @fase))}%"}
                >
                </div>
              </div>
              <span class="w-28 shrink-0 text-right font-mono">{contagem(fase)}</span>
            </div>
          </div>

          <div :if={sync.status == "running" && @fase} class="text-xs">
            collecting now: <span class="font-mono">{legivel(@fase)}</span>
          </div>
        </div>

        <%!-- Três grupos, e a separação é o ponto: os números vinham numa fileira só e
              respondiam perguntas diferentes. "coletados 3641" é da execução, "issues
              3383" é do trabalho trazido, e "pendentes de papel 88" não é nem uma coisa
              nem outra — é lacuna. Lê-los na mesma linha convida a somá-los. --%>
        <div class="grid gap-4 sm:grid-cols-3 border-t border-base-300 pt-3">
          <div>
            <div class="text-xs font-semibold opacity-60 uppercase tracking-wide">
              what the run did
            </div>
            <dl class="mt-1 text-sm space-y-0.5">
              <.field label="records collected">{sync.records_collected}</.field>
              <.field label="created">{sync.records_created}</.field>
              <.field label="updated">{sync.records_updated}</.field>
              <.field label="skipped">{sync.records_skipped}</.field>
              <%!-- Só aparece quando há: um "0 unreachable" em toda execução treinaria quem lê
                    a ignorar a linha, e é justamente a linha que importa quando não é zero. --%>
              <.field :if={sync.repositories_unreachable > 0} label="unreachable repositories">
                {sync.repositories_unreachable}
              </.field>
            </dl>
          </div>

          <div>
            <div class="text-xs font-semibold opacity-60 uppercase tracking-wide">
              the work it brought
            </div>
            <dl class="mt-1 text-sm space-y-0.5">
              <.field label="repositories">{work_summary(sync).repositorios}</.field>
              <.field label="issues">{work_summary(sync).issues}</.field>
            </dl>
            <.link navigate={~p"/work"} class="link link-hover text-sm">
              View the work →
            </.link>
          </div>

          <div>
            <div class="text-xs font-semibold opacity-60 uppercase tracking-wide">
              what went unanswered
            </div>
            <dl class="mt-1 text-sm space-y-0.5">
              <.field label="links with no role">{sync.memberships_pending_role}</.field>
            </dl>
            <%!-- A explicação fica **junto** do número que ela explica. Solta no rodapé do
                  cartão, ela era lida como observação geral sobre a coleta. --%>
            <p class="text-xs opacity-60 mt-1">
              A knowledge gap, not an error: it measures how much of the organisational
              structure the system still does not know.
            </p>
          </div>
        </div>

        <div :if={map_size(sync.skip_reasons) > 0} class="text-xs opacity-70">
          reasons for skipping:
          <span :for={{reason, count} <- sync.skip_reasons}>{reason} ({count})&nbsp;</span>
        </div>

        <div :if={sync.error_reason} class="text-sm text-error">{sync.error_reason}</div>

        <table :if={sync.status != "running"} class="table table-xs stacked">
          <thead>
            <tr>
              <th>entity</th><th class="text-right">pages</th><th class="text-right">records</th><th>
                last page
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={checkpoint <- checkpoints(sync)}>
              <td data-label="entity" class="font-mono text-xs">{checkpoint.entity_type}</td>
              <td data-label="pages" class="text-right tabular-nums">{checkpoint.page_count}</td>
              <td data-label="records" class="text-right tabular-nums">{checkpoint.record_count}</td>
              <td data-label="last page">{checkpoint.last_page_at}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant

    # Reconcilia **antes** de listar, e é um dos três gatilhos da mesma decisão — os outros
    # dois são o trabalho periódico e a ação de encerrar. Nenhum reimplementa a regra.
    #
    # Aqui ela existe para quem está olhando: o trabalho periódico roda a cada cinco minutos,
    # e quem acabou de ver a coleta morrer não deveria esperar cinco minutos para poder tentar
    # de novo.
    {:ok, _encerradas} = Ingestion.reconcile_stuck_syncs()

    socket
    |> assign(tools: Sources.list_connected_tools(tenant))
    |> assign(syncs: Ingestion.list_syncs(tenant, limit: 10))
    |> assign(usuarios: Tenants.users_by_id(tenant))
  end

  # Por sync, e não do tenant: o número ao lado de uma execução tem de ser o que **ela**
  # trouxe.
  defp work_summary(sync), do: Ingestion.work_summary(sync)

  defp put_progress(socket, entity_type, _count), do: assign(socket, fase: entity_type)

  # A organização vem da ferramenta conectada, que **é** a organização: a identidade dela
  # é tenant, tipo, instância e organização.
  # A ferramenta conectada guarda o `organization_login`; a organização em si vive em EO.
  # A ligação é por login, e não por chave estrangeira, porque a ferramenta é conectada
  # antes de a organização ser coletada.
  defp organizacao_do_mapeamento(_tools, nil), do: nil

  defp organizacao_do_mapeamento(tools, tool_id) do
    with tool when not is_nil(tool) <- Enum.find(tools, &(&1.id == tool_id)),
         org when not is_nil(org) <-
           EO.fetch_organization_by_login(tool.tenant_id, tool.organization_login) do
      %{id: org.id, login: org.login || org.name}
    else
      _ -> nil
    end
  end

  defp organizacao(tools, sync) do
    case Enum.find(tools, &(&1.id == sync.connected_tool_id)) do
      nil -> "—"
      tool -> tool.organization_login
    end
  end

  # As seis fases de uma sincronização, na ordem em que ocorrem. As contagens vêm dos
  # checkpoints, que são gravados **depois** de cada página ser processada.
  # As chaves são as que a coleta **grava** no checkpoint, e isso precisou ser conferido:
  # a lista anterior dizia `github.organization_members` e `github.teams`, e a ingestão
  # grava `github.user` e `github.team`. As duas fases apareciam eternamente pendentes com
  # contagem zero — sobre 67 pessoas e 8 equipes que tinham sido coletadas.
  #
  # Era ausência virando zero na tela: "não coletou" e "coletou e não achou nada" liam-se
  # igual, e o primeiro estava errado.
  @fases [
    {"github.organization", "organisation"},
    {"github.user", "people"},
    {"github.team", "teams"},
    {"github.team_member", "team links"},
    {"github.repository", "repositories"},
    {"github.issue", "issues"},
    {"promocao", "promotion"}
  ]

  @doc false
  # Percentual real: numerador e denominador **medidos**, nenhum estimado. O denominador
  # vem de `totalCount` da origem, guardado no checkpoint.
  #
  # Devolve `nil` quando nenhuma fase informou total — e nesse caso a tela não mostra
  # percentual nenhum. Uma barra sobre denominador inventado é a família da L22: número
  # que parece informação e não é.
  defp progresso(sync) do
    com_total = Enum.filter(checkpoints(sync), &(&1.expected_count && &1.expected_count > 0))

    case com_total do
      [] ->
        nil

      cps ->
        total = Enum.sum(Enum.map(cps, & &1.expected_count))
        feitos = Enum.sum(Enum.map(cps, &min(&1.record_count, &1.expected_count)))

        %{feitos: feitos, total: total, percentual: round(feitos / total * 100)}
    end
  end

  # Uma fase pode ter vários checkpoints — `github.team_member:dados`,
  # `github.team_member:ia` e assim por diante. A soma é por prefixo com dois-pontos, e
  # **não** por `String.starts_with?` puro: este casaria `github.team_member` dentro de
  # `github.team`, e a contagem de equipes passaria a incluir vínculos.
  #
  # `registros` é `nil` quando a fase **não tem checkpoint nenhum** — não executada — e é
  # zero quando executou e não achou nada. Colapsar os dois em zero foi o defeito que esta
  # tela tinha.
  # A largura é o progresso **da própria fase**, nunca a proporção entre fases: comparar
  # 1 organização com 4474 promoções não significa nada, e uma barra que insinuasse essa
  # comparação estaria mentindo.
  #
  # Sem total da origem, a barra é cheia quando a fase terminou e vazia quando não
  # começou — é estado, e o número ao lado é a informação.
  defp largura(%{registros: nil}, _estado), do: 0

  defp largura(%{registros: feitos, esperado: total}, _estado)
       when is_integer(total) and total > 0,
       do: min(round(feitos / total * 100), 100)

  defp largura(_fase, :pendente), do: 0
  defp largura(_fase, _estado), do: 100

  # `nil` é "esta fase não executou"; zero é "executou e não achou nada". A tela diz
  # coisas diferentes para os dois, e é a mesma distinção que o corpo da issue carrega.
  defp contagem(%{registros: nil}), do: "—"

  defp contagem(%{registros: feitos, esperado: total}) when is_integer(total) and total > 0,
    do: "#{feitos} de #{total}"

  defp contagem(%{registros: feitos}), do: to_string(feitos)

  defp fases(sync) do
    todos = checkpoints(sync)

    for {fase, rotulo} <- @fases do
      da_fase = Enum.filter(todos, &pertence?(&1.entity_type, fase))

      registros =
        case da_fase do
          [] -> nil
          cps -> Enum.sum(Enum.map(cps, & &1.record_count))
        end

      esperado =
        da_fase
        |> Enum.map(& &1.expected_count)
        |> Enum.reject(&is_nil/1)
        |> case do
          [] -> nil
          totais -> Enum.sum(totais)
        end

      %{id: fase, rotulo: rotulo, registros: registros, esperado: esperado}
    end
  end

  defp pertence?(entity_type, fase),
    do: entity_type == fase or String.starts_with?(entity_type, fase <> ":")

  # Três estados, e nenhum é percentual: a fase tem registro (feita), é a que a última
  # mensagem nomeou (em curso), ou não começou.
  defp estado_fase(fase, sync, atual) do
    tem_registro = Enum.any?(checkpoints(sync), &pertence?(&1.entity_type, fase))
    em_curso = sync.status == "running" and atual != nil and String.starts_with?(atual, fase)

    cond do
      em_curso -> :em_curso
      tem_registro -> :feita
      sync.status == "completed" -> :pendente
      true -> :pendente
    end
  end

  # A fase de issues carrega o repositório: "coletando issues" sem dizer de qual, numa
  # organização de 121 repositórios, não informa nada.
  defp legivel("github.issue:" <> repo), do: "issues from #{repo}"

  defp legivel(fase) do
    Enum.find_value(@fases, fase, fn {id, rotulo} -> id == fase && rotulo end)
  end

  defp running?(syncs, tool) do
    Enum.any?(syncs, &(&1.connected_tool_id == tool.id and &1.status == "running"))
  end

  defp checkpoints(sync), do: Ingestion.list_checkpoints(sync)

  # O aviso muda com o que a plataforma sabe. Quando o trabalho consta **em execução**, ela
  # não tem como provar que o processo morreu — só quem reiniciou a aplicação sabe. E o risco
  # de encerrar nesse caso é real: se a coleta estiver de fato rodando, uma segunda começa em
  # paralelo. Esconder isso atrás de "tem certeza?" seria pedir confirmação sem informar.
  defp confirmacao(sync) do
    if Ingestion.claimed_by_dead_process?(sync) do
      "This sync still shows work as running, and the platform cannot tell whether the process " <>
        "is alive. Close it only if you know it died — if the collection is in fact running, a " <>
        "second one will start alongside it. Nothing already collected is removed."
    else
      "This sync has no work queued. Closing it records why it ended and lets the tool collect " <>
        "again. Nothing already collected is removed."
    end
  end

  # `the platform` por extenso, e não `—`: nulo aqui significa "não foi pessoa", e a
  # plataforma sabe disso. Um travessão diria "não se sabe quem", que é outra coisa.
  defp quem_encerrou(%{interrupted_by_user_id: nil}, _usuarios), do: "the platform"

  defp quem_encerrou(%{interrupted_by_user_id: id}, usuarios) do
    case Map.get(usuarios, id) do
      nil -> "a person no longer registered"
      user -> user.name || user.email
    end
  end

  defp status_label("running"), do: "running"
  defp status_label("completed"), do: "completed"
  defp status_label("failed"), do: "failed"
  defp status_label("interrupted"), do: "interrupted"
end
