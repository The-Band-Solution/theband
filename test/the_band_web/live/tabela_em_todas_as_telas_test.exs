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
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}?ordem=number&dir=desc")

      posicao_30 = :binary.match(html, "30") |> elem(0)
      posicao_10 = :binary.match(html, "10") |> elem(0)

      assert posicao_30 < posicao_10, """
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
end
