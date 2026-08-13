defmodule TheBandWeb.TeamsLive.Show do
  @moduledoc """
  `/teams/:id` — integrantes observados de uma equipe (US3).

  O nível de acesso é rotulado como **acesso na plataforma**, nunca como papel ou
  cargo. O rótulo é parte do contrato: chamá-lo de papel na tela desfaria na
  interface a distinção que o modelo se deu ao trabalho de preservar.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case Enum.find(EO.list_teams(tenant), &(&1.id == id)) do
      # FR-027 — id de outro tenant não devolve o registro; devolve 404.
      nil ->
        {:ok, socket |> put_flash(:error, "Team not found.") |> push_navigate(to: ~p"/teams")}

      team ->
        {:ok,
         socket
         |> assign(page_title: team.name, team: team)
         |> assign(members: EO.list_team_members(tenant, team.id))
         |> assign(pending_role: EO.count_evidence_pending_role(tenant, team_id: team.id))}
    end
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
          {length(@members)} {if length(@members) == 1, do: "integrante", else: "integrantes"} · {@pending_role} sem papel organizacional atribuído
        </:subtitle>
      </.header>

      <div :if={@members == []} class="alert">
        <p>Esta equipe não tem integrantes observados na origem.</p>
      </div>

      <table :if={@members != []} class="table">
        <thead>
          <tr>
            <th>pessoa</th>
            <th>acesso na plataforma</th>
            <th>papel organizacional</th>
            <th>observada em</th>
            <th>última observação</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={member <- @members} class={member.no_longer_observed_at && "opacity-50"}>
            <td>
              <%!-- Nome e login levam ao **mesmo** lugar: são duas grafias da mesma pessoa, e
                    obrigar quem lê a descobrir qual das duas é clicável seria pedir que ele
                    adivinhe. A participação pode ter acabado; a pessoa continua existindo. --%>
              <.link
                navigate={~p"/people/#{member.person.id}"}
                class="link link-hover font-medium underline decoration-dotted"
              >
                {member.person.name}
              </.link>
              <div :if={member.person.login} class="text-xs opacity-60">
                <.link navigate={~p"/people/#{member.person.id}"} class="link link-hover">
                  @{member.person.login}
                </.link>
              </div>
              <div :if={member.no_longer_observed_at} class="text-xs opacity-60">
                não mais observada desde {member.no_longer_observed_at}
              </div>
            </td>
            <td>
              <span class="badge badge-sm badge-ghost font-mono">
                {member.platform_access_level}
              </span>
            </td>
            <td>
              <span :if={member.pending_role} class="text-xs opacity-60">pendente</span>
              <span :if={!member.pending_role} class="text-xs">atribuído</span>
            </td>
            <td class="text-xs">{member.observed_at}</td>
            <td class="text-xs">{member.last_observed_at}</td>
          </tr>
        </tbody>
      </table>

      <div class="alert text-sm">
        <div>
          <p class="font-semibold">Por que o papel organizacional aparece como pendente</p>
          <p>
            <span class="font-mono">MAINTAINER</span>
            e <span class="font-mono">MEMBER</span>
            são níveis de administração do time na plataforma: dizem quem pode gerir membros e
            permissões. Não dizem se a pessoa é programadora, testadora, designer ou gerente.
            Tratá-los como papel produziria um catálogo que não corresponde a nenhuma função real.
            O vínculo fica registrado como evidência até que a organização atribua o papel.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
