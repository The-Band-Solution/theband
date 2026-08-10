defmodule TheBandWeb.TeamsLive.Index do
  @moduledoc """
  `/equipes` — as equipes que a plataforma conhece (US3).

  Exibe também quantos vínculos ainda estão sem papel organizacional atribuído.
  É lacuna de conhecimento, não erro, e a tela a apresenta como número — não como
  alerta.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Equipes") |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Equipes
        <:subtitle>
          {@teams_count} {if @teams_count == 1, do: "equipe", else: "equipes"} · {@pending_role} {if @pending_role ==
                                                                                                       1,
                                                                                                     do:
                                                                                                       "vínculo pendente",
                                                                                                     else:
                                                                                                       "vínculos pendentes"} de papel organizacional
        </:subtitle>
      </.header>

      <div :if={@teams == []} class="alert">
        <p>
          Nenhuma equipe conhecida. Se a sincronização já rodou, a organização observada
          não tem equipes na origem — o que não é erro.
        </p>
      </div>

      <table :if={@teams != []} class="table">
        <thead>
          <tr>
            <th>equipe</th>
            <th>organização</th>
            <th>tipo</th>
            <th>origem</th>
            <th>identificador na origem</th>
            <th>coletada em</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={team <- @teams} class={team.no_longer_observed_at && "opacity-50"}>
            <td>
              <div class="font-medium">{team.name}</div>
              <div :if={team.slug} class="text-xs opacity-60">{team.slug}</div>
            </td>
            <td class="text-xs">
              <%= if org = Map.get(@organizations, team.organization_id) do %>
                {org.login}
              <% else %>
                <span class="opacity-60">—</span>
              <% end %>
            </td>
            <td><span class="badge badge-sm">{team.type}</span></td>
            <td class="text-xs">
              {team.source_system}
              <div class="opacity-60">{team.source_instance}</div>
            </td>
            <td class="font-mono text-xs">{team.external_id}</td>
            <td class="text-xs">{team.collected_at}</td>
            <td>
              <.link navigate={~p"/equipes/#{team.id}"} class="btn btn-xs btn-ghost">
                integrantes
              </.link>
            </td>
          </tr>
        </tbody>
      </table>

      <p class="text-xs opacity-60">
        Equipe do GitHub é registrada como equipe organizacional. Time do GitHub é agrupamento
        de permissão de acesso — que seus integrantes trabalhem juntos num projeto é suposição,
        não dado, e promover a equipe de projeto exigiria vínculo efetivo com repositório ou
        projeto.
      </p>
    </Layouts.app>
    """
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant

    socket
    |> assign(teams: EO.list_teams(tenant))
    # Indexado por id porque a tabela precisa da organização de cada linha. As
    # organizações observadas de um tenant são poucas — carregar todas custa menos
    # que uma consulta por equipe.
    |> assign(organizations: Map.new(EO.list_organizations(tenant), &{&1.id, &1}))
    |> assign(teams_count: EO.count_teams(tenant))
    |> assign(pending_role: EO.count_evidence_pending_role(tenant))
  end
end
