defmodule TheBandWeb.AtividadeRegistradaTest do
  @moduledoc """
  Atividade registrada por pessoa e por mês — issue #508.

  ## Os dois casos que carregam este arquivo

  **A tela não pode chamar isto de throughput.** Não é questão de palavra: throughput conta
  tarefa **concluída** e precisa de início e fim; isto conta **evento** e precisa de um
  carimbo só. Quem lê "throughput" compara com a definição da SRO e dimensiona sprint com o
  número — e ele soma comentário e movimentação de card ao trabalho concluído.

  **O robô não é filtrado por nome.** Medido em 2026-08-26, dos quatro autores fora de
  `eo_people`, dois parecem robô e dois parecem pessoa. Classificar por `github-*` publicaria
  a suposição como medida, e o erro cai para o lado barato — o não reconhecido alguém
  corrige, o reconhecido errado vira número.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    _ = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, user: user}
  end

  describe "a contagem" do
    test "agrupa por pessoa e por mês, e não por média", ctx do
      pessoa(ctx, "ana")
      atividade(ctx, "ana", ~U[2026-05-10 12:00:00Z], 3)
      atividade(ctx, "ana", ~U[2026-06-10 12:00:00Z], 5)

      %{pessoas: [p]} = SPO.activity_by_person_month(ctx.tenant)

      assert p.total == 8

      assert p.meses == [{"2026-05", 3}, {"2026-06", 5}], """
      **Os meses, e não uma média.** "Parou de aparecer em maio" é a pergunta que a média
      apaga — e é uma das três que esta issue existe para responder.
      """
    end

    test "quem tem account_type diferente de person não entra na tabela", ctx do
      pessoa(ctx, "ana")
      pessoa(ctx, "robo", "bot")
      atividade(ctx, "ana", ~U[2026-05-10 12:00:00Z], 2)
      atividade(ctx, "robo", ~U[2026-05-10 12:00:00Z], 90)

      %{pessoas: pessoas, nao_classificado: nc} = SPO.activity_by_person_month(ctx.tenant)

      assert Enum.map(pessoas, & &1.login) == ["ana"]
      assert nc.atividades == 90
      assert [%{login: "robo", atividades: 90}] = nc.autores
    end
  end

  describe "a lacuna tem tamanho e tem nomes" do
    test "autor que não está em eo_people volta em nao_classificado, e NÃO some", ctx do
      pessoa(ctx, "ana")
      atividade(ctx, "ana", ~U[2026-05-10 12:00:00Z], 2)
      # Nunca coletado: pode ser robô, pode ser pessoa nova. A plataforma não sabe.
      atividade(ctx, "github-project-automation", ~U[2026-05-10 12:00:00Z], 40)
      atividade(ctx, "MachadoVsouza", ~U[2026-05-10 12:00:00Z], 3)

      %{pessoas: pessoas, nao_classificado: nc} = SPO.activity_by_person_month(ctx.tenant)

      assert Enum.sum(Enum.map(pessoas, & &1.total)) == 2

      assert nc.atividades == 43, """
      **Devolver só as classificadas faria a soma parecer completa.** Na base real são 2.902
      atividades de 4 autores — 15% do total. Uma tabela que soma 16.298 sem dizer que
      existem 19.200 mente por omissão.
      """

      logins = Enum.map(nc.autores, & &1.login)
      assert "github-project-automation" in logins

      assert "MachadoVsouza" in logins, """
      **`MachadoVsouza` não parece robô, e está na mesma lista.** É de propósito: o que une
      os dois é não haver pessoa declarada por trás, e separá-los por padrão de nome seria
      adivinhar. Quem lê decide; a plataforma não.
      """
    end
  end

  describe "a tela" do
    test "diz que NÃO é throughput, e o rótulo não usa a palavra", ctx do
      pessoa(ctx, "ana")
      atividade(ctx, "ana", ~U[2026-05-10 12:00:00Z], 2)

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "Recorded activity"
      assert html =~ "This is not throughput"

      assert html =~ "counts <em>events</em>", """
      **A tela precisa dizer O QUE conta.** "Atividade" sozinho não separa evento de tarefa
      concluída, e é a separação inteira desta issue.
      """

      refute html =~ ~r/>\\s*Throughput/, """
      **O rótulo não pode ser throughput.** Emprestar o nome faria quem lê comparar com a
      definição da SRO e dimensionar sprint com um número que conta comentário.
      """
    end

    test "a lacuna aparece na tela, com os logins", ctx do
      pessoa(ctx, "ana")
      atividade(ctx, "ana", ~U[2026-05-10 12:00:00Z], 2)
      atividade(ctx, "github-project-automation", ~U[2026-05-10 12:00:00Z], 40)

      {:ok, _live, html} = live(ctx.conn, ~p"/process")

      assert html =~ "40 events are not in this table"
      assert html =~ "github-project-automation"

      assert html =~ "does not guess which", """
      A frase que impede o próximo a "consertar" isto com um regex de nome.
      """
    end

    test "sem atividade, a tela diz ausência e não zero", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/process")
      assert html =~ "This is absence, not zero"
    end
  end

  # ------------------------------------------------------------------ apoio

  defp pessoa(ctx, login, tipo \\ "person") do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: tipo,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    p
  end

  defp atividade(ctx, login, quando, quantas) do
    agora = DateTime.utc_now(:second)

    Repo.insert_all(
      "spo_performed_project_activities",
      for n <- 1..quantas do
        %{
          id: Ecto.UUID.bingenerate(),
          tenant_id: Ecto.UUID.dump!(ctx.tenant.id),
          internal_id: "a-#{login}-#{n}-#{System.unique_integer([:positive])}",
          activity_type: "ProjectV2ItemStatusChangedEvent",
          occurred_at: quando,
          performer_login: login,
          subject_type: "issue",
          subject_id: Ecto.UUID.bingenerate(),
          source_system: "github",
          source_instance: "https://github.com",
          source_external_id: "E_#{login}_#{n}_#{System.unique_integer([:positive])}",
          inserted_at: agora,
          updated_at: agora
        }
      end
    )
  end
end
