defmodule TheBandWeb.NetworkAnalysisLive.GraphComponents do
  @moduledoc """
  O desenho do grafo ponderado, em SVG gerado no servidor — feature 076, T032 (US3; FR-020 a
  FR-025; R16; `contracts/tela.md`, *O grafo*; protótipo aprovado 3.2.1 a 3.2.5, 3.7.2, 3.7.3,
  3.8.1).

  ## Nenhum dado vai para o navegador além do markup

  Tudo é atributo e texto do HEEx, escapado por ele (A9): nenhum `raw/1`, nenhum
  `<foreignObject>`, nenhum `data-*` com JSON (A7), nenhum `push_event`. Todo número é formatado
  aqui, com uma casa; a cor é **classe** da paleta, nunca `style`.

  ## O destaque não vai ao servidor

  Apontar ou focar um nó roda comandos `Phoenix.LiveView.JS` sobre classes já renderizadas: cada
  aresta leva `e-<id>` das duas pontas, e cada nó e rótulo leva `nb-<id>` de si e dos vizinhos.
  **Não existe** `handle_event` de destaque (A8 fica sem superfície). O LiveView 1.2 não tem
  `phx-mouseenter`: o hook `.NetworkGraph` executa, no `pointerover` e no `pointerout`, os mesmos
  comandos que o nó já carrega em `phx-focus` e `phx-blur` — sem dado próprio.

  O hook faz o resto do que é só da vista: roda, + / − / *fit* e arrasto, aplicando `transform`
  no `<g>` da vista. Não recebe dado, não faz `pushEvent` nem `handleEvent`.

  ## O que entra no desenho

  A visão já recortada (`NetworkAnalysis.read/4`): pessoas alcançadas por nome e agregados sem
  nome. Tamanho pelo grau (pessoas ligadas), cor pela faixa de intermediação da base, espessura
  pelo peso, seta pela direção. Nomes escritos só nos nós marcados `labelled?` pelo `Reader` — os
  mais ligados **entre os alcançados** (O1 da revisão semântica 3); os demais no `<title>`, no
  foco e na lista.

  ## A vista de comunidades (T037; FR-021, FR-026; protótipo 3.3.2)

  As **mesmas posições**, sem recalcular nada: cada pessoa com a cor da comunidade, e cada
  comunidade com um contorno tracejado e a **letra** (A a maior), para ler em escala de cinza —
  a cor nunca é o único sinal (WCAG 1.4.1). O contorno é a envoltória convexa dos nós da
  comunidade na visão, alargada, calculada aqui. O agregado de pessoas de fora entra no
  contorno da comunidade dele.

  A interface fala inglês (§11.1): as frases nasceram no protótipo aprovado.
  """
  use Phoenix.Component

  import TheBandWeb.UI, only: [absent: 1]

  alias Phoenix.LiveView.ColocatedHook
  alias Phoenix.LiveView.JS
  alias TheBandWeb.NetworkAnalysisLive.Shared

  # A cor de cada faixa da base (`betweenness_color_bands`), em classes da paleta. Uma faixa nova
  # na base sem cor aqui levanta: cor inventada seria leitura sem razão (FR-031).
  @cor_da_faixa %{
    "none" => "fill-base-200",
    "below_2" => "fill-warning/25",
    "2_to_5" => "fill-warning/45",
    "5_to_10" => "fill-warning/70",
    "10_or_more" => "fill-warning"
  }

  # A cor de cada comunidade, por posição; depois da oitava, as cores se repetem, e a letra
  # continua a distinguir. Classes inteiras, para o Tailwind encontrá-las no markup.
  @cor_da_comunidade {
    "fill-indigo-500 stroke-indigo-600",
    "fill-teal-600 stroke-teal-700",
    "fill-amber-600 stroke-amber-700",
    "fill-rose-700 stroke-rose-800",
    "fill-slate-500 stroke-slate-600",
    "fill-cyan-800 stroke-cyan-900",
    "fill-violet-600 stroke-violet-700",
    "fill-lime-700 stroke-lime-800"
  }

  @doc """
  O grafo da visão: o SVG (`hidden sm:block`), a legenda, o cartão do nó apontado e a lista
  empilhada do telefone (`sm:hidden`). Sem posições (acima do teto), só a lista, em qualquer
  largura.
  """
  attr :id, :string, required: true
  attr :graph, :map, required: true, doc: "o `graph` de `NetworkAnalysis.read/4`, em `{:ok, _}`"
  attr :network, :string, required: true

  attr :view, :string,
    default: "weighted",
    doc: "`weighted` (cor pela intermediação) ou `communities` (cor e letra pela comunidade)"

  def graph(assigns) do
    vizinhos = vizinhos(assigns.graph.edges)
    nos = Map.new(assigns.graph.nodes, &{&1.id, &1})

    assigns =
      assign(assigns,
        vizinhos: vizinhos,
        nos: nos,
        pessoas: assigns.graph.nodes |> Enum.filter(&(&1.kind == :person)) |> por_nome(),
        agregados: Enum.filter(assigns.graph.nodes, &(&1.kind == :outside)),
        svg_id: "#{assigns.id}-svg",
        side_id: "#{assigns.id}-side"
      )

    ~H"""
    <div id={@id} class="flex flex-col gap-4">
      <%= case @graph.layout do %>
        <% {:ok, posicoes} -> %>
          {render_desenho(assign(assigns, posicoes: posicoes))}
          <p class="text-sm sm:hidden">
            On a narrow screen the graph becomes the list below: every person, with the same
            measures and links.
          </p>
          <div class="sm:hidden">{render_lista(assigns)}</div>
        <% {:ausente, motivo} -> %>
          <p id={"#{@id}-sem-desenho"} class="text-sm">
            <.absent reason={sem_desenho(motivo)} />
          </p>
          {render_lista(assigns)}
      <% end %>
    </div>
    """
  end

  attr :community, :integer, required: true

  @doc """
  A marca de uma comunidade fora do desenho (os cartões da página Communities): a cor da
  comunidade **e** a letra, para a cor nunca ser o único sinal.
  """
  def community_mark(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 font-mono font-bold">
      <svg viewBox="0 0 10 10" class="size-3" aria-hidden="true">
        <circle cx="5" cy="5" r="4.5" class={cor_da_comunidade(@community)} />
      </svg>
      {letra(@community)}
    </span>
    """
  end

  defp render_desenho(assigns) do
    ~H"""
    <div class="hidden sm:grid gap-4 sm:grid-cols-2">
      <div
        id={"#{@id}-box"}
        phx-hook=".NetworkGraph"
        class="relative sm:col-span-2 overflow-hidden rounded-box border border-base-300 bg-base-100 touch-none"
      >
        <div class="absolute top-2 right-2 flex gap-1">
          <button type="button" data-zoom="in" aria-label="Zoom in" class="btn btn-xs btn-square">
            +
          </button>
          <button type="button" data-zoom="out" aria-label="Zoom out" class="btn btn-xs btn-square">
            −
          </button>
          <button
            type="button"
            data-zoom="fit"
            aria-label="Fit the whole network"
            class="btn btn-xs btn-square"
          >
            ⤢
          </button>
        </div>
        <span class="pointer-events-none absolute left-2 bottom-1 font-mono text-[10px] opacity-70">
          drag to move · wheel or + − to zoom · point at a person
        </span>
        <svg
          id={@svg_id}
          viewBox="0 0 1000 1000"
          role="group"
          aria-label={rotulo_do_svg(@network, length(@pessoas), length(@graph.edges))}
          class="block w-full h-auto max-h-[80vh] cursor-grab select-none"
        >
          <defs>
            <marker
              id={"#{@id}-seta"}
              viewBox="0 0 10 10"
              refX="9"
              refY="5"
              markerWidth="9"
              markerHeight="9"
              markerUnits="userSpaceOnUse"
              orient="auto-start-reverse"
            >
              <path d="M0,0 L10,5 L0,10 z" class="fill-base-content/60" />
            </marker>
          </defs>
          <g data-viewport>
            <g :if={@view == "communities"} aria-hidden="true">
              <g :for={{c, pontos, {lx, ly}} <- contornos(@graph.nodes, @posicoes)}>
                <polygon
                  points={pontos}
                  class={[
                    "fill-opacity-10 stroke-[1.5] [stroke-dasharray:6_4]",
                    cor_da_comunidade(c)
                  ]}
                />
                <text
                  x={num(lx)}
                  y={num(ly - 6)}
                  text-anchor="middle"
                  class={["font-mono font-bold text-[22px] stroke-none", cor_da_comunidade(c)]}
                >
                  {letra(c)}
                </text>
              </g>
            </g>
            <g>
              <path
                :for={a <- @graph.edges}
                d={caminho(a, @posicoes, @nos)}
                stroke-width={num(0.6 + :math.log2(1 + a.weight) * 0.9)}
                marker-end={"url(##{@id}-seta)"}
                class={["ed fill-none stroke-base-content opacity-30", "e-#{a.from}", "e-#{a.to}"]}
              />
            </g>
            <g>
              <circle
                :for={p <- @pessoas}
                id={"#{@id}-n-#{p.id}"}
                cx={x(@posicoes, p.id)}
                cy={y(@posicoes, p.id)}
                r={num(raio(p))}
                tabindex="0"
                phx-focus={focar(@svg_id, @side_id, p.id)}
                phx-blur={soltar(@svg_id)}
                class={[
                  "nd stroke-base-content outline-none focus:[stroke-width:2.5]",
                  cor_do_no(p, @view),
                  classes_de_vizinho(p.id, @vizinhos)
                ]}
              >
                <title>{titulo(p)}</title>
              </circle>
              <circle
                :for={g <- @agregados}
                id={"#{@id}-n-#{g.id}"}
                cx={x(@posicoes, g.id)}
                cy={y(@posicoes, g.id)}
                r={num(raio(g))}
                tabindex="0"
                phx-focus={focar(@svg_id, @side_id, g.id)}
                phx-blur={soltar(@svg_id)}
                class={[
                  "nd stroke-base-content/60 [stroke-dasharray:4_3] outline-none focus:[stroke-width:2.5]",
                  if(@view == "communities" and is_integer(g.community),
                    do: [cor_da_comunidade(g.community), "fill-opacity-30"],
                    else: "fill-base-200"
                  ),
                  classes_de_vizinho(g.id, @vizinhos)
                ]}
              >
                <title>{titulo_do_agregado(g)}</title>
              </circle>
            </g>
            <g class="pointer-events-none">
              <text
                :for={p <- @pessoas}
                x={x(@posicoes, p.id)}
                y={num(coord(@posicoes, p.id, 1) - raio(p) - 4)}
                text-anchor="middle"
                class={[
                  "lb text-[14px] font-semibold fill-base-content [paint-order:stroke] stroke-base-100 [stroke-width:3px] [stroke-linejoin:round]",
                  if(p.labelled?, do: "major", else: "minor hidden"),
                  classes_de_vizinho(p.id, @vizinhos)
                ]}
              >
                {p.name}
              </text>
              <text
                :for={g <- @agregados}
                x={x(@posicoes, g.id)}
                y={num(coord(@posicoes, g.id, 1) + raio(g) + 14)}
                text-anchor="middle"
                class={[
                  "lb font-mono text-[13px] fill-base-content/70 [paint-order:stroke] stroke-base-100 [stroke-width:3px]",
                  classes_de_vizinho(g.id, @vizinhos)
                ]}
              >
                {rotulo_do_agregado(g)}
              </text>
            </g>
          </g>
        </svg>
      </div>

      {render_legenda(assigns)}

      <div id={@side_id} class="flex flex-col gap-2 min-w-0" aria-live="polite">
        <p class="text-sm opacity-70">
          Point at a person, or move to one with the keyboard, to see their links.
        </p>
        {render_cartoes(assigns)}
      </div>
      <p class="text-xs opacity-70 sm:col-span-2">
        Names are written for the most linked people you reach; the others appear when you point at
        or focus a node. The positions were computed on the server: the same reading always draws
        the same picture.
      </p>
    </div>

    <script :type={ColocatedHook} name=".NetworkGraph">
      // Só a vista: zoom, arrasto e o destaque ao apontar. Nenhum dado, nenhum pushEvent.
      export default {
        mounted() {
          this.t = {s: 1, x: 0, y: 0}
          this.svg = this.el.querySelector("svg")
          const ponto = (e) => {
            const r = this.svg.getBoundingClientRect()
            return [(e.clientX - r.left) / r.width * 1000, (e.clientY - r.top) / r.height * 1000]
          }
          const zoom = (f, cx = 500, cy = 500) => {
            const s = Math.min(8, Math.max(1, this.t.s * f))
            const k = s / this.t.s
            this.t = {s, x: cx - (cx - this.t.x) * k, y: cy - (cy - this.t.y) * k}
            this.aplicar()
          }
          this.svg.addEventListener("wheel", (e) => {
            e.preventDefault()
            const [cx, cy] = ponto(e)
            zoom(e.deltaY > 0 ? 1 / 1.15 : 1.15, cx, cy)
          }, {passive: false})
          this.el.querySelectorAll("[data-zoom]").forEach((b) => b.addEventListener("click", () => {
            const z = b.getAttribute("data-zoom")
            if (z === "in") zoom(1.3)
            else if (z === "out") zoom(1 / 1.3)
            else { this.t = {s: 1, x: 0, y: 0}; this.aplicar() }
          }))
          let arrasto = null
          this.svg.addEventListener("pointerdown", (e) => {
            if (e.target.classList.contains("nd")) return
            arrasto = [...ponto(e), this.t.x, this.t.y]
            this.svg.setPointerCapture(e.pointerId)
          })
          this.svg.addEventListener("pointermove", (e) => {
            if (!arrasto) return
            const [px, py] = ponto(e)
            this.t = {s: this.t.s, x: arrasto[2] + px - arrasto[0], y: arrasto[3] + py - arrasto[1]}
            this.aplicar()
          })
          this.svg.addEventListener("pointerup", () => { arrasto = null })
          // O LiveView 1.2 não tem phx-mouseenter: apontar roda o mesmo comando do foco.
          const rodar = (e, attr) => {
            const n = e.target.closest(".nd")
            if (n && n.getAttribute(attr)) this.liveSocket.execJS(n, n.getAttribute(attr))
          }
          this.svg.addEventListener("pointerover", (e) => rodar(e, "phx-focus"))
          this.svg.addEventListener("pointerout", (e) => rodar(e, "phx-blur"))
        },
        updated() { this.aplicar() },
        aplicar() {
          const g = this.el.querySelector("[data-viewport]")
          if (g) g.setAttribute("transform", `translate(${this.t.x} ${this.t.y}) scale(${this.t.s})`)
        }
      }
    </script>
    """
  end

  defp render_legenda(%{view: "communities"} = assigns) do
    assigns = assign(assigns, comunidades: comunidades_da_visao(assigns.graph.nodes))

    ~H"""
    <div id={"#{@id}-legenda"} class="flex flex-col gap-2 text-xs opacity-90 min-w-0">
      <p>
        <b>Colour, dashed outline and letter</b>
        the community of each person <span class="opacity-70">(derived)</span>; the letter follows
        size, A the largest, so the picture reads in greyscale.
      </p>
      <ul class="flex flex-wrap gap-x-3 gap-y-1" aria-label="communities">
        <li :for={c <- @comunidades} class="inline-flex items-center gap-1">
          <svg viewBox="0 0 10 10" class="size-3" aria-hidden="true">
            <circle cx="5" cy="5" r="4.5" class={cor_da_comunidade(c)} />
          </svg>
          Community {letra(c)}
        </li>
      </ul>
      <p><b>Size</b> people linked, in either direction.</p>
      <p>
        <b>Width</b> how many {unidade(@network)} on that link. <b>Arrow</b> its direction.
      </p>
      <p :if={@agregados != []}>
        <b>Dashed</b> people outside your reach, grouped and unnamed; links between people of the
        same group are not drawn.
      </p>
    </div>
    """
  end

  defp render_legenda(assigns) do
    ~H"""
    <div id={"#{@id}-legenda"} class="flex flex-col gap-2 text-xs opacity-90 min-w-0">
      <p>
        <b>Size</b> people linked, in either direction.
      </p>
      <p>
        <b>Colour</b>
        betweenness, share of shortest paths between others that pass through the person
        <span class="opacity-70">(derived)</span>
      </p>
      <ul class="flex flex-wrap gap-x-3 gap-y-1" aria-label="betweenness bands">
        <li :for={b <- @graph.bands} class="inline-flex items-center gap-1">
          <svg viewBox="0 0 10 10" class="size-3" aria-hidden="true">
            <circle cx="5" cy="5" r="4.5" class={["stroke-base-content", cor(b.code)]} />
          </svg>
          {b.label}
        </li>
        <li class="inline-flex items-center gap-1">
          <svg viewBox="0 0 10 10" class="size-3" aria-hidden="true">
            <circle cx="5" cy="5" r="4.5" class={["stroke-base-content", cor(nil)]} />
          </svg>
          not calculated: fewer than 3 people
        </li>
      </ul>
      <p>
        <b>Width</b> how many {unidade(@network)} on that link. <b>Arrow</b> its direction.
      </p>
      <p :if={@agregados != []}>
        <b>Dashed</b> people outside your reach, grouped and unnamed; links between people of the
        same group are not drawn.
      </p>
    </div>
    """
  end

  # 3.2.5 e 3.7.3: um cartão por nó, escondido, mostrado pelo destaque. Nada do cartão vem do
  # servidor depois do primeiro render.
  defp render_cartoes(assigns) do
    ~H"""
    <div
      :for={p <- @pessoas}
      id={"#{@side_id}-#{p.id}"}
      class="hidden card border border-base-300 p-3 flex-col gap-2"
    >
      <h3 class="font-semibold">{p.name}</h3>
      <span :if={is_integer(p.community)} class="text-xs">community {letra(p.community)}</span>
      <span :if={p.links_outside_reach?} class="text-xs">has links outside your reach</span>
      <dl class="grid grid-cols-[7rem_1fr] gap-x-3 gap-y-1 text-sm">
        <dt class="opacity-70">{verbo_saida(@network)}</dt>
        <dd>{saida(p, @network)}</dd>
        <dt class="opacity-70">{verbo_entrada(@network)}</dt>
        <dd>{entrada(p, @network)}</dd>
        <dt class="opacity-70">degree</dt>
        <dd>linked to <span class="font-mono">{p.degree}</span> {pessoas(p.degree)}</dd>
        <dt class="opacity-70">betweenness</dt>
        <dd>{intermediacao(p.betweenness)}</dd>
        <dt class="opacity-70">closeness</dt>
        <dd>{proximidade(p)}</dd>
        <dt class="opacity-70">eigenvector</dt>
        <dd>{autovetor(Map.get(p, :eigenvector))}</dd>
        <dt class="opacity-70">position</dt>
        <dd>{posicao(Map.get(p, :role))}</dd>
      </dl>
    </div>
    <div
      :for={g <- @agregados}
      id={"#{@side_id}-#{g.id}"}
      class="hidden card border border-base-300 p-3 flex-col gap-2"
    >
      <h3 class="font-semibold">{g.size} people outside your reach</h3>
      <p class="text-sm opacity-80">
        They are part of every measure on this page, but you do not see who they are. Links between
        them are not drawn.
      </p>
    </div>
    """
  end

  # FR-025: a lista carrega tudo o que o desenho diz, por nome, e nunca ordenada por medida.
  defp render_lista(assigns) do
    ~H"""
    <table id={"#{@id}-lista"} class="table table-sm stacked">
      <thead>
        <tr>
          <th>person</th>
          <th>community</th>
          <th>linked to</th>
          <th>links</th>
          <th>betweenness</th>
          <th>links to</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={p <- @pessoas}>
          <td data-label="person">
            {p.name}
            <span :if={p.links_outside_reach?} class="block text-xs opacity-70">
              has links outside your reach
            </span>
          </td>
          <td data-label="community">{comunidade_na_lista(p.community)}</td>
          <td data-label="linked to">{p.degree} {pessoas(p.degree)}</td>
          <td data-label="links">{p.out_people} links out, {p.in_people} in</td>
          <td data-label="betweenness">{intermediacao(p.betweenness)}</td>
          <td data-label="links to">{ligacoes(p.id, @graph.edges, @nos)}</td>
        </tr>
        <tr :for={g <- @agregados}>
          <td data-label="person">{rotulo_do_agregado(g)}</td>
          <td data-label="community">{comunidade_na_lista(g.community)}</td>
          <td data-label="linked to">
            <.absent reason="not shown for people outside your reach" />
          </td>
          <td data-label="links">
            <.absent reason="not shown for people outside your reach" />
          </td>
          <td data-label="betweenness">
            <.absent reason="not shown for people outside your reach" />
          </td>
          <td data-label="links to">{ligacoes(g.id, @graph.edges, @nos)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  # ── destaque ────────────────────────────────────────────────────────────────

  defp focar(svg, side, id) do
    JS.add_class("opacity-15", to: "##{svg} .nd, ##{svg} .lb")
    |> JS.remove_class("opacity-15", to: "##{svg} .nb-#{id}")
    |> JS.remove_class("opacity-30", to: "##{svg} .ed")
    |> JS.add_class("opacity-5", to: "##{svg} .ed")
    |> JS.remove_class("opacity-5", to: "##{svg} .e-#{id}")
    |> JS.add_class("opacity-90", to: "##{svg} .e-#{id}")
    |> JS.remove_class("hidden", to: "##{svg} .lb.nb-#{id}")
    |> JS.hide(to: "##{side} > *")
    |> JS.show(to: "##{side}-#{id}", display: "flex")
  end

  defp soltar(svg) do
    JS.remove_class("opacity-15", to: "##{svg} .nd, ##{svg} .lb")
    |> JS.remove_class("opacity-5 opacity-90", to: "##{svg} .ed")
    |> JS.add_class("opacity-30", to: "##{svg} .ed")
    |> JS.add_class("hidden", to: "##{svg} .lb.minor")
  end

  defp vizinhos(arestas) do
    Enum.reduce(arestas, %{}, fn %{from: u, to: v}, acc ->
      acc
      |> Map.update(u, MapSet.new([v]), &MapSet.put(&1, v))
      |> Map.update(v, MapSet.new([u]), &MapSet.put(&1, u))
    end)
  end

  defp classes_de_vizinho(id, vizinhos),
    do: [
      "nb-#{id}" | vizinhos |> Map.get(id, MapSet.new()) |> Enum.sort() |> Enum.map(&"nb-#{&1}")
    ]

  # ── geometria: tudo formatado aqui, uma casa ────────────────────────────────

  defp raio(%{kind: :person, degree: d}), do: 5 + 3 * :math.sqrt(d)
  defp raio(%{kind: :outside, size: n}), do: 8 + 4 * :math.sqrt(n)

  defp coord(posicoes, id, i), do: posicoes |> Map.fetch!(id) |> elem(i)
  defp x(posicoes, id), do: num(coord(posicoes, id, 0))
  defp y(posicoes, id), do: num(coord(posicoes, id, 1))

  defp num(v), do: :erlang.float_to_binary(v * 1.0, decimals: 1)

  # Curva leve, como no protótipo: o par recíproco não se sobrepõe, e a seta para na borda.
  defp caminho(%{from: u, to: v}, posicoes, nos) do
    {x1, y1} = Map.fetch!(posicoes, u)
    {x2, y2} = Map.fetch!(posicoes, v)
    dx = x2 - x1
    dy = y2 - y1
    l = max(:math.sqrt(dx * dx + dy * dy), 1.0)
    r2 = raio(Map.fetch!(nos, v)) + 2
    ex = x2 - dx / l * r2
    ey = y2 - dy / l * r2
    off = min(18, l * 0.08)
    mx = (x1 + ex) / 2 - dy / l * off
    my = (y1 + ey) / 2 + dx / l * off
    "M#{num(x1)},#{num(y1)} Q#{num(mx)},#{num(my)} #{num(ex)},#{num(ey)}"
  end

  defp cor(nil), do: "fill-base-100 [stroke-dasharray:3_2]"
  defp cor(codigo), do: Map.fetch!(@cor_da_faixa, codigo)

  defp cor_do_no(p, "communities") when is_integer(p.community),
    do: cor_da_comunidade(p.community)

  defp cor_do_no(_p, "communities"), do: "fill-base-100 [stroke-dasharray:3_2]"
  defp cor_do_no(p, _vista), do: cor(p.band)

  defp cor_da_comunidade(c) when is_integer(c),
    do: elem(@cor_da_comunidade, rem(c - 1, tuple_size(@cor_da_comunidade)))

  defp letra(c), do: Shared.community_letter(c)

  defp comunidades_da_visao(nos),
    do:
      nos |> Enum.map(& &1.community) |> Enum.filter(&is_integer/1) |> Enum.uniq() |> Enum.sort()

  defp comunidade_na_lista(c) when is_integer(c), do: letra(c)

  defp comunidade_na_lista(_c),
    do: assigns_absent("not calculated in this reading")

  defp assigns_absent(motivo) do
    assigns = %{motivo: motivo}

    ~H"""
    <.absent reason={@motivo} />
    """
  end

  # O contorno de cada comunidade: a envoltória convexa dos seus nós na visão, cada nó alargado
  # por oito pontos à volta dele, para o contorno não passar por cima do círculo.
  defp contornos(nos, posicoes) do
    nos
    |> Enum.filter(&is_integer(&1.community))
    |> Enum.group_by(& &1.community)
    |> Enum.sort()
    |> Enum.map(fn {c, membros} ->
      pontos =
        for n <- membros,
            {x, y} = Map.fetch!(posicoes, n.id),
            r = raio(n) + 10,
            k <- 0..7 do
          a = k * :math.pi() / 4
          {x + r * :math.cos(a), y + r * :math.sin(a)}
        end

      casca = envoltoria(pontos)

      # A letra fica acima do ponto mais alto do contorno.
      {c, Enum.map_join(casca, " ", fn {x, y} -> "#{num(x)},#{num(y)}" end),
       Enum.min_by(casca, &elem(&1, 1))}
    end)
  end

  # Andrew (monotone chain): a envoltória no sentido anti-horário.
  defp envoltoria(pontos) do
    ordenados = pontos |> Enum.uniq() |> Enum.sort()
    inferior = metade(ordenados)
    superior = metade(Enum.reverse(ordenados))
    Enum.drop(inferior, -1) ++ Enum.drop(superior, -1)
  end

  defp metade(pontos) do
    pontos
    |> Enum.reduce([], fn p, pilha -> [p | podar(pilha, p)] end)
    |> Enum.reverse()
  end

  defp podar([b, a | resto] = pilha, p) do
    if giro(a, b, p) <= 0, do: podar([a | resto], p), else: pilha
  end

  defp podar(pilha, _p), do: pilha

  defp giro({ax, ay}, {bx, by}, {px, py}), do: (bx - ax) * (py - ay) - (by - ay) * (px - ax)

  # ── textos da tela, em inglês: não traduzir de volta ────────────────────────

  defp por_nome(pessoas), do: Enum.sort_by(pessoas, &{String.downcase(&1.name), &1.id})

  defp rotulo_do_svg(rede, pessoas, arestas),
    do:
      "Weighted graph of the #{rede} network: #{pessoas} #{pessoas(pessoas)} named, " <>
        "#{arestas} links drawn. The same content is in the list."

  defp titulo(%{community: c} = p) when is_integer(c) do
    "#{p.name} · community #{letra(c)} · linked to #{p.degree} #{pessoas(p.degree)} · " <>
      "#{p.out_people} links out, #{p.in_people} in · #{intermediacao(p.betweenness)}"
  end

  defp titulo(p) do
    "#{p.name} · linked to #{p.degree} #{pessoas(p.degree)} · #{p.out_people} links out, " <>
      "#{p.in_people} in · #{intermediacao(p.betweenness)}"
  end

  # 3.7.3: o nó sem nome diz só quantas pessoas contém.
  defp titulo_do_agregado(g), do: "#{g.size} people outside your reach. No names."

  defp rotulo_do_agregado(%{community: c, size: n}) when is_integer(c),
    do: "People outside your reach — community #{letra(c)} (#{n})"

  defp rotulo_do_agregado(%{community: :other, size: n}),
    do: "People outside your reach — other communities (#{n})"

  defp rotulo_do_agregado(%{community: :gone, size: n}),
    do: "People no longer in the platform (#{n})"

  defp rotulo_do_agregado(%{size: n}), do: "People outside your reach (#{n})"

  # Em % de caminhos, sem casa decimal (3.0.6); abaixo de 1%, dito assim, e não arredondado a 0.
  defp intermediacao({:ok, v}) when v == 0, do: "on no shortest path between others"

  defp intermediacao({:ok, v}) when v < 0.01,
    do: "on under 1% of the shortest paths between others"

  defp intermediacao({:ok, v}), do: "on #{round(v * 100)}% of the shortest paths between others"
  defp intermediacao({:ausente, :network_too_small}), do: "not calculated: fewer than 3 people"
  defp intermediacao({:ausente, _}), do: "not calculated in this reading"

  # FR-035: a proximidade dita como distância média até quem a pessoa alcança, e quantas — nunca
  # 1/proximidade.
  defp proximidade(%{distance_mean: {:ok, %{mean: m, reaches: r}}}),
    do: "reaches #{r} #{pessoas(r)}, in #{num(m)} steps on average"

  defp proximidade(_p), do: "not calculated in this reading"

  # A posição em frase, da regra da base (T046); a de outra pessoa só com escopo concedido (DS1).
  defp posicao({:ok, papel}), do: "#{papel.label}. #{papel.sentence}"

  defp posicao({:recortado, _}),
    do: "shown only to those granted a scope that reaches this person"

  defp posicao({:ausente, :network_too_small_for_roles}),
    do: "not described: the network is below the minimum size for positions"

  defp posicao(_), do: "not calculated in this reading"

  # O autovetor como está na leitura, de 0 a 1 com duas casas: comparável só dentro do grupo
  # (componente). A escala 0–100 relativa ao maior do protótipo não é usada: com alcance
  # parcial, o 100 poderia ser de alguém de fora, e diria onde ele está (R1).
  defp autovetor({:ok, v}),
    do: "#{:erlang.float_to_binary(v * 1.0, decimals: 2)} (comparable only within its group)"

  defp autovetor({:ausente, :did_not_converge}),
    do: "not calculated: the calculation did not settle"

  defp autovetor(_), do: "not calculated in this reading"

  # Os verbos dizem o que a aresta liga, e só isso (D1): na designação, quem abriu a issue e quem
  # é responsável por ela, nunca quem designou.
  defp verbo_saida("review"), do: "reviewed"
  defp verbo_saida("assignment"), do: "opened"
  defp verbo_entrada("review"), do: "was reviewed"
  defp verbo_entrada("assignment"), do: "assignee of"

  defp saida(%{out_people: 0}, _rede), do: "none in this window"

  defp saida(p, "review"),
    do:
      "#{plural(p.out_weight, "change request", "change requests")} of " <>
        "#{p.out_people} #{pessoas(p.out_people)}"

  defp saida(p, "assignment"),
    do:
      "#{plural(p.out_weight, "issue", "issues")} assigned to " <>
        "#{p.out_people} #{pessoas(p.out_people)}"

  defp entrada(%{in_people: 0}, _rede), do: "none in this window"

  defp entrada(p, "review"),
    do:
      "on #{plural(p.in_weight, "change request", "change requests")}, by " <>
        "#{p.in_people} #{pessoas(p.in_people)}"

  defp entrada(p, "assignment"),
    do:
      "#{plural(p.in_weight, "issue", "issues")} opened by " <>
        "#{p.in_people} #{pessoas(p.in_people)}"

  defp unidade("review"), do: "reviews"
  defp unidade("assignment"), do: "issues"

  defp ligacoes(id, arestas, nos) do
    saem = for a <- arestas, a.from == id, do: "→ #{nome(Map.fetch!(nos, a.to))} (#{a.weight})"
    chegam = for a <- arestas, a.to == id, do: "← #{nome(Map.fetch!(nos, a.from))} (#{a.weight})"

    case saem ++ chegam do
      [] -> "no link drawn"
      partes -> Enum.join(partes, ", ")
    end
  end

  defp nome(%{kind: :person, name: n}), do: n
  defp nome(g), do: rotulo_do_agregado(g)

  defp sem_desenho(:network_too_large_for_platform),
    do: "not drawn: the network is above the size the platform draws; the list has every person"

  defp sem_desenho(_), do: "not drawn in this reading; the list has every person"

  defp pessoas(1), do: "person"
  defp pessoas(_), do: "people"

  defp plural(1, um, _), do: "1 #{um}"
  defp plural(n, _, varios), do: "#{n} #{varios}"
end
