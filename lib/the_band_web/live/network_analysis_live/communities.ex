defmodule TheBandWeb.NetworkAnalysisLive.Communities do
  @moduledoc """
  `/network-analysis/:organization_id/communities` — a página **Communities** da área, feature
  076, T037 (US4; FR-021, FR-026 a FR-031; FR-015, regras 2, 4 e 6; `contracts/tela.md`;
  protótipo aprovado, §3, Tela 3, itens 3.3.1 a 3.3.4, e 3.7.4).

  - três blocos (3.3.1): o número de comunidades, a modularidade **ao lado do Q_rand** com as
    faixas citadas e a fonte (FR-031), e *"Not the declared teams — a reading"* (FR-030);
  - o grafo de comunidades: as mesmas posições do ponderado, cor, contorno tracejado e letra por
    comunidade (3.3.2, FR-021);
  - o método, dito: o guloso de Clauset, Newman e Moore, com peso (3.3.3; R21: o protótipo dizia
    Louvain, vale a base);
  - um cartão por comunidade com alguém alcançado (3.3.4): letra, pessoas, ligações dentro e para
    fora, os três mais ligados dentro **entre os alcançados** e só com escopo concedido (DS1),
    todos os membros alcançados por nome, e os de fora agregados só se forem ao menos 3.

  A visão já chega recortada por `NetworkAnalysis.read/4`: nenhuma decisão de acesso mora aqui.
  As frases são da tela, em inglês (§11.1): não traduzir de volta.
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBandWeb.NetworkAnalysisLive.GraphComponents
  alias TheBandWeb.NetworkAnalysisLive.Leitura
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = NetworkAnalysis.subscribe(socket.assigns.current_tenant)

    {:ok, assign(socket, page_title: "Communities", opcoes: NetworkAnalysis.options())}
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
        active={:communities}
        organization_id={@organization_id}
        selection={@selecao}
      />
      <div :if={assigns[:organizacao]} class="flex flex-col gap-6" id="network-communities">
        <Shared.header
          title="Communities"
          question="Which groups work mostly among themselves?"
          page={:communities}
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
            {render_comunidades(assign(assigns, v: visao))}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_comunidades(%{v: %{communities: {:recortado, :no_reach}}} = assigns) do
    ~H"""
    <p id="sem-alcance" class="text-sm">
      You reach no one else in this network, so its communities are not shown here. The measures of
      the network, and your own, are on the other pages.
    </p>
    """
  end

  defp render_comunidades(%{v: %{communities: {:ausente, motivo}}} = assigns) do
    assigns = assign(assigns, motivo: motivo)

    ~H"""
    <div id="sem-comunidades" class="rounded border border-dashed border-base-content/40 p-4">
      <.absent reason={sem_comunidades(@motivo, @selecao.network)} />
    </div>
    """
  end

  defp render_comunidades(%{v: %{communities: {:ok, c}}} = assigns) do
    assigns = assign(assigns, c: c, rede: assigns.selecao.network)

    ~H"""
    <%!-- 3.3.1: os três blocos --%>
    <section id="resumo-das-comunidades" class="grid gap-4 sm:grid-cols-3">
      <div class="border-t-2 border-warning pt-2 flex flex-col gap-1">
        <h2 class="font-mono text-xs uppercase">
          Communities <Shared.marca tipo={:derivado} />
        </h2>
        <%= case @c.count do %>
          <% {:ok, n} -> %>
            <p id="numero-de-comunidades" class="text-3xl font-semibold tabular-nums">{n}</p>
            <p class="text-sm">
              {if n == 1, do: "group", else: "groups"} whose people are linked more among themselves
              than with the rest.
            </p>
          <% {:suprimido, _} -> %>
            <p id="numero-de-comunidades" class="text-sm">
              <.absent reason="not shown: it would count fewer than 3 people outside your reach" />
            </p>
        <% end %>
      </div>

      <div class="border-t-2 border-warning pt-2 flex flex-col gap-1">
        <h2 class="font-mono text-xs uppercase">
          Modularity <Shared.marca tipo={:derivado} />
        </h2>
        <%= case @c.modularity do %>
          <% {:ok, q} -> %>
            <p id="modularidade" class="text-3xl font-semibold tabular-nums">{duas_casas(q)}</p>
          <% {:ausente, motivo} -> %>
            <p id="modularidade"><.absent reason={medida_ausente(motivo)} /></p>
        <% end %>
        <p id="q-rand" class="text-sm">
          <%= case @c.q_rand do %>
            <% {:ok, %{value: v, graphs_defined: n}} -> %>
              Random networks with the same people, links and weights reach
              <span class="font-mono tabular-nums">{duas_casas(v)}</span>
              on average ({n} networks). The number that tells is the difference between the two.
            <% {:ausente, motivo} -> %>
              Random networks: <.absent reason={medida_ausente(motivo)} />
          <% end %>
        </p>
        <%!-- FR-031: as faixas são citação, com a fonte, e nunca adjetivo da plataforma --%>
        <p id="faixas-citadas" class="text-xs opacity-70">
          0 means no more grouping than chance. Above about {Enum.at(@c.thresholds, 0)}, "in practice
          indicates significant community structure" (Clauset, Newman and Moore, 2004); values
          above {Enum.at(@c.thresholds, 1)} are rare (Newman and Girvan, 2004). Small random
          networks reach {Enum.at(@c.thresholds, 0)} by chance (Guimerà, Sales-Pardo and Amaral,
          2004), which is why the random value is beside it.
        </p>
      </div>

      <div class="border-t-2 border-warning pt-2 flex flex-col gap-1" id="nao-sao-equipes">
        <h2 class="font-mono text-xs uppercase">Not the declared teams</h2>
        <p class="text-lg font-semibold">a reading</p>
        <p class="text-sm">
          A community comes from the links. A team is declared. They can differ, and the difference
          is what to look at.
        </p>
      </div>
    </section>

    <%!-- 3.3.2: o grafo de comunidades, com as posições do ponderado --%>
    <section id="grafo-de-comunidades" class="flex flex-col gap-2">
      <h2 class="font-semibold">Community graph <Shared.marca tipo={:derivado} /></h2>
      <%= case @v.graph do %>
        <% {:ok, grafo} -> %>
          <GraphComponents.graph
            id="grafo-comunidades"
            graph={grafo}
            network={@rede}
            view="communities"
          />
        <% _ -> %>
          <.absent reason={"not drawn: " <> Leitura.sem_aresta(@rede)} />
      <% end %>
      <%!-- 3.3.3: o método, dito; R21: vale a base, e não o Louvain do protótipo --%>
      <p id="metodo" class="text-sm">
        Colour, a dashed outline and a letter mark each community, so the picture reads in
        greyscale. Communities are found by the greedy modularity method of Clauset, Newman and
        Moore on the {@rede} links, weighted by count, with ties broken by a declared rule; the same
        data always gives the same communities. The letter follows size, A the largest.
      </p>
    </section>

    <%!-- 3.3.4 e 3.7.4: um cartão por comunidade com alguém que se alcança --%>
    <section id="cartoes" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <article
        :for={b <- @c.blocks}
        id={"comunidade-#{b.index}"}
        class="card border border-base-300 bg-base-100 p-4 flex flex-col gap-2"
      >
        <h3 class="font-semibold flex items-center gap-2">
          <GraphComponents.community_mark community={b.index} />
          <%= case b.size do %>
            <% {:ok, n} -> %>
              <span>{pessoas(n)}</span>
            <% {:suprimido, _} -> %>
              <span class="text-sm font-normal">
                <.absent reason="size not shown: it would count fewer than 3 people outside your reach" />
              </span>
          <% end %>
        </h3>
        <p class="text-xs opacity-80">
          <%= case {b.internal_edges, b.outside_edges} do %>
            <% {{:ok, dentro}, {:ok, fora}} -> %>
              {plural(dentro, "link", "links")} inside · {fora} to other communities
            <% _ -> %>
              Links not shown: they would count fewer than 3 people outside your reach.
          <% end %>
        </p>

        <div class="text-sm">
          <%= case b.core do %>
            <% {:recortado, :positions_not_granted} -> %>
              <p class="opacity-80">
                The most linked members are shown only to those granted a scope that reaches them,
                or who administer the organisation.
              </p>
            <% [] -> %>
              <p class="opacity-80">No member you may rank is in this community.</p>
            <% nucleo -> %>
              <p>
                <span class="font-semibold">
                  Most linked inside{if @v.reach == :parcial, do: ", among the members you reach"}:
                </span>
                <span :for={{p, i} <- Enum.with_index(nucleo)}>
                  {p.name} ({p.internal_degree}){if i < length(nucleo) - 1, do: ","}
                </span>
              </p>
          <% end %>
        </div>

        <%!-- T048: o nome de alcançado leva ao perfil --%>
        <p class="text-sm">
          <span :for={{m, i} <- Enum.with_index(b.members)}>
            <.link
              navigate={Shared.profile_path(@organization_id, m.person_id, @selecao)}
              class="link link-hover"
            >{m.name}</.link>{if i < length(b.members) - 1, do: ","}
          </span>
        </p>

        <p :if={match?({:agregado, _}, b.outside)} class="text-sm italic">
          {elem(b.outside, 1)} outside your reach
        </p>
        <p :if={b.outside == :sem_agregado} class="text-xs opacity-70">
          Some members are outside your reach; they are not counted here, because the count would
          be fewer than 3.
        </p>
      </article>
    </section>

    <p :if={@v.reach == :parcial} id="comunidades-sem-alcance" class="text-xs opacity-70">
      A community where you reach no one has no card here.
    </p>

    <footer class="text-xs opacity-70">
      Not on this page: export, team names on communities, labels that judge a person.
    </footer>
    """
  end

  defp sem_comunidades(:no_edge_in_window, rede), do: "no community: " <> Leitura.sem_aresta(rede)

  defp sem_comunidades(:not_computed, _rede),
    do: "not calculated: this reading was computed before communities existed in the platform"

  defp medida_ausente(:network_too_large_for_platform),
    do: "not calculated: the network is above the size the platform compares with random networks"

  defp medida_ausente(:no_edge_in_window), do: "not calculated: no link in this window"
  defp medida_ausente(_), do: "not calculated in this reading"

  # Duas casas só para a modularidade (decisão 11 do protótipo; 3.0.6).
  defp duas_casas(v), do: :erlang.float_to_binary(v * 1.0, decimals: 2)

  defp pessoas(1), do: "1 person"
  defp pessoas(n), do: "#{n} people"

  defp plural(1, um, _varios), do: "1 #{um}"
  defp plural(n, _um, varios), do: "#{n} #{varios}"
end
