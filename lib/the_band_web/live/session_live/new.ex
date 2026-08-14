defmodule TheBandWeb.SessionLive.New do
  @moduledoc """
  Entrada na plataforma.

  > **Lacuna declarada.** Não há senha nesta entrega: a tela lista as pessoas
  > usuárias cadastradas e a sessão é aberta por escolha. O que está implementado
  > de verdade é o **escopo por tenant**, que atravessa toda consulta e é
  > verificado com dois tenants povoados (SC-008). Autenticação é feature própria,
  > e aparece como não entregue no `sprint-review.md` — nunca como pronta.
  """

  use TheBandWeb, :live_view

  alias TheBand.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, users: Tenants.list_all_users(), page_title: "Sign in")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Sign in
        <:subtitle>Choose which organisation and person you want to work as.</:subtitle>
      </.header>

      <div :if={@users == []} class="alert alert-warning">
        <div>
          <p class="font-semibold">No organisation registered yet.</p>
          <p class="text-sm">
            Run <code>mix run priv/repo/seeds.exs</code> to create the example organisations.
          </p>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <form :for={user <- @users} action={~p"/session"} method="post">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="hidden" name="user_id" value={user.id} />
          <button class="card w-full bg-base-200 hover:bg-base-300 text-left p-4 cursor-pointer">
            <div class="font-semibold">{user.tenant.name}</div>
            <div class="text-sm opacity-70">{user.email}</div>
            <div class="mt-1">
              <span class={["badge badge-sm", user.role == "admin" && "badge-primary"]}>
                {user.role}
              </span>
            </div>
          </button>
        </form>
      </div>

      <p class="text-xs opacity-60">
        Password authentication is not part of this delivery and is recorded as a gap. The
        isolation between organisations, that one is implemented and tested.
      </p>
    </Layouts.app>
    """
  end
end
