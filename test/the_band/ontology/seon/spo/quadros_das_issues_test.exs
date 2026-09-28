defmodule TheBand.Ontology.SEON.SPO.QuadrosDasIssuesTest do
  @moduledoc """
  Em que quadro cada issue está, e com que valores — feature 062, FR-033.

  As três regras da FR-033, cada uma com o caso que a derrubaria:

  1. **por quadro, e nunca um só**: a issue está em dois quadros, e os dois vêm;
  2. **todo campo de seleção única**: o quadro tem `Status` e `Squad`, e os dois vêm. A
     plataforma não escolhe "a coluna" pelo nome;
  3. **a fase só onde foi declarada**: a opção `In Progress` tem declaração e vem com fase; a
     `Review`, sem declaração, vem sem, mesmo tendo nome que parece fase.
  """
  use TheBandWeb.ConnCase, async: true

  import Ecto.Query, only: [from: 2]
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO.ItemPhase
  alias TheBand.Projects
  alias TheBand.Projects.Schemas.FieldDefinition
  alias TheBand.Repo

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    agora = DateTime.utc_now(:second)

    ctx = %{tenant: tenant, admin: admin, cenario: cenario, agora: agora}

    principal = quadro(ctx, 43, "Conecta Fapes")
    entrega = quadro(ctx, 44, "Conecta Fapes - Delivery")

    status = campo(ctx, principal, "PVTSSF_status", "Status", [{"o_prog", "In Progress"}])
    squad = campo(ctx, principal, "PVTSSF_squad", "Squad", [{"o_green", "Green"}])
    area = campo(ctx, principal, "PVTSSF_area", "Area", [{"o_front", "Frontend"}])
    status_entrega = campo(ctx, entrega, "PVTSSF_st2", "Status", [{"d_rev", "Review"}])

    nos_dois = issue(ctx, 9331)
    em_nenhum = issue(ctx, 9332)

    item_principal = item(ctx, principal, nos_dois, "A1")
    valor(ctx, item_principal, status, "o_prog", "In Progress")
    valor(ctx, item_principal, squad, "o_green", "Green")
    valor(ctx, item_principal, area, "o_front", "Frontend")

    item_entrega = item(ctx, entrega, nos_dois, "A2")
    valor(ctx, item_entrega, status_entrega, "d_rev", "Review")

    # O campo Area saiu do quadro: o valor continua gravado, e não pode aparecer.
    Repo.update_all(
      from(f in FieldDefinition, where: f.id == ^area.id),
      set: [no_longer_observed_at: agora]
    )

    {:ok, _} =
      ItemPhase.declarar(
        tenant,
        %{
          observed_project_id: principal.id,
          field_external_id: "PVTSSF_status",
          option_external_id: "o_prog",
          option_name_at_declaration: "In Progress",
          target_concept: "spo.performed_project_activity.em_andamento"
        },
        admin.id
      )

    Map.merge(ctx, %{nos_dois: nos_dois, em_nenhum: em_nenhum, principal: principal})
  end

  defp quadro(ctx, numero, titulo) do
    {:ok, q} =
      Projects.record_observed_project(ctx.tenant, %{
        connected_tool_id: ctx.cenario.tool.id,
        number: numero,
        title: titulo,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_#{numero}",
        collected_at: ctx.agora
      })

    q
  end

  defp campo(ctx, quadro, id, nome, opcoes) do
    {:ok, f} =
      Projects.record_field_definition(ctx.tenant, %{
        observed_project_id: quadro.id,
        field_external_id: id,
        name: nome,
        data_type: "SINGLE_SELECT",
        options: Enum.map(opcoes, fn {oid, n} -> %{"id" => oid, "name" => n} end),
        collected_at: ctx.agora
      })

    f
  end

  defp issue(ctx, numero) do
    {:ok, i} =
      TheBand.WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: numero,
        title: "issue #{numero}",
        state: "OPEN",
        issue_type: "Task",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{numero}"
      })

    i
  end

  defp item(ctx, quadro, issue, sufixo) do
    {:ok, it} =
      Projects.record_item(ctx.tenant, %{
        observed_project_id: quadro.id,
        collected_issue_id: issue.id,
        is_draft: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{sufixo}",
        collected_at: ctx.agora,
        last_observed_at: ctx.agora
      })

    it
  end

  defp valor(ctx, item, campo, opcao, nome) do
    {:ok, _} =
      Projects.record_item_field_value(ctx.tenant, %{
        project_item_id: item.id,
        project_field_definition_id: campo.id,
        raw_value: %{"optionId" => opcao, "name" => nome},
        collected_at: ctx.agora,
        last_observed_at: ctx.agora
      })
  end

  test "a issue em dois quadros vem com os dois, e cada um com a sua coluna", ctx do
    %{} = mapa = ItemPhase.quadros_das_issues(ctx.tenant, [ctx.nos_dois.id, ctx.em_nenhum.id])

    assert [principal, entrega] = mapa[ctx.nos_dois.id]
    assert principal.quadro == "Conecta Fapes"
    assert entrega.quadro == "Conecta Fapes - Delivery"

    # Cada campo de seleção única com valor, na ordem do nome — e o Area, que saiu, não.
    assert Enum.map(principal.campos, &{&1.campo, &1.valor}) ==
             [{"Squad", "Green"}, {"Status", "In Progress"}]

    assert [%{campo: "Status", valor: "Review"}] = entrega.campos
  end

  test "a fase só vem onde foi declarada, e nunca do nome da opção", ctx do
    [principal, entrega] =
      ItemPhase.quadros_das_issues(ctx.tenant, [ctx.nos_dois.id])[ctx.nos_dois.id]

    status = Enum.find(principal.campos, &(&1.campo == "Status"))
    squad = Enum.find(principal.campos, &(&1.campo == "Squad"))

    assert %{conceito: "spo.performed_project_activity.em_andamento", declarada_em: %DateTime{}} =
             status.fase

    assert squad.fase == nil
    # "Review" parece fase, e não tem declaração: sem fase.
    assert [%{fase: nil}] = entrega.campos
  end

  test "a issue em nenhum quadro não tem entrada", ctx do
    mapa = ItemPhase.quadros_das_issues(ctx.tenant, [ctx.em_nenhum.id])
    refute Map.has_key?(mapa, ctx.em_nenhum.id)
    assert ItemPhase.quadros_das_issues(ctx.tenant, []) == %{}
  end

  test "outro tenant não lê o quadro deste, nem pelo id da issue", ctx do
    {outro, _} = tenant_with_admin()

    assert ItemPhase.quadros_das_issues(outro, [ctx.nos_dois.id]) == %{}
    # A guarda: o mesmo id, no tenant certo, tem os dois quadros.
    assert length(ItemPhase.quadros_das_issues(ctx.tenant, [ctx.nos_dois.id])[ctx.nos_dois.id]) ==
             2
  end

  test "revogada a declaração, a fase some", ctx do
    [declaracao] = ItemPhase.vigentes(ctx.tenant, ctx.principal.id)
    {:ok, _} = ItemPhase.revogar(ctx.tenant, declaracao.id, ctx.admin.id)

    [principal, _] = ItemPhase.quadros_das_issues(ctx.tenant, [ctx.nos_dois.id])[ctx.nos_dois.id]
    assert Enum.all?(principal.campos, &is_nil(&1.fase))
  end
end
