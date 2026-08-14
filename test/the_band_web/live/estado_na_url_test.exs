defmodule TheBandWeb.EstadoNaUrlTest do
  @moduledoc """
  Busca, ordenação e página vivem no endereço (issue #292).

  ## O que estes testes medem, e o que não bastaria

  Conferir que a tela ordena depois de clicar mediria o clique, e o clique já funcionava antes
  desta feature — o estado morava no socket. O que muda aqui é o que sobrevive a **abrir o
  endereço de novo**: é isso que recarregar faz, e é isso que quem recebe o link faz.

  Por isso cada teste abre a URL diretamente, sem passar pelo clique.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "o endereço carrega o que ele diz" do
    test "abrir com ?q= já mostra o resultado da busca", ctx do
      issue(ctx, 99_999, "agulha no palheiro")

      {:ok, _live, html} = live(ctx.conn, ~p"/work?q=agulha")

      assert html =~ "agulha no palheiro", """
      Abrir o endereço com a busca não trouxe o resultado.

      Quem recarrega a página perde o que digitou, e o link que alguém mandou abre outra coisa
      — que é exatamente o que a issue #292 descreve.
      """
    end

    test "abrir com ?ordem= já vem ordenado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work?ordem=number&dir=desc")

      # A seta na coluna é o que a tela mostra sobre a ordenação vigente.
      assert html =~ "↓", "a tela não indica que está ordenada por número, decrescente"
    end

    test "abrir com ?pagina= já vem na página pedida", ctx do
      for n <- 1..60, do: issue(ctx, 90_000 + n, "issue #{n}")

      {:ok, _live, html} = live(ctx.conn, ~p"/work?pagina=2")

      assert html =~ ~s(aria-current="page"), "a paginação não marcou a página vigente"
    end

    test "o clique escreve no endereço, e não só no socket", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/work")

      live |> form("form[phx-change=buscar]", %{"q" => "agulha"}) |> render_change()

      assert_patched(live, ~p"/work?q=agulha")
    end
  end

  describe "parâmetro inválido é dito" do
    test "coluna que a tabela não ordena", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work?ordem=inexistente")

      assert html =~ "is not available on this table", """
      Uma ordenação desconhecida foi ignorada em silêncio.

      Quem mandou o link acredita que a outra pessoa está vendo a lista ordenada como ele pediu.
      Ordenar por outra coisa sem dizer é pior do que recusar.
      """
    end

    test "direção que não é asc nem desc mantém a coluna, e avisa", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work?ordem=number&dir=deitado")

      assert html =~ "is not one of asc or desc"
      # A coluna pedida é respeitada: quem mandou o link pediu por ela.
      assert html =~ "↑"
    end

    test "página que não é número", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work?pagina=abc")

      assert html =~ "is not a page number"
    end

    test "parâmetro inválido não derruba a tela", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/work?ordem=%20&dir=&pagina=-3&q=")

      assert html =~ "Work"
    end
  end

  describe "os estados convivem no mesmo endereço" do
    test "o filtro de repositório sobrevive à busca", ctx do
      issue(ctx, 99_998, "agulha filtrada")
      repo = ctx.cenario.observed_repository_id

      {:ok, live, _html} = live(ctx.conn, ~p"/work?repositorio=#{repo}")

      live |> form("form[phx-change=buscar]", %{"q" => "agulha"}) |> render_change()

      # Comparados como parâmetros, e não como texto: a ordem deles no endereço não é contrato,
      # e afirmar sobre ela faria o teste quebrar por reordenação sem nada ter piorado.
      assert parametros(assert_patch(live)) == %{"repositorio" => repo, "q" => "agulha"}
    end

    test "o endereço fica limpo quando nada foi escolhido", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/work?q=agulha")

      live |> form("form[phx-change=buscar]", %{"q" => ""}) |> render_change()

      # Sem `?q=&pagina=1&ordem=`: parâmetro no padrão sugere escolha que ninguém fez.
      assert_patched(live, ~p"/work")
    end
  end

  describe "a página do repositório segue a mesma regra" do
    test "abrir com busca e ordem já vem aplicado", ctx do
      issue(ctx, 99_997, "agulha do repositório")
      repo = ctx.cenario.observed_repository_id

      {:ok, _live, html} =
        live(ctx.conn, ~p"/work/repositories/#{repo}?q=agulha&ordem=number&dir=desc")

      assert html =~ "agulha do repositório"
      assert html =~ "↓"
    end

    test "ordenação desconhecida é dita, e não ignorada", ctx do
      repo = ctx.cenario.observed_repository_id

      {:ok, _live, html} = live(ctx.conn, ~p"/work/repositories/#{repo}?ordem=inexistente")

      assert html =~ "is not available on this table"
    end
  end

  defp parametros(caminho), do: caminho |> URI.parse() |> Map.get(:query) |> URI.decode_query()

  defp issue(ctx, numero, titulo) do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: numero,
        title: titulo,
        state: "OPEN",
        issue_type: "Task",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{numero}"
      })

    issue
  end
end
