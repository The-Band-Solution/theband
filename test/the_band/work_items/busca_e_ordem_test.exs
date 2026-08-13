defmodule TheBand.WorkItems.BuscaEOrdemTest do
  @moduledoc """
  Busca e ordenação no banco (feature 017, T001).

  ## O caso que pega "buscar em memória"

  Filtrar as linhas já carregadas **parece** busca: a caixa aceita o texto, a tabela responde, e
  quem procura uma issue que está na página 40 recebe "nada encontrado" — sem que a tela tenha como
  saber que mentiu.

  Por isso o caso central procura por algo que **só existe fora da primeira página**.

  ## E o que pega ordem instável

  `number` repete entre repositórios, e `derived_concept` repete em 3 346 issues. Ordenar só pela
  coluna escolhida faz a mesma linha aparecer em duas páginas e outra sumir — **sem erro nenhum**.
  O teste percorre todas as páginas e compara o conjunto com o total.
  """
  use TheBand.DataCase, async: true

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, cenario: cenario}
  end

  describe "a busca" do
    test "acha o que está fora da primeira página", ctx do
      alvo = issue_com_titulo(ctx, "agulha no palheiro")

      # A issue fica no fim da ordem estável, porque o número é o maior do cenário.
      primeira_pagina = WorkItems.list_issues(ctx.tenant, limit: 5)
      refute Enum.any?(primeira_pagina, &(&1.id == alvo.id)), "o cenário não montou o caso"

      achadas = WorkItems.list_issues(ctx.tenant, search: "agulha", limit: 5)

      assert Enum.any?(achadas, &(&1.id == alvo.id)), """
      A busca não alcançou uma linha que está fora da primeira página.

      É o que acontece quando se filtra em memória o que já foi carregado: a caixa aceita o texto,
      a tabela responde, e quem procura recebe "nada encontrado" sem a tela saber que mentiu.
      """
    end

    test "o total acompanha a busca", ctx do
      issue_com_titulo(ctx, "agulha no palheiro")

      total_geral = WorkItems.count_collected(ctx.tenant)
      total_busca = WorkItems.count_collected(ctx.tenant, search: "agulha")

      assert total_busca == 1

      assert total_geral > total_busca, """
      O total ignorou a busca.

      Um total que não acompanha o filtro faz a paginação numerada oferecer páginas vazias, e o
      número do rodapé desmentir o que está na tela.
      """
    end

    test "busca por número encontra a issue", ctx do
      %{pai: issue} = ctx.cenario.issues[3]

      achadas = WorkItems.list_issues(ctx.tenant, search: to_string(issue.number), limit: 500)

      assert Enum.any?(achadas, &(&1.id == issue.id))
    end

    test "busca vazia não filtra nada", ctx do
      todas = WorkItems.list_issues(ctx.tenant, limit: 500)

      assert length(WorkItems.list_issues(ctx.tenant, search: "", limit: 500)) == length(todas)
      assert length(WorkItems.list_issues(ctx.tenant, search: nil, limit: 500)) == length(todas)
    end
  end

  describe "a ordenação" do
    test "ordena por conceito derivado, que não existe no banco", ctx do
      conceitos =
        ctx.tenant
        |> WorkItems.list_issues(order_by: {:conceito, :asc}, limit: 500)
        |> Enum.map(& &1.derived_concept)
        |> Enum.reject(&is_nil/1)

      assert conceitos == Enum.sort(conceitos), """
      A lista não veio ordenada pelo conceito.

      O conceito vem da promoção vigente — não existe como coluna. Ordenar por ele é ordenar por
      resultado calculado, e é o caso que nenhuma biblioteca de tabela resolveria sozinha.
      """
    end

    test "ordena por título nos dois sentidos", ctx do
      subindo = ctx.tenant |> WorkItems.list_issues(order_by: {:title, :asc}, limit: 5)
      descendo = ctx.tenant |> WorkItems.list_issues(order_by: {:title, :desc}, limit: 5)

      refute Enum.map(subindo, & &1.id) == Enum.map(descendo, & &1.id)
    end

    test "nenhuma linha aparece em duas páginas, e nenhuma some", ctx do
      total = WorkItems.count_collected(ctx.tenant)
      por_pagina = 7

      ids =
        0..div(total, por_pagina)
        |> Enum.flat_map(fn p ->
          ctx.tenant
          |> WorkItems.list_issues(
            order_by: {:conceito, :asc},
            limit: por_pagina,
            offset: p * por_pagina
          )
          |> Enum.map(& &1.id)
        end)

      assert length(ids) == total, "alguma linha sumiu entre as páginas"

      assert length(Enum.uniq(ids)) == total, """
      A mesma linha apareceu em mais de uma página.

      `derived_concept` repete em milhares de issues, e ordenar só por ele deixa a ordem interna do
      grupo por conta do plano de execução — que pode mudar entre as consultas de cada página. O
      desempate por `observed_repository_id, number, id` é o que impede isso, e ele **nunca sai**.
      """
    end
  end

  defp issue_com_titulo(ctx, titulo) do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: 99_999,
        title: titulo,
        state: "OPEN",
        issue_type: "Task",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_99999"
      })

    issue
  end
end
