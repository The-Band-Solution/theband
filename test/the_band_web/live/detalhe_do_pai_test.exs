defmodule TheBandWeb.DetalheDoPaiTest do
  @moduledoc """
  Os dois defeitos do detalhe do pai (issues #261 e #262).

  ## Os dois eram silenciosos, e de jeitos diferentes

  **#262** — filha promovida a defeito não caía em nenhuma das três listas. A tela parecia
  completa, e a soma das três batia com o que ela mesma mostrava. Eram **33 vínculos** invisíveis
  no dado real.

  **#261** — `fetch_parent/2` tinha `limit: 1` **sem ordem**: para as **36** issues com mais de um
  pai, devolvia um arbitrário, e a escolha podia mudar entre execuções. A mesma tela dizia coisas
  diferentes.
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

  describe "a filha que a ontologia não nomeia — #262" do
    test "aparece no detalhe do pai, em lista própria", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      promover(ctx.tenant, parte, "osdef.defect")

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{pai.id}")

      assert html =~ "Parts the ontology does not name", """
      A filha promovida a defeito não apareceu no detalhe do pai.

      Ela não é composição nem atendimento, e não é "sem conceito" — a plataforma decidiu o que ela
      é, e a rede é que não nomeia a relação. Sem lista própria, eram 33 vínculos invisíveis, e a
      tela parecia completa.
      """

      assert html =~ "##{parte.number}"
    end

    test "não se confunde com 'sem conceito'", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      promover(ctx.tenant, parte, "osdef.defect")

      sem_conceito = WorkItems.list_unpromoted_parts(ctx.tenant, pai.id)
      sem_nome = WorkItems.list_unnamed_relation_parts(ctx.tenant, pai.id)

      ids_sem_conceito = MapSet.new(sem_conceito, & &1.id)

      refute MapSet.member?(ids_sem_conceito, parte.id), """
      A parte promovida a defeito apareceu na lista de "sem conceito".

      Juntar as duas apagaria a diferença entre "a plataforma não classificou" e "classificou, e a
      relação não tem nome na rede" — a mesma distinção que a coluna `part of` faz na tela vizinha.
      """

      assert Enum.any?(sem_nome, &(&1.id == parte.id))
    end

    test "a contagem de partes faltando deixa de acusar o que existe", ctx do
      %{pai: pai, partes: partes} = ctx.cenario.issues[3]
      for parte <- partes, do: promover(ctx.tenant, parte, "osdef.defect")

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{pai.id}")

      refute html =~ ~r/#{length(partes)} part[s]? the source declares/, """
      A tela disse que faltam partes que ela tem.

      Antes da quarta lista, as filhas promovidas a defeito não entravam na conta do que está
      presente — e apareciam como "a origem declara e a plataforma não tem", quando a plataforma
      tinha.
      """
    end
  end

  describe "o pai escolhido entre vários — #261" do
    test "é sempre o mesmo, em execuções seguidas", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      outro = ctx.cenario.issues[4].pai

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: outro.id,
          child_issue_id: parte.id
        })

      pais = for _ <- 1..5, do: WorkItems.fetch_parent(ctx.tenant, parte.id).id

      assert length(Enum.uniq(pais)) == 1, """
      A mesma issue devolveu pais diferentes em execuções seguidas.

      `limit: 1` sem ordem deixa a escolha por conta do plano de execução. São 36 issues com mais
      de um pai no dado real, e a tela dizia coisas diferentes sobre a mesma issue — sem erro.
      """
    end

    test "a ordem é a declarada, e não a do banco", ctx do
      %{pai: primeiro, partes: [parte | _]} = ctx.cenario.issues[3]
      outro = ctx.cenario.issues[4].pai

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: outro.id,
          child_issue_id: parte.id
        })

      escolhido = WorkItems.fetch_parent(ctx.tenant, parte.id)
      menor = Enum.min_by([primeiro, outro], & &1.number)

      assert escolhido.number == menor.number, """
      O pai devolvido não é o primeiro pela ordem declarada.

      A ordem é `number` e depois `id` — e o desempate por `id` não é enfeite: `number` repete
      entre repositórios, e 57 vínculos têm o pai em outro.
      """
    end
  end

  defp promover(tenant, issue, conceito) do
    {:ok, _} =
      WorkItems.record_promotion(tenant, %{
        collected_issue_id: issue.id,
        declared_concept: "Bug",
        derived_concept: conceito,
        rule_id: "teste",
        rule_version: 1,
        evidence_source: "declared_type",
        promoted_at: DateTime.utc_now(:second)
      })
  end
end
