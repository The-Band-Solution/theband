defmodule TheBand.WorkItems.PromocaoVigenteTest do
  @moduledoc """
  A promoção vigente de uma issue (T002 e T004, feature 013).

  ## Escrito **antes** da reescrita, e é esse o ponto

  A feature 013 troca como a vigente é encontrada — de uma subconsulta sobre todas as promoções do
  tenant para uma resolução por issue exibida. **O que não pode mudar é a resposta**, e este arquivo
  é o que trava a resposta antes de a consulta ser tocada.

  ## O caso que a análise achou, e que nenhum teste cobria

  Oito das catorze chamadas usam `inner`, e `inner` **exclui** a issue sem promoção. Trocar por
  `left` faria as contagens ganharem issues que elas não contam hoje — e nada falharia: os números
  simplesmente ficariam maiores. Por isso a issue sem promoção aparece aqui dos dois lados: ela
  **precisa** estar na lista e **não pode** estar na contagem.
  """
  use TheBand.DataCase, async: true

  import Ecto.Query
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.IssuePromotion

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, cenario: cenario}
  end

  describe "qual promoção é a vigente" do
    test "é a mais recente, e a anterior não some do histórico", ctx do
      %{pai: issue} = ctx.cenario.issues[3]
      antes = conceito(ctx.tenant, issue.id)

      # Um conceito **diferente do atual**, escolhido a partir do que a fixture produziu. Fixar
      # "sro.atomic_user_story" faria o teste passar por acaso quando a issue já fosse isso — e
      # deixaria de provar que a vigente mudou.
      novo = if antes == "sro.epic", do: "sro.atomic_user_story", else: "sro.epic"

      {:ok, _} =
        WorkItems.record_promotion(ctx.tenant, %{
          collected_issue_id: issue.id,
          declared_concept: "Feature",
          derived_concept: novo,
          rule_id: "teste",
          rule_version: 1,
          evidence_source: "declared_type",
          promoted_at: DateTime.utc_now(:second)
        })

      assert conceito(ctx.tenant, issue.id) == novo
      refute conceito(ctx.tenant, issue.id) == antes

      assert Repo.aggregate(
               from(p in IssuePromotion, where: p.collected_issue_id == ^issue.id),
               :count
             ) >
               1,
             "a promoção anterior foi apagada — o histórico é proveniência"
    end

    test "a issue sem promoção nenhuma aparece na lista, sem conceito", ctx do
      sem = issue_sem_promocao(ctx)

      linha =
        ctx.tenant
        |> WorkItems.list_issues(limit: 500)
        |> Enum.find(&(&1.id == sem.id))

      assert linha, """
      A issue sem promoção sumiu da lista.

      A lista usa `left`: quem não foi promovido continua sendo trabalho observado, e esconder a
      issue apagaria a lacuna que a plataforma existe para mostrar.
      """

      assert is_nil(linha.derived_concept), "conceito inventado onde não há promoção"
    end

    test "a issue sem promoção NÃO entra nas contagens por conceito", ctx do
      antes = total_contado(ctx.tenant)
      issue_sem_promocao(ctx)

      assert total_contado(ctx.tenant) == antes, """
      A contagem por conceito passou a incluir issue sem promoção.

      As contagens usam `inner` de propósito: elas respondem "quantas issues **de cada conceito**",
      e uma issue sem conceito não é de conceito nenhum. Trocar por `left` faria o número crescer
      sem que nada falhasse — é o achado A1 da análise desta feature.
      """
    end

    test "não atravessa a fronteira do tenant", ctx do
      vizinho = tenant_fixture()
      cenario_vizinho = cenario_real(vizinho, "Outra-Org")
      %{pai: do_vizinho} = cenario_vizinho.issues[3]

      ids = ctx.tenant |> WorkItems.list_issues(limit: 500) |> MapSet.new(& &1.id)

      refute MapSet.member?(ids, do_vizinho.id)
      assert {:error, :not_found} = WorkItems.fetch_issue(ctx.tenant, do_vizinho.id)
    end
  end

  describe "o desempate" do
    # **Sem `@tag :pending`, e a razão importa.** Este caso entrou esperando falhar, porque eu havia
    # escrito que `inserted_at` tinha precisão de segundo e que o empate era defeito real. É
    # `utc_datetime_usec`, e o caso **passa** hoje. Fica como garantia: a reescrita da feature 013
    # não pode torná-lo instável.
    test "duas promoções no mesmo instante devolvem sempre a mesma", ctx do
      %{pai: issue} = ctx.cenario.issues[3]
      instante = DateTime.utc_now()

      # A coleta não produz este caso — `inserted_at` é `utc_datetime_usec`, e a medida no dado real
      # dá **zero** empates. O caso é montado à mão porque a ordem não deve depender de o carimbo
      # continuar tendo essa precisão.
      for concepto <- ["sro.epic", "sro.atomic_user_story"] do
        Repo.insert!(%IssuePromotion{
          tenant_id: ctx.tenant.id,
          collected_issue_id: issue.id,
          declared_concept: "Feature",
          derived_concept: concepto,
          rule_id: "empate",
          rule_version: 1,
          evidence_source: "declared_type",
          promoted_at: DateTime.utc_now(:second),
          inserted_at: instante
        })
      end

      respostas = for _ <- 1..5, do: conceito(ctx.tenant, issue.id)

      assert Enum.uniq(respostas) |> length() == 1, """
      A mesma issue devolveu conceitos diferentes em execuções seguidas.

      Com empate de `inserted_at`, a ordem sem desempate fica por conta do plano de execução — e o
      conceito exibido passa a depender de qual caminho o Postgres escolheu.
      """
    end
  end

  defp conceito(tenant, issue_id) do
    {:ok, issue} = WorkItems.fetch_issue(tenant, issue_id)
    issue.derived_concept
  end

  defp total_contado(tenant) do
    tenant |> WorkItems.count_by_promotion() |> Map.values() |> Enum.sum()
  end

  defp issue_sem_promocao(ctx) do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: 9_100,
        title: "issue que nenhuma regra promoveu",
        state: "OPEN",
        issue_type: "Spike",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_9100"
      })

    issue
  end
end
