defmodule TheBand.Projects.BacklogsTest do
  @moduledoc """
  Os dois backlogs derivados da atribuição — sprint 017, T054. FR-032, FR-032a, FR-032b.

  ## A asserção que carrega este arquivo

  **SC-009b**: product backlog + sprint backlogs = total de itens do quadro. Nenhum item
  nos dois conjuntos, nenhum fora dos dois. A composição é derivada da atribuição de
  iteração — nunca gravada — e a soma é o que prova que a derivação não perde nem conta
  duas vezes.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Projects

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)

    {:ok, quadro} =
      Projects.record_observed_project(tenant, %{
        connected_tool_id: cenario.tool.id,
        number: 31,
        title: "DevOps",
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_b31",
        collected_at: agora()
      })

    {:ok, campo} =
      Projects.record_field_definition(tenant, %{
        observed_project_id: quadro.id,
        field_external_id: "PVTIF_sprint",
        name: "Sprint",
        data_type: "ITERATION",
        collected_at: agora()
      })

    %{tenant: tenant, quadro: quadro, campo: campo, tool: cenario.tool}
  end

  defp agora, do: DateTime.utc_now(:second)

  defp item(ctx, sufixo, opts \\ []) do
    {:ok, item} =
      Projects.record_item(ctx.tenant, %{
        observed_project_id: ctx.quadro.id,
        is_draft: Keyword.get(opts, :draft, false),
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{sufixo}",
        collected_at: agora()
      })

    item
  end

  defp atribuir(ctx, item, iteration_id) do
    {:ok, _} =
      Projects.record_item_field_value(ctx.tenant, %{
        project_item_id: item.id,
        project_field_definition_id: ctx.campo.id,
        raw_value: %{"iterationId" => iteration_id, "title" => "Sprint X"},
        collected_at: agora()
      })
  end

  defp sprint(ctx, iteration_id, inicio) do
    {:ok, %{promoted_to: {:sprint, sprint_id}}} =
      Projects.record_iteration(ctx.tenant, %{
        observed_project_id: ctx.quadro.id,
        iteration_external_id: iteration_id,
        field_external_id: "PVTIF_sprint",
        board_number: 31,
        board_title: "DevOps",
        field_name: "Sprint",
        title: "Sprint #{iteration_id}",
        start_date: inicio,
        duration_days: 14,
        connected_tool_id: ctx.tool.id,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTIF_sprint:#{iteration_id}",
        collected_at: agora()
      })

    sprint_id
  end

  test "SC-009b: product + sprints = total, nenhum item nos dois nem fora dos dois", ctx do
    s1 = sprint(ctx, "i1", ~D[2026-07-01])
    s2 = sprint(ctx, "i2", ~D[2026-08-01])

    # Sete itens: 3 no sprint 1, 2 no sprint 2, 2 sem iteração (product backlog) —
    # um deles rascunho, porque rascunho também é item do quadro.
    for n <- 1..3, do: atribuir(ctx, item(ctx, "s1_#{n}"), "i1")
    for n <- 1..2, do: atribuir(ctx, item(ctx, "s2_#{n}"), "i2")
    _solto = item(ctx, "solto")
    _rascunho = item(ctx, "rascunho", draft: true)

    product = SRO.product_backlog(ctx.tenant, ctx.quadro.id)
    backlog_s1 = SRO.sprint_backlog(ctx.tenant, s1)
    backlog_s2 = SRO.sprint_backlog(ctx.tenant, s2)
    total = Projects.count_items(ctx.tenant, ctx.quadro.id)

    assert length(product) == 2
    assert length(backlog_s1) == 3
    assert length(backlog_s2) == 2

    assert length(product) + length(backlog_s1) + length(backlog_s2) == total,
           """
           A soma dos backlogs não bate com o total de itens do quadro.

           SC-009b: nenhum item nos dois conjuntos, nenhum fora dos dois. A composição é
           derivada da atribuição de iteração — se a soma quebra, a derivação perdeu ou
           contou item duas vezes.
           """

    ids_product = MapSet.new(product, & &1.id)
    ids_sprints = MapSet.new(backlog_s1 ++ backlog_s2, & &1.id)

    assert MapSet.disjoint?(ids_product, ids_sprints),
           "um item apareceu no product backlog E num sprint backlog"
  end

  test "a composição é derivada: mover o item de iteração muda o backlog sem comando", ctx do
    s1 = sprint(ctx, "i1", ~D[2026-07-01])
    movel = item(ctx, "movel")

    assert [_] = SRO.product_backlog(ctx.tenant, ctx.quadro.id)
    assert [] = SRO.sprint_backlog(ctx.tenant, s1)

    # "Arrastar o item no quadro" é só o valor do campo mudando na coleta seguinte.
    atribuir(ctx, movel, "i1")

    assert [] = SRO.product_backlog(ctx.tenant, ctx.quadro.id)
    assert [item_no_sprint] = SRO.sprint_backlog(ctx.tenant, s1)
    assert item_no_sprint.id == movel.id
  end

  test "importance_source declara a ausência em vez de inventar ordem", ctx do
    assert Projects.importance_source(ctx.tenant, ctx.quadro.id) == :not_declared,
           """
           A importância veio de algum lugar sem mapeamento declarado.

           FR-026: nenhum campo é promovido a substituto — `Priority` não é `importance`.
           A tela mostra a ausência como limitação, e esta função existe para isso.
           """
  end
end
