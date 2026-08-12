defmodule TheBandWeb.PeopleLive.Index do
  @moduledoc """
  `/people` — as pessoas que a plataforma conhece (US3).

  Cada registro exibe origem, identificador na ferramenta e data de coleta
  (FR-026, SC-004). A contagem do cabeçalho usa **as mesmas** `opts` da listagem:
  um cabeçalho dizendo "41 pessoas" sobre uma lista de 10 é exatamente o defeito
  que esta tela existe para tornar visível.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "People", search: "", show_automation: true) |> load()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(
       search: params["search"] || "",
       show_automation: params["show_automation"] == "true"
     )
     |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        People
        <:subtitle>
          {@people_count} {if @people_count == 1, do: "person", else: "people"}
          <span :if={@automation_count > 0}>
            · {@automation_count} {if @automation_count == 1,
              do: "automation account",
              else: "automation accounts"} classified apart
          </span>
        </:subtitle>
      </.header>

      <form
        id="filtro-pessoas"
        phx-change="filter"
        class="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end"
      >
        <label class="form-control">
          <span class="label-text">Search</span>
          <input
            name="search"
            value={@search}
            class="input input-bordered input-sm"
            placeholder="name or login"
            phx-debounce="300"
          />
        </label>
        <label class="label cursor-pointer gap-2">
          <input
            type="checkbox"
            name="show_automation"
            value="true"
            checked={@show_automation}
            class="checkbox checkbox-sm"
          />
          <span class="label-text">show automation accounts</span>
        </label>
      </form>

      <div :if={@rows == []} class="alert">
        <p>{empty_message(@search, @has_any)}</p>
      </div>

      <div :if={@rows != []} class="overflow-x-auto">
        <table class="table table-sm stacked">
          <thead>
            <tr>
              <th>name</th>
              <th>account type</th>
              <th>organisations</th>
              <th>source</th>
              <th>identifier at source</th>
              <th>collected at</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={person <- @rows} class={person.no_longer_observed_at && "opacity-50"}>
              <%!-- O nome abre o detalhe **dentro da plataforma**, não na origem: o que interessa
                    ao clicar é o que foi coletado, e o link para a origem vive lá dentro. --%>
              <td data-label="name">
                <div class="font-medium">
                  <.link navigate={~p"/people/#{person.id}"} class="link link-hover">
                    {person.name || person.login}
                  </.link>
                </div>
                <div :if={person.login} class="text-xs opacity-60">@{person.login}</div>
                <div :if={person.no_longer_observed_at} class="text-xs opacity-60">
                  no longer observed since {person.no_longer_observed_at}
                </div>
              </td>
              <td data-label="account type">
                <span class={["badge badge-sm", person.account_type != "person" && "badge-ghost"]}>
                  {person.account_type}
                </span>
              </td>
              <td data-label="organisations" class="text-xs">
                <% orgs = Map.get(@organizations_by_person, person.id, []) %>
                <%!-- Quem não está em equipe alguma aparece **sem** organização, e a frase diz
                    isso: o vínculo pessoa→organização não existe na origem, ele vem das
                    equipes. Um traço aqui esconderia a razão. --%>
                <.absent :if={orgs == []} reason="no team — organisation unknown" />
                <div :for={org <- orgs}>{org.login}</div>
                <div :if={length(orgs) > 1} class="badge badge-sm badge-outline mt-1">
                  in {length(orgs)} organisations
                </div>
              </td>
              <td data-label="source" class="text-xs">
                {person.source_system}
                <div class="opacity-60">{person.source_instance}</div>
              </td>
              <td data-label="identifier at source" class="font-mono text-xs">
                {person.external_id}
              </td>
              <td data-label="collected at" class="text-xs">{person.collected_at}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="text-xs opacity-60">
        A person's organisation comes from their teams: there is no direct link between person and
        organisation, so whoever is in no team appears with none. Whoever is in more than one
        appears <strong>once</strong>, with all of them listed — so the sum of people per
        organisation is larger than the total, and that is correct.
      </p>

      <p class="text-xs opacity-60">
        Automation accounts are recorded and classified separately: they appear in the list and do
        not enter the people count. Two accounts of the same person remain two records —
        identity reconciliation is not part of this delivery.
      </p>
    </Layouts.app>
    """
  end

  # As mesmas opts alimentam listagem e contagem. Montá-las num lugar só é o que
  # impede as duas de divergirem quando um filtro novo for acrescentado.
  defp load(socket) do
    tenant = socket.assigns.current_tenant

    opts =
      [search: socket.assigns.search]
      |> then(fn opts ->
        if socket.assigns.show_automation, do: opts, else: [{:account_type, "person"} | opts]
      end)

    rows = EO.list_people(tenant, opts)

    socket
    |> assign(rows: rows)
    # Um mapa para todas as linhas, e não uma consulta por linha: a tela desenha 72
    # pessoas hoje, e uma consulta por pessoa cresceria com a coleta.
    |> assign(
      organizations_by_person: EO.organizations_by_person(tenant, Enum.map(rows, & &1.id))
    )
    |> assign(people_count: EO.count_people(tenant, Keyword.put(opts, :account_type, "person")))
    |> assign(
      automation_count: EO.count_people(tenant, Keyword.put(opts, :account_type, ["bot", "app"]))
    )
    |> assign(has_any: EO.count_people(tenant) > 0)
  end

  defp empty_message(search, has_any)
  defp empty_message("", false), do: "No sync has brought people yet."
  defp empty_message("", true), do: "No person matches the filters applied."
  defp empty_message(_search, _), do: "No person matches the search."
end
