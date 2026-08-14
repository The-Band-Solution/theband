defmodule TheBandWeb.RolesLive.Index do
  @moduledoc """
  `/roles` — o catálogo de papéis que a organização reconhece.

  ## Por que esta tela existe

  Medido em 2026-08-14: **101 evidências de vínculo pessoa-equipe, zero vínculos, zero
  papéis**. Os três números são o mesmo fato — o vínculo da ontologia exige papel, e nenhum
  havia sido cadastrado.

  ## A tela sugere, e não cadastra

  A ontologia nomeia quatro papéis do Scrum, e eles aparecem como sugestão de preenchimento.
  Cadastrá-los sozinha faria a plataforma **reconhecer no lugar da organização** —
  `eo.organizational_role` é, por definição, papel *reconhecido pela organização*.

  ## O estado vazio diz o que está esperando

  Uma tela vazia que diz "nenhum papel cadastrado" informa metade. A outra metade é **quantas
  evidências dependem disso** — sem ela, ninguém sabe que a lista vazia é um bloqueio e não uma
  escolha.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 25

  @tabelas [{"roles", [:code, :name], nil}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Roles", renaming: nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  def handle_event("create", %{"code" => code, "name" => name}, socket) do
    case EO.create_role(socket.assigns.current_tenant, %{code: code, name: name}) do
      {:ok, papel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role #{papel.code} registered.")
         |> load()}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Could not register: #{errors(changeset)}")}
    end
  end

  def handle_event("ask_rename", %{"id" => id}, socket),
    do: {:noreply, assign(socket, renaming: id)}

  def handle_event("cancel_rename", _params, socket),
    do: {:noreply, assign(socket, renaming: nil)}

  def handle_event("rename", %{"role_id" => id, "name" => name}, socket) do
    case EO.rename_role(socket.assigns.current_tenant, id, name) do
      {:ok, papel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Renamed to #{papel.name}. The code is unchanged.")
         |> assign(renaming: nil)
         |> load()}

      {:error, :blank_name} ->
        {:noreply, put_flash(socket, :error, "The name cannot be empty.")}

      {:error, :not_found} ->
        {:noreply, socket |> put_flash(:error, "Role not found.") |> assign(renaming: nil)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case EO.delete_role(socket.assigns.current_tenant, id) do
      {:ok, papel} ->
        {:noreply, socket |> put_flash(:info, "Role #{papel.code} removed.") |> load()}

      # A recusa diz **quantos**, e não só que não pode: quem lê precisa saber o tamanho do
      # que a impede, como no impacto exibido antes de encerrar uma observação.
      {:error, {:in_use, quantos}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "#{quantos} membership(s) point to this role. Remove them first, or keep the role."
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Role not found.")}
    end
  end

  defp caminho(socket, id, mudancas), do: ~p"/roles?#{Tabela.query(socket, id, mudancas)}"

  # Mesma forma que `SourceLive.Index` usa: a mensagem do changeset chega à tela nomeando o
  # campo, e não como `inspect` de estrutura.
  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    estado = socket.assigns.tabelas["roles"]

    papeis = EO.list_roles(tenant)

    filtrados =
      Enum.filter(papeis, fn p ->
        estado.busca == "" or
          String.contains?(String.downcase("#{p.code} #{p.name}"), String.downcase(estado.busca))
      end)

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(roles: Enum.take(filtrados, @por_pagina))
    |> assign(encontrados: length(filtrados))
    # Quantas evidências esperam por um papel — é o que transforma "lista vazia" em
    # "bloqueio", e sem ele ninguém sabe que a ausência tem custo.
    |> assign(evidencias_pendentes: EO.count_evidence_pending_role(tenant))
    |> assign(sugestoes: EO.suggested_roles())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Roles
        <:subtitle>
          What this organisation recognises as an organisational role
        </:subtitle>
      </.header>

      <div :if={@roles == [] and @evidencias_pendentes > 0} class="alert block">
        <p class="font-semibold">No role registered yet.</p>
        <p class="text-sm">
          <strong>{@evidencias_pendentes}</strong>
          observed participations are waiting for one: the link this platform records requires a
          role, and none exists. Until a role is registered, none of them becomes a membership.
        </p>
      </div>

      <div class="card bg-base-200 p-4 space-y-3">
        <div class="text-sm font-semibold">Register a role</div>

        <form phx-submit="create" class="flex flex-wrap gap-2 items-end">
          <label class="form-control">
            <span class="label-text text-xs">Code</span>
            <input name="code" class="input input-bordered input-sm" placeholder="developer" />
          </label>
          <label class="form-control">
            <span class="label-text text-xs">Name</span>
            <input name="name" class="input input-bordered input-sm" placeholder="Developer" />
          </label>
          <.button type="submit" variant="primary">Register</.button>
        </form>

        <%!-- Sugestão, e **não** cadastro. A ontologia nomeia quatro papéis do Scrum; quem
              reconhece o papel é a organização, e clicar é a declaração dela. --%>
        <div class="text-xs opacity-70">
          The ontology names these. They are <strong>suggestions</strong>
          — nothing is registered until you say so.
        </div>
        <div class="flex flex-wrap gap-1">
          <button
            :for={sugestao <- @sugestoes}
            type="button"
            class="btn btn-xs btn-outline"
            phx-click="create"
            phx-value-code={sugestao.code}
            phx-value-name={sugestao.name}
          >
            {sugestao.name}
          </button>
        </div>
      </div>

      <.data_table
        id="roles"
        rows={@roles}
        estado={@tabelas["roles"]}
        por_pagina={@por_pagina}
        total={@encontrados}
        onde="code and name"
        vazio="No role matches this search."
      >
        <:col :let={papel} field={:code} label="code" class="font-mono text-xs">
          {papel.code}
        </:col>
        <:col :let={papel} field={:name} label="name">
          <form
            :if={@renaming == papel.id}
            id={"rename-#{papel.id}"}
            phx-submit="rename"
            class="flex items-center gap-1"
          >
            <input type="hidden" name="role_id" value={papel.id} />
            <input
              type="text"
              name="name"
              value={papel.name}
              class="input input-xs input-bordered w-40"
            />
            <button type="submit" class="btn btn-xs btn-primary">save</button>
            <button type="button" class="btn btn-xs btn-ghost" phx-click="cancel_rename">
              cancel
            </button>
          </form>
          <span :if={@renaming != papel.id}>{papel.name}</span>
        </:col>
        <:col :let={papel} label="">
          <button
            :if={@renaming != papel.id}
            class="btn btn-xs btn-ghost"
            phx-click="ask_rename"
            phx-value-id={papel.id}
          >
            rename
          </button>
          <button
            class="btn btn-xs btn-ghost text-error"
            phx-click="delete"
            phx-value-id={papel.id}
            data-confirm="Remove this role? Memberships pointing to it block the removal."
          >
            remove
          </button>
        </:col>
      </.data_table>

      <p class="text-xs opacity-60">
        The <strong>code</strong>
        is the identity: memberships reference it, and renaming changes only the label. A role
        with memberships pointing to it cannot be removed — the refusal says how many.
      </p>
    </Layouts.app>
    """
  end
end
