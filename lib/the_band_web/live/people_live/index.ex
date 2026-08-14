defmodule TheBandWeb.PeopleLive.Index do
  @moduledoc """
  `/people` — as pessoas que a plataforma conhece (US3).

  Cada registro exibe origem, identificador na ferramenta e data de coleta
  (FR-026, SC-004). A contagem do cabeçalho usa **as mesmas** `opts` da listagem:
  um cabeçalho dizendo "41 pessoas" sobre uma lista de 10 é exatamente o defeito
  que esta tela existe para tornar visível.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 50

  # As colunas por onde esta tela ordena. Organizações fica de fora: ela vem de outra consulta,
  # e ordenar por uma coluna que a consulta não trouxe pareceria ordenação sem ser.
  @tabelas [{"people", [:name, :account_type, :source_system, :collected_at], nil}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "People")}
  end

  # O estado vem do endereço, e não do socket: recarregar precisa devolver a mesma tela, e o
  # link precisa levar quem recebe ao que quem mandou estava vendo.
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(show_automation: params["automacao"] != "nao")
     |> Tabela.aplicar(params, @tabelas)
     |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  # Mostrar ou não as contas de automação é filtro da tela, e vive no endereço junto do resto:
  # um link que esconde robôs precisa continuar escondendo para quem o recebe.
  def handle_event("filtrar", params, socket) do
    automacao = if params["show_automation"] == "true", do: nil, else: "nao"

    {:noreply,
     push_patch(socket,
       to: ~p"/people?#{Tabela.query(socket, "people", [pagina: 1], automacao: automacao)}"
     )}
  end

  defp caminho(socket, id, mudancas) do
    automacao = if socket.assigns.show_automation, do: nil, else: "nao"
    ~p"/people?#{Tabela.query(socket, id, mudancas, automacao: automacao)}"
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
        phx-change="filtrar"
        class="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end"
      >
        <%!-- A busca saiu daqui e passou a ser a da tabela: duas caixas procurando a mesma
              coisa faziam quem lê escolher em qual digitar. O que sobra é o filtro que a
              tabela não tem — as contas de automação. --%>
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

      <.data_table
        id="people"
        rows={@rows}
        estado={@tabelas["people"]}
        por_pagina={@por_pagina}
        total={@encontradas}
        onde="name and login"
        vazio={empty_message(@tabelas["people"].busca, @has_any)}
      >
        <:col :let={person} field={:name} label="name">
          <%!-- O nome abre o detalhe **dentro da plataforma**, não na origem: o que interessa
                ao clicar é o que foi coletado, e o link para a origem vive lá dentro. --%>
          <div class="font-medium">
            <.link navigate={~p"/people/#{person.id}"} class="link link-hover">
              {person.name || person.login}
            </.link>
          </div>
          <div :if={person.login} class="text-xs opacity-60">@{person.login}</div>
          <div :if={person.no_longer_observed_at} class="text-xs opacity-60">
            no longer observed since {person.no_longer_observed_at}
          </div>
        </:col>
        <:col :let={person} field={:account_type} label="account type">
          <span class={["badge badge-sm", person.account_type != "person" && "badge-ghost"]}>
            {person.account_type}
          </span>
        </:col>
        <:col :let={person} label="organisations" class="text-xs">
          <% orgs = Map.get(@organizations_by_person, person.id, []) %>
          <%!-- Quem não está em equipe alguma aparece **sem** organização, e a frase diz isso: o
                vínculo pessoa→organização não existe na origem, ele vem das equipes. Um traço
                aqui esconderia a razão. --%>
          <.absent :if={orgs == []} reason="no team — organisation unknown" />
          <div :for={org <- orgs}>{org.login}</div>
          <div :if={length(orgs) > 1} class="badge badge-sm badge-outline mt-1">
            in {length(orgs)} organisations
          </div>
        </:col>
        <:col :let={person} field={:source_system} label="source" class="text-xs">
          {person.source_system}
          <div class="opacity-60">{person.source_instance}</div>
        </:col>
        <:col :let={person} label="identifier at source" class="font-mono text-xs">
          {person.external_id}
        </:col>
        <:col :let={person} field={:collected_at} label="collected at" class="text-xs">
          {person.collected_at}
        </:col>
      </.data_table>

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
    estado = socket.assigns.tabelas["people"]

    opts =
      [search: estado.busca]
      |> then(fn opts ->
        if socket.assigns.show_automation, do: opts, else: [{:account_type, "person"} | opts]
      end)

    rows =
      EO.list_people(
        tenant,
        opts ++
          [order_by: estado.ordem, limit: @por_pagina, offset: (estado.pagina - 1) * @por_pagina]
      )

    socket
    |> assign(rows: rows, por_pagina: @por_pagina)
    # A contagem da paginação é a da busca vigente — paginar sobre o total afirmaria páginas
    # que o filtro não tem.
    |> assign(encontradas: EO.count_people(tenant, opts))
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
