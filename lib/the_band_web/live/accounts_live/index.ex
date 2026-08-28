defmodule TheBandWeb.AccountsLive.Index do
  @moduledoc """
  `/accounts` — as contas do tenant, para quem administra (feature 045, US1).

  Cadastro é ato administrativo (assumption da spec): não há auto-registro, e a
  senha nasce por reinício — a temporária aparece UMA vez nesta tela (FR-013),
  vive só no assign, e o próximo evento a apaga. Ela não é gravada em claro nem
  logada; quem administra a entrega por canal próprio, fora da plataforma.

  A marca de administrador (`users.role`) é gestão, não visão (FR-022): dar a
  marca aqui não abre painel nenhum — escopo se concede em /access-scopes.
  """

  use TheBandWeb, :live_view

  alias TheBand.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Accounts", temporaria: nil, erro: nil)
     |> carregar()}
  end

  defp carregar(socket) do
    assign(socket, users: Tenants.list_users(socket.assigns.current_tenant))
  end

  @impl true
  def handle_event("criar", %{"email" => email, "name" => name}, socket) do
    case Tenants.create_user(socket.assigns.current_tenant, %{
           "email" => email,
           "name" => name,
           "role" => "member"
         }) do
      {:ok, _} ->
        {:noreply, socket |> assign(temporaria: nil, erro: nil) |> carregar()}

      {:error, changeset} ->
        {:noreply,
         assign(socket, erro: "Conta não criada: #{motivo(changeset)}", temporaria: nil)}
    end
  end

  def handle_event("reset", %{"id" => user_id}, socket) do
    case Tenants.reset_password(
           socket.assigns.current_tenant,
           user_id,
           socket.assigns.current_user.id
         ) do
      {:ok, temporaria} ->
        {:noreply,
         socket
         |> assign(temporaria: %{user_id: user_id, senha: temporaria}, erro: nil)
         |> carregar()}

      {:error, _} ->
        {:noreply, assign(socket, erro: "Conta não encontrada.", temporaria: nil)}
    end
  end

  defp motivo(changeset) do
    Enum.map_join(changeset.errors, "; ", fn {campo, {msg, _}} -> "#{campo} #{msg}" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
      operacao_menu={assigns[:operacao_menu]}
    >
      <.header>
        Accounts
        <:subtitle>
          Quem entra na plataforma. Cadastro é ato de administração; a senha nasce
          pelo reinício, e a temporária aparece uma única vez.
        </:subtitle>
      </.header>

      <div :if={@erro} role="alert" class="alert alert-error font-serif text-sm">{@erro}</div>

      <div
        :if={@temporaria}
        role="status"
        class="card border-2 border-warning bg-base-200 p-4 text-sm"
      >
        <p class="font-semibold">Senha temporária — aparece só agora:</p>
        <p class="font-mono text-lg">{@temporaria.senha}</p>
        <p class="opacity-70">
          Entregue por canal próprio. A primeira entrada com ela obriga a definição
          de uma senha nova.
        </p>
      </div>

      <div class="card bg-base-200 p-6">
        <h2 class="mb-3 text-sm font-semibold opacity-70">Create account</h2>
        <form phx-submit="criar" class="flex flex-wrap items-end gap-3">
          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">E-mail</span>
            <input type="email" name="email" required class="input input-bordered" />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">Name</span>
            <input type="text" name="name" class="input input-bordered" />
          </label>
          <button type="submit" class="btn btn-primary">Create</button>
        </form>
        <p class="mt-2 text-xs opacity-60">
          A conta nasce sem senha e sem marca de administrador — a entrada só passa a
          existir depois do primeiro reinício de senha.
        </p>
      </div>

      <div class="card bg-base-200 overflow-x-auto p-0">
        <table class="table">
          <thead>
            <tr>
              <th>E-mail</th>
              <th>Name</th>
              <th>Gestão</th>
              <th>Senha</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={user <- @users}>
              <td>{user.email}</td>
              <td>{user.name}</td>
              <td>
                <span :if={user.role == "admin"} class="badge badge-primary badge-sm">
                  administrador
                </span>
                <span :if={user.role != "admin"} class="opacity-50">—</span>
              </td>
              <td>
                <span :if={user.password_hash && !user.must_change_password}>definida</span>
                <span :if={user.password_hash && user.must_change_password} class="text-warning">
                  temporária pendente
                </span>
                <span :if={!user.password_hash} class="opacity-60">
                  sem senha — a entrada recusa
                </span>
              </td>
              <td class="text-right">
                <button phx-click="reset" phx-value-id={user.id} class="btn btn-ghost btn-xs">
                  Reset password
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
