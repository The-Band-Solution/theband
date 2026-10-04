defmodule TheBandWeb.NetworkAnalysisLive.Index do
  @moduledoc """
  `/network-analysis` — a área **Network analysis**, feature 076, T019 (US1; FR-001;
  `contracts/tela.md`, rota `/network-analysis`; protótipo aprovado, §3, Tela 1).

  O título e a pergunta (3.1.1), as duas arestas definidas em palavras (3.1.2), os seis cartões
  com a rede de revisão como primeira página (3.1.3) e a frase de não-avaliação (3.1.4). Aqui se
  escolhe a organização observada; com uma só, a área abre direto nela (`contracts/tela.md`).

  A lista é das organizações **deste tenant** (`EO.list_organizations/1`): nenhum nome de pessoa
  aparece nesta página, de organização nenhuma (US1, cen. 4).

  ## A língua

  A interface fala inglês (`AGENTS.md` §11.1); as frases nasceram no protótipo aprovado e não se
  traduzem de volta. Nenhum texto diz *collaboration* nem *delegation* (D1).

  Depende de: EO (organizações), NetworkAnalysis (as redes de `options/0`).
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    case EO.list_organizations(socket.assigns.current_tenant) do
      [organizacao] ->
        {:ok, push_navigate(socket, to: ~p"/network-analysis/#{organizacao.id}")}

      organizacoes ->
        {:ok,
         assign(socket,
           page_title: "Network analysis",
           organizacoes: organizacoes,
           redes: NetworkAnalysis.options().networks.allowed
         )}
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
      <div class="flex flex-col gap-6" id="network-analysis">
        <%!-- 3.1.1 --%>
        <header>
          <h1 class="text-2xl font-semibold">Network analysis</h1>
          <p class="opacity-80">Read the links between people as a network.</p>
        </header>

        <%!-- 3.1.2 --%>
        <section id="arestas" class="flex flex-col gap-2">
          <p class="text-sm">
            Every page reads one of two links. You choose which on each page; the choice is kept
            while you move between pages.
          </p>
          <dl class="flex flex-col gap-2">
            <div :for={rede <- @redes} class="flex flex-col gap-0.5 sm:flex-row sm:gap-3">
              <dt class="font-mono font-semibold sm:w-28 sm:shrink-0">
                {Shared.link_label(rede).short}
              </dt>
              <dd>{Shared.link_label(rede).sentence}</dd>
            </div>
          </dl>
        </section>

        <%!-- A escolha da organização (contratos/tela.md) --%>
        <section id="organizacoes" class="flex flex-col gap-2">
          <h2 class="font-semibold">Observed organisations</h2>
          <%= if @organizacoes == [] do %>
            <.absent reason="no observed organisation in this tenant yet" />
          <% else %>
            <p class="text-sm opacity-70">Choose the organisation whose network you want to read.</p>
            <ul class="flex flex-wrap gap-2">
              <li :for={o <- @organizacoes}>
                <.link
                  navigate={~p"/network-analysis/#{o.id}"}
                  class="btn btn-sm btn-ghost"
                  data-organization={o.id}
                >
                  {Shared.nome(o)}
                </.link>
              </li>
            </ul>
          <% end %>
        </section>

        <%!-- 3.1.3: seis cartões, a rede de revisão marcada como primeira página --%>
        <section id="paginas" class="flex flex-col gap-2">
          <h2 class="font-semibold">The pages of this area</h2>
          <ul class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <li
              :for={{p, i} <- Enum.with_index(Shared.pages())}
              class={[
                "card border bg-base-100 p-4 flex flex-col gap-1",
                if(i == 0, do: "border-primary border-2", else: "border-base-300")
              ]}
              data-page={p.page}
            >
              <span class="font-semibold">{p.label}</span>
              <p class="text-sm">{p.question}</p>
              <p class="text-xs opacity-70">{p.measures}</p>
            </li>
          </ul>
        </section>

        <%!-- 3.1.4 --%>
        <p id="nao-avalia" class="text-sm">
          These pages describe how work flows between people in the observed repositories. They do
          not assess anyone: who reviews or is assigned follows role, team, time off and who was
          asked.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
