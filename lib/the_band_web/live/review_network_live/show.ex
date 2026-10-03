defmodule TheBandWeb.ReviewNetworkLive.Show do
  @moduledoc """
  `/organizations/:id/review-network` — a rede de revisão de uma organização observada, feature
  073 (US1, US2, US3; T021, T024, T026).

  **A tela é exatamente o protótipo aprovado** em 2026-10-03 (versão 2,
  `specs/073-rede-de-revisao/prototipo/`). A régua é `prototipo/PROMPT.md` §3: cada item tem o
  número dela num comentário, e o teste confere cada item verificável no HTML. As telas 6 e 7 do
  protótipo (matriz, grupos × equipes) **não** existem aqui (Q1).

  ## O que a tela chama, e só isto (`contracts/tela.md`)

  `ReviewNetwork.read/4` a cada `handle_params` e a cada aviso de leitura pronta, `windows/0` para
  a escolha de janela, `subscribe/1`. O alcance **não** vira `assign` (R10, A13): quem perde o
  vínculo deixa de ver na leitura seguinte. A tela não filtra nada: a visão já chega recortada
  (R3), e não enfileira cálculo (R6).

  ## A língua

  A interface fala inglês, e as frases nasceram no domínio (a régua, em inglês): não traduzir de
  volta (`AGENTS.md` §11.1). Comentários em português.
  """
  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = ReviewNetwork.subscribe(socket.assigns.current_tenant)

    {:ok,
     socket
     |> assign(page_title: "Review network", nav_area: :organization)
     |> assign(abertos: MapSet.new(), janelas: ReviewNetwork.windows())}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    {:noreply, ler(socket, id, Map.get(params, "window", socket.assigns.janelas.default))}
  end

  # A leitura é refeita pela função de domínio, com o alcance de AGORA, e nunca a partir do que
  # chegou na mensagem (que só traz ids, A11).
  @impl true
  def handle_info({:review_network_ready, organization_id, _ids}, socket) do
    if organization_id == socket.assigns[:organization_id] do
      {:noreply, ler(socket, organization_id, socket.assigns.window)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle", %{"id" => person_id}, socket) do
    abertos = socket.assigns.abertos

    abertos =
      if MapSet.member?(abertos, person_id),
        do: MapSet.delete(abertos, person_id),
        else: MapSet.put(abertos, person_id)

    {:noreply, assign(socket, abertos: abertos)}
  end

  defp ler(socket, id, window) do
    %{current_tenant: tenant, current_user: user} = socket.assigns

    case ReviewNetwork.read(tenant, user, id, window) do
      # Janela fora da lista volta à padrão (4.6), sem dizer que o pedido era inválido.
      {:error, :janela_invalida} ->
        push_patch(socket, to: caminho(id, socket.assigns.janelas.default))

      # O mesmo texto para a de outro tenant e a inexistente: dizer "sem permissão" confirmaria
      # que existe (§11.1, 4.6).
      {:error, :not_found} ->
        socket |> put_flash(:error, dgettext("errors", "Not found.")) |> push_navigate(to: ~p"/organizations")

      {:ausente, :not_computed} ->
        socket |> com_organizacao(id) |> assign(window: janela(window), visao: :not_computed)

      {:ok, visao} ->
        socket |> com_organizacao(id) |> assign(window: visao.window_days, visao: visao)
    end
  end

  defp com_organizacao(socket, id) do
    tenant = socket.assigns.current_tenant
    {:ok, organizacao} = EO.fetch_organization(tenant, id)

    assign(socket,
      organization_id: organizacao.id,
      organizacao: organizacao,
      organizacoes: EO.list_organizations(tenant)
    )
  end

  defp janela(dias) when is_integer(dias), do: dias
  defp janela(texto), do: String.to_integer(texto)

  defp caminho(id, dias), do: ~p"/organizations/#{id}/review-network?window=#{dias}"

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
      <div :if={assigns[:organizacao]} class="flex flex-col gap-6" id="review-network">
        <%!-- 1.1 --%>
        <nav class="text-sm opacity-70" aria-label="breadcrumb">
          <.link navigate={~p"/organizations"} class="link link-hover">Organisations</.link>
          › <span id="organizacao-atual">{nome(@organizacao)}</span>
        </nav>

        <%!-- 1.2 --%>
        <header>
          <h1 class="text-2xl font-semibold">Review network</h1>
          <p class="opacity-80">Is code review concentrated in a few people?</p>
        </header>

        <%!-- 1.3: só com mais de uma organização observada --%>
        <div :if={length(@organizacoes) > 1} id="organizacoes" class="flex flex-wrap gap-2 text-sm">
          <span class="opacity-70">Observed organisation</span>
          <.link
            :for={o <- @organizacoes}
            patch={caminho(o.id, @window)}
            class={["btn btn-xs", if(o.id == @organization_id, do: "btn-primary", else: "btn-ghost")]}
            aria-current={if(o.id == @organization_id, do: "page")}
          >
            {nome(o)}
          </.link>
        </div>

        <%!-- 1.4 e 1.5 --%>
        <div id="janelas" class="flex flex-col gap-1">
          <div class="flex flex-wrap gap-2" role="group" aria-label="window">
            <.link
              :for={dias <- @janelas.allowed}
              patch={caminho(@organization_id, dias)}
              class={["btn btn-sm", if(dias == @window, do: "btn-primary", else: "btn-ghost")]}
              aria-current={if(dias == @window, do: "true")}
            >
              {dias} days
            </.link>
          </div>
          <p class="text-xs opacity-70">
            Switching the window reads another stored reading. It computes nothing.
          </p>
        </div>

        <%= if @visao == :not_computed do %>
          <%!-- 4.4: nenhum número, nenhum 0%, nunca a leitura de outra janela --%>
          <div id="nao-calculada" class="border border-dashed border-base-content/40 rounded p-4">
            <p>
              This reading has not been calculated yet. The platform calculates the {lista_de_janelas(
                @janelas.allowed
              )}-day readings when a review collection for {nome(@organizacao)} ends.
            </p>
            <.absent reason="not calculated (the platform has not computed this reading)" />
          </div>
        <% else %>
          {render_leitura(assigns)}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_leitura(assigns) do
    assigns = assign(assigns, parcial?: assigns.visao.reach == :parcial, v: assigns.visao)

    ~H"""
    <%!-- 3.1: o recorte, antes da leitura, sem a cláusula da liderança declarada (D5) --%>
    <div :if={@parcial?} id="aviso-de-recorte" class="alert alert-info block text-sm" role="note">
      <p>
        <.marca tipo={:alcance} />
        This page shows only the people you reach. You reach your own record and the people on
        the teams you belong to or that an access scope grants you, including the teams of an
        organisation in your scope. Administrators of this tenant reach everyone. What you see
        is a slice, not the whole; the page does not say how much is outside it.
      </p>
    </div>

    <%!-- 4.5 (Q3) --%>
    <div
      :if={match?({:em, _}, @v.newer_collection)}
      id="coleta-mais-nova"
      class="border-4 border-double border-warning rounded p-3 text-sm"
    >
      A review collection ended on {dia(elem(@v.newer_collection, 1))}, after this reading. The
      reading was not refreshed. The numbers below are from {dia(@v.computed_at)}.
    </div>

    <%!-- 1.6 --%>
    <div id="leitura" class="text-sm flex flex-col gap-1">
      <p>
        Reading of {instante(@v.computed_at)} ({idade(@v.computed_at)}), computed when the last
        review collection ended. Window: {dia(@v.window_start)} – {dia(@v.window_end)}, {@v.window_days} days.
      </p>
      <p>
        <.marca tipo={:observado} />
        Every number on this page is derived from the submitted reviews observed at the source
      </p>
    </div>

    <%!-- 1.7, 1.8, 3.2, 3.3, 4.1, 4.2, 4.3 --%>
    <section id="concentracao" class="card bg-base-100 border border-base-300 p-4 flex flex-col gap-3">
      <h2 class="font-semibold">
        {if @parcial?, do: "Concentration among the people you reach", else: "Concentration"}
        <.marca tipo={:derivado} />
      </h2>

      <%= case @v.concentration do %>
        <% {:ok, linhas} -> %>
          <div :for={%{k: k, value: valor} <- linhas} class="flex flex-col gap-1" data-k={k}>
            <span>{rotulo_de_k(k)}</span>
            <%= case valor do %>
              <% {:ok, %{reviews: s, of: total}} -> %>
                <span class="font-mono tabular-nums">
                  {porcento(s, total)}% · {s} of {total} reviews
                </span>
                <%!-- A barra é hachurada (derivado) e na mesma escala 0–100%, com marca em 50%;
                      nenhum limiar, nenhuma cor de faixa (1.7). A largura em `style` é o único
                      jeito de o Tailwind expressar um valor contínuo do dado. --%>
                <div class="relative h-3 w-full border border-base-content/40" aria-hidden="true">
                  <div
                    class="h-full text-warning bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
                    style={"width: #{porcento(s, total)}%"}
                  >
                  </div>
                  <div class="absolute top-0 left-1/2 h-full border-l border-dashed border-base-content/60">
                  </div>
                </div>
              <% {:ausente, :fewer_reviewers_than_k} -> %>
                <.absent reason={"only #{revisores(@v)} people reviewed"} />
                <span class="text-xs opacity-70">
                  a share for {k} people says nothing when only {revisores(@v)} reviewed
                </span>
            <% end %>
          </div>
          <p class="text-xs opacity-70">0% · 50% · 100%</p>
          <p class="text-xs opacity-70">
            No name here, for anyone. A review is one person reviewing one change request: a
            change request reviewed by two people counts as two reviews. Excluded reviews are in
            neither part of the fraction.
          </p>
          <p :if={@parcial?} class="text-xs opacity-70">
            Counted only over reviews where both the reviewer and the author are people you reach.
          </p>
        <% {:ausente, {:sample_below_minimum, minimo}} -> %>
          <.absent reason={"too few reviews to speak of concentration: #{revisoes(@v)} of the #{minimo} needed"} />
          <p class="text-xs opacity-70">
            Below {minimo} reviews, one review more moves a share by more than ten points, so no
            share is shown. A review is one person reviewing one change request. The counts beside
            this block still hold.
          </p>
        <% {:ausente, :no_review_in_window} -> %>
          <.absent reason="no review in this window" />
          <p class="text-xs opacity-70">
            The observed repositories show no submitted review between people in this window.
            There is no share to compute, and the page does not write 0%.
          </p>
      <% end %>
    </section>

    <%!-- 1.9, 1.10, 3.2, 3.4 --%>
    <section id="contagens" class="card bg-base-100 border border-base-300 p-4 flex flex-col gap-2">
      <h2 class="font-semibold">
        {if @parcial?,
          do: "Reviews in this window among the people you reach",
          else: "Reviews in this window"}
        <.marca tipo={:derivado} />
      </h2>
      <dl class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <dt>reviews</dt>
          <dd>
            <.contagem valor={@v.reviews} />
            <span class="text-xs opacity-70">person × change request</span>
          </dd>
        </div>
        <div>
          <dt>people who reviewed</dt>
          <dd><.contagem valor={@v.reviewers} /></dd>
        </div>
        <div>
          <dt>people reviewed</dt>
          <dd>
            <.contagem valor={@v.authors} />
            <span class="text-xs opacity-70">had at least one change request reviewed</span>
          </dd>
        </div>
      </dl>
      <p class="text-xs opacity-70">
        <%= if @parcial? do %>
          {@v.people_without_review_activity} people you reach had no review activity in this
          window: they neither reviewed nor opened a change request. They are not in the list.
        <% else %>
          {@v.people_without_review_activity} observed people of this organisation had no review
          activity in this window: they neither reviewed nor opened a change request. They are not
          in the list.
        <% end %>
      </p>
    </section>

    <%!-- 1.11, 1.12, 3.5 --%>
    <section id="grupos" class="card bg-base-100 border border-base-300 p-4 flex flex-col gap-2">
      <h2 class="font-semibold">
        {if @parcial?,
          do: "Groups that do not review each other among the people you reach",
          else: "Groups that do not review each other"}
        <.marca tipo={:derivado} />
      </h2>
      <%= case {@v.groups, @parcial?} do %>
        <% {{:ok, [tamanho]}, false} -> %>
          <p>
            Everyone in the network is linked by review, directly or through others.
            <span class="badge badge-ghost">{pessoas(tamanho)}</span>
          </p>
        <% {{:ok, [tamanho]}, true} -> %>
          <p>
            Everyone you reach with a review between them is linked, directly or through others: {pessoas(
              tamanho
            )}.
          </p>
        <% {{:ok, tamanhos}, parcial?} -> %>
          <p>
            {length(tamanhos)} groups{if parcial?, do: " among the people you reach"}. No review
            goes between them, in either direction.
          </p>
          <div class="flex flex-wrap gap-2">
            <span :for={t <- tamanhos} class="badge badge-ghost">{pessoas(t)}</span>
          </div>
        <% {{:ausente, :no_review_in_window}, false} -> %>
          <.absent reason="With no review there is no group to count." />
        <% {{:ausente, :no_review_in_window}, true} -> %>
          <.absent reason="no review between people you reach in this window" />
      <% end %>
      <p :if={not @parcial?} class="text-xs opacity-70">
        Only people who gave or received at least one review are in a group. A separate group can
        be a separate product on purpose; it is not a silo by itself.
      </p>
      <p :if={@parcial?} class="text-xs opacity-70">
        Counted only among the people you reach: a review with someone outside your reach links
        nobody here, and people outside your reach are in no group on this page. Only people who
        gave or received at least one review are in a group.
      </p>
    </section>

    <%!-- 1.13, 3.6: contagens só para quem alcança todos (Q5); nunca login --%>
    <section id="exclusoes" class="card bg-base-100 border border-base-300 p-4 flex flex-col gap-2">
      <h2 class="font-semibold">Left out of the network <.marca tipo={:derivado} /></h2>
      <%= case @v.exclusions do %>
        <% {:ok, e} -> %>
          <ul class="flex flex-col gap-1 text-sm">
            <li>
              self-reviews <span class="font-mono tabular-nums">{e.self_review}</span>
              <span class="opacity-70">— the person who opened the change request also reviewed it</span>
            </li>
            <li>
              bot or app <span class="font-mono tabular-nums">{e.bot_or_app}</span>
              <span class="opacity-70">— the account on either side is a bot or an app</span>
            </li>
            <li>
              not linked to a person <span class="font-mono tabular-nums">{e.unlinked_person}</span>
              <span class="opacity-70">
                — the account on either side matches no observed person, or was deleted at the source
              </span>
            </li>
          </ul>
          <p class="text-xs opacity-70">
            Counted, never listed by account. A self-review is counted only here, never against a person.
          </p>
        <% {:recortado, :regra} -> %>
          <p class="text-sm">
            Self-reviews, reviews by bots or apps, and reviews by accounts not linked to a person
            are left out. Their counts are about the whole organisation, people you do not reach
            included, so they are shown only to those who reach everyone.
          </p>
      <% end %>
    </section>

    <%!-- 1.14–1.18, 3.7, 3.8; tela 2 --%>
    <section id="pessoas" class="flex flex-col gap-2">
      <h2 class="font-semibold">
        {if @parcial?, do: "People you reach", else: "People"} <.marca tipo={:derivado} />
      </h2>
      <%!-- 1.14: ANTES da tabela. Quem lê a tabela primeiro já julgou (D8). --%>
      <p id="nao-avalia" class="text-sm">
        These counts do not assess a person. How much someone reviews follows who is asked to
        review, their role, time off and time zone; a quick approval and a long review count the
        same; only reviews made on the observed repositories are visible here.
      </p>
      <p class="text-xs opacity-70">
        Ordered by name. No column sorts the list. Open a name to see their pairs.
      </p>
      <p :if={@parcial?} class="text-xs opacity-70">
        Each row shows the person's whole count in the window; the pairs show only people you reach.
      </p>

      <table class="table stacked table-sm" id="tabela-pessoas">
        <thead>
          <tr>
            <th>person</th>
            <th>reviewed</th>
            <th>was reviewed</th>
          </tr>
        </thead>
        <tbody>
          <%= for p <- @v.people do %>
            <tr id={"pessoa-#{p.person_id}"}>
              <td data-label="person">
                <button
                  type="button"
                  class="link link-hover text-left"
                  phx-click="toggle"
                  phx-value-id={p.person_id}
                  aria-expanded={to_string(MapSet.member?(@abertos, p.person_id))}
                  aria-controls={"pares-#{p.person_id}"}
                >
                  {p.name}
                </button>
              </td>
              <td data-label="reviewed">
                <%= case p.given do %>
                  <% {:ok, %{reviews: n, people: m}} -> %>
                    reviewed {n}, of {pessoas(m)}
                  <% {:ausente, :did_not_review_in_window} -> %>
                    <.absent reason="no review by them in this window" />
                <% end %>
              </td>
              <td data-label="was reviewed">
                <%= case p.received do %>
                  <% {:ok, %{change_requests: n, people: m}} -> %>
                    was reviewed on {n}, by {pessoas(m)}
                  <% {:ausente, :no_change_request_reviewed_in_window} -> %>
                    <.absent reason="no review on their change requests in this window" />
                <% end %>
              </td>
            </tr>
            <tr :if={MapSet.member?(@abertos, p.person_id)} id={"pares-#{p.person_id}"}>
              <td colspan="3" data-label="pairs">
                {render_pares(Map.put(assigns, :p, p))}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </section>

    <%!-- 1.19 --%>
    <footer id="proveniencia" class="text-xs opacity-70 flex flex-col gap-1">
      <p>
        Versions:
        <span
          :for={{id, versao} <- Enum.sort(@v.provenance.knowledge_versions)}
          class="font-mono mr-2"
        >
          {id} v{versao}
        </span>
      </p>
      <p>Source: the submitted reviews of the observed repositories of this organisation.</p>
      <p>Not on this page: export, ordering by a count, role labels for people.</p>
    </footer>
    """
  end

  # Tela 2: os pares abrem no lugar, ordenados por nome; os de fora do alcance não viram linha
  # nem número (3.8).
  defp render_pares(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div>
        <p class="font-semibold">{@p.name} reviewed the change requests of</p>
        <ul :if={@p.reviews_of != []}>
          <li :for={par <- @p.reviews_of}>{par.name} on {par.reviews}</li>
        </ul>
        <.absent
          :if={@p.reviews_of == [] and match?({:ausente, _}, @p.given)}
          reason="reviewed nobody in this window"
        />
      </div>
      <div>
        <p class="font-semibold">The change requests of {@p.name} were reviewed by</p>
        <ul :if={@p.reviewed_by != []}>
          <li :for={par <- @p.reviewed_by}>{par.name} on {par.reviews}</li>
        </ul>
        <.absent
          :if={@p.reviewed_by == [] and match?({:ausente, _}, @p.received)}
          reason="nobody reviewed them in this window"
        />
      </div>
    </div>
    <p :if={@p.pairs_outside_reach?} class="text-sm mt-2">
      <.marca tipo={:alcance} /> some pairs are outside your reach
    </p>
    <p class="text-xs opacity-70 mt-2">
      Ordered by name. The number is change requests in this window.
      <.link navigate={~p"/people/#{@p.person_id}"} class="link">Open {@p.name}'s panel</.link>
    </p>
    <p :if={diferem?(@p)} class="text-xs opacity-70">
      {elem(@p.received, 1).change_requests} change requests reviewed, {soma_dos_pares(@p)} reviews: a change request reviewed by two people counts once in the row and once in each pair.
    </p>
    """
  end

  # A marca de proveniência, com a palavra sempre ao lado: a distinção nunca é só cor (WCAG
  # 1.4.1; design system). `<.evidence>` desenha a marca de CONCEITO; esta é de bloco, com o
  # mesmo preenchimento: sólido observado, hachurado derivado, contorno para o alcance.
  attr :tipo, :atom, values: [:observado, :derivado, :alcance], required: true

  defp marca(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 text-xs font-normal align-middle" data-marca={@tipo}>
      <span
        class={[
          "size-2.5 shrink-0 rounded-[1px]",
          @tipo == :observado && "bg-current text-success",
          @tipo == :derivado &&
            "text-warning outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]",
          @tipo == :alcance && "border-2 border-info"
        ]}
        aria-hidden="true"
      ></span>
      {palavra(@tipo)}
    </span>
    """
  end

  defp palavra(:observado), do: "observed"
  defp palavra(:derivado), do: "derived"
  defp palavra(:alcance), do: "your reach"

  attr :valor, :any, required: true

  # 4.1: "none in this window", e nunca 0.
  defp contagem(%{valor: {:ok, n}} = assigns) do
    assigns = assign(assigns, :n, n)

    ~H"""
    <span class="font-mono tabular-nums text-lg">{@n}</span>
    """
  end

  defp contagem(assigns) do
    ~H"""
    <.absent reason="none in this window" />
    """
  end

  defp rotulo_de_k(1), do: "The person who reviewed most did"
  defp rotulo_de_k(2), do: "The two people who reviewed most did"
  defp rotulo_de_k(3), do: "The three people who reviewed most did"
  defp rotulo_de_k(k), do: "The #{k} people who reviewed most did"

  # Porcentagem inteira (D1); a contagem ao lado deixa conferir à mão (SC-001).
  defp porcento(s, total), do: round(s * 100 / total)

  defp revisores(%{reviewers: {:ok, n}}), do: n
  defp revisoes(%{reviews: {:ok, n}}), do: n

  defp pessoas(1), do: "1 person"
  defp pessoas(n), do: "#{n} people"

  defp nome(organizacao), do: organizacao.name || organizacao.login

  defp lista_de_janelas(janelas) do
    {ultimas, [ultima]} = Enum.split(janelas, -1)
    Enum.join(ultimas, ", ") <> " and " <> to_string(ultima)
  end

  defp instante(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  defp dia(dt), do: Calendar.strftime(dt, "%Y-%m-%d")

  defp idade(dt) do
    segundos = DateTime.diff(DateTime.utc_now(), dt)

    cond do
      segundos < 3600 -> "#{max(div(segundos, 60), 0)} minutes ago"
      segundos < 86_400 -> "#{div(segundos, 3600)} hours ago"
      true -> "#{div(segundos, 86_400)} days ago"
    end
  end

  defp soma_dos_pares(p), do: p.reviewed_by |> Enum.map(& &1.reviews) |> Enum.sum()

  # 2.5 só quando a pessoa não tem par fora do alcance: com parte dos pares escondida, a soma
  # visível seria menor que o total por outra razão, e a frase mentiria.
  defp diferem?(%{received: {:ok, %{change_requests: n}}, pairs_outside_reach?: false} = p),
    do: n != soma_dos_pares(p)

  defp diferem?(_p), do: false
end
