defmodule TheBand.Ontology.Continuum.SRO.SprintTest do
  @moduledoc """
  As caixas de tempo e as issues dentro delas (T003, T005, T006, T007, T011).

  ## As duas asserções que carregam este arquivo

  1. **renomear na origem não cria caixa nova.** A identidade é a Application Reference,
     e `title`, `started_on` e `duration_days` são editáveis — um hash sobre eles
     deixaria uma caixa órfã a cada correção;
  2. **`{:error, :board_has_no_iteration_field}` não é `{:ok, 0}`.** As duas produzem o
     mesmo zero na tela e afirmam coisas opostas.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Ontology.Continuum.SRO.Schemas.Sprint
  alias TheBand.Ontology.Continuum.SRO.Schemas.SprintIssue
  alias TheBand.Ontology.KnowledgeBase

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, cenario: cenario, tool: cenario.tool}
  end

  defp caixa(ctx, attrs \\ %{}) do
    Map.merge(
      %{
        connected_tool_id: ctx.tool.id,
        board_number: 31,
        board_title: "DevOps",
        field_name: "Sprint",
        title: "Sprint 38",
        started_on: ~D[2026-06-29],
        duration_days: 14,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTIF_sprint38"
      },
      attrs
    )
  end

  describe "a identidade vem da origem" do
    test "renomear a iteração não cria caixa nova", ctx do
      {:ok, primeira} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      assert primeira.outcome == :created

      {:ok, segunda} =
        SRO.record_sprint(ctx.tenant, caixa(ctx, %{title: "Sprint 38 — Pagamentos"}))

      assert segunda.outcome == :updated
      assert segunda.id == primeira.id

      assert Repo.aggregate(Sprint, :count) == 1, """
      Renomear a iteração na origem criou uma caixa nova.

      A identidade é a Application Reference justamente por isto: `title`, `started_on`
      e `duration_days` são editáveis, e um hash sobre eles deixaria uma caixa órfã ao
      lado da antiga a cada correção — com as issues divididas entre as duas.
      """
    end

    test "recoletar sem mudança devolve :unchanged", ctx do
      {:ok, _} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      {:ok, segunda} = SRO.record_sprint(ctx.tenant, caixa(ctx))

      assert segunda.outcome == :unchanged, """
      A recoleta sem mudança foi contada como atualização.

      Com `:updated` fixo, a contagem da execução diria que tudo mudou a cada coleta, e
      o número deixaria de distinguir sprint novo de sprint revisto.
      """
    end

    test "o fim é derivado, e inclui o dia de início", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))

      assert sprint.ended_on == ~D[2026-07-12], """
      Um sprint de 14 dias que começa em 29/06 termina em 12/07, e não em 13/07.

      A duração inclui o dia de início — somar 14 dias cheios daria 15 dias de sprint.
      """
    end

    test "a duração gravada é a da iteração", ctx do
      # Medido em 2026-08-15: `Sprint 10` tem 3 dias num campo configurado para 14.
      {:ok, curto} =
        SRO.record_sprint(
          ctx.tenant,
          caixa(ctx, %{
            title: "Sprint 10",
            duration_days: 3,
            source_external_id: "PVTIF_sprint10"
          })
        )

      assert curto.duration_days == 3
      assert curto.ended_on == Date.add(curto.started_on, 2)
    end
  end

  describe "todo campo de iteração vira sprint" do
    test "Quarter é gravado, e o nome do campo fica", ctx do
      {:ok, _} = SRO.record_sprint(ctx.tenant, caixa(ctx))

      {:ok, quarter} =
        SRO.record_sprint(
          ctx.tenant,
          caixa(ctx, %{
            field_name: "Quarter",
            title: "Quarter 5",
            duration_days: 90,
            source_external_id: "PVTIF_quarter5"
          })
        )

      assert quarter.field_name == "Quarter", """
      O nome do campo de origem foi descartado.

      Todo campo de iteração vira sprint por decisão, mas `Quarter` de 90 dias e
      `Sprint` de 14 precisam continuar distinguíveis: somá-los sem saber produziria
      uma contagem que mistura granularidades.
      """

      assert length(SRO.list_sprints(ctx.tenant, board_number: 31)) == 2
    end
  end

  describe "as issues dentro da caixa" do
    test "a mesma issue em duas caixas produz dois vínculos", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))

      {:ok, quarter} =
        SRO.record_sprint(
          ctx.tenant,
          caixa(ctx, %{field_name: "Quarter", duration_days: 90, source_external_id: "q5"})
        )

      issue = ctx.cenario.issues[1].pai

      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue.id)
      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, quarter.id, issue.id)

      assert Repo.aggregate(SprintIssue, :count) == 2, """
      A mesma issue em duas caixas produziu um vínculo só.

      É o caso medido em 2026-08-15, e não a exceção: no DevOps, 527 + 203 vínculos
      sobre 677 itens. Achatar isso escolheria uma das duas caixas sem regra que
      justifique — o Produtos Internos inverte a proporção.
      """
    end

    test "associar duas vezes o mesmo par não duplica", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      issue = ctx.cenario.issues[1].pai

      {:ok, primeiro} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue.id)
      {:ok, segundo} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue.id)

      assert primeiro.outcome == :created
      assert segundo.outcome == :unchanged
      assert Repo.aggregate(SprintIssue, :count) == 1
    end

    test "a issue que saiu é marcada, e a linha continua", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      [uma, outra] = Enum.take(ctx.cenario.issues[1].partes, 2)

      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, uma.id)
      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, outra.id)

      agora = DateTime.utc_now(:second)

      {:ok, marcados} =
        SRO.mark_issues_no_longer_in_sprint(ctx.tenant, sprint.id, [uma.id], agora)

      assert marcados == 1

      assert Repo.aggregate(SprintIssue, :count) == 2, """
      A contagem de linhas caiu quando uma issue saiu do sprint.

      Ausência marca, nunca apaga: a issue continua tendo estado no sprint, e apagar a
      linha faria a história dele mudar retroativamente.
      """

      assert length(SRO.list_sprint_issues(ctx.tenant, sprint.id)) == 1
    end

    test "lista vazia de observadas não marca nada", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      issue = ctx.cenario.issues[1].pai
      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue.id)

      {:ok, marcados} =
        SRO.mark_issues_no_longer_in_sprint(ctx.tenant, sprint.id, [], DateTime.utc_now(:second))

      assert marcados == 0, """
      Uma execução que não observou issue alguma marcou todas como ausentes.

      Sprint sem issue observada nesta execução pode ser sprint que a coleta não
      percorreu — é a L19, e na feature 020 o mesmo descuido teria marcado 4261
      vínculos falsos.
      """
    end

    test "a issue que volta ao sprint tem a marca limpa", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      issue = ctx.cenario.issues[1].pai

      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue.id)

      {:ok, 1} =
        SRO.mark_issues_no_longer_in_sprint(
          ctx.tenant,
          sprint.id,
          [Ecto.UUID.generate()],
          DateTime.utc_now(:second)
        )

      {:ok, revisto} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue.id)

      assert revisto.outcome == :updated
      assert is_nil(revisto.no_longer_observed_at)
      assert length(SRO.list_sprint_issues(ctx.tenant, sprint.id)) == 1
    end
  end

  describe "o que ficou fora de qualquer caixa" do
    test "quadro sem caixa de tempo devolve erro, e não zero", ctx do
      assert SRO.count_issues_outside_any_sprint(ctx.tenant, 99) ==
               {:error, :board_has_no_iteration_field},
             """
             Um quadro que não usa caixas de tempo devolveu uma contagem.

             `{:ok, 0}` e `{:error, :board_has_no_iteration_field}` produzem o mesmo zero na
             tela e afirmam coisas opostas: "o quadro organiza por tempo e tudo ficou de fora"
             e "o quadro não organiza por tempo". É a L57.
             """
    end

    test "quadro com caixa devolve a contagem", ctx do
      {:ok, sprint} = SRO.record_sprint(ctx.tenant, caixa(ctx))
      {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, ctx.cenario.issues[1].pai.id)

      assert {:ok, 1} = SRO.count_issues_outside_any_sprint(ctx.tenant, 31)
    end
  end

  describe "o isolamento entre tenants" do
    test "a caixa de um tenant não aparece no outro", ctx do
      outro = tenant_fixture()
      {:ok, _} = SRO.record_sprint(ctx.tenant, caixa(ctx))

      assert SRO.list_sprints(outro) == []
    end
  end
end
