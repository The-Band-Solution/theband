defmodule TheBandWeb.TeamsLive.Index do
  @moduledoc """
  `/teams` — as equipes que a plataforma conhece (US3).

  Exibe também quantos vínculos ainda estão sem papel organizacional atribuído. É lacuna de
  conhecimento, não erro, e a tela a apresenta como número — não como alerta.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 50

  # Organização fica de fora das colunas ordenáveis: ela vem de outra consulta, e ordenar por
  # coluna que a consulta não trouxe pareceria ordenação sem ser.
  @tabelas [{"teams", [:name, :slug, :source_system, :collected_at], nil}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Teams")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  defp caminho(socket, id, mudancas), do: ~p"/teams?#{Tabela.query(socket, id, mudancas)}"

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
        Teams
        <:subtitle>
          {@teams_count} {if @teams_count == 1, do: "team", else: "teams"} · {@pending_role} {if @pending_role ==
                                                                                                   1,
                                                                                                 do:
                                                                                                   "link pending",
                                                                                                 else:
                                                                                                   "links pending"} an organisational role
          <span :if={@derived_count > 0}>
            · {@derived_count} derived by the platform, {@observed_count} at the source
          </span>
        </:subtitle>
      </.header>

      <div :if={@teams_count == 0} class="alert">
        <p>
          No team known. If the sync has already run, the observed organisation has no teams at
          the source — which is not an error.
        </p>
      </div>

      <.data_table
        id="teams"
        rows={@teams}
        estado={@tabelas["teams"]}
        por_pagina={@por_pagina}
        total={@encontradas}
        onde="name and slug"
        vazio="No team matches this search."
        class="table stacked"
      >
        <:col :let={team} field={:name} label="team">
          <div class={["font-medium", team.no_longer_observed_at && "opacity-50"]}>{team.name}</div>
          <div :if={team.slug} class="text-xs opacity-60">{team.slug}</div>
        </:col>
        <:col :let={team} label="organisation" class="text-xs">
          <%= if org = Map.get(@organizations, team.organization_id) do %>
            {org.login}
          <% else %>
            <span class="opacity-60">—</span>
          <% end %>
        </:col>
        <:col :let={team} label="type">
          <span class="badge badge-sm">{team.type}</span>
          <span
            :if={EO.derived_team?(team)}
            class="badge badge-sm badge-warning ml-1"
            title="This team does not exist at the source: the platform created it to gather whoever belongs to the organisation and is in no team."
          >
            derived
          </span>
        </:col>
        <:col :let={team} field={:source_system} label="source" class="text-xs">
          {team.source_system}
          <div class="opacity-60">{team.source_instance}</div>
        </:col>
        <:col :let={team} label="identifier at source" class="font-mono text-xs">
          {team.external_id}
        </:col>
        <:col :let={team} field={:collected_at} label="collected at" class="text-xs">
          {team.collected_at}
        </:col>
        <:col :let={team} label="">
          <.link navigate={~p"/teams/#{team.id}"} class="btn btn-xs btn-ghost">members</.link>
        </:col>
      </.data_table>

      <p :if={@derived_count > 0} class="text-xs opacity-60">
        The team marked <strong>derived</strong> does not exist at the source tool: the platform
        created it, named after the organisation, to gather whoever belongs to the organisation
        and is in no team. Without it those people would belong to no organisation in the model —
        the link to an organisation goes through the team. When comparing the count against
        GitHub, subtract the derived ones.
      </p>

      <p class="text-xs opacity-60">
        A GitHub team is recorded as an organisational team. A GitHub team is an access
        permission grouping — that its members work together on a project is an assumption, not
        data, and promoting it to a project team would require an actual link to a repository or
        a project.
      </p>
    </Layouts.app>
    """
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    estado = socket.assigns.tabelas["teams"]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(
      teams:
        EO.list_teams(tenant,
          search: estado.busca,
          order_by: estado.ordem,
          limit: @por_pagina,
          offset: (estado.pagina - 1) * @por_pagina
        )
    )
    |> assign(encontradas: EO.count_teams(tenant, search: estado.busca))
    # Indexado por id porque a tabela precisa da organização de cada linha. As
    # organizações observadas de um tenant são poucas — carregar todas custa menos
    # que uma consulta por equipe.
    |> assign(organizations: Map.new(EO.list_organizations(tenant), &{&1.id, &1}))
    |> assign(teams_count: EO.count_teams(tenant))
    # Separadas de propósito: quem compara o número da plataforma com o do GitHub
    # precisa ver a diferença sem investigar. Esconder é pior que marcar — quem não vê
    # a equipe não explica por que a contagem de pessoas não fecha.
    |> assign(derived_count: EO.count_teams(tenant, origin: :derived))
    |> assign(observed_count: EO.count_teams(tenant, origin: :observed))
    |> assign(pending_role: EO.count_evidence_pending_role(tenant))
  end
end
