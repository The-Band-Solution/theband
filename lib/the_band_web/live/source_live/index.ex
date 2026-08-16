defmodule TheBandWeb.SourceLive.Index do
  @moduledoc """
  `/tools` — conectar e listar ferramentas (US1).

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
     |> assign(
       page_title: "Tools",
       form_open: false,
       renaming: nil,
       adding: nil,
       correcting: nil
     )
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
         |> put_flash(:info, "#{tool.tool_type} connected, credential validated.")
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
           "The credential is valid but lacks the required scopes: #{Enum.join(missing, ", ")}. " <>
             "Without them the collection would return zero teams, which is worse than failing. Nothing was saved."
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

  # Trocar o token de uma ferramenta **em observação**, sem encerrar nada.
  #
  # `Sources.add_credential/3` existia desde a feature 001 e a tela nunca a chamava: o único
  # campo de credencial nova vivia dentro do fluxo de retomada, que exige ter encerrado
  # antes. Quem só queria trocar um token expirado era empurrado a encerrar a observação —
  # e encerrar marca equipes, vínculos e pessoas como não mais observados. O caminho barato
  # existia no domínio e não tinha porta.
  def handle_event("add_credential", %{"tool_id" => tool_id} = params, socket) do
    tenant = socket.assigns.current_tenant

    with {:ok, tool} <- Sources.fetch_connected_tool(tenant, tool_id),
         {:ok, credential} <- Sources.add_credential(tenant, tool, params) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         "Credential #{credential.label} added and validated. " <>
           "Nothing was ended, and no data was marked."
       )
       |> assign(adding: nil)
       |> load_tools()}
    else
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "The tool refused the credential. Nothing was saved.")}

      {:error, {:missing_scopes, escopos}} ->
        {:noreply,
         put_flash(socket, :error, "The credential lacks scopes: #{Enum.join(escopos, ", ")}.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save: #{errors(changeset)}")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to validate the credential: #{inspect(reason)}")}
    end
  end

  def handle_event("ask_correct", %{"id" => id}, socket),
    do: {:noreply, assign(socket, correcting: id)}

  def handle_event("cancel_correct", _params, socket),
    do: {:noreply, assign(socket, correcting: nil)}

  def handle_event("correct_identity", %{"tool_id" => id} = params, socket) do
    case Sources.correct_identity(socket.assigns.current_tenant, id, params) do
      {:ok, tool} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration corrected to #{tool.organization_login}.")
         |> assign(correcting: nil)
         |> load_tools()}

      # A janela pode ter fechado entre a tela ter sido carregada e o clique: uma coleta
      # que terminou no meio. A recusa vem do domínio, e não da ausência do botão.
      {:error, :already_observed} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "This tool has already collected data. Correcting the registration is no longer " <>
             "possible — another organization is another tool. End the observation and " <>
             "connect the other one."
         )
         |> assign(correcting: nil)
         |> load_tools()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save: #{errors(changeset)}")}
    end
  end

  def handle_event("ask_add_credential", %{"id" => id}, socket),
    do: {:noreply, assign(socket, adding: id)}

  def handle_event("cancel_add_credential", _params, socket),
    do: {:noreply, assign(socket, adding: nil)}

  # Renomear abre um campo na própria linha, e não uma tela: o rótulo é o único campo
  # editável de uma credencial, e uma tela inteira para um campo faria parecer que há mais.
  def handle_event("edit_credential", %{"id" => id}, socket),
    do: {:noreply, assign(socket, renaming: id)}

  def handle_event("cancel_rename", _params, socket),
    do: {:noreply, assign(socket, renaming: nil)}

  def handle_event("rename_credential", %{"credential_id" => id, "label" => label}, socket) do
    case Sources.rename_credential(socket.assigns.current_tenant, id, label) do
      {:ok, credential} ->
        {:noreply,
         socket
         |> put_flash(:info, "Credential renamed to #{credential.label}.")
         |> assign(renaming: nil)
         |> load_tools()}

      {:error, :blank_label} ->
        {:noreply, put_flash(socket, :error, "The label cannot be empty.")}

      {:error, :not_found} ->
        {:noreply, socket |> put_flash(:error, "Credential not found.") |> assign(renaming: nil)}
    end
  end

  def handle_event("destroy_credential", %{"id" => id}, socket) do
    case Sources.destroy_credential(socket.assigns.current_tenant, id) do
      {:ok, credential} ->
        {:noreply,
         socket
         |> put_flash(:info, "Credential #{credential.label} destroyed. The secret is gone.")
         |> load_tools()}

      # A recusa nomeia o caminho certo. Dizer só "não pode" deixaria quem quer parar de
      # coletar sem saber como — e é justamente o que a pessoa estava tentando fazer.
      {:error, :last_active_credential} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This is the only active credential. To stop collecting, end the observation."
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Credential not found.")}
    end
  end

  def handle_event("clear_attention", %{"id" => id}, socket) do
    tenant = socket.assigns.current_tenant

    case Sources.fetch_connected_tool(tenant, id) do
      {:ok, tool} ->
        {:ok, _} = Sources.clear_needs_attention(tool)

        {:noreply,
         socket
         |> put_flash(:info, "Attention state cleared for #{tool.organization_login}.")
         |> load_tools()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tool not found.")}
    end
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
           "and only those the source still shows."
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
           "The credential lacks the scopes: #{Enum.join(faltando, ", ")}"
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
           "#{resultado.marked.people} person(s), #{resultado.marked.teams} team(s) and " <>
           "#{resultado.marked.links} link(s) marked. " <>
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
          Which tools this organisation uses, and with which service accounts.
        </:subtitle>
        <:actions>
          <.button phx-click="toggle_form">
            {if @form_open, do: "Cancel", else: "Connect tool"}
          </.button>
        </:actions>
      </.header>

      <div :if={@form_open} class="card bg-base-200 p-6">
        <form id="connect-tool" phx-submit="connect" class="space-y-4">
          <div class="grid gap-4 sm:grid-cols-2">
            <label class="fieldset">
              <span class="label-text">Tool type</span>
              <select name="tool_type" class="select select-bordered">
                <option value="github">github</option>
              </select>
            </label>

            <label class="fieldset">
              <span class="label-text">Instance</span>
              <input
                name="instance_url"
                value="https://github.com"
                class="input input-bordered"
                placeholder="https://github.com or your own installation"
              />
            </label>

            <label class="fieldset">
              <span class="label-text">Organisation to observe</span>
              <input name="organization_login" class="input input-bordered" placeholder="my-org" />
            </label>

            <label class="fieldset">
              <span class="label-text">Credential label</span>
              <input name="label" class="input input-bordered" placeholder="service account" />
            </label>
          </div>

          <label class="fieldset">
            <span class="label-text">Credential</span>
            <input type="password" name="secret" class="input input-bordered" autocomplete="off" />
            <span class="label-text-alt opacity-70">
              Validated against the tool before being written. After that it is never shown again.
            </span>
          </label>

          <.button type="submit" variant="primary">Validate and connect</.button>
        </form>
      </div>

      <div :if={@tools == []} class="alert">
        <p>No tool connected yet. Connect one so the platform can collect.</p>
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
              <%!-- A situação vem de `Sources.situacao/1`, e não de coluna: ela era um terceiro
                    lugar guardando o mesmo fato, e discordava dos eventos — issue #178. --%>
              <span
                :if={!@ended[tool.id]}
                class={[
                  "badge",
                  @situacao[tool.id] == :active && "badge-success",
                  @situacao[tool.id] == :needs_attention && "badge-warning"
                ]}
              >
                {status_label(@situacao[tool.id])}
              </span>
            </div>
            <div class="text-sm opacity-70">{tool.instance_url}</div>
            <div class="text-sm opacity-70">observed organisation: {tool.organization_login}</div>

            <button
              :if={@editavel[tool.id] and @correcting != tool.id}
              class="btn btn-xs btn-ghost mt-1"
              phx-click="ask_correct"
              phx-value-id={tool.id}
            >
              fix registration
            </button>

            <form
              :if={@correcting == tool.id}
              id={"correct-#{tool.id}"}
              phx-submit="correct_identity"
              class="mt-2 flex flex-wrap gap-2 items-end p-3 rounded bg-base-200"
            >
              <input type="hidden" name="tool_id" value={tool.id} />
              <label class="fieldset">
                <span class="label-text text-xs">Instance</span>
                <input
                  name="instance_url"
                  value={tool.instance_url}
                  class="input input-bordered input-sm"
                />
              </label>
              <label class="fieldset">
                <span class="label-text text-xs">Organisation</span>
                <input
                  name="organization_login"
                  value={tool.organization_login}
                  class="input input-bordered input-sm"
                />
              </label>
              <.button type="submit" variant="primary">Fix registration</.button>
              <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_correct">
                cancel
              </button>
              <p class="basis-full text-xs opacity-70">
                This tool <strong>has not collected anything yet</strong>, which is why the
                registration can still be fixed. After the first sync this stops existing:
                another organisation becomes another tool, because data already collected
                would point at a source that did not produce it.
              </p>
            </form>
          </div>

          <div class="text-right text-sm opacity-70">
            <div :if={tool.last_sync_at}>last collection: {tool.last_sync_at}</div>
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
              end observation
            </button>
            <button
              :if={@ended[tool.id]}
              class="btn btn-xs btn-outline mt-2"
              phx-click="ask_resume"
              phx-value-id={tool.id}
            >
              resume observation
            </button>
          </div>
        </div>

        <%!-- AC4 da US2: depois de retomada, a ferramenta volta a parecer ativa e o
              cartão não diria que houve encerramento. O histórico é o que preserva
              que aconteceu — e é append-only, então nunca encolhe. --%>
        <div :if={@history[tool.id] != []} class="mt-3">
          <button class="link link-hover text-xs" phx-click="toggle_history" phx-value-id={tool.id}>
            observation history ({length(@history[tool.id])})
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
            Resume the observation of {tool.organization_login}
          </div>

          <p class="mb-2 opacity-80">
            The previous credential was destroyed when the observation ended, so a new one is
            required. It is validated against the source before anything is written.
          </p>

          <p class="mb-3 opacity-80">
            The marked records <strong>do not become current again now</strong>: only the next
            collection can say whether the source still shows them. Unmarking here would assert
            an observation that did not happen.
          </p>

          <form phx-submit="resume_observation" class="flex flex-wrap gap-2 items-end">
            <input type="hidden" name="tool_id" value={tool.id} />
            <label class="fieldset">
              <span class="label-text text-xs">New credential</span>
              <input
                name="secret"
                type="password"
                class="input input-bordered input-sm"
                autocomplete="off"
                placeholder="ghp_..."
              />
            </label>
            <label class="fieldset">
              <span class="label-text text-xs">Label</span>
              <input
                name="label"
                class="input input-bordered input-sm"
                placeholder="main credential"
              />
            </label>
            <.button type="submit" variant="primary">Validate and resume</.button>
            <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_resume">
              cancel
            </button>
          </form>
        </div>

        <div :if={@ending && @ending.tool.id == tool.id} class="alert alert-error text-sm block">
          <div class="font-semibold mb-2">
            End the observation of {tool.organization_login}
          </div>

          <div class="mb-2">
            <div class="opacity-80">Will be marked as no longer observed:</div>
            <div class="font-mono">
              {@ending.impact.teams} equipe(s) — {@ending.impact.derived_teams} derivada(s) pela plataforma
            </div>
            <div class="font-mono">{@ending.impact.evidence_links} link(s)</div>
            <div class="font-mono">
              {@ending.impact.people_exclusive} person(s) known only through this organisation
            </div>
          </div>

          <div :if={@ending.impact.people_shared > 0} class="mb-2">
            <div class="opacity-80">Remain current:</div>
            <div class="font-mono">
              {@ending.impact.people_shared} person(s) — also observed in another organisation
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
              {@ending.impact.preserved_payloads} preserved payload(s), nor any person, team or link
            </div>
          </div>

          <form phx-submit="end_observation" class="flex flex-wrap gap-2 items-end">
            <input type="hidden" name="tool_id" value={tool.id} />
            <label class="fieldset">
              <span class="label-text text-xs">
                To confirm, type: <strong>{tool.organization_login}</strong>
              </span>
              <input name="confirmation" class="input input-bordered input-sm" autocomplete="off" />
            </label>
            <.button type="submit" variant="primary">End observation</.button>
            <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_end">
              cancel
            </button>
          </form>
        </div>

        <div :if={@situacao[tool.id] == :needs_attention} class="alert alert-warning text-sm">
          <div>
            <span class="font-semibold">Needs attention since {tool.needs_attention_since}.</span>
            <div>{tool.needs_attention_reason}</div>
            <button
              class="btn btn-xs btn-outline mt-2"
              phx-click="clear_attention"
              phx-value-id={tool.id}
            >
              clear the attention state
            </button>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <div class="text-sm font-semibold">Credentials</div>
            <button
              :if={@situacao[tool.id] != :ended and @adding != tool.id}
              class="btn btn-xs btn-outline"
              phx-click="ask_add_credential"
              phx-value-id={tool.id}
            >
              replace the token
            </button>
          </div>

          <form
            :if={@adding == tool.id}
            id={"add-credential-#{tool.id}"}
            phx-submit="add_credential"
            class="flex flex-wrap gap-2 items-end mb-3 p-3 rounded bg-base-200"
          >
            <input type="hidden" name="tool_id" value={tool.id} />
            <label class="fieldset">
              <span class="label-text text-xs">New token</span>
              <input
                name="secret"
                type="password"
                class="input input-bordered input-sm"
                autocomplete="off"
                placeholder="ghp_..."
              />
            </label>
            <label class="fieldset">
              <span class="label-text text-xs">Label</span>
              <input
                name="label"
                class="input input-bordered input-sm"
                placeholder="new credential"
              />
            </label>
            <.button type="submit" variant="primary">Validate and add</.button>
            <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_add_credential">
              cancel
            </button>
            <p class="basis-full text-xs opacity-70">
              The token is validated against the source <strong>before</strong>
              anything is
              written, and the previous credential stays where it is — deactivate or remove it
              once you have confirmed the new one works.
              <strong>Nothing is ended, and no data is marked.</strong>
            </p>
          </form>

          <table class="table table-sm stacked">
            <thead>
              <tr>
                <th>label</th>
                <th>credential</th>
                <th>scopes</th>
                <th>validated at</th>
                <th>state</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={credential <- tool.credentials}>
                <td>
                  <form
                    :if={@renaming == credential.id}
                    id={"rename-#{credential.id}"}
                    phx-submit="rename_credential"
                    class="flex items-center gap-1"
                  >
                    <%!-- `credential_id`, e não `id`: um input chamado `id` sobrescreve o id
                    do próprio formulário, e o LiveView passa a perder a recuperação dele. --%>
                    <input type="hidden" name="credential_id" value={credential.id} />
                    <input
                      type="text"
                      name="label"
                      value={credential.label}
                      class="input input-xs input-bordered w-40"
                      autofocus
                    />
                    <button type="submit" class="btn btn-xs btn-primary">save</button>
                    <button type="button" class="btn btn-xs btn-ghost" phx-click="cancel_rename">
                      cancel
                    </button>
                  </form>
                  <span :if={@renaming != credential.id}>{credential.label}</span>
                </td>
                <td class="font-mono text-xs">{ToolCredential.masked(credential)}</td>
                <td class="text-xs">{Enum.join(credential.scopes, ", ")}</td>
                <td class="text-xs">{credential.validated_at}</td>
                <td>
                  <span class={["badge badge-sm", credential.active && "badge-success"]}>
                    {if credential.active, do: "active", else: "inactive"}
                  </span>
                </td>
                <td class="flex flex-wrap gap-1">
                  <button
                    class="btn btn-xs btn-ghost"
                    phx-click="toggle_credential"
                    phx-value-id={credential.id}
                    phx-value-active={to_string(!credential.active)}
                  >
                    {if credential.active, do: "deactivate", else: "activate"}
                  </button>
                  <button
                    :if={@renaming != credential.id}
                    class="btn btn-xs btn-ghost"
                    phx-click="edit_credential"
                    phx-value-id={credential.id}
                  >
                    rename
                  </button>
                  <button
                    class="btn btn-xs btn-ghost text-error"
                    phx-click="destroy_credential"
                    phx-value-id={credential.id}
                    data-confirm="Destroy this credential? The secret stops existing, and this cannot be undone."
                  >
                    remove
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
          <p class="text-xs opacity-60 mt-2">
            The credential is encrypted at rest and is never shown in usable form. The last four
            characters exist only to tell one credential from another.
          </p>
          <p class="text-xs opacity-60 mt-2">
            The instance and the organisation are <span class="font-semibold">the identity of the tool</span>, and can only be fixed
            <span class="font-semibold">while it has not collected anything</span>
            — a registration mistake is fixable, the source of already collected data is not.
            After the first sync, what you replace is the token: the new credential joins the old
            one, and nothing is ended or marked. To stop observing this organisation, the way is
            <span class="font-semibold">end the observation</span>
            — the collected data stays queryable, marked as no longer observed.
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
    |> assign(situacao: Map.new(tools, &{&1.id, Sources.situacao(&1)}))
    # Corrigir o cadastro só existe enquanto nada foi coletado. Fica no assign, e não no
    # markup, porque é uma medida — três consultas por ferramenta — e a tela não decide
    # por conta própria quando a janela fechou.
    |> assign(editavel: Map.new(tools, &{&1.id, Sources.identity_editable?(tenant, &1)}))
    |> assign(history: Map.new(tools, &{&1.id, Sources.observation_history(tenant, &1)}))
    |> assign_new(:ending, fn -> nil end)
    |> assign_new(:resuming, fn -> nil end)
    |> assign_new(:open_history, fn -> [] end)
  end

  defp all_credentials(socket), do: Enum.flat_map(socket.assigns.tools, & &1.credentials)

  # Três respostas, e `disabled` não é uma delas: nenhuma linha do código a escrevia, e um estado
  # que nunca acontece é um estado que quem lê precisa considerar à toa.
  defp status_label(:active), do: "active"
  defp status_label(:needs_attention), do: "needs attention"
  defp status_label(:ended), do: "observation ended"

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
