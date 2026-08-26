defmodule TheBandWeb.BoardLive.Index do
  @moduledoc """
  `/boards` — os quadros observados, e o que cada um carrega. Sprint 017, T057.

  ## Uma coisa: "o que a origem declara nos quadros"

  Princípio X. `/projects` responde *o que a organização declarou como empreendimento*;
  esta responde *o que os quadros da ferramenta carregam* — campos, itens e backlogs.
  Juntá-las apagaria a distinção que a regra `github_project_board.yaml` existe para
  manter: quadro é planejamento e visualização, nunca o empreendimento.

  ## O quadro não é promovido, e a tela diz o conteúdo pelo nome certo

  Iteração iniciada aparece como sprint; futura, como processo pretendido; item sem
  iteração compõe o product backlog. A tela usa esses nomes porque são os conceitos que
  o conteúdo virou — o quadro em si não virou nada.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Projects

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    quadros = Projects.list_projects(tenant)

    {:ok,
     socket
     |> assign(page_title: "Boards")
     |> assign(quadros: quadros)
     |> assign(selecionado: nil, detalhe: nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    tenant = socket.assigns.current_tenant

    case Projects.get_project(tenant, id) do
      {:ok, quadro} ->
        {:noreply,
         socket |> assign(selecionado: quadro) |> assign(detalhe: detalhe(tenant, quadro))}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Board not found.")
         |> push_patch(to: ~p"/boards")}
    end
  end

  def handle_params(_params, _uri, socket),
    do: {:noreply, assign(socket, selecionado: nil, detalhe: nil)}

  @impl true
  def handle_event("declarar_criterio", %{"event_type" => tipo}, socket) do
    quadro = socket.assigns.selecionado

    case SPO.declare_start_criterion(
           socket.assigns.current_tenant,
           {:board, quadro.id},
           tipo,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Start criterion declared for this board: #{tipo}.")
         |> recarregar()}

      {:error, :unknown_event_type} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The platform has not collected that event. Only what it observes can be declared."
         )}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not declare: #{inspect(motivo)}")}
    end
  end

  def handle_event("revogar_criterio", _params, socket) do
    quadro = socket.assigns.selecionado

    case SPO.revoke_start_criterion(
           socket.assigns.current_tenant,
           {:board, quadro.id},
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Criterion revoked. The project's one applies again, if declared.")
         |> recarregar()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "There was no criterion to revoke.")}
    end
  end

  defp recarregar(socket) do
    tenant = socket.assigns.current_tenant
    assign(socket, detalhe: detalhe(tenant, socket.assigns.selecionado))
  end

  defp detalhe(tenant, quadro) do
    iteracoes = Projects.list_iterations(tenant, quadro.id)
    mapeamentos = Projects.field_mappings(tenant)

    %{
      # Issue #370: o critério DESTE quadro, e os tipos que a coleta oferece.
      criterio: SPO.start_criterion_for(tenant, {:board, quadro.id}),
      tipos_de_evento: SPO.collected_event_types(tenant),
      campos: Projects.list_field_definitions(tenant, quadro.id),
      mapeamentos: mapeamentos,
      total_itens: Projects.count_items(tenant, quadro.id),
      product_backlog: Projects.product_backlog(tenant, quadro.id),
      sprints:
        for it <- iteracoes, it.sro_sprint_id != nil do
          %{iteracao: it, backlog: Projects.sprint_backlog(tenant, it.sro_sprint_id)}
        end,
      pretendidas: Enum.filter(iteracoes, &(&1.spo_intended_process_id != nil)),
      importancia: Projects.importance_source(tenant, quadro.id)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Boards
        <:subtitle>
          What the source declares in each board — fields, items and the derived backlogs.
          The board itself is planning and visualisation; it is never promoted to a concept.
        </:subtitle>
      </.header>

      <div :if={@quadros == []} class="card bg-base-200 p-6">
        <%!-- FR-040: organização sem quadros é resposta declarada, não coleta vazia. --%>
        <.absent reason="No board collected — either this organisation does not use Projects v2, which the sync declares, or no sync has run since boards began to be collected." />
      </div>

      <table :if={@quadros != []} class="table table-sm stacked">
        <thead>
          <tr>
            <th>#</th>
            <th>title</th>
            <th>state</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={q <- @quadros}>
            <td data-label="#" class="font-mono">{q.number}</td>
            <td data-label="title">
              <.link patch={~p"/boards/#{q.id}"} class="link link-hover">{q.title}</.link>
            </td>
            <td data-label="state" class="text-xs">
              <span :if={q.closed} class="badge badge-sm badge-ghost">closed</span>
              <span :if={q.no_longer_observed_at} class="badge badge-sm badge-warning">
                no longer at the source
              </span>
              <span :if={!q.closed && !q.no_longer_observed_at} class="badge badge-sm">open</span>
            </td>
          </tr>
        </tbody>
      </table>

      <section :if={@selecionado} class="mt-8 space-y-6">
        <.header>
          #{@selecionado.number} · {@selecionado.title}
          <:subtitle>collected board — nothing here is a project of its own</:subtitle>
        </.header>

        <%!-- ═══ O CRITÉRIO DESTE QUADRO — issue #370 ═══ --%>
        <div class="card bg-base-200 p-6">
          <h3 class="mb-1 text-sm font-semibold">Start criterion</h3>

          <p class="mb-3 text-sm">
            <span :if={@detalhe.criterio}>
              Work on this board starts when
              <span class="badge badge-outline badge-sm font-mono">
                {@detalhe.criterio.event_type}
              </span>
              happens. <strong>This wins over the project's criterion.</strong>
            </span>
            <span :if={is_nil(@detalhe.criterio)} class="opacity-70">
              No criterion of its own. Issues on this board follow the <strong>project's</strong>
              criterion — and if no project declared one, they have no start instant.
            </span>
          </p>

          <form phx-submit="declarar_criterio" class="flex flex-wrap items-end gap-2">
            <label class="fieldset">
              <span class="label-text text-xs">event that marks the start</span>
              <select name="event_type" class="select select-sm select-bordered" required>
                <option value="">choose…</option>
                <option :for={t <- @detalhe.tipos_de_evento} value={t.event_type}>
                  {t.event_type} — {t.occurrences} observed
                </option>
              </select>
            </label>
            <.button type="submit" variant="primary" class="btn-sm">
              {if @detalhe.criterio, do: "Replace", else: "Declare"}
            </.button>
            <button
              :if={@detalhe.criterio}
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="revogar_criterio"
              data-confirm="Revoke it? Issues here fall back to the project's criterion."
            >
              revoke
            </button>
          </form>

          <%!-- FR-017: explicar o desempate NO PONTO DA DECISÃO. Uma regra de precedência
                que ninguém entende é obedecida sem ser conferida. --%>
          <p class="mt-3 text-xs opacity-70">
            <strong>When an issue sits on more than one board</strong>
            — 13% of them do — the criterion that applies is the one from the board <strong>most recently linked to the project</strong>. Linking the new board last is
            already the gesture that says which one is current, so the platform reads that
            instead of asking twice.
          </p>
          <p class="mt-1 text-xs opacity-70">
            If two boards were linked at the very same instant — which batch association does —
            the platform <strong>does not pick one</strong>. It names the tie and leaves the
            decision, because picking silently would be choosing where nobody would look.
          </p>
        </div>

        <div class="card bg-base-200 p-6">
          <h3 class="mb-1 text-sm font-semibold">Fields</h3>
          <%!-- FR-026: a ausência de importância é dita, e nenhum campo a substitui. --%>
          <p class="mb-3 text-xs opacity-70">
            <%= case @detalhe.importancia do %>
              <% {:mapped, nome} -> %>
                Importance comes from the field <strong>{nome}</strong>, declared by this
                organisation.
              <% :not_declared -> %>
                No field is mapped to importance — the items below have <strong>no order of
                importance</strong>, and no field stands in for it. Priority is not importance.
            <% end %>
          </p>

          <table class="table table-xs stacked">
            <thead>
              <tr>
                <th>name</th>
                <th>type</th>
                <th>interpretation</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={c <- @detalhe.campos}>
                <td data-label="name">{c.name}</td>
                <td data-label="type" class="font-mono text-xs">{c.data_type}</td>
                <td data-label="interpretation" class="text-xs">
                  <%= if atributo =
                        TheBand.Projects.interpretation_for(
                          @detalhe.mapeamentos,
                          c.field_external_id,
                          c.data_type
                        ) do %>
                    <span class="badge badge-sm badge-success">{atributo}</span>
                  <% else %>
                    <span class="opacity-60">not interpreted — stored raw</span>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="card bg-base-200 p-6 space-y-4">
          <h3 class="text-sm font-semibold">
            Backlogs <span class="font-mono text-xs opacity-70">{@detalhe.total_itens} items</span>
          </h3>
          <%!-- SC-009b ao vivo: as contagens abaixo somam o total acima, e a composição é
                derivada da atribuição de iteração — nunca gravada. --%>
          <div>
            <h4 class="text-xs font-semibold tracking-wide uppercase opacity-70">
              Product backlog · {length(@detalhe.product_backlog)} items
            </h4>
            <p class="text-xs opacity-60">
              Items with no iteration assigned — that absence is what defines it.
            </p>
            <div
              :for={item <- Enum.take(@detalhe.product_backlog, 15)}
              class="border-t border-base-300 py-1 text-sm"
            >
              <.item_linha item={item} />
            </div>
          </div>

          <div :for={s <- @detalhe.sprints}>
            <h4 class="text-xs font-semibold tracking-wide uppercase opacity-70">
              {s.iteracao.title} · sprint backlog · {length(s.backlog)} items
              <span
                :if={s.iteracao.no_longer_in_configuration_at}
                class="badge badge-xs badge-warning"
              >
                removed from the board's configuration
              </span>
            </h4>
            <div :for={item <- Enum.take(s.backlog, 15)} class="border-t border-base-300 py-1 text-sm">
              <.item_linha item={item} />
            </div>
          </div>

          <div :if={@detalhe.pretendidas != []}>
            <h4 class="text-xs font-semibold tracking-wide uppercase opacity-70">
              Intended — iterations that have not started
            </h4>
            <p class="text-xs opacity-60">
              Planning that has not happened: these are intended processes, never sprints.
            </p>
            <div :for={it <- @detalhe.pretendidas} class="border-t border-base-300 py-1 text-sm">
              {it.title} <span class="font-mono text-xs opacity-60">starts {it.start_date}</span>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # Item de rascunho não tem issue por trás, e a tela o diz — registrado, nunca promovido.
  defp item_linha(assigns) do
    ~H"""
    <%= if @item.is_draft do %>
      <span class="opacity-70">draft — no work item behind it</span>
    <% else %>
      <%= if @item.collected_issue_id do %>
        <.link navigate={~p"/work/issues/#{@item.collected_issue_id}"} class="link link-hover">
          #{@item.issue_number} {@item.issue_title}
        </.link>
        <span class="text-xs opacity-60">{String.downcase(@item.issue_state || "")}</span>
      <% else %>
        <span class="opacity-70">item whose issue was not collected</span>
      <% end %>
    <% end %>
    """
  end
end
