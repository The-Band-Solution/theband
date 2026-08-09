defmodule TheBandWeb.PeopleLive.Index do
  @moduledoc """
  `/pessoas` — as pessoas que a plataforma conhece (US3).

  Cada registro exibe origem, identificador na ferramenta e data de coleta
  (FR-026, SC-004). A contagem do cabeçalho usa **as mesmas** `opts` da listagem:
  um cabeçalho dizendo "41 pessoas" sobre uma lista de 10 é exatamente o defeito
  que esta tela existe para tornar visível.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Pessoas", search: "", show_automation: true) |> load()}
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
        Pessoas
        <:subtitle>
          {@people_count} {if @people_count == 1, do: "pessoa", else: "pessoas"}
          <span :if={@automation_count > 0}>
            · {@automation_count} {if @automation_count == 1,
              do: "conta de automação",
              else: "contas de automação"} classificadas à parte
          </span>
        </:subtitle>
      </.header>

      <form phx-change="filter" class="flex flex-wrap gap-4 items-end">
        <label class="form-control">
          <span class="label-text">Buscar</span>
          <input
            name="search"
            value={@search}
            class="input input-bordered input-sm"
            placeholder="nome ou login"
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
          <span class="label-text">mostrar contas de automação</span>
        </label>
      </form>

      <div :if={@rows == []} class="alert">
        <p>{empty_message(@search, @has_any)}</p>
      </div>

      <table :if={@rows != []} class="table">
        <thead>
          <tr>
            <th>nome</th>
            <th>tipo de conta</th>
            <th>origem</th>
            <th>identificador na origem</th>
            <th>coletado em</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={person <- @rows} class={person.no_longer_observed_at && "opacity-50"}>
            <td>
              <div class="font-medium">{person.name}</div>
              <div :if={person.login} class="text-xs opacity-60">@{person.login}</div>
              <div :if={person.no_longer_observed_at} class="text-xs opacity-60">
                não mais observada desde {person.no_longer_observed_at}
              </div>
            </td>
            <td>
              <span class={["badge badge-sm", person.account_type != "person" && "badge-ghost"]}>
                {person.account_type}
              </span>
            </td>
            <td class="text-xs">
              {person.source_system}
              <div class="opacity-60">{person.source_instance}</div>
            </td>
            <td class="font-mono text-xs">{person.external_id}</td>
            <td class="text-xs">{person.collected_at}</td>
          </tr>
        </tbody>
      </table>

      <p class="text-xs opacity-60">
        Contas de automação são registradas e classificadas separadamente: aparecem na lista
        e não entram na contagem de pessoas. Duas contas da mesma pessoa continuam sendo dois
        registros — a reconciliação de identidade não faz parte desta entrega.
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

    socket
    |> assign(rows: EO.list_people(tenant, opts))
    |> assign(people_count: EO.count_people(tenant, Keyword.put(opts, :account_type, "person")))
    |> assign(
      automation_count: EO.count_people(tenant, Keyword.put(opts, :account_type, ["bot", "app"]))
    )
    |> assign(has_any: EO.count_people(tenant) > 0)
  end

  defp empty_message(search, has_any)
  defp empty_message("", false), do: "Nenhuma sincronização trouxe pessoas ainda."
  defp empty_message("", true), do: "Nenhuma pessoa corresponde aos filtros aplicados."
  defp empty_message(_search, _), do: "Nenhuma pessoa corresponde à busca."
end
