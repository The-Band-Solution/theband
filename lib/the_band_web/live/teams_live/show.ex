defmodule TheBandWeb.TeamsLive.Show do
  @moduledoc """
  `/teams/:id` — integrantes observados de uma equipe (US3).

  O nível de acesso é rotulado como **acesso na plataforma**, nunca como papel ou
  cargo. O rótulo é parte do contrato: chamá-lo de papel na tela desfaria na
  interface a distinção que o modelo se deu ao trabalho de preservar.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 50

  # O papel organizacional fica fora das colunas ordenáveis: ele é **derivado** de haver ou não
  # vínculo promovido, e não coluna da consulta. Ordenar por ele exigiria ordenar por uma
  # ausência, o que a lista já diz em texto.
  @tabelas [{"members", [:name, :platform_access_level, :observed_at, :last_observed_at], nil}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case Enum.find(EO.list_teams(tenant), &(&1.id == id)) do
      # FR-027 — id de outro tenant não devolve o registro; devolve 404.
      nil ->
        {:ok, socket |> put_flash(:error, "Team not found.") |> push_navigate(to: ~p"/teams")}

      team ->
        {:ok, assign(socket, page_title: team.name, team: team)}
    end
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{team: nil}} = socket), do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  defp caminho(socket, id, mudancas),
    do: ~p"/teams/#{socket.assigns.team.id}?#{Tabela.query(socket, id, mudancas)}"

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team
    estado = socket.assigns.tabelas["members"]

    opts = [search: estado.busca]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(
      members:
        EO.list_team_members(
          tenant,
          team.id,
          opts ++
            [
              order_by: estado.ordem,
              limit: @por_pagina,
              offset: (estado.pagina - 1) * @por_pagina
            ]
        )
    )
    |> assign(encontradas: EO.count_team_members(tenant, team.id, opts))
    |> assign(pending_role: EO.count_evidence_pending_role(tenant, team_id: team.id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.breadcrumb niveis={[
        %{rotulo: "Teams", destino: ~p"/teams"},
        %{rotulo: @team.name, destino: nil}
      ]} />
      <.header>
        {@team.name}
        <:subtitle>
          {@encontradas} {if @encontradas == 1, do: "member", else: "members"} · {@pending_role} with no organisational role assigned
        </:subtitle>
      </.header>

      <.data_table
        id="members"
        rows={@members}
        estado={@tabelas["members"]}
        por_pagina={@por_pagina}
        total={@encontradas}
        onde="name and login"
        vazio="This team has no member observed at the source."
        class="table stacked"
      >
        <:col :let={member} field={:name} label="person">
          <%!-- Nome e login levam ao **mesmo** lugar: são duas grafias da mesma pessoa, e
                obrigar quem lê a descobrir qual das duas é clicável seria pedir que ele
                adivinhe. A participação pode ter acabado; a pessoa continua existindo. --%>
          <.link
            navigate={~p"/people/#{member.person.id}"}
            class={[
              "link link-hover font-medium underline decoration-dotted",
              member.no_longer_observed_at && "opacity-50"
            ]}
          >
            {member.person.name}
          </.link>
          <div :if={member.person.login} class="text-xs opacity-60">
            <.link navigate={~p"/people/#{member.person.id}"} class="link link-hover">
              @{member.person.login}
            </.link>
          </div>
          <div :if={member.no_longer_observed_at} class="text-xs opacity-60">
            no longer observed since {member.no_longer_observed_at}
          </div>
        </:col>
        <:col :let={member} field={:platform_access_level} label="access at the platform">
          <span class="badge badge-sm badge-ghost font-mono">
            {member.platform_access_level}
          </span>
        </:col>
        <:col :let={member} label="organisational role">
          <span :if={member.pending_role} class="text-xs opacity-60">pending</span>
          <span :if={!member.pending_role} class="text-xs">assigned</span>
        </:col>
        <:col :let={member} field={:observed_at} label="observed at" class="text-xs">
          {member.observed_at}
        </:col>
        <:col :let={member} field={:last_observed_at} label="last observation" class="text-xs">
          {member.last_observed_at}
        </:col>
      </.data_table>

      <div class="alert text-sm">
        <div>
          <p class="font-semibold">Por que o papel organizacional aparece como pendente</p>
          <p>
            <span class="font-mono">MAINTAINER</span>
            e <span class="font-mono">MEMBER</span>
            are team administration levels at the platform: they say who can manage members and
            permissions. They do not say whether the person is a developer, a tester, a designer
            or a manager. Treating them as a role would produce a catalogue matching no real
            function. The link stays recorded as evidence until the organisation assigns the role.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
