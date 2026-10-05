defmodule TheBandWeb.NetworkAnalysisLive.Positions do
  @moduledoc """
  `/network-analysis/:organization_id/positions` — a página **Positions and profiles** da área,
  feature 076, T046 (US8, cen. 1 a 5; FR-034, FR-044 a FR-047; FR-015 regra 7; DS1; protótipo
  aprovado, §3, Tela 6, itens 3.6.1 a 3.6.3).

  Uma tabela **por nome**, sem ordenação por coluna: pessoa (link para o perfil), comunidade,
  com quantas pessoas se liga, e a posição **em frase** — o rótulo e a frase da regra
  `network.position_role`, com os dois percentis e o corte que decidiu ao lado. O papel é frase
  sobre as ligações, e nunca o percentil como rótulo de pessoa (Q1 da aprovação). A regra está a
  um clique (3.6.2), e a frase de não-avaliação e de que a posição muda com a rede vem antes da
  tabela (3.6.3, FR-047).

  Só alcançados aparecem; o papel de **outra** pessoa só com escopo concedido (DS1), o próprio
  sempre; nenhuma contagem de papel entre os de fora. As linhas da visão já chegam assim de
  `NetworkAnalysis.read/4`.

  As frases são da tela, em inglês (§11.1): não traduzir de volta.
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBandWeb.NetworkAnalysisLive.Leitura
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = NetworkAnalysis.subscribe(socket.assigns.current_tenant)

    {:ok, assign(socket, page_title: "Positions and profiles", opcoes: NetworkAnalysis.options())}
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
        active={:positions}
        organization_id={@organization_id}
        selection={@selecao}
      />
      <div :if={assigns[:organizacao]} class="flex flex-col gap-6" id="network-positions">
        <Shared.header
          title="Positions and profiles"
          question="Where does each person sit, and who do they work with?"
          page={:positions}
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
            {render_posicoes(assign(assigns, v: visao))}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_posicoes(%{v: %{positions: {:recortado, :no_reach}}} = assigns) do
    ~H"""
    <p id="sem-alcance" class="text-sm">
      You reach no one else in this network, so no list of people is shown here. Your own position
      is on your profile.
    </p>
    """
  end

  defp render_posicoes(%{v: %{positions: {:ausente, _}}} = assigns) do
    ~H"""
    <div id="sem-posicoes" class="rounded border border-dashed border-base-content/40 p-4">
      <.absent reason={"no position: " <> Leitura.sem_aresta(@selecao.network)} />
    </div>
    """
  end

  defp render_posicoes(%{v: %{positions: {:ok, linhas}}} = assigns) do
    assigns = assign(assigns, linhas: linhas)

    ~H"""
    <%!-- 3.6.3 e FR-047 --%>
    <div id="nao-avaliacao" class="text-sm border-l-4 border-base-content/40 pl-3 flex flex-col gap-1">
      <p>
        Position in this network and window. It does not measure performance, importance or merit,
        and must not be used to evaluate a person.
      </p>
      <p>
        Ordered by name. No column sorts the list. The position describes the links around someone
        in this window, not the person: it changes with role, team, time off and who was asked, and
        when other people enter or leave the network.
      </p>
    </div>

    <p :if={@v.reach == :parcial} class="text-sm">
      Only the people you reach are listed; nothing is said here about anyone else.
    </p>

    <table id="posicoes" class="table table-sm stacked">
      <thead>
        <tr>
          <th>person</th>
          <th>community</th>
          <th>linked to</th>
          <th>position in this network <Shared.marca tipo={:derivado} /></th>
        </tr>
      </thead>
      <tbody>
        <tr :for={l <- @linhas} data-person={l.person_id}>
          <td data-label="person">
            <.link
              navigate={Shared.profile_path(@organization_id, l.person_id, @selecao)}
              class="link link-primary"
            >
              {l.name}
            </.link>
          </td>
          <td data-label="community">{comunidade(l.community)}</td>
          <td data-label="linked to">{l.degree}</td>
          <td data-label="position in this network">
            <%= case l.role do %>
              <% {:ok, p} -> %>
                <span class="block">
                  <span class="font-semibold">{p.label}.</span> {p.sentence}
                </span>
                <span class="block text-xs opacity-70">
                  links: percentile {inteiro(p.degree_percentile)} · paths through them: percentile {inteiro(
                    p.betweenness_percentile
                  )} · cut: {p.cut}
                </span>
              <% {:ausente, :network_too_small_for_roles} -> %>
                <.absent reason={"not described: the network has fewer than #{@v.position_rule.min_people} people"} />
              <% {:recortado, :positions_not_granted} -> %>
                <span class="text-xs opacity-70">
                  shown only to those granted a scope that reaches this person
                </span>
            <% end %>
          </td>
        </tr>
      </tbody>
    </table>

    <%!-- 3.6.2: a regra a um clique --%>
    <details id="regra-da-posicao" class="text-sm">
      <summary class="cursor-pointer link">How the position is decided</summary>
      <div class="flex flex-col gap-1 pt-2">
        <p>
          For links (people linked, in either direction) and paths through someone (betweenness),
          the percentile is taken over everyone in this network, ties sharing the same percentile.
          The first rule that applies decides:
        </p>
        <ol class="list-decimal pl-6">
          <li>
            links above {@v.position_rule.high_above} and paths above {@v.position_rule.high_above}: {rotulo(
              @v,
              "central_position"
            )};
          </li>
          <li>links above {@v.position_rule.high_above}: {rotulo(@v, "many_direct_links")};</li>
          <li>paths above {@v.position_rule.high_above}: {rotulo(@v, "on_many_paths")};</li>
          <li>
            links above {@v.position_rule.median_above} and paths above {@v.position_rule.median_above}: {rotulo(
              @v,
              "above_median_in_both"
            )};
          </li>
          <li>
            links below {@v.position_rule.low_below} and paths below {@v.position_rule.low_below}: {rotulo(
              @v,
              "few_links_few_paths"
            )};
          </li>
          <li>otherwise: {rotulo(@v, "mixed_position")}.</li>
        </ol>
        <p>
          With fewer than {@v.position_rule.min_people} people in the network, no one is described.
        </p>
      </div>
    </details>
    """
  end

  defp comunidade(c) when is_integer(c), do: Shared.community_letter(c)
  defp comunidade(_c), do: "not calculated"

  defp inteiro(v), do: round(v)

  # Os rótulos vêm da base (`network.position_role.labels`), e nunca daqui.
  defp rotulo(v, codigo), do: v.position_rule.labels |> Map.fetch!(codigo) |> Map.fetch!("en")
end
