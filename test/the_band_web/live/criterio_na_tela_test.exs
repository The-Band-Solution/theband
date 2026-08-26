defmodule TheBandWeb.CriterioNaTelaTest do
  @moduledoc """
  As regras do critério de início **na tela** — feature 042, `FR-013` a `FR-017`.

  ## Por que estes casos existem

  Pedido da pessoa mantenedora: *"coloque essas regras nas telas para o usuário entender"*.

  Uma escala de precedência que decide um número e vive só na spec produz o efeito que esta
  casa combate: quem lê o número não sabe de onde ele veio, e quem discorda dele não sabe onde
  mexer.

  O caso que mais importa é a `SC-008` — **nenhum código de motivo é renderizado**. Afirmar
  que a frase está lá não prova que o código não está.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo

  @evento "ProjectV2ItemStatusChangedEvent"

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, projeto} = SPO.create_project(tenant, %{name: "Conecta Fapes"}, user.id)

    atividade(tenant, @evento, 5965)
    atividade(tenant, "AssignedEvent", 2172)

    {:ok, quadro} =
      TheBand.Projects.record_observed_project(tenant, %{
        connected_tool_id: cenario.tool.id,
        number: 1,
        title: "Delivery",
        closed: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_1",
        collected_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    {:ok, _} = SPO.link_board(tenant, projeto.id, quadro.id, user.id)

    %{
      conn: log_in(conn, user),
      tenant: tenant,
      tool_id: cenario.tool.id,
      user: user,
      projeto: projeto,
      quadro: quadro
    }
  end

  describe "a tela do projeto" do
    test "sem critério, a ausência é frase e diz o que fazer", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "No criterion declared"

      assert html =~ "no start instant", """
      **A FR-015.** A frase diz o CUSTO da ausência — sem ela, "nenhum critério declarado"
      parece configuração opcional em vez de bloqueio.
      """
    end

    test "os tipos vêm com volume, e nenhum recomendado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "5965 observed", """
      **A FR-012.** Mostrar volume é informar. Sem ele, escolher entre
      `ProjectV2ItemStatusChangedEvent` e `AssignedEvent` seria às cegas.
      """

      refute html =~ "recommended"
      refute html =~ "suggested"
    end

    test "declarar grava e a tela passa a dizer qual evento", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/projects")

      html =
        live
        |> form("form[phx-submit=declarar_criterio]", %{
          "project_id" => ctx.projeto.id,
          "event_type" => @evento
        })
        |> render_submit()

      assert html =~ "Start criterion declared"
      assert html =~ "Work starts when"
      assert html =~ @evento
    end

    test "avisa quais quadros vão IGNORAR a declaração — antes de gravar", ctx do
      {:ok, _} =
        SPO.declare_start_criterion(
          ctx.tenant,
          {:board, ctx.quadro.id},
          "AssignedEvent",
          ctx.user.id
        )

      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "board(s) will ignore this", """
      **A FR-014.** Ao declarar num projeto que tem quadros com critério próprio, a tela diz
      quais vão ignorar — ANTES de gravar. Depois seria informação inútil.
      """

      assert html =~ "Delivery", "e nomeia o quadro, senão quem lê não sabe onde mexer"
    end
  end

  describe "a tela do quadro" do
    test "explica POR QUE o desempate é a data do vínculo", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{ctx.quadro.id}")

      assert html =~ "most recently linked to the project", """
      **A FR-017.** Uma regra de precedência que ninguém entende é obedecida sem ser
      conferida — e esta decide de qual quadro o instante de início vem.
      """

      assert html =~ "does not pick one", """
      E diz o que acontece no empate: a plataforma NÃO escolhe. Sem isso, quem vê uma issue
      sem instante conclui que há defeito, e há decisão pendente.
      """
    end

    test "sem critério próprio, diz que vale o do projeto", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{ctx.quadro.id}")

      assert html =~ "No criterion of its own"

      # `project&#39;s`, e não `project's`: o LiveView escapa a apóstrofe. Procurar a forma
      # não escapada passaria a impressão de que a frase sumiu quando ela está lá.
      assert html =~ "follow the <strong>project&#39;s</strong>", """
      **A escala.** Quadro sem critério próprio não é quadro sem critério: vale o do projeto.
      Sem esta frase, quem lê conclui que precisa declarar em todo quadro.
      """
    end

    test "com critério próprio, diz que vence o do projeto", ctx do
      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, ctx.quadro.id}, @evento, ctx.user.id)

      {:ok, _live, html} = live(ctx.conn, ~p"/boards/#{ctx.quadro.id}")

      assert html =~ "wins over the project"
      assert html =~ @evento
    end
  end

  describe "o que a declaração alcança — T013" do
    test "sem critério, a contagem diz QUANTAS e por quê; declarar move o número", ctx do
      for _ <- 1..3, do: issue_no_quadro(ctx, ctx.quadro, @evento)

      {:ok, _live, antes} = live(ctx.conn, ~p"/projects")

      assert antes =~ "3 issues reached"

      assert antes =~ "have none because no criterion applies", """
      **A FR-009.** As três ausências são causas diferentes com ações diferentes. Somá-las
      num total produziria um número que ninguém sabe como reduzir.
      """

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      {:ok, _live, depois} = live(ctx.conn, ~p"/projects")

      assert depois =~ ~r{<strong>3</strong>\s*have a start instant}, """
      **Sem etapa de recálculo entre as duas leituras.** O instante é resolvido na leitura;
      se dependesse de um passo de materialização, declarar não mudaria nada até alguém
      lembrar de rodá-lo.
      """

      refute depois =~ "have none because no criterion applies"
    end

    test "evento declarado que a issue nunca teve é ausência PRÓPRIA", ctx do
      issue_no_quadro(ctx, ctx.quadro, "AssignedEvent")

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "the declared event was never observed", """
      **A terceira ausência.** Critério declarado e evento ausente não é "sem critério": a
      ação é coletar de novo, e não declarar outra vez.
      """

      refute html =~ "have none because no criterion applies"
    end
  end

  describe "as pendências de desambiguação — T019" do
    test "a linha nomeia a issue e os dois quadros, e some quando o empate é desfeito", ctx do
      outro = quadro(ctx, 2, "Discovery")
      {:ok, vinculo} = SPO.link_board(ctx.tenant, ctx.projeto.id, outro.id, ctx.user.id)

      # Empate exato: associação em lote produz `linked_at` iguais, e é o jeito natural de
      # povoar um projeto. Fixar a data evita depender de os dois caírem no mesmo segundo.
      empatar(ctx.projeto.id)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, ctx.quadro.id}, @evento, ctx.user.id)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, outro.id}, "AssignedEvent", ctx.user.id)

      issue_id = issue_no_quadro(ctx, ctx.quadro, @evento)
      item_no_quadro(ctx, issue_id, outro)
      titulo = titulo_da(ctx.tenant, issue_id)

      {:ok, _live, com_empate} = live(ctx.conn, ~p"/projects")

      assert com_empate =~ "Waiting on a decision"
      assert com_empate =~ titulo, "sem o título, quem administra não sabe qual issue resolver"
      assert com_empate =~ "Delivery"
      assert com_empate =~ "Discovery"

      assert com_empate =~ "does not pick one", """
      **A FR-008.** Escolher o primeiro faria o que a `FR-007` da feature 022 proíbe, num
      lugar onde ninguém procuraria.
      """

      {:ok, _} = SPO.unlink_board(ctx.tenant, vinculo.id, ctx.user.id)

      {:ok, _live, sem_empate} = live(ctx.conn, ~p"/projects")

      refute sem_empate =~ "Waiting on a decision", """
      Desfeito o empate, a pendência some. Uma lista que não esvazia deixa de ser lida.
      """
    end
  end

  describe "nenhum código de motivo na tela — SC-008" do
    test "nem no projeto, nem no quadro", ctx do
      {:ok, _live, projetos} = live(ctx.conn, ~p"/projects")
      {:ok, _live, quadros} = live(ctx.conn, ~p"/boards/#{ctx.quadro.id}")

      for html <- [projetos, quadros],
          codigo <- ~w(criterio_ambiguo sem_criterio evento_nao_coletado) do
        refute html =~ codigo, """
        **A SC-008.** `#{codigo}` é código de motivo, e a tela escreve frases.

        Um código obriga quem lê a procurar o que ele significa — e a frase, além de dizer o
        que houve, diz o que fazer.
        """
      end
    end
  end

  # Em lotes: o protocolo do PostgreSQL aceita 65.535 parâmetros por comando, e 5.965 linhas
  # de doze campos passam disso. O número precisa ser o real — a `FR-012` mostra volume, e
  # volume redondo de teste não prova que a tela sabe formatar o volume de verdade.
  defp atividade(tenant, tipo, quantas) do
    agora = DateTime.utc_now(:second)

    1..quantas
    |> Enum.map(fn n ->
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(tenant.id),
        internal_id: "#{tipo}-#{n}",
        activity_type: tipo,
        occurred_at: agora,
        subject_type: "issue",
        subject_id: Ecto.UUID.bingenerate(),
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "#{tipo}-#{n}",
        inserted_at: agora,
        updated_at: agora
      }
    end)
    |> Enum.chunk_every(2_000)
    |> Enum.each(&Repo.insert_all("spo_performed_project_activities", &1))
  end

  # ------------------------------------------------------------------ apoio

  defp quadro(ctx, numero, titulo) do
    {:ok, q} =
      TheBand.Projects.record_observed_project(ctx.tenant, %{
        connected_tool_id: ctx.tool_id,
        number: numero,
        title: titulo,
        closed: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_#{numero}",
        collected_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    q
  end

  # Uma issue já coletada, posta no quadro, com a atividade que o critério procura.
  defp issue_no_quadro(ctx, quadro, tipo_de_evento) do
    issue_id = proxima_issue(ctx)
    item_no_quadro(ctx, issue_id, quadro)
    atividade_da_issue(ctx.tenant, issue_id, tipo_de_evento)
    issue_id
  end

  defp proxima_issue(ctx) do
    usadas = Process.get(:issues_usadas, MapSet.new())

    id =
      Repo.one!(
        from i in "collected_issues",
          where: i.tenant_id == type(^ctx.tenant.id, :binary_id),
          where: i.id not in type(^MapSet.to_list(usadas), {:array, :binary_id}),
          limit: 1,
          select: type(i.id, :binary_id)
      )

    Process.put(:issues_usadas, MapSet.put(usadas, id))
    id
  end

  defp titulo_da(tenant, issue_id) do
    Repo.one!(
      from i in "collected_issues",
        where:
          i.tenant_id == type(^tenant.id, :binary_id) and i.id == type(^issue_id, :binary_id),
        select: i.title
    )
  end

  defp item_no_quadro(ctx, issue_id, quadro) do
    agora = DateTime.utc_now(:second)

    Repo.insert_all("project_items", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(ctx.tenant.id),
        observed_project_id: Ecto.UUID.dump!(quadro.id),
        collected_issue_id: Ecto.UUID.dump!(issue_id),
        is_draft: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{System.unique_integer([:positive])}",
        collected_at: agora,
        last_observed_at: agora,
        inserted_at: agora,
        updated_at: agora
      }
    ])
  end

  defp atividade_da_issue(tenant, issue_id, tipo) do
    agora = DateTime.utc_now(:second)

    Repo.insert_all("spo_performed_project_activities", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(tenant.id),
        internal_id: "a-#{System.unique_integer([:positive])}",
        activity_type: tipo,
        occurred_at: agora,
        subject_type: "issue",
        subject_id: Ecto.UUID.dump!(issue_id),
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "E_#{System.unique_integer([:positive])}",
        inserted_at: agora,
        updated_at: agora
      }
    ])
  end

  defp empatar(project_id) do
    Repo.update_all(
      from(v in "spo_project_boards", where: v.project_id == type(^project_id, :binary_id)),
      set: [linked_at: ~N[2026-08-20 12:00:00]]
    )
  end
end
