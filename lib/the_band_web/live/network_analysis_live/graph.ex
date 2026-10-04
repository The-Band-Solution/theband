defmodule TheBandWeb.NetworkAnalysisLive.Graph do
  @moduledoc """
  `/network-analysis/:organization_id/graph` — a página **Graph** da área, feature 076, T029 (US2;
  FR-005 a FR-009; `contracts/tela.md`; protótipo aprovado, §3, Tela 2, itens 3.2.6 a 3.2.8).

  Nesta fatia, as contagens da rede, sem o desenho (o grafo é a US3): pessoas, arestas dirigidas,
  issues ou revisões da janela; a conectividade dita certa (*"1 group"*); as exclusões por motivo,
  só para quem alcança todos; as pessoas da organização sem aresta; o número de contas declaradas
  da organização; e, na designação, a frase do que a aresta liga e do que **não** diz.

  ## O que a tela chama, e só isto

  `NetworkAnalysis.selection/1` e `read/4` a cada `handle_params` e a cada aviso de leitura pronta,
  `options/0` para os seletores, `subscribe/1`. O alcance não vira `assign` (A22): quem o perde
  deixa de ver na leitura seguinte. A tela não filtra nada: a visão já chega recortada.

  ## A língua

  A interface fala inglês (`AGENTS.md` §11.1); as frases nasceram no protótipo aprovado. Nenhuma
  diz *collaboration* nem *delegation* (D1).
  """
  use TheBandWeb, :live_view

  alias TheBand.NetworkAnalysis
  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = NetworkAnalysis.subscribe(socket.assigns.current_tenant)

    {:ok, assign(socket, page_title: "Graph", opcoes: NetworkAnalysis.options())}
  end

  @impl true
  def handle_params(%{"organization_id" => id} = params, _uri, socket) do
    {:noreply, ler(socket, id, NetworkAnalysis.selection(params))}
  end

  # A leitura é refeita pela função de domínio, com o alcance de AGORA (A22), e nunca a partir
  # do que chegou na mensagem, que só traz ids.
  @impl true
  def handle_info({:network_analysis_ready, organization_id, _ids}, socket) do
    if organization_id == socket.assigns[:organization_id],
      do: {:noreply, ler(socket, organization_id, socket.assigns.selecao)},
      else: {:noreply, socket}
  end

  defp ler(socket, id, selecao) do
    %{current_tenant: tenant, current_user: user} = socket.assigns

    case NetworkAnalysis.read(tenant, user, id, selecao) do
      # O mesmo texto para outro tenant, inexistente e id malformado (FR-014; §11.1).
      {:error, :not_found} ->
        socket
        |> put_flash(:error, dgettext("errors", "Not found."))
        |> push_navigate(to: ~p"/network-analysis")

      {:ausente, motivo} ->
        socket |> com_organizacao(id) |> assign(selecao: selecao, visao: {:ausente, motivo})

      {:ok, visao} ->
        socket |> com_organizacao(id) |> assign(selecao: selecao, visao: visao)
    end
  end

  # A organização já foi conferida por `read/4` (id e tenant): aqui só se busca o nome.
  defp com_organizacao(socket, id) do
    {:ok, organizacao} = EO.fetch_organization(socket.assigns.current_tenant, id)
    assign(socket, organization_id: organizacao.id, organizacao: organizacao)
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
        active={:graph}
        organization_id={@organization_id}
        selection={@selecao}
      />
      <div :if={assigns[:organizacao]} class="flex flex-col gap-6" id="network-graph">
        <Shared.header
          title="Graph"
          question="Who is linked to whom, and who sits between groups?"
          page={:graph}
          organization={@organizacao}
          selection={@selecao}
          options={@opcoes}
          reading={leitura_para_o_cabecalho(@visao)}
        />

        <%!-- US2, cen. 5: o que a aresta liga, e o que não diz --%>
        <p id="o-que-a-aresta-liga" class="text-sm">{frase_da_aresta(@selecao.network)}</p>

        <%= case @visao do %>
          <% {:ausente, motivo} -> %>
            <div id="sem-leitura" class="rounded border border-dashed border-base-content/40 p-4">
              <.absent reason={motivo_da_ausencia(motivo, @selecao.network)} />
            </div>
          <% visao -> %>
            {render_contagens(assign(assigns, v: visao))}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_contagens(assigns) do
    assigns = assign(assigns, c: assigns.v.counts, rede: assigns.selecao.network)

    ~H"""
    <%!-- 3.2.8 e a contagem da rede --%>
    <section id="contagens" class="card bg-base-100 border border-base-300 p-4 flex flex-col gap-2">
      <h2 class="font-semibold">
        The network <Shared.marca tipo={:derivado} />
      </h2>

      <%= case @c.edges do %>
        <% {:ausente, :no_edge_in_window} -> %>
          <.absent reason={sem_aresta(@rede)} />
          <p :if={match?({:ok, _}, @c.items)} class="text-xs opacity-70">
            {itens(@c.items, @rede)} in this window, and none of them links two people.
          </p>
        <% {:ok, arestas} -> %>
          <p id="resumo">
            <span :if={match?({:ok, _}, @c.people)} class="font-mono tabular-nums">
              {pessoas(elem(@c.people, 1))},
            </span>
            <span class="font-mono tabular-nums">{plural(arestas, "directed link", "directed links")}</span>, <span class="font-mono tabular-nums">{itens(@c.items, @rede)}</span>.
          </p>
          <p :if={match?({:suprimido, _}, @c.people)} class="text-xs opacity-70">
            The number of people is not shown: it would count fewer than 3 people outside your
            reach.
          </p>
          {render_conectividade(assigns)}
      <% end %>

      <%!-- 3.2.7: quem não tem aresta é escrito, e não desenhado --%>
      <p id="sem-aresta" class="text-sm">
        <%= case @c.people_without_edges do %>
          <% {:ok, 0} -> %>
            Every observed person of this organisation has a link in this window.
          <% {:ok, n} -> %>
            {pessoas_observadas(n)} of this organisation had no {ato(@rede)} in this window and {if n ==
                                                                                                      1,
                                                                                                    do:
                                                                                                      "is",
                                                                                                    else:
                                                                                                      "are"} not drawn.
          <% {:ausente, :no_edge_in_window} -> %>
            <.absent reason="with no link in this window, nobody is set apart as without one" />
          <% {:recortado, :regra} -> %>
            People of this organisation without a link are counted only for those who reach
            everyone.
        <% end %>
      </p>
    </section>

    <%!-- 3.2.6: contados, e não desenhados; só para quem alcança todos (073, Q5) --%>
    <section id="exclusoes" class="card bg-base-100 border border-base-300 p-4 flex flex-col gap-2">
      <h2 class="font-semibold">Not drawn as nodes, counted <Shared.marca tipo={:derivado} /></h2>
      <%= case @c.exclusions do %>
        <% {:ok, e} -> %>
          <ul class="flex flex-col gap-1 text-sm">
            <li :for={{chave, rotulo, explicacao} <- motivos(@rede)} data-motivo={chave}>
              {rotulo}
              <%= case Map.get(e, chave) do %>
                <% n when is_integer(n) -> %>
                  <span class="font-mono tabular-nums">{n}</span>
                <% _ -> %>
                  <.absent reason="not evaluated in this reading" />
              <% end %>
              <span class="opacity-70">— {explicacao}</span>
            </li>
          </ul>
          <p class="text-xs opacity-70">
            Counted, never listed by account. A node is a person observed with account type
            person.
          </p>
          <p
            :if={
              is_integer(@v.provenance.account_type_unknown) and
                @v.provenance.account_type_unknown > 0
            }
            id="tipo-desconhecido"
            class="text-xs opacity-70"
          >
            {plural(@v.provenance.account_type_unknown, "assignment", "assignments")} had an account
            whose type was not recorded at collection; they are counted as not linked to a person.
          </p>
        <% {:ausente, :none_in_window} -> %>
          <.absent reason={"no #{ato(@rede)} in this window"} />
        <% {:recortado, :regra} -> %>
          <p class="text-sm">
            Links with bots or apps, with the organisation's account, with accounts not linked to a
            person, and {if @rede == "review", do: "self-reviews", else: "self-assignments"} are left
            out. Their counts are about the whole organisation, people you do not reach included, so
            they are shown only to those who reach everyone.
          </p>
      <% end %>
    </section>

    <%!-- R14: quantas, e nunca quais --%>
    <p id="contas-declaradas" class="text-sm">
      <%= if @v.declared_organization_accounts == 0 do %>
        No account of this organisation is declared as the organisation's account.
      <% else %>
        {plural(@v.declared_organization_accounts, "account", "accounts")} declared by
        administrators as the organisation's account {if @v.declared_organization_accounts == 1,
          do: "is",
          else: "are"} not a person in this network.
      <% end %>
    </p>

    <footer id="proveniencia" class="text-xs opacity-70 flex flex-col gap-1">
      <p :if={@v.provenance.knowledge_versions != %{}}>
        Versions:
        <span
          :for={{id, versao} <- Enum.sort(@v.provenance.knowledge_versions)}
          class="font-mono mr-2"
        >
          {id} v{versao}
        </span>
      </p>
      <p>Not on this page: export, ordering by a count, labels that judge a person.</p>
    </footer>
    """
  end

  defp render_conectividade(assigns) do
    ~H"""
    <p id="conectividade">
      <%= case @v.graph do %>
        <% {:ok, %{components: {:ok, [_um]}}} -> %>
          Everyone drawn is linked to everyone else through some path (1 group).
        <% {:ok, %{components: {:ok, tamanhos}}} -> %>
          {length(tamanhos)} groups not linked to each other:
          <span :for={t <- tamanhos} class="badge badge-ghost mr-1">{pessoas(t)}</span>
        <% {:ok, %{components: {:suprimido, _}}} -> %>
          The groups are not shown: their sizes would count fewer than 3 people outside your reach.
        <% {:recortado, :no_reach} -> %>
          You reach no one else in this network, so its groups are not shown here.
        <% _ -> %>
          <.absent reason="no group to count" />
      <% end %>
    </p>
    """
  end

  # A linha da leitura só existe quando há leitura (3.0.5).
  defp leitura_para_o_cabecalho({:ausente, _}), do: nil
  defp leitura_para_o_cabecalho(visao), do: visao

  # US2, cen. 5. Frases da tela, em inglês: não traduzir de volta.
  defp frase_da_aresta("assignment"),
    do:
      "Each arrow goes from the person who opened an issue to a person assigned to it. It does " <>
        "not say who made the assignment, nor who did the work."

  defp frase_da_aresta("review"),
    do: "Each arrow goes from the person who reviewed to the author of the change request."

  defp motivo_da_ausencia(:not_computed, "review"),
    do:
      "not calculated: the review network of this organisation has no reading for this window " <>
        "yet, or the analysis has not run since"

  defp motivo_da_ausencia(:not_computed, _rede),
    do: "not calculated: the platform has not computed this reading yet"

  # E4 da revisão semântica do PR #1383: a leitura da 073 não sabe das contas declaradas
  # vigentes, e a conta declarada seria nó aqui e não na rede de designação.
  defp motivo_da_ausencia(:review_reading_outdated, _rede),
    do:
      "not shown: the review network reading was calculated before the latest change to the " <>
        "accounts declared as the organisation's, so it does not know about it; it is " <>
        "recalculated at the next synchronization of this organisation"

  defp motivo_da_ausencia(:stale, _rede),
    do: "not shown: this reading is older than the longest window, and was not recalculated"

  defp sem_aresta("assignment"), do: "no assignment between people in this window"
  defp sem_aresta("review"), do: "no review between people in this window"

  defp ato("assignment"), do: "assignment"
  defp ato("review"), do: "review"

  defp itens({:ok, n}, "assignment"), do: plural(n, "issue", "issues") <> " opened"
  defp itens({:ok, n}, "review"), do: plural(n, "review", "reviews")
  defp itens({:ausente, _}, "assignment"), do: "no issue opened"
  defp itens({:ausente, _}, "review"), do: "no review"

  # Os motivos, na ordem da regra de cada rede (FR-007). A ausência de motivo na designação
  # (issue sem responsável) não é par, e vai por último.
  defp motivos("assignment") do
    [
      {"bot_or_app", "bot or app", "the account on either side is a bot or an app"},
      {"organization_account", "organisation account",
       "the account on either side was declared as the organisation's account"},
      {"unlinked_person", "not linked to a person",
       "the account on either side matches no observed person"},
      {"self_assignment", "self-assignments", "the person who opened the issue is its assignee"},
      {"issues_without_assignee", "issues without an assignee", "no link to draw"}
    ]
  end

  defp motivos("review") do
    [
      {"bot_or_app", "bot or app", "the account on either side is a bot or an app"},
      {"organization_account", "organisation account",
       "the account on either side was declared as the organisation's account"},
      {"unlinked_person", "not linked to a person",
       "the account on either side matches no observed person"},
      {"self_review", "self-reviews", "the person who opened the change request also reviewed it"}
    ]
  end

  defp pessoas(n), do: plural(n, "person", "people")

  defp pessoas_observadas(1), do: "1 observed person"
  defp pessoas_observadas(n), do: "#{n} observed people"

  defp plural(1, um, _varios), do: "1 #{um}"
  defp plural(n, _um, varios), do: "#{n} #{varios}"
end
