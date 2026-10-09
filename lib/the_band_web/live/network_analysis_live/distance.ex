defmodule TheBandWeb.NetworkAnalysisLive.Distance do
  @moduledoc """
  `/network-analysis/:organization_id/distance` — a página **Distance and small world** da área,
  feature 076, T042 e T044 (US6, US7; FR-037 a FR-043; protótipo aprovado, §3, Tela 5, itens
  3.5.1 a 3.5.5, com as divergências de R21).

  **Primeira metade (T042)**: distância média, diâmetro e eficiência global, cada um com o valor
  médio dos aleatórios ao lado; a fração de pares que se alcançam; o diâmetro como *"the longest
  distance between people who reach each other"*; a nota de que só a eficiência conta o par sem
  caminho como zero; a distribuição dos comprimentos em barras hachuradas. **Nenhuma faixa vira
  adjetivo** (a referência escrevia *"efficient"* acima de 0,7, `:354`).

  **Segunda metade (T044)**: a tabela clustering e distância média, real × aleatórios, com as
  razões; σ com uma casa; *"meets the σ > 1 criterion"* (ou *"does not meet"*) e a frase do que o
  critério não prova (Telesford et al., 2011); quantos aleatórios, a semente, quantos entraram em
  cada média e quantas pessoas ficaram fora do clustering. σ ausente **nunca** é lido como *"not a
  small world"* (FR-042). O protótipo dizia 50 aleatórios e σ *"not tested"* em rede partida;
  vale a base: 100, e σ medido pelos pares que se alcançam (R21).

  As medidas são da rede inteira e aparecem para todo alcance (DS5). As frases são da tela, em
  inglês (§11.1): não traduzir de volta.
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBandWeb.NetworkAnalysisLive.Leitura
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = NetworkAnalysis.subscribe(socket.assigns.current_tenant)

    {:ok,
     assign(socket, page_title: "Distance and small world", opcoes: NetworkAnalysis.options())}
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
        active={:distance}
        organization_id={@organization_id}
        selection={@selecao}
      />
      <div :if={assigns[:organizacao]} class="flex flex-col gap-6" id="network-distance">
        <Shared.header
          title="Distance and small world"
          question="How many steps separate people, and is the network a small world?"
          page={:distance}
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
            {render_distancia(assign(assigns, v: visao, d: visao.distance, sw: visao.small_world))}
            {render_mundo_pequeno(assign(assigns, v: visao, d: visao.distance, sw: visao.small_world))}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ── primeira metade: T042 ──────────────────────────────────────────────────

  defp render_distancia(assigns) do
    ~H"""
    <p id="conectividade" class="text-sm">
      {conectividade(@v)} Distances ignore direction and count each link once, whatever its weight.
    </p>

    <p
      :if={is_number(@d.reachable_share) and @d.reachable_share < 1}
      id="pares-sem-caminho"
      class="text-sm"
    >
      Some pairs of people have no path between them: {pct(@d.reachable_share)} of the pairs reach
      each other, and the average distance and the diameter are measured only between them.
    </p>

    <section id="tres-medidas" class="grid gap-4 sm:grid-cols-3">
      <div id="distancia-media" class="border-t-2 border-warning pt-2 flex flex-col gap-1">
        <h2 class="font-mono text-xs uppercase">
          Average distance <Shared.marca tipo={:derivado} />
        </h2>
        <%= case @d.average do %>
          <% {:ok, v} -> %>
            <p class="text-3xl font-semibold tabular-nums">
              {uma_casa(v)} <span class="text-base font-normal">steps</span>
            </p>
            <p class="text-sm">between two people who reach each other, along the shortest path.</p>
          <% {:ausente, m} -> %>
            <.absent reason={ausencia(m)} />
        <% end %>
        <p class="text-xs opacity-80">{aleatorio(@d.random, :average, &"#{uma_casa(&1)} steps")}</p>
      </div>

      <div id="diametro" class="border-t-2 border-warning pt-2 flex flex-col gap-1">
        <h2 class="font-mono text-xs uppercase">Diameter <Shared.marca tipo={:derivado} /></h2>
        <%= case @d.diameter do %>
          <% {:ok, v} -> %>
            <p class="text-3xl font-semibold tabular-nums">
              {v} <span class="text-base font-normal">steps</span>
            </p>
            <p class="text-sm">the longest distance between people who reach each other.</p>
          <% {:ausente, m} -> %>
            <.absent reason={ausencia(m)} />
        <% end %>
        <p class="text-xs opacity-80">{aleatorio(@d.random, :diameter, &"#{uma_casa(&1)} steps")}</p>
      </div>

      <div id="eficiencia" class="border-t-2 border-warning pt-2 flex flex-col gap-1">
        <h2 class="font-mono text-xs uppercase">
          Global efficiency <Shared.marca tipo={:derivado} />
        </h2>
        <%= case @d.efficiency do %>
          <% {:ok, v} -> %>
            <p class="text-3xl font-semibold tabular-nums">{pct(v)}</p>
            <p class="text-sm">
              of what it would be if everyone were linked to everyone. Pairs that cannot reach each
              other count as zero here, and only here.
            </p>
          <% {:ausente, m} -> %>
            <.absent reason={ausencia(m)} />
        <% end %>
        <p class="text-xs opacity-80">{aleatorio(@d.random, :efficiency, &pct/1)}</p>
      </div>
    </section>

    <section id="comprimentos" class="flex flex-col gap-2">
      <h2 class="font-semibold">Shortest paths, by length <Shared.marca tipo={:derivado} /></h2>
      <%= case @d.lengths do %>
        <% {:ok, []} -> %>
          <.absent reason={"no path: " <> Leitura.sem_aresta(@selecao.network)} />
        <% {:ok, comprimentos} -> %>
          <p class="text-xs opacity-70">
            {Enum.sum(Enum.map(comprimentos, &elem(&1, 1)))} pairs of people who reach each other
          </p>
          <ul class="flex flex-col gap-1 text-xs font-mono">
            <li
              :for={{d, n} <- comprimentos}
              class="grid grid-cols-[4.5rem_1fr_5rem] items-center gap-2"
              data-length={d}
            >
              <span>{if d == 1, do: "1 step", else: "#{d} steps"}</span>
              <span
                class="h-3 border border-warning/70 bg-[repeating-linear-gradient(135deg,var(--color-warning)_0_2px,transparent_2px_5px)]"
                style={"width: #{largura(n, comprimentos)}%"}
              ></span>
              <span class="text-right">{n} {if n == 1, do: "pair", else: "pairs"}</span>
            </li>
          </ul>
        <% {:suprimido, _} -> %>
          <p class="text-sm">
            The counts of pairs are not shown: they would tell how many people are in the network,
            which would count fewer than 3 people outside your reach.
          </p>
        <% {:ausente, _} -> %>
          <.absent reason="not calculated in this reading" />
      <% end %>
    </section>
    """
  end

  # ── segunda metade: T044 ───────────────────────────────────────────────────

  defp render_mundo_pequeno(assigns) do
    ~H"""
    <section id="mundo-pequeno" class="flex flex-col gap-3">
      <h2 class="font-semibold">Small world <Shared.marca tipo={:derivado} /></h2>
      <p class="text-sm">
        A small world has tight local groups and still short paths between any two people. It is
        tested against random networks with the same people and the same number of links.
      </p>

      <table id="tabela-mundo-pequeno" class="table table-sm stacked">
        <thead>
          <tr>
            <th>measure</th>
            <th>this network</th>
            <th>random networks</th>
            <th>ratio</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td data-label="measure">
              Clustering
              <span class="block text-xs opacity-70">
                share of someone's contacts who are also linked to each other
              </span>
            </td>
            <td data-label="this network">{duas_casas_ou_ausente(@sw.clustering)}</td>
            <td data-label="random networks">
              {media_ou_ausente(@sw.random_clustering, &duas_casas/1)}
            </td>
            <td data-label="ratio">{razao(@sw.sigma, :clustering_ratio)}</td>
          </tr>
          <tr>
            <td data-label="measure">Average distance</td>
            <td data-label="this network">{passos_ou_ausente(@d.average)}</td>
            <td data-label="random networks">
              {media_ou_ausente(@sw.random_average, &"#{uma_casa(&1)} steps")}
            </td>
            <td data-label="ratio">{razao(@sw.sigma, :distance_ratio)}</td>
          </tr>
        </tbody>
      </table>

      <%= case @sw.sigma do %>
        <% {:ok, %{value: s}} -> %>
          <p id="sigma" class="border-l-4 border-base-content pl-3">
            <span class="font-semibold">σ = {uma_casa(s)}.</span>
            <%= if @sw.criterion == :meets do %>
              The network meets the σ &gt; {@sw.threshold} criterion: its clustering is higher than
              in random networks by more than its distances are longer.
            <% else %>
              The network does not meet the σ &gt; {@sw.threshold} criterion.
            <% end %>
          </p>
        <% {:ausente, m} -> %>
          <p id="sigma" class="border-l-4 border-base-content/40 pl-3">
            σ: <.absent reason={sigma_ausente(m)} />
            This absence says nothing, either way, about the small-world criterion.
          </p>
      <% end %>

      <p id="o-que-o-criterio-nao-prova" class="text-xs opacity-80">
        σ is the clustering ratio divided by the distance ratio. The criterion only compares with
        random networks of the same size: it does not prove how the work is organised, and networks
        far from a lattice can pass it (Telesford et al., 2011).
      </p>

      <p id="aleatorios" class="text-xs opacity-70">
        {aleatorios(@sw, @v.provenance)}
        <span :if={is_integer(@sw.excluded_degree_below_two) and @sw.excluded_degree_below_two > 0}>
          {pessoas(@sw.excluded_degree_below_two)} with fewer than two contacts {if @sw.excluded_degree_below_two ==
                                                                                      1,
                                                                                    do: "is",
                                                                                    else: "are"} left out of the clustering, not counted as zero.
        </span>
      </p>
    </section>
    """
  end

  # ── frases ──────────────────────────────────────────────────────────────────

  defp conectividade(%{graph: {:ok, %{components: {:ok, [_um]}}}}),
    do: "Everyone drawn is linked to everyone else through some path (1 group)."

  defp conectividade(%{graph: {:ok, %{components: {:ok, tamanhos}}}}),
    do:
      "#{length(tamanhos)} groups not linked to each other, of " <>
        "#{Enum.map_join(tamanhos, ", ", &Integer.to_string/1)} people. No path joins them."

  defp conectividade(%{graph: {:ok, %{components: {:suprimido, _}}}}),
    do:
      "The groups are not shown: their sizes would count fewer than 3 people outside your reach."

  defp conectividade(_visao), do: ""

  defp aleatorio(%{absent: {:ausente, m}}, _chave, _fmt),
    do: "Random networks: " <> ausencia(m)

  defp aleatorio(random, chave, fmt) do
    case Map.fetch!(random, chave) do
      {:ok, %{value: v, graphs_defined: n}} -> "Random networks: #{fmt.(v)} (average of #{n})"
      {:ausente, m} -> "Random networks: " <> ausencia(m)
    end
  end

  defp media_ou_ausente({:ok, %{value: v, graphs_defined: n}}, fmt),
    do: "#{fmt.(v)} (average of #{n})"

  defp media_ou_ausente({:ausente, m}, _fmt), do: ausencia(m)

  defp duas_casas_ou_ausente({:ok, v}), do: duas_casas(v)
  defp duas_casas_ou_ausente({:ausente, m}), do: ausencia(m)

  defp passos_ou_ausente({:ok, v}), do: "#{uma_casa(v)} steps"
  defp passos_ou_ausente({:ausente, m}), do: ausencia(m)

  defp razao({:ok, r}, chave), do: "#{uma_casa(Map.fetch!(r, chave))}×"
  defp razao(_sigma, _chave), do: "not calculated"

  # 3.5.4 (T053): quantos aleatórios não ficaram ligados, e como a distância foi medida neles.
  # Leitura anterior à contagem não a traz, e a frase diz isso em vez de um zero.
  defp nao_ligados(0, _n), do: "All of them came out linked."

  defp nao_ligados(k, n) when is_integer(k),
    do:
      "#{k} of #{n} came out not fully linked; in those, the distance is the average over " <>
        "the pairs that reach each other."

  defp nao_ligados(nil, _n),
    do: "How many came out not fully linked is not recorded in this reading."

  defp aleatorios(sw, proveniencia) do
    case sw.graphs do
      n when is_integer(n) ->
        definidos =
          case sw.random_clustering do
            {:ok, %{graphs_defined: k}} when k < n ->
              " The clustering is defined in #{k} of them, and the average is over those."

            _ ->
              ""
          end

        "#{n} random networks, every one generated included, linked or not. " <>
          "#{nao_ligados(sw.not_linked, n)} Seed #{proveniencia.seed}, generator " <>
          "#{proveniencia.generator}.#{definidos}"

      _ ->
        "No random networks in this reading."
    end
  end

  defp sigma_ausente(:network_too_small),
    do: "not calculated: the network has fewer people than the minimum declared for σ"

  defp sigma_ausente(:random_clustering_undefined),
    do: "not calculated: the random networks have no clustering to compare with"

  defp sigma_ausente(:clustering_undefined),
    do: "not calculated: no one in this network has two contacts"

  defp sigma_ausente(m), do: ausencia(m)

  defp ausencia(:no_edge_in_window), do: "no link in this window"

  defp ausencia(:network_too_large_for_platform),
    do: "not calculated: the network is above the size the platform compares with random networks"

  defp ausencia(:no_person_with_two_neighbours), do: "no one has two contacts"
  defp ausencia(_), do: "not calculated in this reading"

  defp largura(n, comprimentos) do
    maior = comprimentos |> Enum.map(&elem(&1, 1)) |> Enum.max()
    :erlang.float_to_binary(n / maior * 100, decimals: 1)
  end

  defp pct(v), do: "#{round(v * 100)}%"
  defp uma_casa(v), do: :erlang.float_to_binary(v * 1.0, decimals: 1)
  defp duas_casas(v), do: :erlang.float_to_binary(v * 1.0, decimals: 2)

  defp pessoas(1), do: "1 person"
  defp pessoas(n), do: "#{n} people"
end
