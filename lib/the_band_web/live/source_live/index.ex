defmodule TheBandWeb.SourceLive.Index do
  @moduledoc """
  `/ferramentas` — conectar e listar ferramentas (US1).

  Só perfil `admin`. A credencial é validada contra a ferramenta **antes** de
  qualquer gravação; quando a validação falha, a tela diz o que faltou e nada é
  gravado. Depois de conectada, a chave nunca mais aparece — só `••••` mais os
  quatro últimos caracteres.
  """

  use TheBandWeb, :live_view

  alias TheBand.Sources
  alias TheBand.Sources.ToolCredential

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Tools", form_open: false)
     |> load_tools()}
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, form_open: !socket.assigns.form_open)}
  end

  def handle_event("connect", params, socket) do
    case Sources.connect_tool(socket.assigns.current_tenant, params) do
      {:ok, %{tool: tool}} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{tool.tool_type} conectado e credencial validada.")
         |> assign(form_open: false)
         |> load_tools()}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The tool refused the credential. Nothing was saved."
         )}

      {:error, {:missing_scopes, missing}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "A credencial é válida mas não tem os escopos necessários: #{Enum.join(missing, ", ")}. " <>
             "Sem eles a coleta devolveria zero equipes, o que é pior que falhar. Nada foi gravado."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save: #{errors(changeset)}")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to validate the credential: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_credential", %{"id" => id, "active" => active}, socket) do
    credential = Enum.find(all_credentials(socket), &(&1.id == id))

    if credential do
      Sources.set_credential_active(credential, active == "true")
    end

    {:noreply, load_tools(socket)}
  end

  def handle_event("ask_end", %{"id" => id}, socket) do
    tenant = socket.assigns.current_tenant

    case Sources.fetch_connected_tool(tenant, id) do
      {:ok, tool} ->
        impact = Sources.observation_impact(tenant, tool)

        {:noreply,
         assign(socket,
           ending: %{
             tool: tool,
             impact: impact,
             shared_names: Sources.shared_people_names(tenant, tool)
           }
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}
    end
  end

  def handle_event("cancel_end", _params, socket), do: {:noreply, assign(socket, ending: nil)}

  def handle_event("ask_resume", %{"id" => id}, socket) do
    case Sources.fetch_connected_tool(socket.assigns.current_tenant, id) do
      {:ok, tool} -> {:noreply, assign(socket, resuming: tool)}
      {:error, :not_found} -> {:noreply, put_flash(socket, :error, "Tool not found.")}
    end
  end

  def handle_event("toggle_history", %{"id" => id}, socket) do
    abertos = socket.assigns.open_history

    {:noreply,
     assign(socket, open_history: if(id in abertos, do: abertos -- [id], else: [id | abertos]))}
  end

  def handle_event("cancel_resume", _params, socket),
    do: {:noreply, assign(socket, resuming: nil)}

  def handle_event("resume_observation", %{"tool_id" => id} = params, socket) do
    tenant = socket.assigns.current_tenant

    with {:ok, tool} <- Sources.fetch_connected_tool(tenant, id),
         {:ok, _resultado} <-
           Sources.resume_observation(tenant, tool, %{
             "secret" => params["secret"],
             "label" => params["label"],
             "actor_user_id" => socket.assigns.current_user.id
           }) do
      {:noreply,
       socket
       |> assign(resuming: nil)
       |> put_flash(
         :info,
         "Observation of #{tool.organization_login} resumed. " <>
           "The marked records become current again on the next collection, " <>
           "e só os que a origem ainda mostrar."
       )
       |> load_tools()}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "The tool refused the credential.")}

      {:error, {:missing_scopes, faltando}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "A credencial não tem os escopos: #{Enum.join(faltando, ", ")}"
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not resume the observation.")}
    end
  end

  def handle_event("end_observation", %{"tool_id" => id} = params, socket) do
    tenant = socket.assigns.current_tenant

    with {:ok, tool} <- Sources.fetch_connected_tool(tenant, id),
         {:ok, resultado} <-
           Sources.end_observation(tenant, tool, %{
             "confirmation" => params["confirmation"],
             "actor_user_id" => socket.assigns.current_user.id
           }) do
      {:noreply,
       socket
       |> assign(ending: nil)
       |> put_flash(
         :info,
         "Observation of #{tool.organization_login} ended. " <>
           "#{resultado.marked.people} pessoa(s), #{resultado.marked.teams} equipe(s) e " <>
           "#{resultado.marked.links} vínculo(s) marcados. " <>
           "#{resultado.credentials_destroyed} credential(s) destroyed. Nothing was deleted."
       )
       |> load_tools()}
    else
      {:error, :confirmation_mismatch} ->
        {:noreply, put_flash(socket, :error, "The name typed does not match the organisation.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Ferramentas conectadas
        <:subtitle>
          Quais ferramentas esta organização usa, e com quais contas de serviço.
        </:subtitle>
        <:actions>
          <.button phx-click="toggle_form">
            {if @form_open, do: "Cancel", else: "Connect tool"}
          </.button>
        </:actions>
      </.header>

      <div :if={@form_open} class="card bg-base-200 p-6">
        <form id="conectar-ferramenta" phx-submit="connect" class="space-y-4">
          <div class="grid gap-4 sm:grid-cols-2">
            <label class="form-control">
              <span class="label-text">Tool type</span>
              <select name="tool_type" class="select select-bordered">
                <option value="github">github</option>
              </select>
            </label>

            <label class="form-control">
              <span class="label-text">Instance</span>
              <input
                name="instance_url"
                value="https://github.com"
                class="input input-bordered"
                placeholder="https://github.com ou a instalação própria"
              />
            </label>

            <label class="form-control">
              <span class="label-text">Organisation to observe</span>
              <input name="organization_login" class="input input-bordered" placeholder="minha-org" />
            </label>

            <label class="form-control">
              <span class="label-text">Credential label</span>
              <input name="label" class="input input-bordered" placeholder="conta de serviço" />
            </label>
          </div>

          <label class="form-control">
            <span class="label-text">Credential</span>
            <input type="password" name="secret" class="input input-bordered" autocomplete="off" />
            <span class="label-text-alt opacity-70">
              Validada contra a ferramenta antes de ser gravada. Depois disso não é mais exibida.
            </span>
          </label>

          <.button type="submit" variant="primary">Validate and connect</.button>
        </form>
      </div>

      <div :if={@tools == []} class="alert">
        <p>Nenhuma ferramenta conectada ainda. Conecte uma para que a plataforma possa coletar.</p>
      </div>

      <div :for={tool <- @tools} class="card bg-base-200 p-6 space-y-4">
        <div class="flex items-start justify-between gap-4">
          <div>
            <div class="flex items-center gap-2">
              <span class="font-semibold text-lg">{tool.tool_type}</span>
              <%!-- Um selo só. Mostrar "ativa" ao lado de "observação encerrada" fazia o
                    cartão afirmar duas coisas contrárias — o estado de observação vence,
                    porque é ele que decide se a plataforma coleta (FR-022). --%>
              <span :if={@ended[tool.id]} class="badge badge-ghost">
                observation ended
              </span>
              <span
                :if={!@ended[tool.id]}
                class={[
                  "badge",
                  tool.status == "active" && "badge-success",
                  tool.status == "needs_attention" && "badge-warning",
                  tool.status == "disabled" && "badge-ghost"
                ]}
              >
                {status_label(tool.status)}
              </span>
            </div>
            <div class="text-sm opacity-70">{tool.instance_url}</div>
            <div class="text-sm opacity-70">organização observada: {tool.organization_login}</div>
          </div>

          <div class="text-right text-sm opacity-70">
            <div :if={tool.last_sync_at}>última coleta: {tool.last_sync_at}</div>
            <div :if={is_nil(tool.last_sync_at)}>never synced</div>
            <div :if={@ended[tool.id]} class="text-xs">
              ended at {@ended[tool.id]}
            </div>
            <button
              :if={!@ended[tool.id]}
              class="btn btn-xs btn-outline btn-error mt-2"
              phx-click="ask_end"
              phx-value-id={tool.id}
            >
              encerrar observação
            </button>
            <button
              :if={@ended[tool.id]}
              class="btn btn-xs btn-outline mt-2"
              phx-click="ask_resume"
              phx-value-id={tool.id}
            >
              retomar observação
            </button>
          </div>
        </div>

        <%!-- AC4 da US2: depois de retomada, a ferramenta volta a parecer ativa e o
              cartão não diria que houve encerramento. O histórico é o que preserva
              que aconteceu — e é append-only, então nunca encolhe. --%>
        <div :if={@history[tool.id] != []} class="mt-3">
          <button class="link link-hover text-xs" phx-click="toggle_history" phx-value-id={tool.id}>
            histórico de observação ({length(@history[tool.id])})
          </button>

          <ul :if={tool.id in @open_history} class="mt-2 text-xs space-y-1">
            <li :for={event <- @history[tool.id]} class="flex gap-2">
              <span class={[
                "badge badge-xs",
                event.event == "ended" && "badge-error",
                event.event == "resumed" && "badge-success"
              ]}>
                {if event.event == "ended", do: "ended", else: "resumed"}
              </span>
              <span class="opacity-70">{event.occurred_at}</span>
              <span :if={event.reason} class="opacity-70">— {event.reason}</span>
            </li>
          </ul>
        </div>

        <div :if={@resuming && @resuming.id == tool.id} class="alert block text-sm">
          <div class="font-semibold mb-2">
            Retomar a observação de {tool.organization_login}
          </div>

          <p class="mb-2 opacity-80">
            A credencial anterior foi destruída no encerramento, então é preciso informar
            uma nova. Ela é validada contra a origem antes de qualquer coisa ser gravada.
          </p>

          <p class="mb-3 opacity-80">
            Os registros marcados <strong>do not become current again now</strong>: só a
            coleta seguinte pode dizer se a origem ainda os mostra. Desmarcar aqui
            afirmaria uma observação que não aconteceu.
          </p>

          <form phx-submit="resume_observation" class="flex flex-wrap gap-2 items-end">
            <input type="hidden" name="tool_id" value={tool.id} />
            <label class="form-control">
              <span class="label-text text-xs">New credential</span>
              <input
                name="secret"
                type="password"
                class="input input-bordered input-sm"
                autocomplete="off"
                placeholder="ghp_..."
              />
            </label>
            <label class="form-control">
              <span class="label-text text-xs">Rótulo</span>
              <input
                name="label"
                class="input input-bordered input-sm"
                placeholder="credencial principal"
              />
            </label>
            <.button type="submit" variant="primary">Validate and resume</.button>
            <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_resume">
              cancelar
            </button>
          </form>
        </div>

        <div :if={@ending && @ending.tool.id == tool.id} class="alert alert-error text-sm block">
          <div class="font-semibold mb-2">
            Encerrar a observação de {tool.organization_login}
          </div>

          <div class="mb-2">
            <div class="opacity-80">Will be marked as no longer observed:</div>
            <div class="font-mono">
              {@ending.impact.teams} equipe(s) — {@ending.impact.derived_teams} derivada(s) pela plataforma
            </div>
            <div class="font-mono">{@ending.impact.evidence_links} vínculo(s)</div>
            <div class="font-mono">
              {@ending.impact.people_exclusive} pessoa(s) conhecida(s) só por esta organização
            </div>
          </div>

          <div :if={@ending.impact.people_shared > 0} class="mb-2">
            <div class="opacity-80">Remain current:</div>
            <div class="font-mono">
              {@ending.impact.people_shared} pessoa(s) — também observada(s) em outra organização
            </div>
            <div :for={p <- @ending.shared_names} class="font-mono text-xs opacity-80">
              {p}
            </div>
          </div>

          <div class="mb-2">
            <div class="opacity-80">Will be destroyed:</div>
            <div class="font-mono">this tool&#39;s credentials</div>
          </div>

          <div class="mb-3">
            <div class="opacity-80 font-semibold">Will NOT be deleted:</div>
            <div class="font-mono">
              {@ending.impact.preserved_payloads} payload(s) preservado(s), nem pessoa, equipe ou vínculo algum
            </div>
          </div>

          <form phx-submit="end_observation" class="flex flex-wrap gap-2 items-end">
            <input type="hidden" name="tool_id" value={tool.id} />
            <label class="form-control">
              <span class="label-text text-xs">
                Para confirmar, digite: <strong>{tool.organization_login}</strong>
              </span>
              <input name="confirmation" class="input input-bordered input-sm" autocomplete="off" />
            </label>
            <.button type="submit" variant="primary">End observation</.button>
            <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_end">
              cancelar
            </button>
          </form>
        </div>

        <div :if={tool.status == "needs_attention"} class="alert alert-warning text-sm">
          <div>
            <span class="font-semibold">Precisa de atenção desde {tool.needs_attention_since}.</span>
            <div>{tool.needs_attention_reason}</div>
          </div>
        </div>

        <div>
          <div class="text-sm font-semibold mb-2">Credentials</div>
          <table class="table table-sm stacked">
            <thead>
              <tr>
                <th>rótulo</th>
                <th>credential</th>
                <th>scopes</th>
                <th>validated at</th>
                <th>estado</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={credential <- tool.credentials}>
                <td>{credential.label}</td>
                <td class="font-mono text-xs">{ToolCredential.masked(credential)}</td>
                <td class="text-xs">{Enum.join(credential.scopes, ", ")}</td>
                <td class="text-xs">{credential.validated_at}</td>
                <td>
                  <span class={["badge badge-sm", credential.active && "badge-success"]}>
                    {if credential.active, do: "ativa", else: "inativa"}
                  </span>
                </td>
                <td>
                  <button
                    class="btn btn-xs btn-ghost"
                    phx-click="toggle_credential"
                    phx-value-id={credential.id}
                    phx-value-active={to_string(!credential.active)}
                  >
                    {if credential.active, do: "desativar", else: "ativar"}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
          <p class="text-xs opacity-60 mt-2">
            A credencial é cifrada em repouso e nunca é exibida em forma utilizável.
            Os quatro caracteres finais existem só para distinguir uma credencial da outra.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_tools(socket) do
    tenant = socket.assigns.current_tenant
    tools = Sources.list_connected_tools(tenant)

    socket
    |> assign(tools: tools)
    # A derivação vem de `observation_ended?/1`, a mesma função que o filtro de coleta
    # usa. Dois caminhos discordariam, e a tela mostraria como encerrado o que a
    # plataforma continua coletando.
    |> assign(ended: Map.new(tools, &{&1.id, Sources.observation_ended_at(&1)}))
    |> assign(history: Map.new(tools, &{&1.id, Sources.observation_history(tenant, &1)}))
    |> assign_new(:ending, fn -> nil end)
    |> assign_new(:resuming, fn -> nil end)
    |> assign_new(:open_history, fn -> [] end)
  end

  defp all_credentials(socket), do: Enum.flat_map(socket.assigns.tools, & &1.credentials)

  defp status_label("active"), do: "ativa"
  defp status_label("needs_attention"), do: "precisa de atenção"
  defp status_label("disabled"), do: "desativada"

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
