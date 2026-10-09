defmodule TheBandWeb.NetworkAnalysisLive.Hubs do
  @moduledoc """
  `/network-analysis/:organization_id/hubs` — a página **Hubs** da área, feature 076, T040 (US5;
  FR-032 a FR-036, FR-047; FR-015 regra 5; R1 da segurança, DS1, DS5; protótipo aprovado, §3,
  Tela 4, itens 3.4.1 a 3.4.4, com as divergências de R21).

  Quatro listas — grau, intermediação, proximidade e autovetor —, cada uma do tamanho da base,
  ordenada pela medida da rede inteira, empate pelo identificador e **marcado** (*"tied"*; o
  protótipo dizia *"ties ordered by name"*, vale a base). Cada linha diz o valor na unidade e a
  frase que ele sustenta:

  - **grau** em pessoas distintas, separado por sentido com os rótulos de `network.degree.count`;
  - **intermediação** em % dos caminhos mais curtos;
  - **proximidade** com a distância média até quem a pessoa alcança **e quantas alcança**, nunca
    1/proximidade (FR-035);
  - **autovetor** por componente, com a frase de que componentes não se comparam (FR-036); o que
    não converge é ausência escrita (3.4.4).

  Com alcance parcial, só as pessoas alcançadas, *"Among the people you reach"*, e *"People
  outside your reach are not ranked here."*, sem dizer quantas (R1). Sem escopo concedido, a
  página diz que os hubs com nome de outras pessoas não estão disponíveis (DS1); sem alcance, só
  as medidas da rede (DS5). A visão já chega recortada por `NetworkAnalysis.read/4`.

  As frases são da tela, em inglês (§11.1): não traduzir de volta.
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBandWeb.NetworkAnalysisLive.Leitura
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = NetworkAnalysis.subscribe(socket.assigns.current_tenant)

    {:ok, assign(socket, page_title: "Hubs", opcoes: NetworkAnalysis.options())}
  end

  @impl true
  def handle_params(%{"organization_id" => id} = params, _uri, socket) do
    {:noreply, Leitura.ler(socket, id, NetworkAnalysis.selection(params))}
  end

  @impl true
  def handle_info({:network_analysis_ready, organization_id, _ids}, socket) do
    if organization_id == socket.assigns[:organization_id],
      do: {:noreply, Leitura.ler(socket, organization_id, socket.assigns.selecao)},
      else: {:noreply, socket}
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
        :if={assigns[:organizacao]}
        active={:hubs}
        organization_id={@organization_id}
        selection={@selecao}
      />
      <div :if={assigns[:organizacao]} class="flex flex-col gap-6" id="network-hubs">
        <Shared.header
          title="Hubs"
          question="Who is central, and in which sense?"
          page={:hubs}
          organization={@organizacao}
          selection={@selecao}
          options={@opcoes}
          reading={Leitura.para_o_cabecalho(@visao)}
        />

        <%= case @visao do %>
          <% {:ausente, motivo} -> %>
            <div id="sem-leitura" class="rounded border border-dashed border-base-content/40 p-4">
              <.absent reason={Leitura.motivo_da_ausencia(motivo, @selecao.network)} />
            </div>
          <% visao -> %>
            {render_hubs(assign(assigns, v: visao, rede: @selecao.network))}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_hubs(%{v: %{hubs: {:recortado, :no_reach}}} = assigns) do
    ~H"""
    <p id="sem-alcance" class="text-sm">
      You reach no one else in this network, so no list of people is shown here. The measures of the
      network are on the Distance page, and your own on your profile.
    </p>
    """
  end

  defp render_hubs(%{v: %{hubs: {:recortado, :positions_not_granted}}} = assigns) do
    ~H"""
    <p id="sem-concessao" class="text-sm">
      Hubs with other people's names are available to those granted a scope that reaches them, or
      who administer the organisation. Your own position is on your profile.
    </p>
    {render_nao_avaliacao(assigns)}
    """
  end

  defp render_hubs(%{v: %{hubs: {:ausente, _}}} = assigns) do
    ~H"""
    <div id="sem-hubs" class="rounded border border-dashed border-base-content/40 p-4">
      <.absent reason={"no list: " <> Leitura.sem_aresta(@rede)} />
    </div>
    """
  end

  defp render_hubs(%{v: %{hubs: {:ok, h}}} = assigns) do
    assigns = assign(assigns, h: h)

    ~H"""
    <p class="text-sm">
      Four measures, four different senses of “central”. The {tamanho(@h)} highest in each, ties
      broken by an internal identifier and marked “tied”. A high value describes where someone sits
      in the links, not how good their work is.
    </p>
    {render_nao_avaliacao(assigns)}

    <div :if={@v.reach == :parcial} id="entre-alcancados" class="text-sm">
      <p class="font-semibold">Among the people you reach.</p>
      <p>People outside your reach are not ranked here.</p>
    </div>

    <div class="grid gap-6 sm:grid-cols-2">
      <section id="hubs-grau" class="flex flex-col gap-2">
        <h2 class="font-semibold">Degree <Shared.marca tipo={:derivado} /></h2>
        <p class="text-sm">How many different people someone is linked to, in either direction.</p>
        <.linhas
          organization_id={@organization_id}
          selecao={@selecao}
          lista={@h.degree}
          id="lista-grau"
        >
          <:valor :let={l}>
            <span class="block">linked to {pessoas(elem(l.value, 1))}</span>
            <span class="block text-xs opacity-70">
              {saida(@rede, l.detail.out_people)} · {entrada(@rede, l.detail.in_people)}
            </span>
          </:valor>
        </.linhas>
      </section>

      <section id="hubs-intermediacao" class="flex flex-col gap-2">
        <h2 class="font-semibold">Betweenness <Shared.marca tipo={:derivado} /></h2>
        <p class="text-sm">
          How often someone lies on the shortest path between two other people: a bridge between
          groups.
        </p>
        <.linhas
          organization_id={@organization_id}
          selecao={@selecao}
          lista={@h.betweenness}
          id="lista-intermediacao"
        >
          <:valor :let={l}>{caminhos(elem(l.value, 1))}</:valor>
        </.linhas>
      </section>

      <section id="hubs-proximidade" class="flex flex-col gap-2">
        <h2 class="font-semibold">Closeness <Shared.marca tipo={:derivado} /></h2>
        <p class="text-sm">
          How few steps someone needs to reach the people they can reach, and how many they reach.
        </p>
        <.linhas
          organization_id={@organization_id}
          selecao={@selecao}
          lista={@h.closeness}
          id="lista-proximidade"
        >
          <:valor :let={l}>
            <%= case l.detail do %>
              <% %{distance_mean: m, reaches: r} -> %>
                <span class="block">{passos(m)} on average</span>
                <span class="block text-xs opacity-70">to the {pessoas(r)} they reach</span>
              <% _ -> %>
                <.absent reason="distance not calculated in this reading" />
            <% end %>
          </:valor>
        </.linhas>
      </section>

      <section id="hubs-autovetor" class="flex flex-col gap-2">
        <h2 class="font-semibold">Eigenvector <Shared.marca tipo={:derivado} /></h2>
        <p class="text-sm">
          How linked someone is to people who are themselves well linked. It is computed inside each
          group not linked to the others, and values of different groups are not compared.
        </p>
        <div
          :for={g <- @h.eigenvector}
          id={"autovetor-grupo-#{g.component}"}
          class="flex flex-col gap-1"
        >
          <h3 :if={length(@h.eigenvector) > 1} class="text-xs font-mono uppercase opacity-70">
            Group {g.component}
          </h3>
          <%= case g.rows do %>
            <% {:ausente, :did_not_converge} -> %>
              <p class="text-sm">
                <.absent reason="not computed: the calculation did not settle" />
                After {rodadas()} rounds, the most the base allows, the values were still changing
                by more than {tolerancia()} per person between rounds: in a group whose links run
                mostly one way, the calculation can circle without settling. No one gets a value,
                and no one gets zero.
              </p>
            <% _ -> %>
              <.linhas
                organization_id={@organization_id}
                selecao={@selecao}
                lista={g.rows}
                id={"lista-autovetor-#{g.component}"}
              >
                <:valor :let={l}>{Shared.autovetor_texto(elem(l.value, 1))}</:valor>
              </.linhas>
          <% end %>
        </div>
      </section>
    </div>
    """
  end

  defp render_nao_avaliacao(assigns) do
    ~H"""
    <%!-- FR-047: o texto exato --%>
    <p id="nao-avaliacao" class="text-sm border-l-4 border-base-content/40 pl-3">
      Position in this network and window. It does not measure performance, importance or merit,
      and must not be used to evaluate a person.
    </p>
    """
  end

  attr :lista, :any, required: true
  attr :organization_id, :string, required: true
  attr :selecao, :map, required: true
  attr :id, :string, required: true
  slot :valor, required: true

  defp linhas(%{lista: {:ausente, motivo}} = assigns) do
    assigns = assign(assigns, motivo: motivo)

    ~H"""
    <p id={@id} class="text-sm"><.absent reason={ausencia(@motivo)} /></p>
    """
  end

  defp linhas(%{lista: {:ok, linhas}} = assigns) do
    assigns = assign(assigns, linhas: linhas)

    ~H"""
    <ul id={@id} class="flex flex-col divide-y divide-base-300 text-sm">
      <li
        :for={l <- @linhas}
        class="flex items-baseline justify-between gap-3 py-1"
        data-person={l.person_id}
      >
        <span>
          <.link
            navigate={Shared.profile_path(@organization_id, l.person_id, @selecao)}
            class="link link-hover"
            data-nome
          >
            {l.name}
          </.link>
          <span :if={l.tied?} class="badge badge-ghost badge-xs ml-1">tied</span>
        </span>
        <span class="font-mono text-xs text-right">{render_slot(@valor, l)}</span>
      </li>
    </ul>
    """
  end

  defp tamanho(h) do
    case h.degree do
      {:ok, linhas} -> length(linhas)
      _ -> "five"
    end
  end

  defp ausencia(:network_too_small), do: "not calculated: fewer than 3 people"
  defp ausencia(:did_not_converge), do: "not computed: the calculation did not settle"
  defp ausencia(:no_edge_in_window), do: "no link in this window"
  defp ausencia(_), do: "not calculated in this reading"

  # Os rótulos de `network.degree.count`, por sentido (FR-033): nunca "assigns to".
  defp saida("assignment", n), do: "opened issues assigned to #{pessoas(n)}"
  defp saida("review", n), do: "reviews #{pessoas(n)}"
  defp entrada("assignment", n), do: "assigned on issues opened by #{pessoas(n)}"
  defp entrada("review", n), do: "is reviewed by #{pessoas(n)}"

  defp caminhos(v) when v == 0, do: "on no shortest path"
  defp caminhos(v) when v < 0.01, do: "under 1% of paths"
  defp caminhos(v), do: "#{round(v * 100)}% of paths"

  defp passos(m), do: "#{:erlang.float_to_binary(m * 1.0, decimals: 1)} steps"

  defp pessoas(1), do: "1 person"
  defp pessoas(n), do: "#{n} people"

  # 3.4.4: o número de rodadas e a razão, da base (`network.analysis.parameters`), lidos aqui
  # para a frase não envelhecer quando a base mudar (T053).
  defp rodadas, do: NetworkAnalysis.options().eigenvector.max_iterations

  defp tolerancia,
    do:
      :erlang.float_to_binary(NetworkAnalysis.options().eigenvector.tolerance_per_node, [
        :compact,
        decimals: 10
      ])
end
