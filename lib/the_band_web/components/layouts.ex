defmodule TheBandWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TheBandWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  attr :current_user, :map, default: nil
  attr :current_tenant, :map, default: nil

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-300">
      <div class="flex-1">
        <a href="/" class="flex items-center gap-2 font-semibold">
          The Band <span class="badge badge-sm badge-ghost">integração semântica</span>
        </a>
      </div>
      <div :if={@current_tenant} class="flex-none">
        <ul class="flex px-1 space-x-1 items-center">
          <%!-- A ordem segue o que a plataforma observa, do agente para o trabalho:
                quem (pessoas), com quem (equipes), sobre o quê (trabalho). Depois vêm as
                telas de operação — sincronizações e ferramentas —, separadas por borda,
                porque respondem "a plataforma está funcionando" e não "o que ela sabe". --%>
          <li><.link navigate={~p"/pessoas"} class="btn btn-ghost btn-sm">Pessoas</.link></li>
          <li><.link navigate={~p"/equipes"} class="btn btn-ghost btn-sm">Equipes</.link></li>
          <li><.link navigate={~p"/trabalho"} class="btn btn-ghost btn-sm">Trabalho</.link></li>
          <li class="pl-2 border-l border-base-300">
            <.link navigate={~p"/sincronizacoes"} class="btn btn-ghost btn-sm">Sincronizações</.link>
          </li>
          <li :if={@current_user && @current_user.role == "admin"}>
            <.link navigate={~p"/ferramentas"} class="btn btn-ghost btn-sm">Ferramentas</.link>
          </li>
          <li class="pl-3 border-l border-base-300">
            <span class="text-xs opacity-70">
              {@current_tenant.name} · {@current_user.email}
            </span>
          </li>
          <li>
            <.link href={~p"/sessao"} method="delete" class="btn btn-ghost btn-xs">sair</.link>
          </li>
          <li><.theme_toggle /></li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-6xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc "Mensagens de flash e os avisos de reconexão do LiveView."
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Sem conexão com o servidor"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentando reconectar
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Algo deu errado"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentando reconectar
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
