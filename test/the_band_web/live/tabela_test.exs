defmodule TheBandWeb.TabelaTest do
  @moduledoc """
  A tabela que busca, ordena e pagina (feature 017).

  ## O caso que separa busca de filtro visual

  Filtrar as linhas exibidas parece busca. O teste procura por algo que **não está na primeira
  página** — é ali que a diferença aparece, e é ali que a versão fácil mente.

  ## E o que separa painel de listagem

  Os painéis de cima respondem *"o que a plataforma sabe deste escopo"*. Filtrá-los pela busca faria
  os números mudarem enquanto alguém digita, e quem lesse concluiria que a plataforma esqueceu o
  resto. **Só a listagem filtra.**
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

  describe "a busca" do
    test "alcança o que a página não mostra", ctx do
      agulha(ctx)

      {:ok, live, html} = live(ctx.conn, ~p"/work")
      refute html =~ "agulha no palheiro", "o cenário não montou o caso"

      resultado = live |> form("form[phx-change=buscar]", %{"q" => "agulha"}) |> render_change()

      assert resultado =~ "agulha no palheiro", """
      A busca não alcançou uma linha fora da página exibida.

      É o que acontece quando se filtra o que já foi carregado: quem procura recebe "nada
      encontrado" sem a tela ter como saber que mentiu.
      """
    end

    test "diz onde procura, e o que fazer quando não acha", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/work")

      assert html =~ "search in title and number", """
      A tela não diz onde a busca procura.

      Quem não encontra conclui que o dado não existe — quando talvez tenha procurado na coluna
      errada.
      """

      vazio =
        live |> form("form[phx-change=buscar]", %{"q" => "zzzznaoexiste"}) |> render_change()

      assert vazio =~ "No issue with"
      assert vazio =~ "zzzznaoexiste"
    end

    test "os painéis do topo não mudam com a busca", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/work")
      total_antes = Regex.run(~r/(\d+) issues collected/, html)

      depois = live |> form("form[phx-change=buscar]", %{"q" => "agulha"}) |> render_change()

      assert Regex.run(~r/(\d+) issues collected/, depois) == total_antes, """
      O painel do topo mudou junto com a busca.

      Ele responde "o que a plataforma sabe", e a listagem responde "quais destas eu procuro". Se o
      número encolhe enquanto alguém digita, quem lê conclui que a plataforma esqueceu o resto.
      """
    end
  end

  describe "a ordenação" do
    test "o cabeçalho ordena, e a direção aparece sem depender de cor", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/work")

      ordenado = live |> element("th button[phx-value-campo=title]") |> render_click()

      assert ordenado =~ "↑", "a direção não aparece como texto"
      assert ordenado =~ "sorted ascending"

      invertido = live |> element("th button[phx-value-campo=title]") |> render_click()
      assert invertido =~ "↓"
    end

    test "ordena pelo conceito, que não é coluna do banco", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/work")

      assert live |> element("th button[phx-value-campo=conceito]") |> render_click() =~ "↑", """
      A coluna do conceito não ordenou.

      Ele vem da promoção vigente — não existe como campo. Ordenar por ele é ordenar por resultado
      calculado, e era o caso que nenhuma biblioteca de tabela resolveria sozinha.
      """
    end
  end

  describe "a paginação" do
    test "mostra índices numerados quando há mais de uma página", ctx do
      for n <- 1..60, do: issue(ctx, n + 5_000, "issue de paginação #{n}")

      {:ok, _live, html} = live(ctx.conn, ~p"/work")

      assert html =~ ~s(aria-label="Pages")
      assert html =~ ~s(phx-value-n="2")
      assert html =~ ~s(aria-current="page")
    end

    test "uma página só não tem paginação", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams")

      refute html =~ ~s(aria-label="Pages"), """
      Uma tabela de uma página só ganhou paginação.

      Mostrar o índice `1` sozinho é dizer que há para onde ir quando não há.
      """
    end
  end

  defp agulha(ctx), do: issue(ctx, 99_999, "agulha no palheiro")

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
