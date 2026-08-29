defmodule TheBandWeb.ProfileLive.Index do
  @moduledoc """
  `/profile` — a própria conta (feature 045, US3), protótipo aprovado.

  O que a pessoa muda aqui: o próprio nome e a própria senha (com a atual —
  FR-012). O que ela VÊ e não muda: os escopos vigentes com a origem de cada um,
  e o elo com a pessoa observada — concessão e elo são atos de quem administra,
  e a tela diz isso em vez de esconder os campos.

  A troca de senha POSTa num controller: trocar gira o token de sessão
  (FR-015), e é o cookie desta sessão que precisa do token novo.
  """

  use TheBandWeb, :live_view

  alias TheBand.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Profile", ok: nil, erro: nil)
     |> carregar()}
  end

  defp carregar(socket) do
    tenant = socket.assigns.current_tenant
    user = socket.assigns.current_user

    assign(socket,
      escopos: Tenants.scopes(tenant, user),
      pessoa: Tenants.person_of_user(user)
    )
  end

  @impl true
  def handle_event("nome", %{"name" => nome}, socket) do
    case Tenants.update_name(
           socket.assigns.current_tenant,
           socket.assigns.current_user.id,
           nome
         ) do
      {:ok, user} ->
        {:noreply,
         assign(socket,
           current_user: user,
           ok: dgettext("sistema", "Nome atualizado."),
           erro: nil
         )}

      {:error, _} ->
        {:noreply, assign(socket, erro: dgettext("errors", "Nome não atualizado."), ok: nil)}
    end
  end

  defp origem_rotulo(:floor), do: "piso do elo — ninguém concede"
  defp origem_rotulo(:derived_team), do: "derivado do vínculo pessoa-equipe"
  defp origem_rotulo(:derived_project), do: "derivado de equipe→projeto declarado"
  defp origem_rotulo(:granted), do: "concedido"

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
        Profile
        <:subtitle>Your account, your password, and what your access reaches.</:subtitle>
      </.header>

      <div :if={@erro} role="alert" class="alert alert-error font-serif text-sm">{@erro}</div>
      <div :if={@ok} role="status" class="alert alert-success text-sm">{@ok}</div>

      <div class="grid gap-6 sm:grid-cols-2">
        <div class="card bg-base-200 p-6">
          <h2 class="mb-3 text-sm font-semibold opacity-70">Identity</h2>
          <form phx-submit="nome" class="flex flex-col gap-3">
            <label class="flex flex-col gap-1">
              <span class="text-[13px] font-semibold opacity-70">Name</span>
              <input
                type="text"
                name="name"
                value={@current_user.name}
                class="input input-bordered w-full"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-[13px] font-semibold opacity-70">E-mail</span>
              <input
                type="email"
                value={@current_user.email}
                disabled
                class="input input-bordered w-full opacity-60"
              />
              <span class="text-xs opacity-60">
                O e-mail identifica a sua conta na entrada e não muda aqui.
              </span>
            </label>
            <div class="flex justify-end">
              <button type="submit" class="btn btn-primary btn-sm">Save</button>
            </div>
          </form>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="mb-3 text-sm font-semibold opacity-70">Password</h2>
          <form action={~p"/profile/password"} method="post" class="flex flex-col gap-3">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <label class="flex flex-col gap-1">
              <span class="text-[13px] font-semibold opacity-70">Current password</span>
              <input
                type="password"
                name="current"
                required
                autocomplete="current-password"
                class="input input-bordered w-full"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-[13px] font-semibold opacity-70">New password</span>
              <input
                type="password"
                name="password"
                required
                minlength="12"
                autocomplete="new-password"
                class="input input-bordered w-full"
              />
              <span class="text-xs opacity-60">
                Mínimo de 12 caracteres. Trocar a senha encerra as outras sessões abertas.
              </span>
            </label>
            <div class="flex justify-end">
              <button type="submit" class="btn btn-sm">Update password</button>
            </div>
          </form>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="mb-3 text-sm font-semibold opacity-70">Access scopes</h2>
          <p :if={@escopos == []} class="text-sm opacity-60">
            Nenhum escopo: sem elo declarado e sem concessão, nenhum painel está
            alcançável. Quem administra declara o elo em People, ou concede escopo em
            Access scopes.
          </p>
          <ul class="flex flex-col gap-2 text-sm">
            <li :for={escopo <- @escopos} class="flex flex-wrap items-center gap-2">
              <span class="badge badge-ghost badge-sm">{escopo.level}</span>
              <span :if={escopo.target_name}>{escopo.target_name}</span>
              <span class="opacity-60">· {origem_rotulo(escopo.origin)}</span>
            </li>
          </ul>
          <p class="mt-3 border-t border-base-300 pt-2 text-xs opacity-60">
            A sua visão é a união destes escopos. Concessão é ato de quem administra;
            derivado acompanha as relações e fecha com elas.
          </p>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="mb-3 text-sm font-semibold opacity-70">Observed person</h2>
          <p :if={@pessoa == :not_declared} class="text-sm opacity-60">
            Ninguém declarou quem esta conta é entre as pessoas observadas — sem o elo,
            nem o próprio painel é alcançável. A declaração é ato de quem administra.
          </p>
          <p :if={match?({:ok, _}, @pessoa)} class="text-sm">
            <span class="badge badge-primary badge-sm">declared</span>
            <span class="ml-2 opacity-70">
              Declarado por quem administra; revogável, com registro de quem e quando.
            </span>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
