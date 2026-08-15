defmodule TheBandWeb.ProcessoTest do
  @moduledoc """
  A tela do processo, e o antipadrão estrutural que ela sinaliza (T011, T013).

  ## O teste que mais importa é o negativo

  Um quadro que **tem** estado de andamento não é sinalizado. Um aviso que aparece
  sempre treina quem lê a ignorá-lo — e é justamente o aviso que importa quando aparece.

  Sem esse caso, um sinalizador que gritasse para todo quadro passaria em todos os
  outros testes deste arquivo.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    %{conn: log_in(conn, user), tenant: tenant}
  end

  defp movimentacao(tenant, de, para, at) do
    {:ok, _} =
      SPO.record_activity(tenant, %{
        activity_type: "ProjectV2ItemStatusChangedEvent",
        concept_id: "spo.performed_project_activity",
        occurred_at: at,
        subject_type: "issue",
        subject_id: Ecto.UUID.generate(),
        source_system: "github",
        source_instance: "https://github.com",
        payload: %{"previousStatus" => de, "status" => para}
      })
  end

  # O quadro medido em 2026-08-14 na The-Band-Solution.
  defp quadro_sem_andamento(tenant) do
    movimentacao(tenant, "", "Backlog", ~U[2026-08-10 09:00:00Z])
    movimentacao(tenant, "Backlog", "Ready", ~U[2026-08-11 09:00:00Z])
    movimentacao(tenant, "Ready", "In review", ~U[2026-08-12 09:00:00Z])
    movimentacao(tenant, "In review", "Done", ~U[2026-08-13 09:00:00Z])
  end

  describe "os estados observados" do
    test "aparecem com a frequência de cada um", ctx do
      quadro_sem_andamento(ctx.tenant)
      movimentacao(ctx.tenant, "Ready", "Done", ~U[2026-08-14 09:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "Board states"
      assert html =~ "Backlog"
      assert html =~ "Ready"
      assert html =~ "In review"
      assert html =~ "Done"
    end

    test "sem movimentação, diz que não olhou — e não que o processo está bem", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "means the platform has not looked", """
      A tela mostrou quadro vazio sem distinguir "não coletei" de "não houve movimento".

      É o limite escrito no próprio `process_antipatterns.yaml`, e a L57: zero detectado
      com zero coletado não significa processo saudável.
      """
    end

    test "o quadro vazio não é sinalizado como antipadrão", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      refute html =~ "process.ap05", """
      A plataforma acusou antipadrão estrutural sem ter coletado movimentação nenhuma.

      "Não tem estado de andamento" e "não olhei" são coisas diferentes, e afirmar a
      primeira a partir da segunda é inventar um achado.
      """
    end
  end

  describe "o antipadrão estrutural do quadro" do
    test "quadro sem estado de andamento é sinalizado, com a consequência", ctx do
      quadro_sem_andamento(ctx.tenant)

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "no state that means work in progress"
      assert html =~ "process.ap05"

      assert html =~ "every issue on this board", """
      A tela sinalizou o antipadrão sem dizer a consequência.

      A consequência é o que importa, e não a violação: a medida é impossível para TODA
      issue do quadro. Sem isso, quem lê tenta consertar esta issue.
      """

      assert html =~ "fixed on the board", """
      A tela não disse onde se conserta.

      A plataforma não cria estado, e não deveria — o quadro é da organização.
      """
    end

    test "quadro COM estado de andamento não é sinalizado", ctx do
      # O quadro da leds-conectafapes, medido no mesmo dia. É a SC-008, e é o caso que
      # separa um sinalizador útil de um que grita sempre.
      movimentacao(ctx.tenant, "", "To Do", ~U[2026-08-10 09:00:00Z])
      movimentacao(ctx.tenant, "To Do", "In Progress", ~U[2026-08-11 09:00:00Z])
      movimentacao(ctx.tenant, "In Progress", "In Validation", ~U[2026-08-12 09:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      refute html =~ "process.ap05", """
      Um quadro que TEM estado de andamento foi sinalizado assim mesmo.

      É a SC-008. Um aviso que aparece sempre treina quem lê a ignorá-lo, e aí o aviso
      que importa passa despercebido junto com os outros.
      """
    end
  end

  describe "os estados que podem duplicar significado" do
    test "To Do e Todo são apontados, sem a plataforma decidir", ctx do
      movimentacao(ctx.tenant, "", "To Do", ~U[2026-08-10 09:00:00Z])
      movimentacao(ctx.tenant, "", "Todo", ~U[2026-08-11 09:00:00Z])
      movimentacao(ctx.tenant, "Todo", "In Progress", ~U[2026-08-12 09:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "process.ap06"
      assert html =~ "may mean the same thing"

      assert html =~ "someone confirms", """
      A tela afirmou que os dois estados significam o mesmo.

      Ela não sabe disso. `Refinamento` e `Pronto para desenvolvimento` podem ser etapas
      distintas de verdade, e decidir por quem conhece o quadro é o erro que a alocação
      de papel já ensinou a não cometer.
      """
    end

    test "estados distintos não geram sugestão de fusão", ctx do
      quadro_sem_andamento(ctx.tenant)

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      refute html =~ "process.ap06", """
      A tela sugeriu fundir estados que são distintos.

      Sugestão errada custa a confiança nas certas — é por isso que o critério é estreito
      (mesma sequência de letras, ignorando caixa e separador) e não similaridade.
      """
    end
  end

  describe "os tipos de atividade" do
    test "os sem conceito aparecem dizendo que a rede não os nomeia", ctx do
      {:ok, _} =
        SPO.record_activity(ctx.tenant, %{
          activity_type: "LabeledEvent",
          concept_id: nil,
          occurred_at: ~U[2026-08-10 09:00:00Z],
          subject_type: "issue",
          subject_id: Ecto.UUID.generate(),
          source_system: "github",
          source_instance: "https://github.com"
        })

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "LabeledEvent"

      assert html =~ "unnamed by the network", """
      O tipo sem conceito apareceu como um evento qualquer.

      São exatamente eles que dizem o que falta mapear a seguir, e essa é a razão de a
      lista existir.
      """
    end
  end

  describe "o isolamento entre tenants" do
    test "o quadro de um tenant não aparece no outro", ctx do
      quadro_sem_andamento(ctx.tenant)

      {outro, outro_user} = tenant_with_admin()
      conn = log_in(Phoenix.ConnTest.build_conn(), outro_user)
      _ = outro

      {:ok, _live, html} = live(conn, ~p"/process")

      refute html =~ "In review"
      refute html =~ "process.ap05"
    end
  end
end
