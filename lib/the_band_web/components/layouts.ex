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
    <%!-- Mobile-first: a navegação empilha e rola horizontalmente no telefone, e só vira
          barra a partir de `sm:`. O caminho inverso — desenhar para a mesa e quebrar para
          baixo — produz o menu que corta no meio em 360px.

          A tagline diz a cadeia inteira, e nesta ordem: dado, informação, ação de quem
          decide. O nome carrega a metáfora da tese — cada serviço é um músico tocando um
          instrumento, uma ontologia, e juntos produzem música (informação) a partir de
          notas (os dados das aplicações) para um público (a organização).

          `Orchestrating` é escolha deliberada da pessoa mantenedora, e tem um sentido a
          desfazer: em vocabulário técnico ele virou palavra de infraestrutura — contêiner,
          fluxo de tarefa. Aqui ele é o maestro da metáfora, e o resto da frase é o que
          impede a leitura errada: orquestrador de contêiner não entrega informação sobre
          que a organização age.

          E a frase termina em `act on` porque informação que ninguém usa para decidir não
          é o produto. É o público da tese, dito sem metáfora. --%>
    <header class="border-b border-base-300 px-4 py-2 sm:px-6 sm:py-0 lg:px-8">
      <div class="flex flex-col gap-2 sm:h-16 sm:flex-row sm:items-center sm:gap-4">
        <a href="/" class="flex items-baseline gap-2 font-semibold">
          The Band
          <span class="hidden text-xs font-normal text-base-content/60 sm:inline">
            Orchestrating data into information organisations can act on
          </span>
        </a>
      </div>
      <div
        :if={@current_tenant}
        class="-mx-4 overflow-x-auto px-4 pb-1 sm:mx-0 sm:overflow-visible sm:px-0 sm:pb-0"
      >
        <ul class="flex items-center gap-1 whitespace-nowrap">
          <%!-- A ordem segue o que a plataforma observa, do agente para o trabalho:
                quem (pessoas), com quem (equipes), sobre o quê (trabalho). Depois vêm as
                telas de operação — sincronizações e ferramentas —, separadas por borda,
                porque respondem "a plataforma está funcionando" e não "o que ela sabe". --%>
          <li><.link navigate={~p"/people"} class="btn btn-ghost btn-sm">People</.link></li>
          <li><.link navigate={~p"/teams"} class="btn btn-ghost btn-sm">Teams</.link></li>
          <li><.link navigate={~p"/work"} class="btn btn-ghost btn-sm">Work</.link></li>
          <%!-- Fica do lado do conhecimento, e não da operação: responde "o que a
                organização faz", e não "a plataforma está funcionando". --%>
          <li><.link navigate={~p"/process"} class="btn btn-ghost btn-sm">Process</.link></li>
          <li class="border-l border-base-300 pl-2">
            <.link navigate={~p"/syncs"} class="btn btn-ghost btn-sm">Syncs</.link>
          </li>
          <li :if={@current_user && @current_user.role == "admin"}>
            <.link navigate={~p"/tools"} class="btn btn-ghost btn-sm">Tools</.link>
          </li>
          <li class="ml-auto hidden border-l border-base-300 pl-3 lg:block">
            <span class="text-xs opacity-70">
              {@current_tenant.name} · {@current_user.email}
            </span>
          </li>
          <li>
            <.link href={~p"/session"} method="delete" class="btn btn-ghost btn-xs">Sign out</.link>
          </li>
          <li><.theme_toggle /></li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
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
        title="No connection to the server"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Trying to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Trying to reconnect
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
