defmodule TheBandWeb.NetworkAnalysisLive.Shared do
  @moduledoc """
  O que toda página da área **Network analysis** repete — feature 076, T019
  (`specs/076-analise-de-rede/contracts/tela.md`, *Toda página da área*; protótipo aprovado,
  `prototipo/PROMPT.md` §3, *Em toda página da área*).

  - `area_nav/1` — as seis páginas da área, nesta ordem (3.0.1), com a rede e a janela escolhidas
    acompanhando a navegação (3.0.3);
  - `header/1` — título, pergunta, os seletores de rede e de janela, a linha da leitura com as
    marcas *derived* e *observed* (3.0.5, FR-051) e o aviso de alcance parcial (US1, cen. 5);
  - `marca/1` — a marca de proveniência com a palavra ao lado, a mesma da 073.

  Componente de exibição: não lê leitura, não decide alcance, não guarda nada. Recebe a visão que
  `NetworkAnalysis.read/4` já recortou.

  ## A língua

  As frases vão para a tela e são em inglês, mesmo nascendo no domínio (`AGENTS.md` §11.1): não
  traduzir de volta. A aresta de designação é *assignment*, e nunca *delegation* nem
  *collaboration* (D1; revisão semântica 2, A1).

  Depende de: nenhuma ontologia.
  """
  use TheBandWeb, :html

  # As seis páginas da área, na ordem do protótipo (3.0.1), com a pergunta que cada uma responde e
  # as medidas que mostra (3.1.3). Frases da tela, em inglês.
  @paginas [
    %{
      page: :review,
      label: "Review network",
      question: "Is code review concentrated in a few people?",
      measures: "the first page · concentration · counts · groups that do not review each other"
    },
    %{
      page: :graph,
      label: "Graph",
      question: "Who is linked to whom, and who sits between groups?",
      measures: "size = people linked · colour = betweenness · width = links"
    },
    %{
      page: :communities,
      label: "Communities",
      question: "Which groups work mostly among themselves?",
      measures: "modularity · communities · members · the most linked in each"
    },
    %{
      page: :hubs,
      label: "Hubs",
      question: "Who is central, and in which sense?",
      measures: "degree · betweenness · closeness · eigenvector"
    },
    %{
      page: :distance,
      label: "Distance and small world",
      question: "How many steps separate people, and is the network a small world?",
      measures: "average distance · diameter · efficiency · clustering · σ"
    },
    %{
      page: :positions,
      label: "Positions and profiles",
      question: "Where does each person sit, and who do they work with?",
      measures:
        "position in the network · who is assigned their issues, and whose they are assigned"
    }
  ]

  # As páginas que já existem nesta fatia. As outras entram com a user story que as constrói
  # (tasks.md, fases 4 a 11); até lá aparecem na ordem, sem link, e nunca como link quebrado.
  @disponiveis [:review, :graph, :communities, :hubs, :distance, :positions]

  @doc "As seis páginas da área, na ordem do protótipo (3.0.1)."
  @spec pages() :: [map()]
  def pages, do: @paginas

  @doc "A página já existe nesta fatia?"
  @spec available?(atom()) :: boolean()
  def available?(page), do: page in @disponiveis

  @doc """
  O caminho de uma página da área, levando a rede e a janela escolhidas (3.0.3).

  A rede de revisão da 073 só lê janela: a rede dela é sempre a de revisão, e a escolhida passa
  por ela só para voltar às outras páginas.
  """
  @spec page_path(atom(), Ecto.UUID.t(), %{
          optional(:network) => String.t(),
          optional(:view) => String.t(),
          window: pos_integer()
        }) ::
          String.t()
  # A rede vai junto quando foi escolhida: a página da 073 não a lê, mas a devolve às abas, e
  # quem passa por ela volta à rede que tinha (T053).
  def page_path(:review, organization_id, selecao),
    do: ~p"/network-analysis/#{organization_id}?#{consulta(Map.delete(selecao, :view))}"

  # A rede só vai no endereço quando foi escolhida: da página da 073, que só lê janela, o link
  # leva a janela, e a página de análise abre na rede padrão.
  def page_path(:graph, organization_id, selecao),
    do: ~p"/network-analysis/#{organization_id}/graph?#{consulta(selecao)}"

  def page_path(:communities, organization_id, selecao),
    do: ~p"/network-analysis/#{organization_id}/communities?#{consulta(selecao)}"

  def page_path(:hubs, organization_id, selecao),
    do: ~p"/network-analysis/#{organization_id}/hubs?#{consulta(selecao)}"

  def page_path(:distance, organization_id, selecao),
    do: ~p"/network-analysis/#{organization_id}/distance?#{consulta(selecao)}"

  def page_path(:positions, organization_id, selecao),
    do: ~p"/network-analysis/#{organization_id}/positions?#{consulta(selecao)}"

  # A vista de comunidades do grafo (FR-026) acompanha a troca de rede e de janela; a ponderada é
  # o padrão, e não vai no endereço.
  defp consulta(selecao) do
    [
      network: Map.get(selecao, :network),
      window: Map.get(selecao, :window),
      view: if(Map.get(selecao, :view) == "communities", do: "communities")
    ]
    |> Enum.reject(fn {_chave, valor} -> is_nil(valor) end)
  end

  @doc """
  O caminho do perfil de uma pessoa alcançada, com a seleção (T048). Só para alcançados: quem
  chama tem a pessoa na visão recortada.
  """
  @spec profile_path(Ecto.UUID.t(), Ecto.UUID.t(), map()) :: String.t()
  def profile_path(organization_id, person_id, selecao),
    do:
      ~p"/network-analysis/#{organization_id}/people/#{person_id}?#{[network: Map.get(selecao, :network), window: Map.get(selecao, :window)]}"

  @doc """
  A letra de uma comunidade (protótipo 3.3.2, decisão de 2026-10-04): 1 → A, 26 → Z, 27 → AA.
  As comunidades são numeradas por tamanho, e a letra segue o número: A é a maior.
  """
  @spec community_letter(pos_integer()) :: String.t()
  def community_letter(n) when is_integer(n) and n > 0 do
    if n <= 26,
      do: <<?A + n - 1>>,
      else: community_letter(div(n - 1, 26)) <> <<?A + rem(n - 1, 26)>>
  end

  @doc """
  As frases das duas arestas, em palavras, com a direção da seta (3.0.2, 3.1.2).

  A de designação diz o que **não** afirma: quem designou e quem executou (US2, cen. 5).
  """
  @spec link_label(String.t()) :: %{short: String.t(), arrow: String.t(), sentence: String.t()}
  def link_label("review") do
    %{
      short: "review",
      arrow: "reviewer → author of the change request",
      sentence:
        "a person reviewed a change request someone else opened. The arrow goes from the " <>
          "reviewer to the author."
    }
  end

  def link_label("assignment") do
    %{
      short: "assignment",
      arrow: "author of the issue → assignee",
      sentence:
        "a person opened an issue and someone else is its assignee. The arrow goes from the " <>
          "author of the issue to the assignee. It does not say who made the assignment, nor " <>
          "who did the work."
    }
  end

  attr :active, :atom, required: true, doc: "a página aberta, um dos `page` de `pages/0`"
  attr :organization_id, :string, required: true
  attr :selection, :map, required: true, doc: "`%{network:, window:}` escolhidos"

  @doc """
  As seis páginas da área, na ordem (3.0.1). A rede e a janela vão em todo link (3.0.3): trocar
  de rede numa página e achar a outra na seguinte leria a rede errada em silêncio.
  """
  def area_nav(assigns) do
    assigns = assign(assigns, :paginas, @paginas)

    ~H"""
    <nav
      id="area-network-analysis"
      class="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0"
      aria-label="Network analysis"
    >
      <ul class="tabs tabs-border whitespace-nowrap">
        <li :for={p <- @paginas} class="contents">
          <%= if available?(p.page) do %>
            <.link
              navigate={page_path(p.page, @organization_id, @selection)}
              class={["tab", p.page == @active && "tab-active"]}
              aria-current={p.page == @active && "page"}
              data-page={p.page}
            >
              {p.label}
            </.link>
          <% else %>
            <span class="tab cursor-default opacity-50" data-page={p.page}>{p.label}</span>
          <% end %>
        </li>
      </ul>
    </nav>
    """
  end

  attr :title, :string, required: true
  attr :question, :string, required: true
  attr :page, :atom, required: true
  attr :organization, :map, required: true, doc: "a organização, com `id`, `name` e `login`"
  attr :selection, :map, required: true
  attr :options, :map, required: true, doc: "`NetworkAnalysis.options/0`"

  attr :reading, :any,
    required: true,
    doc: "a visão de `NetworkAnalysis.read/4`, ou `nil` quando não há leitura a mostrar"

  @doc """
  O cabeçalho de toda página de análise da área (`contracts/tela.md`).

  A linha da leitura leva a marca *derived* junto dos números e *observed* junto da origem
  (FR-051, 3.0.5); o aviso de alcance parcial é o texto da US1, cen. 5.
  """
  def header(assigns) do
    ~H"""
    <div class="flex flex-col gap-4" id="cabecalho-da-area">
      <nav class="text-sm opacity-70" aria-label="breadcrumb">
        <.link navigate={~p"/network-analysis"} class="link link-hover">Network analysis</.link>
        › <span id="organizacao-atual">{nome(@organization)}</span>
      </nav>

      <header>
        <h1 class="text-2xl font-semibold">{@title}</h1>
        <p class="opacity-80">{@question}</p>
      </header>

      <%!-- 3.0.2: as duas arestas, cada uma com a direção da seta --%>
      <div id="redes" class="flex flex-wrap gap-2" role="group" aria-label="link">
        <.link
          :for={rede <- @options.networks.allowed}
          patch={page_path(@page, @organization.id, %{@selection | network: rede})}
          class={[
            "btn btn-sm h-auto py-1",
            if(rede == @selection.network, do: "btn-primary", else: "btn-ghost")
          ]}
          aria-current={rede == @selection.network && "true"}
          data-network={rede}
        >
          <span class="flex flex-col items-start text-left">
            <span>{link_label(rede).short}</span>
            <span class="text-xs font-normal opacity-80">{link_label(rede).arrow}</span>
          </span>
        </.link>
      </div>

      <%!-- 3.0.4 --%>
      <div id="janelas" class="flex flex-col gap-1">
        <div class="flex flex-wrap gap-2" role="group" aria-label="window">
          <.link
            :for={dias <- @options.windows.allowed}
            patch={page_path(@page, @organization.id, %{@selection | window: dias})}
            class={["btn btn-sm", if(dias == @selection.window, do: "btn-primary", else: "btn-ghost")]}
            aria-current={dias == @selection.window && "true"}
          >
            {dias} days
          </.link>
        </div>
        <p class="text-xs opacity-70">
          Switching the window reads another stored reading. It computes nothing.
        </p>
      </div>

      <%= if @reading do %>
        <%!-- US1, cen. 5: o texto exato da spec --%>
        <div
          :if={@reading.reach == :parcial}
          id="aviso-de-alcance"
          class="flex items-start gap-3 rounded border-2 border-info bg-base-100 p-3 text-sm"
          role="note"
        >
          <span
            class="inline-flex size-6 shrink-0 items-center justify-center rounded-full border-2 border-info font-mono font-bold text-info"
            aria-hidden="true"
          >
            i
          </span>
          <p>
            <.marca tipo={:alcance} />
            Names appear only for the people you reach. Measures are computed over the whole
            network. People outside your reach appear grouped, without names, and only in groups
            of at least 3.
          </p>
        </div>

        <%!-- 073, Q3: a coleta terminou depois da leitura --%>
        <div
          :if={match?({:em, _}, @reading.newer_collection)}
          id="coleta-mais-nova"
          class="border-4 border-double border-warning rounded p-3 text-sm"
        >
          A collection ended on {dia(elem(@reading.newer_collection, 1))}, after this reading. The
          reading was not refreshed. The numbers below are from {dia(@reading.computed_at)}.
        </div>

        <.linha_da_leitura id="leitura" reading={@reading} network={@selection.network} />
      <% end %>
    </div>
    """
  end

  attr :id, :string, required: true

  attr :reading, :map,
    required: true,
    doc: "com `computed_at`, `window_start`, `window_end`, `window_days`"

  attr :network, :string, required: true

  @doc """
  A linha da leitura (3.0.5): o instante, há quanto tempo, a janela, e as marcas *derived* junto
  dos números e *observed* junto da origem. No cabeçalho das páginas e em cada rede do perfil,
  que lê duas leituras (T053).
  """
  def linha_da_leitura(assigns) do
    ~H"""
    <div id={@id} class="text-sm flex flex-col gap-1">
      <p>
        Reading of {instante(@reading.computed_at)} ({idade(@reading.computed_at)}). Window: {dia(
          @reading.window_start
        )} – {dia(@reading.window_end)}, {@reading.window_days} days.
      </p>
      <p>
        <.marca tipo={:derivado} /> Every number here is derived from
        <.marca tipo={:observado} /> {origem(@network)}.
      </p>
    </div>
    """
  end

  @doc """
  O autovetor como está na leitura, de 0 a 1 com duas casas. Abaixo de 0,005 a conta de duas
  casas daria "0.00", e o valor é estritamente positivo (A + I, por componente): o zero seria
  afirmado sem existir (3.0.6, T053).
  """
  @spec autovetor_texto(number()) :: String.t()
  def autovetor_texto(v) when v < 0.005, do: "under 0.01"
  def autovetor_texto(v), do: :erlang.float_to_binary(v * 1.0, decimals: 2)

  attr :tipo, :atom, values: [:observado, :derivado, :alcance], required: true

  @doc """
  A marca de proveniência, com a palavra sempre ao lado: a distinção nunca é só cor (WCAG 1.4.1;
  design system). Sólido observado, hachurado derivado, contorno para o alcance — a mesma da 073
  (`ReviewNetworkLive.Show`).
  """
  def marca(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1 text-xs font-normal align-middle",
        @tipo == :alcance && "rounded-sm border border-info px-1.5 text-info"
      ]}
      data-marca={@tipo}
    >
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

  defp origem("review"), do: "the submitted reviews observed at the source"
  defp origem("assignment"), do: "the issues and their assignees observed at the source"

  @doc "O nome da organização, ou o login quando a origem não deu nome."
  @spec nome(map()) :: String.t()
  def nome(organizacao), do: organizacao.name || organizacao.login

  defp instante(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  defp dia(dt), do: Calendar.strftime(dt, "%Y-%m-%d")

  # O plural é do gettext, e não de concatenação (073, issue #1308).
  defp idade(dt) do
    segundos = DateTime.diff(DateTime.utc_now(), dt)

    cond do
      segundos < 3600 ->
        ngettext("%{count} minute ago", "%{count} minutes ago", max(div(segundos, 60), 0))

      segundos < 86_400 ->
        ngettext("%{count} hour ago", "%{count} hours ago", div(segundos, 3600))

      true ->
        ngettext("%{count} day ago", "%{count} days ago", div(segundos, 86_400))
    end
  end
end
