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
     |> assign(page_title: "Ferramentas", form_open: false)
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
           "A credencial foi recusada pela ferramenta. Nada foi gravado."
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
        {:noreply, put_flash(socket, :error, "Não foi possível gravar: #{errors(changeset)}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Falha ao validar a credencial: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_credential", %{"id" => id, "active" => active}, socket) do
    credential = Enum.find(all_credentials(socket), &(&1.id == id))

    if credential do
      Sources.set_credential_active(credential, active == "true")
    end

    {:noreply, load_tools(socket)}
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
            {if @form_open, do: "Cancelar", else: "Conectar ferramenta"}
          </.button>
        </:actions>
      </.header>

      <div :if={@form_open} class="card bg-base-200 p-6">
        <form id="conectar-ferramenta" phx-submit="connect" class="space-y-4">
          <div class="grid gap-4 sm:grid-cols-2">
            <label class="form-control">
              <span class="label-text">Tipo de ferramenta</span>
              <select name="tool_type" class="select select-bordered">
                <option value="github">github</option>
              </select>
            </label>

            <label class="form-control">
              <span class="label-text">Instância</span>
              <input
                name="instance_url"
                value="https://github.com"
                class="input input-bordered"
                placeholder="https://github.com ou a instalação própria"
              />
            </label>

            <label class="form-control">
              <span class="label-text">Organização a observar</span>
              <input name="organization_login" class="input input-bordered" placeholder="minha-org" />
            </label>

            <label class="form-control">
              <span class="label-text">Rótulo da credencial</span>
              <input name="label" class="input input-bordered" placeholder="conta de serviço" />
            </label>
          </div>

          <label class="form-control">
            <span class="label-text">Credencial</span>
            <input type="password" name="secret" class="input input-bordered" autocomplete="off" />
            <span class="label-text-alt opacity-70">
              Validada contra a ferramenta antes de ser gravada. Depois disso não é mais exibida.
            </span>
          </label>

          <.button type="submit" variant="primary">Validar e conectar</.button>
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
              <span class={[
                "badge",
                tool.status == "active" && "badge-success",
                tool.status == "needs_attention" && "badge-warning",
                tool.status == "disabled" && "badge-ghost"
              ]}>
                {status_label(tool.status)}
              </span>
            </div>
            <div class="text-sm opacity-70">{tool.instance_url}</div>
            <div class="text-sm opacity-70">organização observada: {tool.organization_login}</div>
          </div>

          <div class="text-right text-sm opacity-70">
            <div :if={tool.last_sync_at}>última coleta: {tool.last_sync_at}</div>
            <div :if={is_nil(tool.last_sync_at)}>nunca sincronizada</div>
          </div>
        </div>

        <div :if={tool.status == "needs_attention"} class="alert alert-warning text-sm">
          <div>
            <span class="font-semibold">Precisa de atenção desde {tool.needs_attention_since}.</span>
            <div>{tool.needs_attention_reason}</div>
          </div>
        </div>

        <div>
          <div class="text-sm font-semibold mb-2">Credenciais</div>
          <table class="table table-sm">
            <thead>
              <tr>
                <th>rótulo</th>
                <th>credencial</th>
                <th>escopos</th>
                <th>validada em</th>
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
    assign(socket, tools: Sources.list_connected_tools(socket.assigns.current_tenant))
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
