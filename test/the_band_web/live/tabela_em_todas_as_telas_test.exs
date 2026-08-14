defmodule TheBandWeb.TabelaEmTodasAsTelasTest do
  @moduledoc """
  O componente de tabela, provado na primeira tela que passou a usá-lo.

  A feature 017 escreveu *"toda tabela tem search, ordenação por coluna e paginação"* e o
  sprint 014 cortou "as tabelas menores", com o destino escrito: **quando alguém precisar
  procurar nelas**. Alguém precisou — a página de uma pessoa com 350 issues designadas.

  O teste abre o endereço **direto**, sem passar por clique: o clique já funcionava nas duas
  telas que tinham o comportamento. O que se prova aqui é que ele sobrevive a recarregar, que
  é o que quem recebe o link faz.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, source_attrs("U_alvo", %{name: "Alvo", login: "alvo"}))

    # Três issues com títulos distintos, para que a busca tenha o que separar e a ordenação
    # tenha o que inverter.
    for {numero, titulo} <- [{10, "agulha no palheiro"}, {20, "outra coisa"}, {30, "terceira"}] do
      {:ok, issue} =
        WorkItems.record_collected_issue(tenant, %{
          observed_repository_id: cenario.observed_repository_id,
          number: numero,
          title: titulo,
          state: "OPEN",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "I_#{numero}",
          collected_at: DateTime.utc_now(:second),
          last_observed_at: DateTime.utc_now(:second)
        })

      {:ok, _} =
        WorkItems.replace_assignees(tenant, issue.id, [
          %{login: "alvo", person_id: pessoa.id}
        ])
    end

    %{conn: log_in(conn, user), tenant: tenant, pessoa: pessoa}
  end

  # Os parâmetros do endereço para onde a tela navegou, como mapa.
  #
  # Mapa, e não texto: a ordem em que a query string sai é detalhe de codificação, e um teste
  # que a fixa reprova por mudança que não muda o que a tela faz.
  defp parametros(live) do
    assert_patch(live)
    |> URI.parse()
    |> Map.get(:query)
    |> URI.decode_query()
  end

  # Os números da coluna `#`, na ordem em que a tela os desenhou.
  #
  # **Não** `:binary.match/2` sobre o HTML inteiro: "30" aparece dentro de UUID e de data, e a
  # posição encontrada dependia do identificador sorteado — o teste passava ou falhava por
  # sorte, e era exatamente a L46 escrita de novo. Aqui a extração é da célula.
  defp numeros(html) do
    ~r{data-label="#"[^>]*>\s*(\d+)\s*<}
    |> Regex.scan(html)
    |> Enum.map(fn [_, n] -> String.to_integer(n) end)
  end

  describe "a página da pessoa passou a buscar, ordenar e paginar" do
    test "o endereço com busca já abre buscado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?q=agulha")

      assert html =~ "agulha no palheiro"

      refute html =~ "outra coisa", """
      Abrir `?q=agulha` tem de trazer a tela já buscada. Enquanto o estado morava no socket,
      o endereço abria a lista inteira e quem recebeu o link via outra coisa.
      """
    end

    test "o endereço com ordenação já abre ordenado", ctx do
      {:ok, _live, crescente} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?ordem=number&dir=asc")

      {:ok, _live, decrescente} =
        live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?ordem=number&dir=desc")

      assert numeros(crescente) == [10, 20, 30]

      assert numeros(decrescente) == [30, 20, 10], """
      `dir=desc` tem de inverter a ordem no HTML, e não só no parâmetro. Uma tela que aceita o
      parâmetro e ordena igual é pior que uma que recusa: quem mandou o link acredita que a
      outra pessoa vê o que ele pediu.
      """
    end

    test "coluna não ordenável é dita, e a tela não cai", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?ordem=inexistente")

      assert html =~ "agulha no palheiro", "a tela precisa continuar de pé"
    end

    test "página inválida não derruba a tela", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?pagina=abc")

      assert html =~ "agulha no palheiro"
    end

    test "buscar pela tela muda o endereço, e não só o socket", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      html =
        live
        |> form("form[phx-change=buscar]", %{"q" => "agulha"})
        |> render_change()

      assert html =~ "agulha no palheiro"
      refute html =~ "outra coisa"

      assert_patched(live, ~p"/people/#{ctx.pessoa.id}?q=agulha")
    end

    test "a contagem exibida é a da busca, não a do total", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?q=agulha")

      assert html =~ "1–1 of 1", """
      Paginar sobre o total afirmaria páginas que a busca não tem. A contagem da faixa vem da
      busca vigente; o número do cartão, que diz quantas issues a pessoa tem, não muda.
      """
    end
  end

  describe "as listas de pessoas e equipes seguem a mesma regra" do
    test "/people abre buscado pelo endereço", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people?q=alvo")

      assert html =~ "Alvo"
      assert html =~ "search in name and login"
    end

    test "/people ordena por clique na coluna", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/people")

      ordenado = live |> element("th button[phx-value-campo=name]") |> render_click()

      assert ordenado =~ "↑"
      assert parametros(live) == %{"ordem" => "name", "dir" => "asc"}
    end

    test "/teams abre buscado pelo endereço, e a tela não cai com parâmetro inválido", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams?q=nada&ordem=inexistente&pagina=abc")

      assert html =~ "search in name and slug", "a tela precisa continuar de pé"
    end

    test "/teams/:id ordena os integrantes por clique", ctx do
      organizacao = organization_fixture(ctx.tenant, "acme")
      equipe = team_fixture(ctx.tenant, "T_a", %{organization: organizacao})

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{equipe.id}")

      ordenado = live |> element("th button[phx-value-campo=name]") |> render_click()

      assert ordenado =~ "↑"
      assert parametros(live) == %{"ordem" => "name", "dir" => "asc"}
    end
  end
end
