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

  attr :nav_area, :atom,
    default: nil,
    doc: "a área ativa do menu, derivada do caminho pela hook (ver nav_area/1)"

  attr :operacao_menu, :boolean,
    default: false,
    doc: "a seção Operação aparece? admin OU organization (FR-023), decidido na hook"

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
      <%!-- A rolagem vale em QUALQUER largura, e não só no telefone. Com treze itens a
            barra passou de 1.280px e o `sm:overflow-visible` deixava a PÁGINA rolar de
            lado — medido em 2026-08-19: documento de 1.430px num viewport de 1.280. O
            conteúdo largo rola dentro do próprio contêiner; o corpo da página, nunca. --%>
      <div :if={@current_tenant} class="flex items-center gap-2">
        <%!-- A barra carrega as ENTIDADES — as mesmas do axioma de acesso da spec 045:
              quem (pessoas), com quem (equipes), sobre o quê (projetos). O resto vive em
              Settings, em seções nomeadas — spec 046.

              SÓ as entidades vivem no contêiner rolável. `overflow-x: auto` força
              overflow-y a auto, e um dropdown absoluto lá dentro abre CORTADO pela
              altura da barra — foi o defeito do Settings "que não abria": abria, e a
              barra o engolia. O menu e o bloco da conta ficam FORA, num irmão que
              não rola. --%>
        <div class="nav-rolavel -mx-4 min-w-0 flex-1 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0 sm:pb-0">
          <ul class="flex items-center gap-1 whitespace-nowrap">
            <li>
              <.nav_item navigate={~p"/people"} active={@nav_area == :people}>People</.nav_item>
            </li>
            <li>
              <.nav_item navigate={~p"/teams"} active={@nav_area == :teams}>Teams</.nav_item>
            </li>
            <li>
              <.nav_item navigate={~p"/projects"} active={@nav_area == :projects}>
                Projects
              </.nav_item>
            </li>
            <li>
              <.nav_item navigate={~p"/organizations"} active={@nav_area == :organization}>
                Organization
              </.nav_item>
            </li>
          </ul>
        </div>

        <ul class="flex shrink-0 items-center gap-1 whitespace-nowrap">
          <li>
            <details class="dropdown dropdown-end">
              <summary
                class={["btn btn-ghost btn-sm", @nav_area == :settings && "btn-active"]}
                aria-current={@nav_area == :settings && "true"}
              >
                <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
              </summary>
              <ul class="menu dropdown-content z-10 mt-1 w-60 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg">
                <li class="menu-title">Trabalho</li>
                <li><.link navigate={~p"/work"}>Work</.link></li>
                <li class="menu-title">Vocabulário</li>
                <%!-- `Roles` é onde se confirma quem é quem — sem ela, 100 participações
                      observadas ficaram esperando numa tela que só se alcançava pela URL. --%>
                <li><.link navigate={~p"/roles"}>Roles</.link></li>
                <%!-- Operação responde "a plataforma está funcionando", não "o que ela
                      sabe" — e aparece para quem administra OU tem concessão
                      organization (FR-023 da 045, no ponto único que a 046 previu:
                      a hook decide, o markup obedece). IA e geração de perfis seguem
                      como ABAS de Tools e de Syncs (#428) — não são itens. --%>
                <%= if @operacao_menu do %>
                  <li class="menu-title">Operação</li>
                  <li><.link navigate={~p"/syncs"}>Syncs</.link></li>
                  <li><.link navigate={~p"/tools"}>Tools</.link></li>
                <% end %>
                <%!-- Contas e concessões são GESTÃO — só a marca de administrador
                      (FR-008/013); credencial de modelo idem (leitura de FR-023
                      registrada no roteador). --%>
                <%= if @current_user && @current_user.role == "admin" do %>
                  <li class="menu-title">Contas</li>
                  <li><.link navigate={~p"/accounts"}>Accounts</.link></li>
                  <li><.link navigate={~p"/access-scopes"}>Access scopes</.link></li>
                <% end %>
              </ul>
            </details>
          </li>
          <li class="hidden border-l border-base-300 pl-3 lg:block">
            <span class="text-xs opacity-70">
              {@current_tenant.name} · {@current_user.email}
            </span>
          </li>
          <li>
            <.link navigate={~p"/profile"} class="btn btn-ghost btn-xs">Profile</.link>
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

  @doc """
  A área do menu a que um caminho pertence — spec 046, FR-006.

  Mapa declarativo por prefixo de rota, testável sem LiveView; nenhuma tela
  declara a própria área, então tela nova não quebra em silêncio — cai em `nil`
  (nenhuma marcação) até ganhar linha aqui. `/ai` e `/profiles` continuam com
  rota própria mesmo fora do menu (#428), e pertencem a Settings quando abertas
  por URL.
  """
  @nav_areas [
    {"/people", :people},
    {"/teams", :teams},
    {"/projects", :projects},
    {"/organizations", :organization},
    {"/work", :settings},
    {"/roles", :settings},
    {"/syncs", :settings},
    {"/tools", :settings},
    {"/boards", :settings},
    {"/process", :settings},
    {"/ai", :settings},
    {"/profiles", :settings}
  ]

  @spec nav_area(String.t() | nil) :: atom() | nil
  def nav_area(path) when is_binary(path) do
    Enum.find_value(@nav_areas, fn {prefix, area} ->
      if path == prefix or String.starts_with?(path, prefix <> "/"), do: area
    end)
  end

  def nav_area(_), do: nil

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  # `aria-current="true"`, e nunca `"page"`: a barra marca a SEÇÃO atual — de
  # /people/123, o item People é outra página. `"page"` pertence à migalha, que é
  # quem aponta o lugar exato; dois donos para o mesmo valor fariam o leitor de
  # tela anunciar dois "você está aqui" diferentes.
  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={["btn btn-ghost btn-sm", @active && "btn-active"]}
      aria-current={@active && "true"}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Sub-abas das telas de trabalho — spec 046, FR-005.

  Com Work fora da barra, as seis visões viraram irmãs visíveis aqui: um clique
  entre elas, nas rotas que sempre tiveram. Componente único para as seis telas
  não divergirem na primeira mudança.
  """
  attr :active, :atom,
    required: true,
    values: [:issues, :changes, :files, :checks, :boards, :process]

  def work_tabs(assigns) do
    ~H"""
    <nav class="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
      <div role="tablist" class="tabs tabs-border whitespace-nowrap">
        <.link navigate={~p"/work"} role="tab" class={tab_class(@active == :issues)}>
          Issues
        </.link>
        <.link navigate={~p"/work/changes"} role="tab" class={tab_class(@active == :changes)}>
          Changes
        </.link>
        <.link navigate={~p"/work/files"} role="tab" class={tab_class(@active == :files)}>
          Files
        </.link>
        <.link navigate={~p"/work/verifications"} role="tab" class={tab_class(@active == :checks)}>
          Checks
        </.link>
        <.link navigate={~p"/boards"} role="tab" class={tab_class(@active == :boards)}>
          Boards
        </.link>
        <.link navigate={~p"/process"} role="tab" class={tab_class(@active == :process)}>
          Process
        </.link>
      </div>
    </nav>
    """
  end

  defp tab_class(true), do: "tab tab-active"
  defp tab_class(false), do: "tab"

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
