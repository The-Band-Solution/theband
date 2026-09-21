defmodule TheBand.Teams.FlowPerPersonTest do
  @moduledoc """
  As medidas da aba *Flow per person* — feature 060, protótipo aprovado em 2026-09-08.

  Três coisas são provadas aqui, e cada uma existe porque a alternativa é um defeito que esta
  casa já cometeu:

  1. **três consultas para qualquer número de pessoas.** A forma óbvia custa três POR pessoa,
     e é o padrão 1+N que o teto de consultas desta tela existe para pegar (L38);
  2. **a identidade do burn**, que é o que dispensa uma consulta por amostra;
  3. **os três estados da previsão, na ordem certa** — quem não tem item aberto não é *"abaixo
     do piso"*, e inverter a ordem culparia o método por uma ausência de trabalho.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Teams.FlowPerPerson
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  @janela_em_dias 56

  setup do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    agora = DateTime.utc_now(:second)
    desde = DateTime.add(agora, -@janela_em_dias, :day)

    %{
      tenant: tenant,
      admin: admin,
      repo_id: cenario.observed_repository_id,
      agora: agora,
      desde: desde,
      janela: [desde: desde, ate: agora]
    }
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    p
  end

  # Grava a issue direto: o caminho de coleta exige payload completo, e o que importa aqui são
  # as duas datas e a designação — `external_created_at` presente e `external_closed_at` nulo é
  # a substituição declarada do WIP.
  defp item(ctx, designados, criada, fechada \\ nil) do
    # O PREFIXO NÃO PODE SER `I_`, e é um teste instável que ensinou.
    #
    # `cenario_real/1` grava as issues do cenário com `external_id: "I_#{numero}"` — `I_1`,
    # `I_3`, `I_5`, `I_79`, `I_98`, `I_200`. E `System.unique_integer([:positive])` devolve
    # inteiros pequenos: podia devolver exatamente 1, 3, 5 ou 79, e o insert batia no
    # `collected_issues_application_reference_index`.
    #
    # Falhava em cerca de uma execução em cinco, sempre num teste diferente, e o erro
    # apontava para a linha do `item/4` como se o cenário estivesse errado. Prefixo próprio
    # mais `:monotonic` fecha as duas portas.
    externo = "FPP_#{System.unique_integer([:positive, :monotonic])}"

    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "item #{externo}",
        state: if(fechada, do: "CLOSED", else: "OPEN"),
        external_created_at: criada,
        external_closed_at: fechada,
        collected_at: DateTime.utc_now(:second)
      })

    for d <- designados do
      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: d.login,
        person_id: d.id
      })
    end

    i
  end

  describe "o lote: três consultas para qualquer número de pessoas" do
    test "trinta pessoas custam as mesmas três consultas que uma", ctx do
      ids = for n <- 1..30, do: pessoa(ctx.tenant, "p#{n}").id

      uma =
        contar_consultas(fn ->
          FlowPerPerson.linhas(ctx.tenant, [hd(ids)], :semana, ctx.janela)
        end)

      trinta =
        contar_consultas(fn -> FlowPerPerson.linhas(ctx.tenant, ids, :semana, ctx.janela) end)

      assert uma == 3, "as três declaradas: criadas, fechadas, e o aberto inicial"

      assert trinta == uma, """
      O PADRÃO 1+N. Chamar `PersonWork.state_changes_by_period/3` por linha custaria três
      consultas POR pessoa — noventa aqui, e cento e quarenta e quatro numa equipe de 48.
      """

      assert map_size(FlowPerPerson.linhas(ctx.tenant, ids, :semana, ctx.janela)) == 30,
             "e devolve linha para todas, inclusive as sem item nenhum"
    end
  end

  describe "a identidade do burn" do
    test "aberto(t) = aberto(0) + criadas − fechadas, acumuladas", ctx do
      p = pessoa(ctx.tenant, "ana")

      # Aberto ANTES da janela e ainda aberto: entra no inicial e em nenhuma das séries.
      item(ctx, [p], DateTime.add(ctx.desde, -10, :day))
      # Dois dentro da janela, um deles fechado dentro dela.
      item(ctx, [p], DateTime.add(ctx.desde, 7, :day))
      item(ctx, [p], DateTime.add(ctx.desde, 14, :day), DateTime.add(ctx.desde, 21, :day))

      linhas = FlowPerPerson.linhas(ctx.tenant, [p.id], :semana, ctx.janela)
      linha = linhas[p.id]

      assert linha.aberto_inicial == 1, "a guarda: o item anterior à janela está no inicial"
      assert linha.criadas_na_janela == 2
      assert linha.fechadas_na_janela == 1

      assert FlowPerPerson.aberto_agora(linha) == 2, """
      1 + 2 − 1. Sem a identidade, a série de abertos exigiria uma consulta POR AMOSTRA — nove
      por pessoa numa janela de oito semanas.
      """

      assert linha.periodos_com_fechamento == 1
    end

    test "o item de DOIS responsáveis conta uma vez para CADA, e nenhuma coluna soma a equipe",
         ctx do
      a = pessoa(ctx.tenant, "ana")
      b = pessoa(ctx.tenant, "bruno")

      item(ctx, [a, b], DateTime.add(ctx.desde, 7, :day))

      linhas = FlowPerPerson.linhas(ctx.tenant, [a.id, b.id], :semana, ctx.janela)

      assert FlowPerPerson.aberto_agora(linhas[a.id]) == 1
      assert FlowPerPerson.aberto_agora(linhas[b.id]) == 1

      soma = Enum.sum(Enum.map(Map.values(linhas), &FlowPerPerson.aberto_agora/1))

      assert soma == 2, """
      A soma das linhas é DOIS, e a equipe tem UM item. É a regra da 057 FR-008, e é por isso
      que a tela diz em palavras que nenhuma coluna soma ao fluxo da equipe: quem somar as
      linhas obtém outro número, e não o da equipe.
      """
    end
  end

  describe "a variação, em palavras" do
    test "sem mudança diz que se conferiu, e em quantas amostras", ctx do
      p = pessoa(ctx.tenant, "ana")
      item(ctx, [p], DateTime.add(ctx.desde, -10, :day))

      linhas = FlowPerPerson.linhas(ctx.tenant, [p.id], :semana, ctx.janela)

      assert {:sem_mudanca, amostras} = FlowPerPerson.variacao(linhas[p.id])
      assert amostras > 1, "o número de amostras é dito, nunca um `0` solto"
    end

    test "com mudança diz de onde, quanto, e em quantas amostras", ctx do
      p = pessoa(ctx.tenant, "ana")
      item(ctx, [p], DateTime.add(ctx.desde, -10, :day))
      item(ctx, [p], DateTime.add(ctx.desde, 21, :day))

      linhas = FlowPerPerson.linhas(ctx.tenant, [p.id], :semana, ctx.janela)

      assert {:mudou, primeiro, delta, _amostras} = FlowPerPerson.variacao(linhas[p.id])
      assert primeiro == 1, "o valor na primeira amostra, e não só o delta"
      assert delta == 1
    end
  end

  describe "os três estados da previsão, e a ordem entre eles" do
    test "sem item aberto é `nada a prever`, e NÃO `abaixo do piso`", ctx do
      p = pessoa(ctx.tenant, "ana")
      # Abriu e fechou dentro da janela: há história, e nada aberto.
      item(ctx, [p], DateTime.add(ctx.desde, 7, :day), DateTime.add(ctx.desde, 14, :day))

      linhas = FlowPerPerson.linhas(ctx.tenant, [p.id], :semana, ctx.janela)

      assert {:nada_a_prever, _} = FlowPerPerson.previsao(linhas[p.id]), """
      A ORDEM É A DECISÃO. `nada_a_prever` é conferido ANTES do piso: quem não tem item aberto
      não tem o que prever, e dizer "below the floor" ali culparia o método por uma ausência
      de trabalho.
      """
    end

    test "com item aberto e sem história é `sem histórico`, com os QUATRO números", ctx do
      p = pessoa(ctx.tenant, "ana")
      item(ctx, [p], DateTime.add(ctx.desde, 7, :day))

      linhas = FlowPerPerson.linhas(ctx.tenant, [p.id], :semana, ctx.janela)

      assert {:sem_historico, faltando} = FlowPerPerson.previsao(linhas[p.id])

      assert %{semanas_exigidas: 6, fechadas: 0, fechadas_exigidas: 10} = faltando, """
      Os quatro números da coluna: `history a of 6 · closed b of 10`. São DOIS modos de
      bloqueio distintos, e um pode estar atendido enquanto o outro não — as palavras *met* e
      *short* carregam essa diferença.
      """

      assert is_integer(faltando.semanas)
    end

    test "a contagem da FR-100 aparece inclusive quando é 0 de N", ctx do
      ids = for n <- 1..3, do: pessoa(ctx.tenant, "p#{n}").id

      linhas = FlowPerPerson.linhas(ctx.tenant, ids, :semana, ctx.janela)

      assert {0, 3} = FlowPerPerson.quantas_com_previsao(linhas), """
      `produced for 0 of 3` diz que se conferiu, e é diferente de a linha não existir. O piso
      é do MÉTODO, nunca das pessoas abaixo dele.
      """
    end
  end

  # Conta as consultas do bloco — é a única forma de provar o lote, porque o resultado é o
  # mesmo com três consultas e com noventa.
  defp contar_consultas(fun) do
    ref = make_ref()
    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], &__MODULE__.contar/4, self())

    try do
      fun.()
      drenar(0)
    after
      :telemetry.detach({__MODULE__, ref})
    end
  end

  @doc false
  def contar(_evento, _medidas, _meta, destino), do: send(destino, :consulta)

  defp drenar(n) do
    receive do
      :consulta -> drenar(n + 1)
    after
      0 -> n
    end
  end
end
