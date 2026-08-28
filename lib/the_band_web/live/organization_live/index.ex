defmodule TheBandWeb.OrganizationLive.Index do
  @moduledoc """
  `/organizations` — a página da organização, feature 046 (US3).

  Fecha o espelho entre o menu e as entidades do axioma de acesso (spec 045): a
  barra tem People, Teams, Projects — e a organização, que as contém, não tinha
  página. Aqui ela mostra o que a EO responde por ela: equipes vigentes,
  responsáveis declarados e os projetos observados.

  ## Dois contextos, compostos aqui — de propósito

  A EO entrega organizações, equipes e responsáveis (`organization_overview/1`);
  os projetos vêm do contexto Projects e são agrupados NESTA camada por
  `source_instance` ↔ `login`. A primeira versão do contrato punha os projetos
  dentro da EO — furaria a fronteira de módulo para poupar um `group_by` de
  apresentação, e foi corrigida (ver o contrato da feature).

  ## A limitação é declarada, não escondida

  Projeto observado não carrega vínculo direto com organização; a cadeia
  declarada é `connected_tool_id → connected_tools.organization_login →
  organizations.login` (research R3 — a primeira versão casaria por
  `source_instance`, e a coleta desmentiu: ali vive a URL da instância). Projeto
  cuja ferramenta não aponta organização observada aparece no grupo "sem
  organização identificada", com a frase do porquê — ausência nomeada, nunca
  omitida (lição L61: limitação vira ramo no código e frase na tela).

  ## Toda contagem deriva das listas

  `length/1` sobre o que a consulta devolveu — nunca contador armazenado.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Projects
  alias TheBand.Sources

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    overview = EO.organization_overview(tenant)
    projetos = Projects.list_projects(tenant)

    # A cadeia declarada: projeto → ferramenta conectada → login da organização.
    login_da_ferramenta =
      Map.new(Sources.list_connected_tools(tenant), &{&1.id, &1.organization_login})

    por_login =
      Enum.group_by(projetos, &Map.get(login_da_ferramenta, &1.connected_tool_id))

    entradas =
      Enum.map(overview, fn entrada ->
        Map.put(entrada, :projects, Map.get(por_login, entrada.organization.login, []))
      end)

    logins_observados =
      overview |> Enum.map(& &1.organization.login) |> Enum.reject(&is_nil/1) |> MapSet.new()

    orfaos =
      projetos
      |> Enum.reject(fn p ->
        MapSet.member?(logins_observados, Map.get(login_da_ferramenta, p.connected_tool_id))
      end)
      |> Enum.sort_by(& &1.number)
      |> Enum.map(&%{projeto: &1, login: Map.get(login_da_ferramenta, &1.connected_tool_id)})

    {:ok,
     assign(socket,
       page_title: "Organization",
       entradas: entradas,
       orfaos: orfaos
     )}
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
        Organization
        <:subtitle>
          What the platform observes of each organisation: teams, declared
          responsibles, and projects.
        </:subtitle>
      </.header>

      <div :if={@entradas == []} class="card bg-base-200 p-6">
        <p class="font-semibold">No organisation observed yet.</p>
        <p class="text-sm opacity-70">
          Organisations arrive with the collection: connect a tool and run a sync —
          Settings › Operação.
        </p>
      </div>

      <section :for={entrada <- @entradas} class="card bg-base-200 p-6 space-y-4">
        <div class="flex items-baseline gap-3">
          <h2 class="text-lg font-semibold">{entrada.organization.name}</h2>
          <span :if={entrada.organization.login} class="font-mono text-xs opacity-60">
            {entrada.organization.login}
          </span>
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
          <div>
            <h3 class="text-sm font-semibold opacity-70">
              Teams ({length(entrada.teams)})
            </h3>
            <p :if={entrada.teams == []} class="text-sm opacity-60">
              No team observed for this organisation.
            </p>
            <ul class="mt-1 space-y-1">
              <li :for={team <- entrada.teams}>
                <.link navigate={~p"/teams/#{team.id}"} class="link link-hover text-sm">
                  {team.name}
                </.link>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="text-sm font-semibold opacity-70">
              Responsibles ({length(entrada.responsibles)})
            </h3>
            <p :if={entrada.responsibles == []} class="text-sm opacity-60">
              Nobody declared responsible — the organization-scope grant in Roles is
              what declares it.
            </p>
            <ul class="mt-1 space-y-1">
              <li :for={r <- entrada.responsibles} class="text-sm">
                <.link navigate={~p"/people/#{r.person.id}"} class="link link-hover">
                  {r.person.name || r.person.login}
                </.link>
                <span class="opacity-60">· {r.role_name}</span>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="text-sm font-semibold opacity-70">
              Projects ({length(entrada.projects)})
            </h3>
            <p :if={entrada.projects == []} class="text-sm opacity-60">
              No project identified for this organisation.
            </p>
            <ul class="mt-1 space-y-1">
              <li :for={projeto <- entrada.projects}>
                <.link navigate={~p"/boards/#{projeto.id}"} class="link link-hover text-sm">
                  {projeto.title}
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </section>

      <section :if={@orfaos != []} class="card bg-base-200 p-6 space-y-2">
        <h2 class="text-sm font-semibold opacity-70">
          Projects without an identified organisation ({length(@orfaos)})
        </h2>
        <p class="text-sm opacity-60">
          A project reaches an organisation through the connected tool that collected
          it; these projects' tools point to no observed organisation.
        </p>
        <ul class="space-y-1">
          <li :for={orfao <- @orfaos}>
            <.link navigate={~p"/boards/#{orfao.projeto.id}"} class="link link-hover text-sm">
              {orfao.projeto.title}
            </.link>
            <span :if={orfao.login} class="font-mono text-xs opacity-60">{orfao.login}</span>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end
end
