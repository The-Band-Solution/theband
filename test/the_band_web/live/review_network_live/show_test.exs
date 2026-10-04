defmodule TheBandWeb.ReviewNetworkLive.ShowTest do
  @moduledoc """
  A tela da rede de revisão contra a régua do protótipo aprovado — feature 073, T021, T024, T026
  (`specs/073-rede-de-revisao/prototipo/PROMPT.md` §3, versão 2).

  Cada teste nomeia os itens da régua que confere. Os que não se verificam no HTML (cor, escala
  das barras, 360 px real, tons de cinza) ficam para a conferência do QA com a tela aberta;
  aqui se confere o que o HTML carrega: texto, ordem, marca com palavra, ausência nomeada,
  `data-label`, e o que **não** pode estar (1.20, 3.9, telas 6 e 7).

  Cenário: Zuleica Ana (fora do alcance de Lia) revisa 8 de Bia; Ciro revisa 4 de Bia; Bia revisa
  2 de Ciro — 14 revisões. Mais uma auto-revisão, uma de bot e uma de conta não ligada. Caio abriu
  e ninguém revisou. Lia é colega de Bia e Ciro na equipe X.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork
  alias TheBand.Tenants

  @login_de_fora "prestador-sem-pessoa-xyz"

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n * 86_400, :second)

  defp revisar(tenant, repo, revisor, autor, vezes) do
    for i <- 1..vezes do
      cr = solicitacao(tenant, repo, autor, dias_atras(20 + i))
      revisao(tenant, cr, revisor, dias_atras(19 + i))
    end
  end

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organizacao_com_repositorio(tenant)
    repo = org.observed_repository_id

    ana = pessoa(tenant, "Zuleica Ana")
    bia = pessoa(tenant, "Bia")
    ciro = pessoa(tenant, "Ciro")
    caio = pessoa(tenant, "Caio")
    lia = pessoa(tenant, "Lia")
    robo = pessoa(tenant, "Robo", "bot")

    revisar(tenant, repo, ana, bia, 8)
    revisar(tenant, repo, ciro, bia, 4)
    revisar(tenant, repo, bia, ciro, 2)

    propria = solicitacao(tenant, repo, ciro, dias_atras(10))
    revisao(tenant, propria, ciro, dias_atras(9))
    revisao(tenant, propria, robo, dias_atras(9))
    revisao(tenant, propria, {:login, @login_de_fora, "User"}, dias_atras(9))
    solicitacao(tenant, repo, caio, dias_atras(5))

    {:ok, _} = ReviewNetwork.compute(tenant, org.organization, DateTime.utc_now(:second))

    {:ok, equipe} = EO.create_declared_team(tenant, "X", admin.id)

    {:ok, papel} =
      EO.create_role(tenant, org.organization.id, %{code: "dev", name: "Dev"}, admin.id)

    for p <- [lia, bia, ciro] do
      {:ok, _} =
        EO.declare_team_membership(
          tenant,
          equipe.id,
          p.id,
          %{organizational_role_id: papel.id},
          admin.id
        )
    end

    {:ok, conta} =
      Tenants.create_user(tenant, %{
        "email" => "lia-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, conta} = Tenants.declare_person(tenant, conta.id, lia.id, admin.id)

    %{
      conn: conn,
      tenant: tenant,
      admin: admin,
      conta: conta,
      org: org,
      ana: ana,
      bia: bia,
      ciro: ciro,
      caio: caio
    }
  end

  defp abrir(ctx, user, query \\ "") do
    live(
      log_in(ctx.conn, user),
      "/organizations/#{ctx.org.organization.id}/review-network#{query}"
    )
  end

  # O texto visível de um seletor, sem as tags.
  defp texto(html, seletor) do
    html |> LazyHTML.from_fragment() |> LazyHTML.query(seletor) |> LazyHTML.text() |> espremer()
  end

  # O texto da página inteira, com o espaço normalizado: a quebra de linha do HEEx não é texto.
  defp plano(html), do: texto(html, "#review-network")

  defp espremer(texto), do: texto |> String.replace(~r/\s+/, " ") |> String.trim()

  describe "tela 1 — quem administra, 90 dias" do
    test "1.1–1.6: título, janelas na ordem com 90 escolhida, a frase da troca e a leitura",
         ctx do
      {:ok, _view, html} = abrir(ctx, ctx.admin)

      assert plano(html) =~ "Review network"
      assert plano(html) =~ "Is code review concentrated in a few people?"
      assert texto(html, "nav[aria-label=breadcrumb]") =~ "Organisations"

      janelas = texto(html, "#janelas [role=group]")
      assert janelas =~ ~r/30 days\s*90 days\s*180 days/
      assert texto(html, "#janelas a[aria-current=true]") =~ "90 days"

      assert plano(html) =~
               "Switching the window reads another stored reading. It computes nothing."

      leitura = texto(html, "#leitura")
      assert leitura =~ ~r/Reading of \d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC \(\d+ minutes ago\)/
      assert leitura =~ "computed when the last review collection ended. Window:"
      assert leitura =~ "90 days."

      assert leitura =~
               "Every number on this page is derived from the submitted reviews observed at the source"

      assert leitura =~ "observed"

      # 1.3: com uma organização só, a linha das organizações não aparece.
      refute plano(html) =~ "Observed organisation"
    end

    test "1.7, 1.8: três linhas de concentração, sem nome, com a contagem e a escala", ctx do
      {:ok, _view, html} = abrir(ctx, ctx.admin)
      concentracao = texto(html, "#concentracao")

      assert concentracao =~ "Concentration"
      assert concentracao =~ "derived"

      assert concentracao =~
               ~r/The person who reviewed most did\s*57% · 8 of 14 reviews.*The two people who reviewed most did\s*86% · 12 of 14 reviews.*The three people who reviewed most did\s*100% · 14 of 14 reviews/s

      assert concentracao =~ "0% · 50% · 100%"

      assert concentracao =~
               "No name here, for anyone. A review is one person reviewing one change request"

      for nome <- ["Zuleica", "Bia", "Ciro"], do: refute(concentracao =~ nome)
    end

    test "1.9–1.12: as contagens, quem não teve atividade, e os grupos", ctx do
      {:ok, _view, html} = abrir(ctx, ctx.admin)

      contagens = texto(html, "#contagens")
      assert contagens =~ ~r/reviews\s*14\s*person × change request/
      assert contagens =~ ~r/people who reviewed\s*3/
      assert contagens =~ ~r/people reviewed\s*2\s*had at least one change request reviewed/

      assert contagens =~
               "observed people of this organisation had no review activity in this window"

      grupos = texto(html, "#grupos")
      assert grupos =~ "Everyone in the network is linked by review, directly or through others."
      assert grupos =~ "Only people who gave or received at least one review are in a group."
    end

    test "1.13 e A15: exclusões contadas, explicadas, e nenhum login", ctx do
      {:ok, _view, html} = abrir(ctx, ctx.admin)
      exclusoes = texto(html, "#exclusoes")

      assert exclusoes =~ ~r/self-reviews\s*1/
      assert exclusoes =~ ~r/bot or app\s*1/
      assert exclusoes =~ ~r/not linked to a person\s*1/
      assert exclusoes =~ "or was deleted at the source"
      assert exclusoes =~ "Counted, never listed by account."

      refute html =~ @login_de_fora
      refute html =~ "Robo"
    end

    test "1.14–1.18 e FR-018a: a frase antes da tabela, ordem por nome, nenhuma ordenação", ctx do
      {:ok, _view, html} = abrir(ctx, ctx.admin)

      {antes, _} = :binary.match(html, "These counts do not assess a person")
      {tabela, _} = :binary.match(html, "id=\"tabela-pessoas\"")
      assert antes < tabela

      assert plano(html) =~
               "Ordered by name. No column sorts the list. Open a name to see their pairs."

      nomes =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("#tabela-pessoas td[data-label=person] button")
        |> Enum.map(&LazyHTML.text/1)
        |> Enum.map(&String.trim/1)

      assert nomes == ["Bia", "Caio", "Ciro", "Zuleica Ana"]

      refute html =~ "phx-click=\"sort"
      refute html =~ ~r/aria-sort|sortable/

      linha_bia = texto(html, "#pessoa-#{ctx.bia.id}")
      assert linha_bia =~ "reviewed 2, of 1 person"
      assert linha_bia =~ "was reviewed on 12, by 2 people"

      linha_caio = texto(html, "#pessoa-#{ctx.caio.id}")
      assert linha_caio =~ "no review by them in this window"
      assert linha_caio =~ "no review on their change requests in this window"
    end

    test "1.19, 1.20, 5.2, Q1: proveniência, o que não existe, e as células com o nome da coluna",
         ctx do
      {:ok, _view, html} = abrir(ctx, ctx.admin)

      rodape = texto(html, "#proveniencia")
      assert rodape =~ "review.network.edge v1"
      assert rodape =~ "review.network.parameters v1"
      assert rodape =~ "review.network.concentration.top_k_share v1"
      assert rodape =~ "Not on this page: export, ordering by a count, role labels for people."

      for proibido <- [
            ~r/export/i,
            ~r/top reviewer/i,
            ~r/\bhub\b/i,
            ~r/centrality/i,
            "<svg",
            "<canvas",
            ~r/download/i
          ] do
        refute String.replace(html, "Not on this page: export", "") =~ proibido
      end

      assert html =~ ~s(class="table stacked table-sm")
      assert html =~ ~s(data-label="person")
      assert html =~ ~s(data-label="reviewed")
      assert html =~ ~s(data-label="was reviewed")
    end

    test "1.4, R6: trocar a janela lê outra leitura e não enfileira nada", ctx do
      {:ok, view, _html} = abrir(ctx, ctx.admin)
      antes = Repo.aggregate(Oban.Job, :count)

      html = view |> element("#janelas a", "30 days") |> render_click()

      assert_patch(view, "/organizations/#{ctx.org.organization.id}/review-network?window=30")
      assert texto(html, "#janelas a[aria-current=true]") =~ "30 days"
      assert texto(html, "#leitura") =~ "30 days."
      assert Repo.aggregate(Oban.Job, :count) == antes
    end

    test "1.3: com duas organizações, um link por organização, a atual destacada", ctx do
      outra = organizacao_com_repositorio(ctx.tenant)
      {:ok, _view, html} = abrir(ctx, ctx.admin)

      assert plano(html) =~ "Observed organisation"
      assert texto(html, "#organizacoes a[aria-current=page]") =~ ctx.org.organization.login
      assert texto(html, "#organizacoes") =~ outra.organization.login
    end
  end

  describe "tela 2 — uma pessoa aberta" do
    test "2.1–2.4: os pares abrem no lugar, ordenados por nome, com o link do painel", ctx do
      {:ok, view, html} = abrir(ctx, ctx.admin)
      assert html =~ ~s(aria-expanded="false")

      html = view |> element("#pessoa-#{ctx.bia.id} button") |> render_click()

      assert html =~ ~s(aria-expanded="true")
      pares = texto(html, "#pares-#{ctx.bia.id}")
      assert pares =~ "Bia reviewed the change requests of"
      assert pares =~ "Ciro on 2"
      assert pares =~ "The change requests of Bia were reviewed by"
      assert pares =~ ~r/Ciro on 4.*Zuleica Ana on 8/s
      assert pares =~ "Ordered by name. The number is change requests in this window."
      assert html =~ ~s(href="/people/#{ctx.bia.id}")

      html = view |> element("#pessoa-#{ctx.caio.id} button") |> render_click()
      pares_caio = texto(html, "#pares-#{ctx.caio.id}")
      assert pares_caio =~ "reviewed nobody in this window"
      assert pares_caio =~ "nobody reviewed them in this window"
    end
  end

  describe "tela 3 — alcance parcial" do
    test "3.1–3.9, A4, A7: o recorte dito, sem nome de fora, sem contagem de fora", ctx do
      {:ok, view, html} = abrir(ctx, ctx.conta)

      aviso = texto(html, "#aviso-de-recorte")
      assert aviso =~ "This page shows only the people you reach."
      assert aviso =~ "the page does not say how much is outside it."
      refute aviso =~ "declared role"

      assert plano(html) =~ "Concentration among the people you reach"
      assert plano(html) =~ "Reviews in this window among the people you reach"
      assert plano(html) =~ "People you reach"
      assert plano(html) =~ "people you reach had no review activity in this window"
      assert plano(html) =~ "Groups that do not review each other among the people you reach"

      assert texto(html, "#grupos") =~
               "Everyone you reach with a review between them is linked, directly or through others: 2 people."

      exclusoes = texto(html, "#exclusoes")
      assert exclusoes =~ "they are shown only to those who reach everyone"
      refute exclusoes =~ ~r/\d/

      assert plano(html) =~
               "Each row shows the person's whole count in the window; the pairs show only people you reach."

      # A4: nem o nome, nem o login de quem está fora, em lugar nenhum.
      refute html =~ "Zuleica"
      refute html =~ ctx.ana.login

      html = view |> element("#pessoa-#{ctx.bia.id} button") |> render_click()
      pares = texto(html, "#pares-#{ctx.bia.id}")
      assert pares =~ "some pairs are outside your reach"
      assert pares =~ "Ciro on 4"
      refute pares =~ "on 8"
      refute html =~ "Zuleica"

      # A linha mostra o total verdadeiro de Bia (12), sem número do que ficou fora.
      assert texto(html, "#pessoa-#{ctx.bia.id}") =~ "was reviewed on 12, by 2 people"
      refute html =~ ~r/\d+ (reviews|pairs|people)[^.]* outside/
    end
  end

  describe "tela 4 — ausências" do
    test "4.2: abaixo de 10 revisões, nenhuma fração nem barra, e as contagens continuam", ctx do
      {:ok, _view, html} = abrir(ctx, ctx.conta)
      concentracao = texto(html, "#concentracao")

      assert concentracao =~ "too few reviews to speak of concentration: 6 of the 10 needed"

      assert concentracao =~
               "Below 10 reviews, one review more moves a share by more than ten points"

      refute concentracao =~ "%"
      assert texto(html, "#contagens") =~ ~r/reviews\s*6/
    end

    test "4.1: janela sem revisão — ausências nomeadas, nunca 0", ctx do
      vazia = organizacao_com_repositorio(ctx.tenant)
      solicitacao(ctx.tenant, vazia.observed_repository_id, ctx.caio, dias_atras(3))
      {:ok, _} = ReviewNetwork.compute(ctx.tenant, vazia.organization, DateTime.utc_now(:second))

      {:ok, _view, html} =
        live(
          log_in(ctx.conn, ctx.admin),
          "/organizations/#{vazia.organization.id}/review-network"
        )

      assert texto(html, "#concentracao") =~ "no review in this window"
      assert texto(html, "#concentracao") =~ "the page does not write 0%."
      assert texto(html, "#contagens") =~ "none in this window"
      refute texto(html, "#contagens") =~ ~r/reviews\s*0/
      assert texto(html, "#grupos") =~ "With no review there is no group to count."

      linha_caio = texto(html, "#pessoa-#{ctx.caio.id}")
      assert linha_caio =~ "no review by them in this window"
      assert linha_caio =~ "no review on their change requests in this window"
    end

    test "4.4: leitura não calculada — nenhum número, e a ausência é da plataforma", ctx do
      sem = organizacao_com_repositorio(ctx.tenant)

      {:ok, _view, html} =
        live(log_in(ctx.conn, ctx.admin), "/organizations/#{sem.organization.id}/review-network")

      aviso = texto(html, "#nao-calculada")
      assert aviso =~ "This reading has not been calculated yet."

      assert aviso =~
               "The platform calculates the 30, 90 and 180-day readings when a review collection for"

      assert aviso =~ "not calculated"
      refute html =~ "id=\"concentracao\""
      refute plano(html) =~ "%"
    end

    test "4.5 (Q3): coleta mais nova que a leitura é dita", ctx do
      Repo.update_all(
        from(r in "observed_repositories",
          where: r.id == type(^ctx.org.observed_repository_id, :binary_id)
        ),
        set: [changes_collected_at: DateTime.add(DateTime.utc_now(:second), 3600, :second)]
      )

      {:ok, _view, html} = abrir(ctx, ctx.admin)
      aviso = texto(html, "#coleta-mais-nova")

      assert aviso =~
               "after this reading. The reading was not refreshed. The numbers below are from"
    end

    test "4.6: de outro tenant é Not found; janela fora da lista volta para 90", ctx do
      {outro, _} = tenant_with_admin()
      de_fora = organizacao_com_repositorio(outro)

      assert {:error, {:live_redirect, %{to: "/organizations", flash: flash}}} =
               live(
                 log_in(ctx.conn, ctx.admin),
                 "/organizations/#{de_fora.organization.id}/review-network"
               )

      assert flash["error"] == "Not found."

      assert {:error, {:live_redirect, %{flash: inexistente}}} =
               live(
                 log_in(ctx.conn, ctx.admin),
                 "/organizations/#{Ecto.UUID.generate()}/review-network"
               )

      assert inexistente == flash
      refute inspect(flash) =~ ~r/permission/i

      assert {:error, {:live_redirect, %{to: destino}}} = abrir(ctx, ctx.admin, "?window=36500")
      assert destino == "/organizations/#{ctx.org.organization.id}/review-network?window=90"
    end
  end

  test "o aviso de leitura pronta faz a tela reler pela função de domínio", ctx do
    {:ok, view, _html} = abrir(ctx, ctx.conta)
    refute render(view) =~ "Zuleica"

    send(view.pid, {:review_network_ready, ctx.org.organization.id, []})
    html = render(view)

    assert plano(html) =~ "People you reach"
    refute html =~ "Zuleica"
  end

  test "1.1: a página das organizações leva à rede de revisão de cada uma", ctx do
    {:ok, _view, html} = live(log_in(ctx.conn, ctx.admin), "/organizations")
    assert html =~ ~s(href="/organizations/#{ctx.org.organization.id}/review-network")
  end
end
