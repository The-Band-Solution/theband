defmodule TheBandWeb.AILive.Index do
  @moduledoc """
  `/ai` — a chave do provedor de modelo de linguagem desta organização.

  Só perfil `admin`, como `/tools`: quem declara a credencial declara quem paga a conta.

  ## A tela nomeia de onde a chave vem, e não só se existe

  São três fatos, e não dois. Gravada para este tenant é uma coisa; herdada do `API_KEY` do
  processo é outra — ela é **compartilhada por toda instalação**, e numa com dois tenants a
  conta de um pagaria pelo outro. Mostrar as duas como "configurado" esconderia isso.

  ## Nada é gravado sem ter sido conferido

  A chave é conferida contra `/models` **antes** de qualquer escrita, e cada recusa tem
  frase própria — recusada, provedor inalcançável, e chave aceita sem modelo algum. As três
  pedem ação diferente de quem lê: gerar outra chave, tentar de novo, e olhar a conta.
  """

  use TheBandWeb, :live_view

  alias TheBand.AI
  alias TheBand.AI.ProviderCredential

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "AI provider") |> carregar()}
  end

  @impl true
  def handle_event("save", params, socket) do
    tenant = socket.assigns.current_tenant

    case AI.put(tenant, params, socket.assigns.current_user.id) do
      {:ok, cred} ->
        {:noreply,
         socket
         |> put_flash(:info, "Key checked against the provider and saved (#{masked(cred)}).")
         |> carregar()}

      # Cada recusa diz o que fazer em seguida, e todas terminam em "nothing was saved" —
      # sem isso, quem lê fica sem saber se a chave anterior sobreviveu.
      {:error, {:rejeitada, motivo}} ->
        {:noreply,
         put_flash(socket, :error, "The provider refused the key: #{motivo}. Nothing was saved.")}

      {:error, {:indisponivel, motivo}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Could not reach the provider: #{motivo}. The key was not checked, " <>
             "so nothing was saved — it may well be valid."
         )}

      {:error, {:sem_modelos, motivo}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "#{motivo}. A key that reaches no model would fail on the first generation, " <>
             "an hour later and for somebody else. Nothing was saved."
         )}

      {:error, {:modelo_desconhecido, pedido, disponiveis}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This key does not reach the model #{pedido}. It reaches: " <>
             "#{Enum.join(Enum.take(disponiveis, 8), ", ")}. Nothing was saved."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save: #{errors(changeset)}")}
    end
  end

  def handle_event("delete", _params, socket) do
    case AI.delete(socket.assigns.current_tenant) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Key removed. The secret is gone — there is no history of it.")
         |> carregar()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "There is no key saved for this organisation.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Language model provider
        <:subtitle>
          Which account this organisation uses to generate competence profiles.
        </:subtitle>
      </.header>

      <div class="card bg-base-200 p-6 space-y-3">
        <div class="text-sm font-semibold">Key in use</div>

        <div :if={match?({:tenant, _}, @origem)} class="space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <span class="badge badge-success">saved for this organisation</span>
            <span class="font-mono text-sm">{masked(elem(@origem, 1))}</span>
          </div>

          <dl class="grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
            <div>
              <dt class="opacity-70">provider</dt>
              <dd class="font-mono">{elem(@origem, 1).provider}</dd>
            </div>
            <div>
              <dt class="opacity-70">model</dt>
              <dd class="font-mono">
                <span :if={elem(@origem, 1).default_model}>{elem(@origem, 1).default_model}</span>
                <%!-- Modelo em branco é escolha, e não falta: significa o padrão do provedor.
                      Um travessão aqui faria parecer que alguém esqueceu de preencher. --%>
                <.absent
                  :if={is_nil(elem(@origem, 1).default_model)}
                  reason="the provider default, because none was chosen"
                />
              </dd>
            </div>
            <div>
              <dt class="opacity-70">checked against the provider at</dt>
              <dd class="font-mono">{elem(@origem, 1).validated_at}</dd>
            </div>
            <div :if={elem(@origem, 1).last_failure_at}>
              <dt class="opacity-70">last failure</dt>
              <dd class="font-mono">
                {elem(@origem, 1).last_failure_at} — {elem(@origem, 1).last_failure_reason}
              </dd>
            </div>
          </dl>

          <button
            class="btn btn-xs btn-outline btn-error"
            phx-click="delete"
            data-confirm="Remove this key? The secret stops existing, and this cannot be undone. Generation falls back to the server environment key, if there is one."
          >
            remove the key
          </button>
        </div>

        <%!-- O aviso não é sobre a chave estar errada: ela funciona. É sobre ela ser do
              **processo**, e não desta organização — e isso só aparece na fatura. --%>
        <div :if={match?({:ambiente, _}, @origem)} class="alert alert-warning block text-sm">
          <div class="font-semibold">
            Coming from the server environment (••••{elem(@origem, 1)}), not from this
            organisation.
          </div>
          <p class="mt-1 opacity-90">
            Generation works. But this key belongs to the installation: every organisation on
            this server uses it, and one organisation's usage lands on another's bill. Saving a
            key below makes this organisation use its own account.
          </p>
        </div>

        <div :if={@origem == :nenhuma}>
          <.absent reason="No key saved, and none in the server environment — profile generation cannot run." />
        </div>
      </div>

      <div class="card bg-base-200 p-6">
        <form id="ai-credential" phx-submit="save" class="space-y-4">
          <label class="form-control flex flex-col gap-1">
            <span class="label-text">API key</span>
            <input
              type="password"
              name="secret"
              class="input input-bordered"
              autocomplete="off"
              placeholder="sk-..."
            />
            <span class="label-text-alt opacity-70">
              Checked against the provider before being written, encrypted at rest, and never
              shown again — only the last four characters, so one key can be told from another.
            </span>
          </label>

          <label class="form-control flex flex-col gap-1">
            <span class="label-text">Model (optional)</span>
            <input
              name="default_model"
              class="input input-bordered"
              autocomplete="off"
              placeholder="leave empty for the provider default"
            />
            <span class="label-text-alt opacity-70">
              Only accepted if the provider lists it for this key. A name it does not list is
              refused here, and not silently replaced.
            </span>
          </label>

          <.button type="submit" variant="primary">Check and save</.button>
        </form>

        <p class="text-xs opacity-60 mt-4">
          Saving replaces the previous key. There is no history of secrets: an old secret kept
          around is attack surface with no use.
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp carregar(socket),
    do: assign(socket, origem: AI.origem_da_chave(socket.assigns.current_tenant))

  defp masked(cred), do: ProviderCredential.masked(cred)

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
