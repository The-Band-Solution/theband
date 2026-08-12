defmodule TheBandWeb.StuckSyncTest do
  @moduledoc """
  A tela de sincronizações com a execução presa (T008, T009).

  ## A tela não é a defesa

  O botão só aparece onde a plataforma não consegue provar que o trabalho está vivo — mas a
  **decisão reconfere**. Entre desenhar o botão e alguém clicar, a coleta pode ter voltado a
  executar, e uma tela que confia no próprio botão decide com dado de segundos atrás.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Sources.ConnectedTool

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    %{conn: log_in(conn, user), tenant: tenant, user: user, tool: ferramenta(tenant)}
  end

  describe "a ação de encerrar" do
    test "aparece na execução presa e some depois de encerrada", ctx do
      presa(ctx)

      {:ok, live, html} = live(ctx.conn, ~p"/syncs")

      # A reconciliação roda ao carregar, então a execução já chega encerrada — e é o
      # comportamento: quem está olhando não espera cinco minutos.
      refute html =~ "Close stuck sync"
      assert render(live) =~ "interrupted"
    end

    test "trabalho que a fila vai pegar não recebe a ação", ctx do
      sync = presa(ctx)
      job(sync, "available")

      {:ok, _live, html} = live(ctx.conn, ~p"/syncs")

      refute html =~ "Close stuck sync", """
      A ação apareceu numa execução cujo trabalho a fila **vai** pegar.

      Encerrar aqui libera o índice e a coleta começa em paralelo com uma segunda — o defeito
      oposto ao da issue #175, e pior: o bloqueio não duplica número.
      """

      assert Ingestion.reload(sync).status == "running"
    end

    test "trabalho em execução recebe a ação, com o aviso do risco", ctx do
      sync = presa(ctx)
      job(sync, "executing")

      {:ok, _live, html} = live(ctx.conn, ~p"/syncs")

      assert html =~ "Close stuck sync", """
      A ação não apareceu para o caso que a feature existe para resolver: trabalho `executing`
      num nó que morreu. Aconteceu duas vezes, e a saída foi SQL.
      """

      assert html =~ "cannot tell whether the process", """
      O aviso precisa dizer o que a plataforma **não** sabe, e qual é o risco: se a coleta
      estiver de fato rodando, uma segunda começa em paralelo. Pedir "tem certeza?" sem
      informar é pedir confirmação de nada.
      """

      assert Ingestion.reload(sync).status == "running", "a tela não encerra ao desenhar"
    end

    test "a requisição direta é recusada mesmo sem botão na tela", ctx do
      sync = presa(ctx)
      job(sync, "available")

      {:ok, live, _html} = live(ctx.conn, ~p"/syncs")

      # O evento é disparado à mão, como faria quem inspeciona a página. É o SC-008a.
      html = render_click(live, "encerrar", %{"sync_id" => sync.id})

      assert html =~ "still has work running", """
      A recusa precisa vir da decisão, não do botão: sem ela, a tela seria a única defesa, e
      qualquer requisição direta derrubaria uma coleta viva.
      """

      assert Ingestion.reload(sync).status == "running"
    end

    test "execução de outro tenant não é alcançada", ctx do
      outro = tenant_fixture()
      ferramenta_outro = ferramenta(outro)

      {:ok, sync_alheia} =
        %Sync{}
        |> Sync.changeset(%{
          tenant_id: outro.id,
          connected_tool_id: ferramenta_outro.id,
          status: "running",
          started_at: DateTime.add(DateTime.utc_now(:second), -600, :second)
        })
        |> Repo.insert()

      {:ok, live, _html} = live(ctx.conn, ~p"/syncs")
      html = render_click(live, "encerrar", %{"sync_id" => sync_alheia.id})

      assert html =~ "not found", """
      A mensagem precisa ser **não encontrado**, nunca "sem permissão": confirmar existência
      já é vazamento entre tenants.
      """

      refute html =~ "permission"
    end
  end

  describe "quem encerrou" do
    test "a plataforma aparece por extenso, e a pessoa pelo nome", ctx do
      presa(ctx)
      {:ok, _live, html_plataforma} = live(ctx.conn, ~p"/syncs")

      assert html_plataforma =~ "the platform", """
      A execução foi encerrada pela plataforma, e a tela não disse isso.

      O autor nulo **afirma** "não foi pessoa" — a plataforma sabe disso. Exibir travessão
      diria "não se sabe quem", que é outra coisa, e é o que o design system proíbe.
      """

      # Agora uma encerrada por pessoa, com o trabalho ausente.
      outra = ferramenta(ctx.tenant, "outra-org")
      sync = presa(%{ctx | tool: outra})
      {:ok, _} = Ingestion.interrupt_sync(ctx.tenant, sync.id, ctx.user)

      {:ok, _live, html} = live(ctx.conn, ~p"/syncs")

      # Os parênteses importam: `=~` liga mais forte que `||`, e sem eles a expressão vira
      # `(html =~ nil) || email` — que levanta quando `name` é nulo, e é o caso do fixture.
      assert html =~ (ctx.user.name || ctx.user.email)
    end

    test "a célula de quem encerrou nunca é um travessão", ctx do
      presa(ctx)

      {:ok, _live, html} = live(ctx.conn, ~p"/syncs")

      [bloco] = Regex.run(~r/closed by.{0,200}/s, html)

      refute bloco =~ "—" and not (bloco =~ "the platform"), """
      A tela mostrou travessão onde deveria nomear quem encerrou.

      Ausência é nomeada: `the platform` quando foi automático, o nome quando foi pessoa.
      """
    end

    test "o motivo aparece em texto, ao lado de quem encerrou", ctx do
      presa(ctx)

      {:ok, _live, html} = live(ctx.conn, ~p"/syncs")

      assert html =~ "o processo que a executava não existe mais", """
      O motivo precisa estar visível: sem ele, quem lê não sabe se tenta de novo. E ele
      distingue falha do momento de falha permanente — a L29.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp presa(ctx) do
    {:ok, sync} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: ctx.tenant.id,
        connected_tool_id: ctx.tool.id,
        status: "running",
        started_at: DateTime.add(DateTime.utc_now(:second), -600, :second)
      })
      |> Repo.insert()

    sync
  end

  defp job(%Sync{id: sync_id}, estado) do
    Repo.insert!(%Oban.Job{
      state: estado,
      queue: "ingestion",
      worker: "TheBand.Jobs.SyncGitHubEO",
      args: %{"sync_id" => sync_id, "tenant_id" => Ecto.UUID.generate()},
      attempt: 1,
      max_attempts: 5,
      attempted_at: DateTime.utc_now(),
      scheduled_at: DateTime.utc_now()
    })
  end

  defp ferramenta(tenant, login \\ "acme") do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: login
      })
      |> Repo.insert()

    tool
  end
end
