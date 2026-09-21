defmodule TheBandWeb.DeclararFaseTest do
  @moduledoc """
  O que cada coluna do quadro significa — feature 066, US1.

  ## As asserções que carregam este arquivo

  1. **toda opção observada aparece**, na ordem observada, com a contagem de hoje — esconder
     uma faria a tela mentir por omissão sobre o que o quadro tem;
  2. **proposta não é decisão**: o nome que o vocabulário reconhece vem como *proposed*, e
     **nada muda** enquanto ninguém ativa;
  3. **opção sem declaração diz "no decision"** — ausência escrita, nunca célula vazia;
  4. **declarar grava autor e instante**, e a tela os mostra;
  5. **revogar marca**: a declaração anterior continua visível, riscada;
  6. **aceitação não é oferecida**, e a razão (`sro.rule03`) está escrita onde a pessoa
     procuraria por ela;
  7. **o desacordo é dito, e sem declaração diz "not declared"** — zero seria mentira: não é
     que não haja desacordo, é que não há definição.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Ontology.SEON.SPO.EventConcept
  alias TheBand.Ontology.SEON.SPO.ItemPhase
  alias TheBand.Projects

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    agora = DateTime.utc_now(:second)

    {:ok, quadro} =
      Projects.record_observed_project(tenant, %{
        connected_tool_id: cenario.tool.id,
        number: 43,
        title: "Conecta Fapes",
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_43",
        collected_at: agora
      })

    # As opções na ordem em que a origem as mostra — e é essa ordem que a tela usa.
    {:ok, _} =
      Projects.record_field_definition(tenant, %{
        observed_project_id: quadro.id,
        field_external_id: "PVTSSF_status",
        name: "Status",
        data_type: "SINGLE_SELECT",
        options: [
          %{"id" => "o_backlog", "name" => "Backlog"},
          %{"id" => "o_refin", "name" => "Refinamento"},
          %{"id" => "o_homol", "name" => "Homologation"},
          %{"id" => "o_done", "name" => "Done"}
        ],
        collected_at: agora
      })

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      cenario: cenario,
      quadro: quadro
    }
  end

  test "toda opção observada aparece, na ordem observada", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "What each column means"

    # A ordem é conferida DENTRO do cartão: a explicação do topo da página cita nomes de
    # coluna como exemplo, e medir a página inteira mediria o texto, não a tabela.
    [_, cartao] = String.split(html, "What each column means", parts: 2)

    posicoes =
      for nome <- ["Backlog", "Refinamento", "Homologation", "Done"] do
        {nome, :binary.match(cartao, nome) |> elem(0)}
      end

    assert posicoes == Enum.sort_by(posicoes, &elem(&1, 1)),
           "as opções têm de aparecer na ordem observada: #{inspect(posicoes)}"
  end

  test "o vocabulário propõe, e a proposta não decide nada", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "proposed"
    assert html =~ "a proposal decides nothing until someone activates it"

    # E nada foi gravado: proposta não é declaração.
    assert ItemPhase.vigentes(ctx.tenant, ctx.quadro.id) == []
  end

  test "opção que o vocabulário não reconhece diz 'no decision'", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "no decision"

    # Os que ficam de fora, e cada família por um motivo diferente:
    #
    #   * `Refinamento` e `Discovery Técnico` — estágios anteriores, e se são planejamento ou
    #     andamento depende da casa;
    #   * `Paused` e `Blocked` — INTERRUPÇÃO, que não é andamento nem planejamento, e a rede
    #     não tem destino para isso hoje;
    #   * `Desaprovado` — recusa, e recusa de quê é o que a feature 067 vai declarar.
    for nome <- ["Refinamento", "Discovery Técnico", "Paused", "Blocked", "Desaprovado"] do
      refute ItemPhase.proposta_para(nome), "#{nome} passou a propor sem decisão registrada"
    end

    # **`Homologation` saiu desta lista em 2026-09-21**, por decisão da pessoa mantenedora:
    # homologar é alguém conferindo, e enquanto confere o trabalho está em curso. A evidência
    # e a contraevidência estão na regra — e este teste guarda a decisão contra um retorno
    # silencioso ao estado anterior.
    assert ItemPhase.proposta_para("Homologation") ==
             "spo.performed_project_activity.em_andamento"

    assert ItemPhase.proposta_para("Aguardando Deploy") ==
             "spo.performed_project_activity.em_andamento"
  end

  test "declarar grava autor e instante, e a tela os mostra", ctx do
    {:ok, live, _} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    html =
      live
      |> form("#declarar-fase-o_done",
        field_external_id: "PVTSSF_status",
        option_external_id: "o_done",
        option_name: "Done",
        target_concept: "spo.performed_project_activity.concluida"
      )
      |> render_submit()

    assert html =~ "completed"
    assert html =~ "declared "

    [declaracao] = ItemPhase.vigentes(ctx.tenant, ctx.quadro.id)
    assert declaracao.option_external_id == "o_done"
    assert declaracao.option_name_at_declaration == "Done"
    assert declaracao.declared_by_user_id == ctx.admin.id
    assert declaracao.declared_at
    refute declaracao.revoked_at
  end

  test "revogar marca, e a anterior continua visível", ctx do
    {:ok, declaracao} =
      ItemPhase.declarar(
        ctx.tenant,
        %{
          observed_project_id: ctx.quadro.id,
          field_external_id: "PVTSSF_status",
          option_external_id: "o_done",
          option_name_at_declaration: "Done",
          target_concept: "spo.performed_project_activity.concluida"
        },
        ctx.admin.id
      )

    {:ok, live, _} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    html =
      live
      |> element("button[phx-click='revogar_fase'][phx-value-id='#{declaracao.id}']")
      |> render_click()

    assert html =~ "revoked "
    assert ItemPhase.vigentes(ctx.tenant, ctx.quadro.id) == []

    [revogada] = ItemPhase.revogadas(ctx.tenant, ctx.quadro.id)
    assert revogada.id == declaracao.id
    assert revogada.revoked_by_user_id == ctx.admin.id
  end

  test "declarar sobre a vigente revoga a anterior, e sobra UMA vigente", ctx do
    attrs = %{
      observed_project_id: ctx.quadro.id,
      field_external_id: "PVTSSF_status",
      option_external_id: "o_done",
      option_name_at_declaration: "Done"
    }

    {:ok, _} =
      ItemPhase.declarar(
        ctx.tenant,
        Map.put(attrs, :target_concept, "spo.performed_project_activity.em_andamento"),
        ctx.admin.id
      )

    {:ok, _} =
      ItemPhase.declarar(
        ctx.tenant,
        Map.put(attrs, :target_concept, "spo.performed_project_activity.concluida"),
        ctx.admin.id
      )

    assert [vigente] = ItemPhase.vigentes(ctx.tenant, ctx.quadro.id)
    assert vigente.target_concept == "spo.performed_project_activity.concluida"
    assert [_anterior] = ItemPhase.revogadas(ctx.tenant, ctx.quadro.id)
  end

  test "destino fora da regra é recusado, e a regra é a fonte", ctx do
    assert {:error, changeset} =
             ItemPhase.declarar(
               ctx.tenant,
               %{
                 observed_project_id: ctx.quadro.id,
                 field_external_id: "PVTSSF_status",
                 option_external_id: "o_done",
                 option_name_at_declaration: "Done",
                 target_concept: "sro.accepted_deliverable"
               },
               ctx.admin.id
             )

    assert {"não é um destino declarado em github.project_item_status", _} =
             changeset.errors[:target_concept]

    # E a razão está na tela, onde alguém procuraria por "accepted".
    {:ok, _live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")
    assert html =~ "Not offered here: accepted / not accepted"
    assert html =~ "sro.rule03"
  end

  test "o desacordo sem declaração é dito, e não é zero", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "Disagreement: not declared"
    assert ItemPhase.desacordo(ctx.tenant, ctx.quadro.id) == :nao_declarado
  end

  test "a página diz POR QUE pergunta, e o que acontece se ninguém declarar", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "Why this page asks you things"
    assert html =~ "A board is"
    # Cada declaração diz a consequência de não ser feita — e a ausência nunca vira zero.
    assert html =~ "no start instant"
    assert html =~ "the house default"
    assert html =~ "not declared"
  end

  test "o evento aparece por extenso, com o padrão da casa, e a organização declara", ctx do
    {:ok, live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "What each event materialises"

    # Sem eventos coletados no cenário, a tabela existe e não inventa linha.
    refute html =~ "house default — nobody declared"

    # E o conceito é oferecido pela regra, nunca escrito na tela.
    assert Enum.map(EventConcept.conceitos_admitidos(), & &1.id) == [
             "spo.performed_project_activity",
             "cmpo.change_request",
             "sro.performed_scrum_development_task",
             "nao_nomeado"
           ]

    # A declaração vale para a organização inteira, e a tela o diz.
    assert render(live) =~ "Declaring for the organisation, not for this board"
  end

  test "declarar um evento grava autor, e revogar devolve o padrão da casa", ctx do
    {:ok, d} =
      EventConcept.declarar(
        ctx.tenant,
        "AddedToProjectV2Event",
        "spo.performed_project_activity",
        ctx.admin.id
      )

    assert d.declared_by_user_id == ctx.admin.id
    assert [vigente] = EventConcept.vigentes(ctx.tenant)
    assert vigente.event_type == "AddedToProjectV2Event"

    {:ok, _} = EventConcept.revogar(ctx.tenant, d.id, ctx.admin.id)
    assert EventConcept.vigentes(ctx.tenant) == []
  end

  test "o critério de fim é por quadro, e sem ele a plataforma diz o que assume", ctx do
    {:ok, live, html} = live(ctx.conn, ~p"/boards?id=#{ctx.quadro.id}")

    assert html =~ "End criterion"
    assert html =~ "No end criterion"
    # A ausência diz o que a plataforma assume no lugar — nunca fica em silêncio.
    assert html =~ "the issue being closed"
    # E diz que dá o instante, não a aceitação.
    assert html =~ "not the acceptance"

    # Declarar um evento que a coleta NÃO traz é recusado: critério que nunca resolve faria a
    # ausência parecer defeito.
    assert {:error, :unknown_event_type} =
             SPO.declare_end_criterion(
               ctx.tenant,
               {:board, ctx.quadro.id},
               "EventoQueNinguemColetou",
               ctx.admin.id
             )

    refute render(live) =~ "EventoQueNinguemColetou"
  end

  test "o fim e o início são critérios distintos do mesmo quadro", ctx do
    # Não se confundem: declarar um não toca o outro.
    assert SPO.end_criterion_for(ctx.tenant, {:board, ctx.quadro.id}) == nil
    assert SPO.start_criterion_for(ctx.tenant, {:board, ctx.quadro.id}) == nil
  end

  test "conceito fora da regra é recusado", ctx do
    assert {:error, changeset} =
             EventConcept.declarar(
               ctx.tenant,
               "ClosedEvent",
               "sro.accepted_deliverable",
               ctx.admin.id
             )

    assert {"não é um conceito admitido em github.timeline_event_vocabulary", _} =
             changeset.errors[:target_concept]
  end
end
