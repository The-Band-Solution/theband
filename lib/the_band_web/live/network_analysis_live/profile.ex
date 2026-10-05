defmodule TheBandWeb.NetworkAnalysisLive.Profile do
  @moduledoc """
  `/network-analysis/:organization_id/people/:person_id` — o perfil de uma pessoa na área,
  feature 076, T048 (US9, cen. 1 a 4; FR-047 a FR-049; protótipo aprovado 3.6.4 e Tela 8).

  As duas redes, uma ao lado da outra (empilhadas no telefone): em cada uma, as contagens com os
  rótulos de `network.degree.count` (*"opened issues assigned to N people"*, *"assigned on issues
  opened by N people"*; *"reviews N people"*, *"is reviewed by N people"* — nunca *"assigns to"*
  nem *"receives from"*, que atribuem ao autor o ato de designar), grau e intermediação com o
  percentil, a posição em frase, e as duas listas de pares por peso, com o total. Os pares com
  pessoas de fora do alcance só somados (FR-049). Sem aresta, a ausência escrita, e não zeros.

  `NetworkAnalysis.profile/5` decide quem abre: o mesmo *"not found"* para outro tenant,
  inexistente, fora do alcance e id malformado (FR-014). As frases são da tela, em inglês (§11.1).
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = NetworkAnalysis.subscribe(socket.assigns.current_tenant)
    {:ok, assign(socket, page_title: "Profile", opcoes: NetworkAnalysis.options())}
  end

  @impl true
  def handle_params(%{"organization_id" => org, "person_id" => pessoa} = params, _uri, socket) do
    {:noreply, ler(socket, org, pessoa, NetworkAnalysis.selection(params))}
  end

  # Relida pela função de domínio, com o alcance de agora (A22).
  @impl true
  def handle_info({:network_analysis_ready, organization_id, _ids}, socket) do
    if organization_id == socket.assigns[:organization_id],
      do:
        {:noreply,
         ler(socket, organization_id, socket.assigns.perfil.person_id, socket.assigns.selecao)},
      else: {:noreply, socket}
  end

  defp ler(socket, org, pessoa, selecao) do
    %{current_tenant: tenant, current_user: user} = socket.assigns

    case NetworkAnalysis.profile(tenant, user, org, pessoa, selecao) do
      {:ok, perfil} ->
        {:ok, organizacao} = EO.fetch_organization(tenant, org)

        assign(socket,
          perfil: perfil,
          selecao: selecao,
          organization_id: organizacao.id,
          organizacao: organizacao,
          page_title: perfil.name
        )

      # O mesmo texto para os quatro casos (FR-014; §11.1): nunca "permission denied".
      {:error, :not_found} ->
        socket
        |> put_flash(:error, dgettext("errors", "Not found."))
        |> push_navigate(to: ~p"/network-analysis")
    end
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
      <Shared.area_nav
        :if={assigns[:perfil]}
        active={:positions}
        organization_id={@organization_id}
        selection={@selecao}
      />
      <div :if={assigns[:perfil]} id="perfil" class="flex flex-col gap-6">
        <nav class="text-sm opacity-70" aria-label="breadcrumb">
          <.link navigate={~p"/network-analysis"} class="link link-hover">Network analysis</.link>
          ›
          <.link
            navigate={Shared.page_path(:positions, @organization_id, @selecao)}
            class="link link-hover"
          >
            {Shared.nome(@organizacao)}
          </.link>
          › <span>{@perfil.name}</span>
        </nav>
        <header>
          <h1 class="text-2xl font-semibold">{@perfil.name}</h1>
          <p class="opacity-80">
            Both networks, in the last {@selecao.window} days. <Shared.marca tipo={:derivado} />
          </p>
        </header>

        <p id="nao-avaliacao" class="text-sm border-l-4 border-base-content/40 pl-3">
          Position in this network and window. It does not measure performance, importance or merit,
          and must not be used to evaluate a person.
        </p>

        <div class="grid gap-6 sm:grid-cols-2">
          <section
            :for={rede <- @opcoes.networks.allowed}
            id={"rede-#{rede}"}
            class="card border border-base-300 bg-base-100 p-4 flex flex-col gap-3"
          >
            <h2 class="font-semibold">
              {Shared.link_label(rede).short} network
              <span class="block text-xs font-normal opacity-70">{Shared.link_label(rede).arrow}</span>
            </h2>
            {render_rede(assign(assigns, rede: rede, r: Map.fetch!(@perfil.networks, rede)))}
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp render_rede(%{r: {:ausente, motivo}} = assigns) do
    assigns = assign(assigns, motivo: motivo)

    ~H"""
    <.absent reason={ausencia(@motivo, @rede)} />
    """
  end

  defp render_rede(%{r: {:ok, r}} = assigns) do
    assigns = assign(assigns, r: r)

    ~H"""
    <dl class="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
      <dt class="opacity-70">{rotulo_saida(@rede)}</dt>
      <dd data-contagem="saida">{saida(@rede, @r.out_people)}</dd>
      <dt class="opacity-70">{rotulo_entrada(@rede)}</dt>
      <dd data-contagem="entrada">{entrada(@rede, @r.in_people)}</dd>
      <dt class="opacity-70">linked to</dt>
      <dd>{pessoas(elem(@r.degree, 1))}{percentil(@r.role, :degree_percentile)}</dd>
      <dt class="opacity-70">betweenness</dt>
      <dd>{intermediacao(@r.betweenness)}{percentil(@r.role, :betweenness_percentile)}</dd>
      <dt class="opacity-70">community</dt>
      <dd>
        {if is_integer(@r.community),
          do: Shared.community_letter(@r.community),
          else: "not calculated"}
      </dd>
      <dt class="opacity-70">position</dt>
      <dd>
        <%= case @r.role do %>
          <% {:ok, p} -> %>
            <span class="font-semibold">{p.label}.</span> {p.sentence}
            <span class="block text-xs opacity-70">cut: {p.cut}</span>
          <% {:ausente, :network_too_small_for_roles} -> %>
            <.absent reason="not described: the network is below the minimum size for positions" />
          <% {:recortado, _} -> %>
            <span class="text-xs opacity-70">
              shown only to those granted a scope that reaches this person
            </span>
        <% end %>
      </dd>
    </dl>

    <div class="grid gap-4">
      {render_lista(
        assign(assigns,
          id: "#{@rede}-para",
          titulo: titulo_para(@rede),
          linhas: @r.to,
          fora: @r.to_outside_reach,
          total: @r.to_total
        )
      )}
      {render_lista(
        assign(assigns,
          id: "#{@rede}-de",
          titulo: titulo_de(@rede),
          linhas: @r.from,
          fora: @r.from_outside_reach,
          total: @r.from_total
        )
      )}
    </div>
    """
  end

  defp render_lista(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col gap-1">
      <h3 class="font-mono text-xs uppercase">
        {@titulo} · {unidades(@rede, @total)}
      </h3>
      <%= if @linhas == [] and @fora == :nenhum do %>
        <.absent reason="no one in this window" />
      <% else %>
        <ul class="flex flex-col divide-y divide-base-300 text-sm">
          <li :for={l <- @linhas} class="flex justify-between gap-3 py-1">
            <.link
              navigate={Shared.profile_path(@organization_id, l.person_id, @selecao)}
              class="link"
            >
              {l.name}
            </.link>
            <span class="font-mono text-xs">{unidades(@rede, l.weight)}</span>
          </li>
          <li :if={match?({:agregado, _}, @fora)} class="py-1 italic">
            {unidades(@rede, elem(@fora, 1))} with people outside your reach
          </li>
        </ul>
      <% end %>
    </div>
    """
  end

  # Os rótulos de `network.degree.count`, por rede e sentido (FR-048).
  defp rotulo_saida("assignment"), do: "opened"
  defp rotulo_saida("review"), do: "reviewed"
  defp rotulo_entrada("assignment"), do: "assignee of"
  defp rotulo_entrada("review"), do: "was reviewed"

  defp saida("assignment", 0), do: "opened no issue assigned to someone else in this window"
  defp saida("assignment", n), do: "opened issues assigned to #{pessoas(n)}"
  defp saida("review", 0), do: "reviewed no one in this window"
  defp saida("review", n), do: "reviews #{pessoas(n)}"

  defp entrada("assignment", 0), do: "assigned on no issue opened by someone else in this window"
  defp entrada("assignment", n), do: "assigned on issues opened by #{pessoas(n)}"
  defp entrada("review", 0), do: "reviewed by no one in this window"
  defp entrada("review", n), do: "is reviewed by #{pessoas(n)}"

  defp titulo_para("assignment"), do: "Issues they opened, assigned to"
  defp titulo_para("review"), do: "Change requests they reviewed, of"
  defp titulo_de("assignment"), do: "Issues they are assigned on, opened by"
  defp titulo_de("review"), do: "Reviewed by"

  defp unidades("assignment", 1), do: "1 issue"
  defp unidades("assignment", n), do: "#{n} issues"
  defp unidades("review", 1), do: "1 review"
  defp unidades("review", n), do: "#{n} reviews"

  defp intermediacao({:ok, v}) when v == 0, do: "on no shortest path between others"

  defp intermediacao({:ok, v}) when v < 0.01,
    do: "on under 1% of the shortest paths between others"

  defp intermediacao({:ok, v}), do: "on #{round(v * 100)}% of the shortest paths between others"
  defp intermediacao({:ausente, :network_too_small}), do: "not calculated: fewer than 3 people"
  defp intermediacao(_), do: "not calculated in this reading"

  defp percentil({:ok, p}, chave), do: " · percentile #{round(Map.fetch!(p, chave))}"
  defp percentil(_papel, _chave), do: ""

  defp ausencia(:no_edges_in_window, "assignment"),
    do: "no assignment with another person in this network in this window"

  defp ausencia(:no_edges_in_window, "review"),
    do: "no review with another person in this network in this window"

  defp ausencia(:not_computed, _),
    do: "not calculated: the platform has not computed this reading yet"

  defp ausencia(:stale, _),
    do: "not shown: this reading is older than the longest window, and was not recalculated"

  defp ausencia(:review_reading_outdated, _),
    do:
      "not shown: the review network reading was calculated before the latest change to the " <>
        "accounts declared as the organisation's; it is recalculated at the next synchronization"

  defp pessoas(1), do: "1 person"
  defp pessoas(n), do: "#{n} people"
end
