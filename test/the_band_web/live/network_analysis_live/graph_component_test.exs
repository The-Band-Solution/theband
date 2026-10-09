defmodule TheBandWeb.NetworkAnalysisLive.GraphComponentTest do
  @moduledoc """
  O desenho do grafo em SVG, sem dado no navegador — feature 076, T032 (FR-020 a FR-025; R16;
  A7, A8, A9 de `seguranca.md`).

  - **A9**: nome `<script>alert(1)</script>` e `"><foreignObject>` saem escapados em `<text>` e
    `<title>`; nenhum elemento novo nasce deles;
  - **A7**: nenhum `data-*` com JSON, nenhum `push_event`/`pushEvent`; o hook só tem vista;
  - **A8**: não existe `handle_event` de destaque na página: o evento forjado não tem a quem
    chegar, e nenhum estado cresce com ele;
  - `style` não aparece; cor por classe; números com uma casa;
  - tamanho pelo grau, cor pela faixa, espessura pelo peso, seta pela direção; nomes escritos só
    nos marcados `labelled?`; o agregado diz só quantos contém.

  **Defeitos a injetar**, um por vez: `raw/1` no rótulo; passar a leitura num `data-graph`. Cada
  um reprova.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias TheBandWeb.NetworkAnalysisLive.GraphComponents

  @script "<script>alert(1)</script>"
  @fo ~s(\"><foreignObject>)

  defp pessoa(id, nome, grau, banda, labelled?, extra \\ %{}) do
    Map.merge(
      %{
        kind: :person,
        id: id,
        name: nome,
        degree: grau,
        out_people: grau,
        in_people: 1,
        out_weight: grau * 2,
        in_weight: 1,
        betweenness: {:ok, 0.03},
        band: banda,
        labelled?: labelled?,
        links_outside_reach?: false,
        community: nil
      },
      extra
    )
  end

  defp grafo do
    nos = [
      pessoa("p-ana", "Ana", 3, "2_to_5", true),
      pessoa("p-xss", @script, 1, "none", true, %{betweenness: {:ok, 0.0}}),
      pessoa("p-fo", @fo, 1, nil, false, %{betweenness: {:ausente, :network_too_small}}),
      %{kind: :outside, id: "outside-1", community: 2, size: 4}
    ]

    %{
      nodes: nos,
      edges: [
        %{from: "p-ana", to: "p-xss", weight: 5},
        %{from: "p-fo", to: "p-ana", weight: 1},
        %{from: "p-ana", to: "outside-1", weight: 2}
      ],
      components: {:ok, [4]},
      layout:
        {:ok,
         %{
           "p-ana" => {500.0, 500.0},
           "p-xss" => {200.0, 300.0},
           "p-fo" => {800.0, 700.0},
           "outside-1" => {300.0, 800.0}
         }},
      bands: [
        %{code: "none", label: "none"},
        %{code: "below_2", label: "<2%"},
        %{code: "2_to_5", label: "2–5%"},
        %{code: "5_to_10", label: "5–10%"},
        %{code: "10_or_more", label: "≥10%"}
      ]
    }
  end

  defp render_grafo(g \\ grafo()) do
    assigns = %{g: g}

    rendered_to_string(~H"""
    <GraphComponents.graph id="g" graph={@g} network="review" />
    """)
  end

  defp doc(html), do: LazyHTML.from_fragment(html)

  defp q(html, sel), do: html |> doc() |> LazyHTML.query(sel)

  defp textos(html, sel),
    do: html |> q(sel) |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  test "A9: os nomes saem escapados em <text> e <title>, sem elemento novo" do
    html = render_grafo()

    # Mediu: os nomes estão no desenho, como texto.
    assert @script in textos(html, "svg text")
    assert Enum.any?(textos(html, "svg title"), &String.starts_with?(&1, @fo))

    assert Enum.empty?(q(html, "script"))
    assert Enum.empty?(q(html, "foreignObject"))
    assert Enum.empty?(q(html, "foreignobject"))
    assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "A7: nenhum data-* com JSON, nenhum style, nenhum push_event no componente nem no hook" do
    html = render_grafo()

    atributos =
      html
      |> q("*")
      |> Enum.flat_map(&LazyHTML.attributes/1)
      |> Enum.flat_map(& &1)

    # Mediu: há atributos e os nós estão lá.
    assert Enum.count(q(html, "svg circle.nd")) == 4

    for {nome, valor} <- atributos, String.starts_with?(nome, "data-") do
      refute valor =~ ~r/[\{\[]/, "#{nome} carrega estrutura: #{String.slice(valor, 0, 80)}"
    end

    refute Enum.any?(atributos, fn {nome, _} -> nome == "style" end)

    fonte = File.read!("lib/the_band_web/live/network_analysis_live/graph_components.ex")
    refute fonte =~ ~r/\.pushEvent\(|\.handleEvent\(|push_event\(|raw\(/

    pagina = File.read!("lib/the_band_web/live/network_analysis_live/graph.ex")
    refute pagina =~ ~r/push_event\(/
  end

  test "A8: a página não tem handle_event de destaque" do
    Code.ensure_loaded!(TheBandWeb.NetworkAnalysisLive.Graph)
    refute function_exported?(TheBandWeb.NetworkAnalysisLive.Graph, :handle_event, 3)
  end

  test "tamanho pelo grau, cor pela faixa, espessura pelo peso, seta pela direção" do
    html = render_grafo()

    raio = fn id -> html |> q("#g-n-#{id}") |> LazyHTML.attribute("r") |> hd() end
    assert raio.("p-ana") == "10.2"
    assert raio.("p-xss") == "8.0"

    classe = fn id -> html |> q("#g-n-#{id}") |> LazyHTML.attribute("class") |> hd() end
    assert classe.("p-ana") =~ "fill-warning/45"
    assert classe.("p-xss") =~ "fill-base-200"
    assert classe.("p-fo") =~ "[stroke-dasharray:3_2]"

    larguras = html |> q("path.ed") |> LazyHTML.attribute("stroke-width")
    assert "2.9" in larguras
    assert "1.5" in larguras

    assert html |> q("path.ed") |> LazyHTML.attribute("marker-end") |> Enum.uniq() == [
             "url(#g-seta)"
           ]

    for v <- html |> q("svg circle.nd") |> LazyHTML.attribute("cx"),
        do: assert(v =~ ~r/^\d+\.\d$/)

    # A legenda em texto, com as faixas da base.
    legenda = html |> q("#g-legenda") |> LazyHTML.text()
    for rotulo <- ["none", "<2%", "2–5%", "5–10%", "≥10%"], do: assert(legenda =~ rotulo)
  end

  describe "a conferência da tela (T053)" do
    test "a legenda leva a marca derived, a escala do tamanho, e o 'not calculated' só se houver" do
      html = render_grafo()

      assert html |> q("#g-legenda [data-marca=derivado]") |> Enum.count() >= 1
      refute html |> q("#g-legenda") |> LazyHTML.text() =~ "(derived)"
      assert textos(html, ~s(#g-legenda ul[aria-label="node size"] li)) == ["1", "3"]
      assert html |> q("#g-legenda") |> LazyHTML.text() =~ "not calculated: fewer than 3 people"

      com_faixa =
        Enum.map(grafo().nodes, fn n ->
          if n[:band] == nil and n.kind == :person, do: %{n | band: "none"}, else: n
        end)

      refute render_grafo(%{grafo() | nodes: com_faixa}) |> q("#g-legenda") |> LazyHTML.text() =~
               "not calculated"
    end

    test "o cartão conta revisões recebidas como vezes, e o autovetor pequeno não vira 0.00" do
      g =
        Enum.map(grafo().nodes, fn
          %{id: "p-ana"} = n -> Map.merge(n, %{in_weight: 7, eigenvector: {:ok, 0.001}})
          n -> n
        end)

      texto = render_grafo(%{grafo() | nodes: g}) |> doc() |> LazyHTML.text()
      assert texto =~ "7 times on their change requests"
      refute texto =~ "on 7 change requests"
      assert texto =~ "under 0.01 (comparable only within its group)"
      refute texto =~ "0.00 (comparable"
    end

    test "nomes marcados próximos não se sobrepõem: o segundo vai para outro lado do nó" do
      g = grafo()

      perto = %{
        g
        | nodes: [
            pessoa("p-a", "Alessandra Longname", 3, "none", true),
            pessoa("p-b", "Bernardo Longname", 2, "none", true),
            # Dois nós distantes, sem rótulo, fixam a extensão: o enquadramento não afasta os dois.
            pessoa("p-c", "C", 1, "none", false),
            pessoa("p-d", "D", 1, "none", false)
          ],
          edges: [%{from: "p-a", to: "p-b", weight: 1}],
          layout:
            {:ok,
             %{
               "p-a" => {500.0, 500.0},
               "p-b" => {505.0, 502.0},
               "p-c" => {0.0, 0.0},
               "p-d" => {1000.0, 1000.0}
             }}
      }

      html = render_grafo(perto)

      # A caixa de cada rótulo pela mesma estimativa do componente (7,8 px por letra, 16 de altura).
      caixa = fn nome ->
        el = html |> q("svg text.major") |> Enum.find(&(LazyHTML.text(&1) =~ nome))
        [x] = el |> LazyHTML.attribute("x") |> Enum.map(&String.to_float/1)
        [y] = el |> LazyHTML.attribute("y") |> Enum.map(&String.to_float/1)
        w = String.length(LazyHTML.text(el) |> String.trim()) * 7.8

        x0 =
          case LazyHTML.attribute(el, "text-anchor") do
            ["middle"] -> x - w / 2
            ["start"] -> x
            ["end"] -> x - w
          end

        {x0, y - 16, w, 16}
      end

      {ax, ay, aw, ah} = caixa.("Alessandra")
      {bx, by, bw, bh} = caixa.("Bernardo")
      sobrepoe? = ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
      refute sobrepoe?
    end
  end

  test "nomes escritos só nos marcados; o agregado diz só quantos contém" do
    html = render_grafo()

    escritos = textos(html, "svg text.major")
    assert "Ana" in escritos
    assert @fo in textos(html, "svg text.minor")
    refute @fo in escritos

    assert textos(html, "#g-n-outside-1 title") == ["4 people outside your reach. No names."]
    assert "People outside your reach — community B (4)" in textos(html, "svg text")
  end

  test "o destaque é JS sobre classes, e a aresta leva as classes das duas pontas" do
    html = render_grafo()

    [foco] = html |> q("#g-n-p-ana") |> LazyHTML.attribute("phx-focus")
    assert foco =~ "#g-svg .e-p-ana"
    assert foco =~ "#g-side-p-ana"

    classes = html |> q("path.ed") |> LazyHTML.attribute("class")
    assert Enum.any?(classes, &(&1 =~ "e-p-ana" and &1 =~ "e-outside-1"))
  end

  test "o telefone tem a lista, com data-label, e sem posições o desenho some" do
    html = render_grafo()
    assert Enum.count(q(html, "#g-lista tbody tr")) == 4
    assert html |> q("#g-lista td") |> LazyHTML.attribute("data-label") |> Enum.all?(&(&1 != ""))
    assert textos(html, "#g-lista td[data-label=links]") |> hd() =~ ~r"\d+ links? out"

    sem = render_grafo(%{grafo() | layout: {:ausente, :network_too_large_for_platform}})
    assert Enum.empty?(q(sem, "svg circle"))
    assert Enum.count(q(sem, "#g-lista tbody tr")) == 4
    assert textos(sem, "#g-sem-desenho") |> hd() =~ "not drawn"
  end
end
