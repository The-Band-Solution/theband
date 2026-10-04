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

  test "nomes escritos só nos marcados; o agregado diz só quantos contém" do
    html = render_grafo()

    escritos = textos(html, "svg text.major")
    assert "Ana" in escritos
    assert @fo in textos(html, "svg text.minor")
    refute @fo in escritos

    assert textos(html, "#g-n-outside-1 title") == ["4 people outside your reach. No names."]
    assert "People outside your reach — community 2 (4)" in textos(html, "svg text")
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
    assert textos(html, "#g-lista td[data-label=links]") |> hd() =~ "links out"

    sem = render_grafo(%{grafo() | layout: {:ausente, :network_too_large_for_platform}})
    assert Enum.empty?(q(sem, "svg circle"))
    assert Enum.count(q(sem, "#g-lista tbody tr")) == 4
    assert textos(sem, "#g-sem-desenho") |> hd() =~ "not drawn"
  end
end
