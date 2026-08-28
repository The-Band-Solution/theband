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

  alias TheBand.Ontology.Continuum.SMPO
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
  # Issue #514: a organização declara o que o campo significa. A plataforma NÃO escolhe
  # pelo nome — `Quarter` parece trimestre, e classificar por padrão de nome publicaria a
  # suposição como medida.
  def handle_event("declarar_papel", %{"field_name" => campo, "role" => papel}, socket) do
    case SMPO.declare_field_role(
           socket.assigns.current_tenant,
           socket.assigns.selecionado.id,
           campo,
           papel,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Field #{campo} declared: #{rotulo_do_papel(papel)}.")
         |> recarregar()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That role could not be recorded.")}
    end
  end

  def handle_event("revogar_papel", %{"field_name" => campo}, socket) do
    case SMPO.revoke_field_role(
           socket.assigns.current_tenant,
           socket.assigns.selecionado.id,
           campo,
           socket.assigns.current_user.id
         ) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Role revoked.") |> recarregar()}
      {:error, :not_declared} -> {:noreply, put_flash(socket, :error, "Nothing to revoke.")}
    end
  end

  # Issue #368: ACRESCENTA, e não substitui. Diferente do critério de início, que é um só
  # porque um instante de início é um só: aqui sprint e marco valem ao mesmo tempo, e 304
  # issues têm as duas.
  def handle_event("declarar_prazo", %{"source" => origem} = params, socket) do
    campo = if origem == "board_field", do: params["field_name"], else: nil

    case SPO.declare_deadline_criterion(
           socket.assigns.current_tenant,
           {:board, socket.assigns.selecionado.id},
           origem,
           campo,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deadline source added: #{rotulo_da_origem(origem, campo)}.")
         |> recarregar()}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "That source is already declared, or the field is missing.")}
    end
  end

  def handle_event("revogar_prazo", %{"source" => origem} = params, socket) do
    campo = if origem == "board_field", do: params["field_name"], else: nil

    case SPO.revoke_deadline_criterion(
           socket.assigns.current_tenant,
           {:board, socket.assigns.selecionado.id},
           origem,
           campo,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Deadline source revoked.") |> recarregar()}

      {:error, :not_declared} ->
        {:noreply, put_flash(socket, :error, "Nothing to revoke.")}
    end
  end

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

  # O nome do campo vem da origem e traz espaço e acento — `Sprint (2 weeks)` existe. O
  # `id` precisa ser selecionável, e trocar o que não é seguro mantém o formulário de cada
  # linha distinto sem inventar um identificador que a origem não deu.
  defp identificador(nome), do: String.replace(nome, ~r/[^A-Za-z0-9_-]/, "-")

  defp rotulo_da_origem("board_field", campo), do: "the board field #{campo}"
  defp rotulo_da_origem("sprint", _), do: "the end of the time box"
  defp rotulo_da_origem("milestone", _), do: "the milestone's due date"
  defp rotulo_da_origem(outra, _), do: outra

  defp rotulo_do_papel("planning_horizon"), do: "planning horizon"
  defp rotulo_do_papel("sprint"), do: "sprint"
  defp rotulo_do_papel(outro), do: outro

  defp detalhe(tenant, quadro) do
    iteracoes = Projects.list_iterations(tenant, quadro.id)
    mapeamentos = Projects.field_mappings(tenant)
    horizontes = SMPO.horizon_field_external_ids(tenant, quadro.id)

    %{
      # Issue #514: o que cada campo de iteração significa, e a evidência para decidir.
      campos_de_iteracao: SMPO.iteration_fields(tenant, quadro.id),
      # Issue #368: as origens de prazo declaradas, e os campos de data que a coleta
      # trouxe. Três origens que NÃO se excluem — sprint e marco valem juntos.
      prazos: SPO.deadline_criteria_for(tenant, {:board, quadro.id}),
      campos_de_data: Projects.date_fields(tenant, quadro.id),
      # Issue #370: o critério DESTE quadro, e os tipos que a coleta oferece.
      criterio: SPO.start_criterion_for(tenant, {:board, quadro.id}),
      tipos_de_evento: SPO.collected_event_types(tenant),
      campos: Projects.list_field_definitions(tenant, quadro.id),
      mapeamentos: mapeamentos,
      total_itens: Projects.count_items(tenant, quadro.id),
      product_backlog: Projects.product_backlog(tenant, quadro.id),
      # Issue #514: a mesma linha, lida conforme o papel declarado. O que a organização
      # chamou de horizonte sai da lista de sprints — não some da tela, muda de seção.
      sprints:
        for it <- iteracoes,
            it.sro_sprint_id != nil,
            not MapSet.member?(horizontes, it.field_external_id) do
          %{iteracao: it, backlog: Projects.sprint_backlog(tenant, it.sro_sprint_id)}
        end,
      horizontes:
        for it <- iteracoes,
            it.sro_sprint_id != nil,
            MapSet.member?(horizontes, it.field_external_id) do
          %{iteracao: it, itens: length(Projects.sprint_backlog(tenant, it.sro_sprint_id))}
        end,
      pretendidas: Enum.filter(iteracoes, &(&1.spo_intended_process_id != nil)),
      importancia: Projects.importance_source(tenant, quadro.id)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
    >
      <Layouts.work_tabs active={:boards} />
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

        <%!-- ═══ O QUE CADA CAMPO DE ITERAÇÃO SIGNIFICA — issue #514 ═══
              A coleta promovia TODO campo de iteração a `sro.sprint`. Medido em 2026-08-26:
              669 vínculos de issue em 2.685 — 25% — apontavam para trimestre lido como
              sprint, e a vazão do trimestre parecia seis vezes maior sem que mais trabalho
              tivesse atravessado nada. --%>
        <div :if={@detalhe.campos_de_iteracao != []} class="card mb-4 bg-base-200">
          <div class="card-body gap-2 p-4 sm:p-5">
            <h3 class="font-semibold">What each iteration field means</h3>

            <p class="text-xs text-base-content/70">
              The platform <strong>does not guess</strong>. A field named
              <span class="font-mono">Quarter</span>
              looks like a quarter — and classifying by name pattern would publish the guess as
              a measure. The durations below are the evidence; the decision is yours.
            </p>

            <table class="table table-sm mt-1">
              <thead>
                <tr>
                  <th>field</th>
                  <th class="text-right">iterations</th>
                  <th>duration</th>
                  <th>read as</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={c <- @detalhe.campos_de_iteracao}>
                  <td class="font-mono">{c.field_name}</td>
                  <td class="text-right tabular-nums">{c.iteracoes}</td>
                  <%!-- Mínimo, máximo e média: uma média sozinha esconde que `Sprint 10` tem
                        3 dias num campo de 14, e é a dispersão que revela o campo mal usado. --%>
                  <td class="text-xs opacity-70 tabular-nums">
                    {c.duracao_min}–{c.duracao_max} days · avg {c.duracao_media}
                  </td>
                  <td>
                    <span :if={c.papel == "planning_horizon"} class="badge badge-sm">
                      planning horizon
                    </span>
                    <span :if={c.papel == "sprint"} class="badge badge-outline badge-sm">sprint</span>
                    <%!-- Ausência declarada, e não um traço: enquanto ninguém declara, a
                          leitura trata como sprint — que é o comportamento que a #514 aponta. --%>
                    <em :if={is_nil(c.papel)} class="text-xs opacity-60">
                      not declared — read as sprint
                    </em>
                  </td>
                  <td class="text-right">
                    <form
                      id={"papel-#{identificador(c.field_name)}"}
                      phx-submit="declarar_papel"
                      class="flex items-center justify-end gap-1"
                    >
                      <input type="hidden" name="field_name" value={c.field_name} />
                      <select name="role" class="select select-xs select-bordered">
                        <option value="">declare…</option>
                        <%!-- Da ontologia, e não repetidos aqui: uma segunda lista
                              divergiria em silêncio no dia em que um papel for acrescentado. --%>
                        <option :for={papel <- SMPO.papeis()} value={papel}>
                          {rotulo_do_papel(papel)}
                        </option>
                      </select>
                      <.button type="submit" class="btn-xs">save</.button>
                      <button
                        :if={c.papel}
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="revogar_papel"
                        phx-value-field_name={c.field_name}
                      >
                        revoke
                      </button>
                    </form>
                  </td>
                </tr>
              </tbody>
            </table>

            <p class="mt-1 text-xs opacity-60">
              A <strong>planning horizon</strong>
              is not a sprint. A sprint is a process that was <em>performed</em>
              — work happened inside it and it ended in a deliverable. A horizon
              is <em>declared</em>
              ahead of time and says <strong>when the work was planned for</strong>;
              it produces nothing. Reading one as the other makes the quarter's throughput look six
              times larger with no extra work having crossed anything.
            </p>
          </div>
        </div>

        <%!-- ═══ DE ONDE VEM O PRAZO — issue #368 ═══
              O GitHub não tem campo de prazo na issue. A sondagem achou 33 pares
              (quadro, campo) de data em 13 nomes e duas línguas: `End date` é fim
              planejado num quadro e fim real noutro, com o mesmo nome. --%>
        <div class="card mb-4 bg-base-200 p-6">
          <h3 class="mb-1 text-sm font-semibold">Where the deadline comes from</h3>

          <p class="mb-3 text-sm">
            <span :if={@detalhe.prazos == []} class="opacity-70">
              <%!-- Ausência declarada: 43% das issues não alcançam origem alguma, e "não
                    sabemos o prazo" é diferente de "está no prazo". --%>
              No source declared. Issues on this board have <strong>no known deadline</strong>
              — which is not the same as being on time, and the platform will not guess one.
            </span>
            <span :if={@detalhe.prazos != []}>
              A deadline here comes from <strong>{length(@detalhe.prazos)}</strong>
              source{if length(@detalhe.prazos) > 1, do: "s"}. They
              <strong>add up rather than replace</strong>
              each other: a task inside a sprint and tied to a milestone has both deadlines,
              and the platform shows both.
            </span>
          </p>

          <ul :if={@detalhe.prazos != []} class="mb-3 flex flex-wrap gap-2">
            <li :for={c <- @detalhe.prazos} class="badge badge-outline gap-2">
              <span class="text-xs">{rotulo_da_origem(c.source, c.field_name)}</span>
              <button
                type="button"
                class="cursor-pointer"
                phx-click="revogar_prazo"
                phx-value-source={c.source}
                phx-value-field_name={c.field_name}
              >
                ×
              </button>
            </li>
          </ul>

          <form
            id="prazo-por-campo"
            phx-submit="declarar_prazo"
            class="flex flex-wrap items-end gap-2"
          >
            <label class="fieldset">
              <span class="label-text text-xs">a date field of this board</span>
              <select name="field_name" class="select select-sm select-bordered">
                <%!-- Quantos itens preenchem cada campo: informar, e não recomendar.
                      `Start date` é começo, e lê-lo como prazo produziria atraso desde o
                      dia em que o trabalho começou. --%>
                <option value="">choose a field…</option>
                <option :for={c <- @detalhe.campos_de_data} value={c.name}>
                  {c.name} — {c.preenchidos} items filled
                </option>
              </select>
            </label>
            <input type="hidden" name="source" value="board_field" />
            <.button type="submit" class="btn-sm">add field</.button>
          </form>

          <p :if={@detalhe.campos_de_data == []} class="mt-1 text-xs opacity-60">
            This board has no date field at all — the other two sources below are the only
            ones available here.
          </p>

          <div class="mt-3 flex flex-wrap gap-2">
            <form phx-submit="declarar_prazo">
              <input type="hidden" name="source" value="sprint" />
              <.button type="submit" class="btn-outline btn-sm">
                also use the end of the time box
              </.button>
            </form>
            <form phx-submit="declarar_prazo">
              <input type="hidden" name="source" value="milestone" />
              <.button type="submit" class="btn-outline btn-sm">
                also use the milestone's due date
              </.button>
            </form>
          </div>

          <%!-- A #514 dentro da #368: a caixa pode ser sprint de 13 dias ou horizonte de
                84, e as duas produzem um fim. Explicar NO PONTO DA DECISÃO. --%>
          <p class="mt-3 text-xs opacity-70">
            <strong>The time box is not always a sprint.</strong>
            Where a field on this board is declared a <em>planning horizon</em>, the deadline
            it yields is labelled as such and never as a sprint deadline — the end of a
            sprint is when the execution box closes, while the end of a horizon is the limit
            of the period the work <em>had been planned for</em>. Measuring lateness against
            an 84-day box as if it were a 14-day one invents 70 days of slack.
          </p>
          <p class="mt-1 text-xs opacity-70">
            Measured on 2026-08-26: <strong>304 issues</strong>
            have both a milestone and a time box, and <strong>640</strong>
            sit in more than one box. Collapsing those into a single deadline would silently
            pick which date counts.
          </p>
        </div>

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

          <%!-- Horizonte de planejamento: aparece, mas fora da lista de sprint backlog.
                Some da contagem de sprint sem sumir da tela — o trimestre existe, e
                esconder faria a organização achar que a declaração apagou o dado. --%>
          <div :if={@detalhe.horizontes != []}>
            <h4 class="text-xs font-semibold tracking-wide uppercase opacity-70">
              Planning horizons — not sprints
            </h4>
            <p class="text-xs opacity-60">
              Declared ahead of time to say <strong>when the work was planned for</strong>.
              A horizon produces no deliverable, so what sits inside it is not a sprint
              backlog and its item count is not throughput.
            </p>
            <div :for={h <- @detalhe.horizontes} class="border-t border-base-300 py-1 text-sm">
              {h.iteracao.title}
              <span class="text-xs opacity-60">
                starts {h.iteracao.start_date} · {h.iteracao.duration_days} days · {h.itens} items planned for it
              </span>
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
