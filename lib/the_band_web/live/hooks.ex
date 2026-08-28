defmodule TheBandWeb.Live.Hooks do
  @moduledoc """
  Leva o tenant e a pessoa usuária da sessão para dentro do LiveView.

  Sem isso o LiveView teria de buscar o tenant por conta própria a cada evento —
  e a primeira vez que alguém esquecesse, a consulta rodaria sem filtro.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  def on_mount(:current_scope, _params, session, socket) do
    case session["user_id"] && Tenants.fetch_user(session["user_id"]) do
      {:ok, user} ->
        {:cont,
         socket
         |> assign(:current_user, user)
         |> assign(:current_tenant, user.tenant)
         |> attach_hook(:nav_area, :handle_params, &nav_area_hook/3)}

      _ ->
        {:halt, redirect(socket, to: "/sign-in")}
    end
  end

  def on_mount(:require_admin, params, session, socket) do
    case on_mount(:current_scope, params, session, socket) do
      {:cont, socket} ->
        if User.admin?(socket.assigns.current_user) do
          {:cont, socket}
        else
          {:halt,
           socket
           |> put_flash(:error, "Only organisation administrators can do that.")
           |> redirect(to: "/people")}
        end

      halted ->
        halted
    end
  end

  # A área ativa do menu vem do caminho da request (spec 046, FR-006). Vive na
  # hook, e não em cada LiveView, pelo mesmo motivo do tenant acima: a primeira
  # tela que esquecesse de declarar ficaria sem marcação em silêncio.
  defp nav_area_hook(_params, uri, socket) do
    {:cont, assign(socket, :nav_area, TheBandWeb.Layouts.nav_area(URI.parse(uri).path))}
  end
end
