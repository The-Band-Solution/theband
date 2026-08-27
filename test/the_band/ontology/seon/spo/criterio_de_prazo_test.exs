defmodule TheBand.Ontology.SEON.SPO.CriterioDePrazoTest do
  @moduledoc """
  De onde vem o prazo — issue #368.

  ## As asserções que carregam este arquivo

  1. **prazo é lista, e nunca um valor.** Medido em 2026-08-26: 304 issues têm marco e
     caixa de tempo ao mesmo tempo, e 640 estão em mais de uma caixa. Devolver um só
     escolheria em silêncio qual das datas conta;
  2. **horizonte não entra como sprint.** Depois da #514 a caixa pode ser de 13 ou de 84
     dias, e somá-las mediria atraso de trimestre contra uma caixa de duas semanas;
  3. **declarar acrescenta, e não substitui.** Diferente da 042: lá o início é um só, aqui
     sprint e marco valem juntos, e substituir apagaria metade do prazo;
  4. **sem critério é lista vazia, e não zero.** 43% das issues não alcançam origem
     alguma, e "não sabemos" é diferente de "está no prazo".

  ## Os dois filtros de tenant se cobrem — e isso é armadilha para quem vier depois

  Medido por injeção em 2026-08-26: remover o filtro de tenant de `origens_por_quadro/1`
  **sozinho** não quebra teste nenhum, e remover o de `caixas/3` sozinho também não. Os
  dois juntos quebram.

  Não é redundância a limpar: é defesa em profundidade, e cada um é a única barreira quando
  o outro falha. Quem achar um deles "óbvio pelo join" e apagar não verá teste vermelho, e
  a próxima edição do outro abre a fronteira em silêncio. **Não simplifique nenhum dos
  dois.**
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.Continuum.SMPO
  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Projects

  setup do
    tenant = tenant_fixture()
    user = user_fixture(tenant)
    cenario = cenario_real(tenant)
    quadro = quadro(tenant, cenario.tool)

    %{
      tenant: tenant,
      tool: cenario.tool,
      user: user,
      quadro: quadro,
      # `issues` chaveia por número e devolve `%{pai:, partes:}` — o pai é a issue.
      issue: Map.fetch!(cenario.issues, 1).pai,
      outra: Map.fetch!(cenario.issues, 3).pai
    }
  end

  defp quadro(tenant, tool) do
    agora = DateTime.utc_now(:second)

    {:ok, q} =
      Projects.record_observed_project(tenant, %{
        connected_tool_id: tool.id,
        number: 31,
        title: "DevOps",
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_31",
        collected_at: agora,
        last_observed_at: agora
      })

    q
  end

  # O item do quadro liga a issue ao quadro. Sem ele nenhuma origem alcança a issue — é
  # pelo quadro que o critério chega.
  defp item(ctx, issue) do
    agora = DateTime.utc_now(:second)

    {:ok, it} =
      Projects.record_item(ctx.tenant, %{
        observed_project_id: ctx.quadro.id,
        collected_issue_id: issue.id,
        is_draft: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{issue.id}",
        collected_at: agora,
        last_observed_at: agora
      })

    it
  end

  defp campo_de_data(ctx, item, nome, data) do
    agora = DateTime.utc_now(:second)

    {:ok, d} =
      Projects.record_field_definition(ctx.tenant, %{
        observed_project_id: ctx.quadro.id,
        field_external_id: "PVTF_#{nome}",
        name: nome,
        data_type: "DATE",
        collected_at: agora,
        last_observed_at: agora
      })

    {:ok, _} =
      Projects.record_item_field_value(ctx.tenant, %{
        project_item_id: item.id,
        project_field_definition_id: d.id,
        raw_value: %{"date" => Date.to_iso8601(data)},
        collected_at: agora,
        last_observed_at: agora
      })

    d
  end

  defp caixa(ctx, issue, nome_do_campo, titulo, inicio, dias) do
    {:ok, s} =
      SRO.record_sprint(ctx.tenant, %{
        connected_tool_id: ctx.tool.id,
        board_number: ctx.quadro.number,
        board_title: ctx.quadro.title,
        field_name: nome_do_campo,
        title: titulo,
        started_on: inicio,
        duration_days: dias,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{titulo}"
      })

    {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, s.id, issue.id)
    s
  end

  defp com_marco(ctx, issue, titulo, vence_em) do
    Repo.update_all(
      from(i in "collected_issues",
        where:
          i.id == type(^issue.id, :binary_id) and
            i.tenant_id == type(^ctx.tenant.id, :binary_id)
      ),
      set: [milestone_title: titulo, milestone_due_on: vence_em]
    )
  end

  defp declarar(ctx, origem, campo \\ nil) do
    {:ok, c} =
      SPO.declare_deadline_criterion(
        ctx.tenant,
        {:board, ctx.quadro.id},
        origem,
        campo,
        ctx.user.id
      )

    c
  end

  defp prazos(ctx, issue),
    do: SPO.resolve_deadlines(ctx.tenant, [issue.id]) |> Map.fetch!(issue.id)

  describe "sem critério declarado" do
    test "a issue sai com lista vazia, e não com zero", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      com_marco(ctx, ctx.issue, "V1", ~D[2026-08-31])

      assert prazos(ctx, ctx.issue) == [], """
      Uma origem alcançou a issue sem ninguém ter declarado.

      A caixa e o marco existem, mas o quadro não disse que o fim deles é prazo. 43% das
      issues não alcançam origem alguma, e lista vazia é "não sabemos o prazo" — nunca
      "está no prazo", que é a leitura que produziria atraso onde não há.
      """
    end

    test "lista vazia é declarada para TODA issue pedida, e não omitida do mapa", ctx do
      item(ctx, ctx.issue)

      assert SPO.resolve_deadlines(ctx.tenant, [ctx.issue.id, ctx.outra.id]) == %{
               ctx.issue.id => [],
               ctx.outra.id => []
             },
             """
             Uma issue sumiu do mapa em vez de sair com lista vazia.

             Chave ausente vira `nil` em quem lê, e `nil` não é o mesmo que "sem prazo conhecido":
             a tela precisa distinguir "perguntei e não há" de "não perguntei".
             """
    end
  end

  describe "as três origens" do
    test "campo do quadro devolve a data daquele campo, e não a dos outros", ctx do
      it = item(ctx, ctx.issue)
      campo_de_data(ctx, it, "Target date", ~D[2026-12-30])
      campo_de_data(ctx, it, "Start date", ~D[2026-06-12])

      declarar(ctx, "board_field", "Target date")

      assert [%{quando: ~D[2026-12-30], origem: :board_field, rotulo: "Target date"}] =
               prazos(ctx, ctx.issue),
             """
             O campo declarado não foi o único lido.

             Há 33 pares (quadro, campo) de data e 13 nomes. `Start date` é início, não prazo, e
             lê-lo como prazo produziria atraso desde o dia em que o trabalho começou.
             """
    end

    test "sprint devolve o fim da caixa", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      declarar(ctx, "sprint")

      assert [%{origem: :sprint, rotulo: "Sprint 38", quando: fim}] = prazos(ctx, ctx.issue)
      assert fim == ~D[2026-07-12]
    end

    test "marco devolve o dueOn, e marco sem prazo não vira data nenhuma", ctx do
      item(ctx, ctx.issue)
      item(ctx, ctx.outra)
      com_marco(ctx, ctx.issue, "[Módulo] V1", ~D[2026-08-31])
      com_marco(ctx, ctx.outra, "[QA] Backlog de Bugs", nil)
      declarar(ctx, "milestone")

      assert [%{quando: ~D[2026-08-31], origem: :milestone, rotulo: "[Módulo] V1"}] =
               prazos(ctx, ctx.issue)

      assert prazos(ctx, ctx.outra) == [], """
      Marco sem `dueOn` produziu um prazo.

      1.580 issues têm marco, e o marco sem data é marco sem prazo declarado — não é hoje,
      nem a data de criação. Preencher produziria atraso onde não há.
      """
    end
  end

  describe "as origens não se excluem" do
    test "sprint E marco valem ao mesmo tempo, e os dois voltam", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      com_marco(ctx, ctx.issue, "[Módulo] V1", ~D[2026-08-31])

      declarar(ctx, "sprint")
      declarar(ctx, "milestone")

      assert [
               %{quando: ~D[2026-07-12], origem: :sprint},
               %{quando: ~D[2026-08-31], origem: :milestone}
             ] = prazos(ctx, ctx.issue),
             """
             Declarar a segunda origem apagou a primeira.

             A decisão de 2026-08-26 é explícita: "se uma task está dentro do sprint, o prazo dela
             é do sprint E do milestone". 304 issues têm as duas, e devolver uma só escolheria em
             silêncio qual das datas conta.
             """
    end

    # Duas origens DIFERENTES (`sprint` e `milestone`) não provam o filtro de campo: elas
    # já se separam por `source`. O caso que prova é o mesmo `source` com campos
    # diferentes — dois campos de data declarados no mesmo quadro, que é o que os 33 pares
    # de data tornam comum.
    test "revogar um campo de data deixa o outro campo de pé", ctx do
      it = item(ctx, ctx.issue)
      campo_de_data(ctx, it, "End date", ~D[2026-07-31])
      campo_de_data(ctx, it, "Target date", ~D[2026-12-30])
      declarar(ctx, "board_field", "End date")
      declarar(ctx, "board_field", "Target date")

      assert length(prazos(ctx, ctx.issue)) == 2

      assert {:ok, 1} =
               SPO.revoke_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "board_field",
                 "End date",
                 ctx.user.id
               )

      assert [%{rotulo: "Target date", quando: ~D[2026-12-30]}] = prazos(ctx, ctx.issue), """
      Revogar um campo revogou o outro também.

      Há 33 pares (quadro, campo) de data, e o mesmo quadro tem mais de um. Revogar `End
      date` e ver `Target date` cair junto apagaria um prazo que ninguém mandou apagar.
      """
    end

    test "revogar uma origem deixa a outra de pé", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      com_marco(ctx, ctx.issue, "[Módulo] V1", ~D[2026-08-31])
      declarar(ctx, "sprint")
      declarar(ctx, "milestone")

      assert {:ok, 1} =
               SPO.revoke_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "sprint",
                 nil,
                 ctx.user.id
               )

      assert [%{origem: :milestone}] = prazos(ctx, ctx.issue)
    end

    test "revogar o que ninguém declarou não é sucesso silencioso", ctx do
      assert {:error, :not_declared} =
               SPO.revoke_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "sprint",
                 nil,
                 ctx.user.id
               )
    end

    test "duas issues em mais de uma caixa devolvem um prazo por caixa", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 39", ~D[2026-07-13], 14)
      declarar(ctx, "sprint")

      assert [%{quando: ~D[2026-07-12]}, %{quando: ~D[2026-07-26]}] = prazos(ctx, ctx.issue), """
      Uma issue em duas caixas devolveu um prazo só.

      640 issues estão em mais de uma caixa de tempo. Escolher uma — a primeira, a última,
      a mais próxima — é decisão que ninguém tomou, e a tela precisa mostrar as duas para
      quem lê poder ver que a tarefa atravessou o limite da caixa.
      """
    end
  end

  describe "o horizonte de planejamento não é sprint — issue #514" do
    test "a caixa declarada horizonte volta com origem própria", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      caixa(ctx, ctx.issue, "Quarter", "Q3", ~D[2026-07-01], 92)
      declarar(ctx, "sprint")

      assert [%{origem: :sprint}, %{origem: :sprint}] = prazos(ctx, ctx.issue)

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.quadro.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      assert [
               %{quando: ~D[2026-07-12], origem: :sprint, rotulo: "Sprint 38"},
               %{quando: ~D[2026-09-30], origem: :planning_horizon, rotulo: "Q3"}
             ] = prazos(ctx, ctx.issue),
             """
             O trimestre voltou como prazo de sprint.

             São 92 dias contra 14. O fim do sprint é quando a caixa de execução fecha; o fim do
             horizonte é o limite do período para o qual o trabalho HAVIA sido planejado. Medir
             atraso contra o segundo achando que é o primeiro dá 78 dias de folga inventada.
             """
    end
  end

  describe "a fronteira do tenant" do
    test "outro tenant SEM critério nenhum não alcança prazo daqui", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      declarar(ctx, "sprint")

      outro = tenant_fixture()

      assert SPO.resolve_deadlines(outro, [ctx.issue.id]) == %{ctx.issue.id => []}
      assert SPO.deadline_criteria_for(outro, {:board, ctx.quadro.id}) == []
    end

    # Tenant sem critério nenhum não prova a fronteira: a resolução para antes de consultar
    # a caixa, porque não há quadro com origem declarada. O vazamento só aparece quando o
    # OUTRO tenant também declarou — aí a consulta roda, e o filtro é a única coisa entre
    # ela e as caixas de quem não é dele.
    test "outro tenant COM critério próprio não alcança as caixas daqui", ctx do
      item(ctx, ctx.issue)
      caixa(ctx, ctx.issue, "Sprint", "Sprint 38", ~D[2026-06-29], 14)
      declarar(ctx, "sprint")

      outro = tenant_fixture()
      dele = user_fixture(outro)
      ferramenta_dele = ferramenta(outro, "Outra-Org")
      quadro_dele = quadro(outro, ferramenta_dele)

      {:ok, _} =
        SPO.declare_deadline_criterion(outro, {:board, quadro_dele.id}, "sprint", nil, dele.id)

      assert SPO.resolve_deadlines(outro, [ctx.issue.id]) == %{ctx.issue.id => []}, """
      Um tenant com critério próprio alcançou a caixa de tempo de outro.

      Consulta sem filtro de tenant é bug de segurança, não de correção — princípio V. Aqui
      ele não apareceria no teste anterior, porque sem critério a resolução nem consulta.
      """
    end
  end

  describe "o que o schema recusa" do
    test "origem que a ontologia não define", ctx do
      assert {:error, %Ecto.Changeset{}} =
               SPO.declare_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "data_de_entrega",
                 nil,
                 ctx.user.id
               )
    end

    test "board_field sem campo nomeado", ctx do
      assert {:error, cs} =
               SPO.declare_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "board_field",
                 nil,
                 ctx.user.id
               )

      assert errors_on(cs)[:field_name] != nil
    end

    test "sprint COM campo nomeado — dado que nenhuma leitura consulta", ctx do
      assert {:error, cs} =
               SPO.declare_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "sprint",
                 "End date",
                 ctx.user.id
               )

      assert errors_on(cs)[:field_name] != nil
    end

    test "declarar a mesma origem duas vezes não cria duas vigentes", ctx do
      declarar(ctx, "sprint")

      assert {:error, cs} =
               SPO.declare_deadline_criterion(
                 ctx.tenant,
                 {:board, ctx.quadro.id},
                 "sprint",
                 nil,
                 ctx.user.id
               )

      assert errors_on(cs) != %{}
      assert length(SPO.deadline_criteria_for(ctx.tenant, {:board, ctx.quadro.id})) == 1
    end
  end
end
