defmodule TheBandWeb.NetworkAnalysisLive.IndexTest do
  @moduledoc """
  A área Network analysis — feature 076, T019 (US1, cen. 4 e 5; protótipo aprovado, §3, Tela 1;
  `contracts/tela.md`).

  Dois tenants: o primeiro com duas organizações observadas, o segundo com uma. Quem consulta o
  primeiro escolhe entre as duas dele, e nenhuma do outro tenant aparece. Com uma organização só,
  a área abre direto nela.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBandWeb.NetworkAnalysisLive.Shared

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    a = organizacao_com_repositorio(tenant, "org-a-#{System.unique_integer([:positive])}")
    b = organizacao_com_repositorio(tenant, "org-b-#{System.unique_integer([:positive])}")

    {outro, admin_outro} = tenant_with_admin()
    c = organizacao_com_repositorio(outro, "org-c-#{System.unique_integer([:positive])}")
    pessoa(outro, "Somente Do Outro Tenant")

    %{conn: conn, admin: admin, a: a, b: b, admin_outro: admin_outro, c: c}
  end

  defp texto(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#network-analysis")
    |> LazyHTML.text()
    |> String.replace(~r/\s+/, " ")
  end

  test "3.1: título, as duas arestas em palavras, seis cartões e a frase de não-avaliação", ctx do
    {:ok, _view, html} = live(log_in(ctx.conn, ctx.admin), ~p"/network-analysis")
    t = texto(html)

    assert t =~ "Network analysis"
    assert t =~ "Read the links between people as a network."
    assert t =~ "The arrow goes from the reviewer to the author."
    assert t =~ "The arrow goes from the author of the issue to the assignee."
    assert t =~ "It does not say who made the assignment, nor who did the work."

    paginas =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#paginas li[data-page]")
      |> LazyHTML.attribute("data-page")

    assert paginas == ~w(review graph communities hubs distance positions)
    assert t =~ "They do not assess anyone"

    # D1: nenhum dos dois nomes que a aresta não observa.
    refute t =~ ~r/collaborat/i
    refute t =~ ~r/delegat/i
  end

  test "com duas organizações, escolhe-se entre as do tenant, e nenhuma do outro aparece", ctx do
    {:ok, _view, html} = live(log_in(ctx.conn, ctx.admin), ~p"/network-analysis")

    escolhas =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#organizacoes a[data-organization]")
      |> LazyHTML.attribute("data-organization")

    # A medida mediu alguma coisa antes de qualquer refute.
    assert Enum.sort(escolhas) == Enum.sort([ctx.a.organization.id, ctx.b.organization.id])
    assert html =~ ctx.a.organization.login

    refute ctx.c.organization.id in escolhas
    refute html =~ ctx.c.organization.login
    refute html =~ "Somente Do Outro Tenant"
  end

  test "com uma organização só, a área abre direto nela", ctx do
    destino = "/network-analysis/#{ctx.c.organization.id}"

    assert {:error, {:live_redirect, %{to: ^destino}}} =
             live(log_in(ctx.conn, ctx.admin_outro), ~p"/network-analysis")
  end

  describe "o cabeçalho de toda página de análise" do
    setup ctx do
      agora = DateTime.utc_now(:second)

      leitura = %{
        reach: :total,
        computed_at: agora,
        window_start: DateTime.add(agora, -90 * 86_400, :second),
        window_end: agora,
        window_days: 90,
        newer_collection: :nenhuma
      }

      atributos = %{
        title: "Graph",
        question: "Who is linked to whom, and who sits between groups?",
        page: :review,
        organization: ctx.a.organization,
        selection: %{network: "assignment", window: 90},
        options: %{
          networks: %{allowed: ["review", "assignment"], default: "review"},
          windows: %{allowed: [30, 90, 180], default: 90},
          views: %{allowed: ["weighted", "communities"], default: "weighted"}
        },
        reading: leitura
      }

      %{atributos: atributos}
    end

    test "a linha da leitura leva a marca derived, em texto, junto dos números", ctx do
      html = render_component(&Shared.header/1, ctx.atributos)
      doc = LazyHTML.from_fragment(html)

      leitura = doc |> LazyHTML.query("#leitura") |> LazyHTML.text()
      assert leitura =~ "derived"
      assert leitura =~ "observed"
      assert leitura =~ "90 days."

      assert doc |> LazyHTML.query(~s(#leitura [data-marca="derivado"])) |> Enum.count() == 1

      # 3.0.2: as duas arestas com a direção, a escolhida marcada.
      redes = doc |> LazyHTML.query("#redes") |> LazyHTML.text()
      assert redes =~ "reviewer → author of the change request"
      assert redes =~ "author of the issue → assignee"

      assert doc
             |> LazyHTML.query(~s(#redes a[aria-current="true"]))
             |> LazyHTML.attribute("data-network") ==
               ["assignment"]

      refute html =~ "aviso-de-alcance"
    end

    test "com alcance parcial, o aviso da US1, cen. 5", ctx do
      atributos = put_in(ctx.atributos, [:reading, :reach], :parcial)
      html = render_component(&Shared.header/1, atributos)

      aviso =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("#aviso-de-alcance")
        |> LazyHTML.text()
        |> String.replace(~r/\s+/, " ")

      assert aviso =~
               "Names appear only for the people you reach. Measures are computed over the " <>
                 "whole network. People outside your reach appear grouped, without names, and " <>
                 "only in groups of at least 3."
    end

    test "sem leitura, nenhum número e nenhuma marca de leitura", ctx do
      html = render_component(&Shared.header/1, %{ctx.atributos | reading: nil})
      refute html =~ ~s(id="leitura")
    end
  end
end
