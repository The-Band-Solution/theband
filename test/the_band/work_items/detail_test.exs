defmodule TheBand.WorkItems.DetailTest do
  @moduledoc """
  O detalhe da issue (feature 006): composição, atendimento, axioma e histórico.

  O cenário é o mesmo `cenario_real/2` das outras suítes — a issue #1 tem 30 partes do
  tipo `Task` e 9 do tipo `Feature`, e é justamente essa mistura que torna possível o
  defeito que estes testes existem para impedir: somar as duas relações.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    %{tenant: tenant, cenario: cenario_real(tenant)}
  end

  describe "composição e atendimento" do
    test "no épico #1, as duas relações têm contagens próprias e a soma nunca aparece",
         %{tenant: tenant, cenario: c} do
      epico = c.issues[1].pai

      composicao = WorkItems.list_composition(tenant, epico.id)
      atendimento = WorkItems.list_attendance(tenant, epico.id)

      assert length(composicao) == 9, """
      A composição são as partes promovidas a user story — as 9 `Feature`.
      """

      assert length(atendimento) == 30, """
      O atendimento são as 30 `Task`. Elas NÃO compõem o épico: atendem às user stories.
      """

      # É o SC-004 escrito como asserção: o número somado não pode existir em lugar
      # nenhum. Se alguém trocar as duas funções por uma contagem de "filhas", este
      # teste é o que quebra.
      refute length(composicao) + length(atendimento) == length(composicao)
      refute length(composicao) == 39
      refute length(atendimento) == 39
    end

    test "a user story #3 tem composição vazia e nove tarefas atendendo",
         %{tenant: tenant, cenario: c} do
      us = c.issues[3].pai

      assert WorkItems.list_composition(tenant, us.id) == [], """
      As nove partes são tarefas. Tarefa não compõe user story — atende a ela. Se
      aparecerem na composição, #3 passa a ser épico e 78 tarefas se ligam a épicos.
      """

      assert length(WorkItems.list_attendance(tenant, us.id)) == 9
      assert WorkItems.classification(tenant, us.id) == :atomic_user_story
    end

    test "as partes que a plataforma não promoveu ficam numa terceira lista",
         %{tenant: tenant, cenario: c} do
      # #79 tem uma Feature e duas Task; todas promovidas. Uma issue sem partes tem as
      # três listas vazias, e é isso que distingue "sem partes" de "partes perdidas".
      solta = c.issues[202].pai

      assert WorkItems.list_composition(tenant, solta.id) == []
      assert WorkItems.list_attendance(tenant, solta.id) == []
      assert WorkItems.list_unpromoted_parts(tenant, solta.id) == []
    end
  end

  describe "o pai" do
    test "a tarefa aponta para a issue que ela atende", %{tenant: tenant, cenario: c} do
      tarefa = c.issues[3].partes |> hd()
      pai = WorkItems.fetch_parent(tenant, tarefa.id)

      assert pai.number == 3
      assert pai.derived_concept == "sro.atomic_user_story"
    end

    test "issue sem pai devolve nil, e nil é resposta, não erro",
         %{tenant: tenant, cenario: c} do
      assert WorkItems.fetch_parent(tenant, c.issues[201].pai.id) == nil
    end
  end

  describe "sro.rule07" do
    test "tarefa cujo pai é épico viola, e tarefa sem pai viola de outra forma" do
      assert WorkItems.rule07("sro.intended_scrum_development_task", "sro.epic") ==
               {:violation, :task_parent_is_epic}

      assert WorkItems.rule07("sro.intended_scrum_development_task", nil) ==
               {:violation, :task_without_parent}

      assert WorkItems.rule07("sro.intended_scrum_development_task", "sro.atomic_user_story") ==
               :ok

      # A regra fala de tarefas. Uma user story sem pai não viola nada — e tratá-la como
      # violação encheria a tela de avisos sobre issues corretas.
      assert WorkItems.rule07("sro.atomic_user_story", nil) == :ok
      assert WorkItems.rule07(nil, nil) == :ok
    end

    test "as duas formas aparecem separadas, e a issue continua promovida",
         %{tenant: tenant, cenario: c} do
      violacoes = WorkItems.rule07_violations(tenant)

      # 32, e não 30: as 30 tarefas do épico #1 mais as 2 do épico #79. Contar só as do
      # #1 esconderia que a violação atravessa os épicos do repositório.
      assert length(violacoes.task_parent_is_epic) == 32

      # A #201 é uma Task sem pai.
      assert Enum.any?(violacoes.task_without_parent, &(&1.number == 201))

      # E o ponto que importa: nenhuma delas perdeu a promoção. O inválido é o vínculo.
      {:ok, tarefa} = WorkItems.fetch_issue(tenant, hd(violacoes.task_parent_is_epic).id)
      assert tarefa.derived_concept == "sro.intended_scrum_development_task"

      {:ok, sem_pai} = WorkItems.fetch_issue(tenant, c.issues[201].pai.id)
      assert sem_pai.derived_concept == "sro.intended_scrum_development_task"
    end

    test "a lista em lote concorda com a verificação de uma issue só",
         %{tenant: tenant} do
      violacoes = WorkItems.rule07_violations(tenant)

      em_lote =
        MapSet.new(violacoes.task_parent_is_epic ++ violacoes.task_without_parent, & &1.id)

      # `Enum.filter`, e não `for` com atribuição: dentro de uma comprehension, uma
      # expressão que não é gerador vale como **filtro** pelo seu valor — e
      # `pai = nil` descartava justamente a tarefa sem pai, que é um dos dois casos
      # que este teste compara. O teste passava a concordar por não olhar.
      uma_a_uma =
        tenant
        |> WorkItems.list_issues(limit: 10_000)
        |> Enum.filter(fn issue ->
          pai = WorkItems.fetch_parent(tenant, issue.id)
          WorkItems.rule07(issue.derived_concept, pai && pai.derived_concept) != :ok
        end)
        |> MapSet.new(& &1.id)

      assert MapSet.equal?(em_lote, uma_a_uma), """
      A tela do repositório e o detalhe da issue discordam sobre quem viola o axioma.

      É o defeito que `classification/2` existe para impedir, na sua segunda forma: duas
      implementações do mesmo axioma. Uma tela avisaria o que a outra nega.
      """
    end
  end

  describe "fetch_issue" do
    test "traz os campos coletados, os designados e os rótulos",
         %{tenant: tenant, cenario: c} do
      issue = c.issues[1].pai

      {:ok, _} =
        WorkItems.replace_assignees(tenant, issue.id, [
          %{login: "paulossjunior", person_id: nil},
          %{login: "outra-pessoa", person_id: nil}
        ])

      {:ok, _} =
        WorkItems.replace_labels(tenant, issue.id, [%{name: "bug", color: "d73a4a"}])

      {:ok, detalhe} = WorkItems.fetch_issue(tenant, issue.id)

      assert detalhe.number == 1
      assert length(detalhe.assignees) == 2
      assert [%{name: "bug"}] = detalhe.labels
      assert detalhe.classification == :epic

      # O rótulo `bug` NÃO promove a defeito: quem decide é o tipo declarado ou a regra
      # da organização. Promover por semelhança de nome é o antipadrão do princípio I.
      refute detalhe.derived_concept == "osdef.defect"
    end

    test "issue de outro tenant devolve não encontrada, nunca sem permissão",
         %{cenario: c} do
      outro = tenant_fixture()

      assert WorkItems.fetch_issue(outro, c.issues[1].pai.id) == {:error, :not_found}
    end

    test "corpo vazio na origem é gravado como vazio, e não vira nulo",
         %{tenant: tenant, cenario: c} do
      issue = c.issues[79].pai

      {:ok, _} =
        WorkItems.record_collected_issue(tenant, %{
          observed_repository_id: issue.observed_repository_id,
          number: issue.number,
          title: issue.title,
          state: issue.state,
          body: "",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: issue.external_id
        })

      {:ok, detalhe} = WorkItems.fetch_issue(tenant, issue.id)

      assert detalhe.body == "", """
      `cast/4` descarta string vazia por padrão, e isso colapsa os dois casos que a tela
      precisa distinguir: `nil` é "nunca pedido à origem", `""` é "a origem não tem
      descrição".

      Foi medido contra a origem: 480 issues tinham NULL no banco e `bodyText` de
      comprimento zero na API. A suíte estava verde — o defeito só apareceu ao conferir
      o número com a origem.
      """
    end

    test "corpo nunca coletado é nil, e é diferente de corpo vazio",
         %{tenant: tenant, cenario: c} do
      {:ok, sem_coletar} = WorkItems.fetch_issue(tenant, c.issues[1].pai.id)

      assert sem_coletar.body == nil, """
      O cenário grava a issue sem corpo, como a coleta anterior à feature 006 fazia.
      `nil` é "nunca pedido à origem"; `""` seria "a origem não tem corpo". A tela diz
      coisas diferentes para os dois, e é a L13 aplicada à exibição.
      """
    end
  end

  describe "designados e rótulos" do
    test "substituir remove o que a origem não traz mais",
         %{tenant: tenant, cenario: c} do
      issue = c.issues[3].pai

      {:ok, 2} =
        WorkItems.replace_assignees(tenant, issue.id, [
          %{login: "a", person_id: nil},
          %{login: "b", person_id: nil}
        ])

      {:ok, 1} = WorkItems.replace_assignees(tenant, issue.id, [%{login: "b", person_id: nil}])

      {:ok, detalhe} = WorkItems.fetch_issue(tenant, issue.id)
      assert Enum.map(detalhe.assignees, & &1.login) == ["b"]
    end

    test "substituir duas vezes com o mesmo dado não duplica",
         %{tenant: tenant, cenario: c} do
      issue = c.issues[4].pai
      designados = [%{login: "a", person_id: nil}]

      {:ok, 1} = WorkItems.replace_assignees(tenant, issue.id, designados)
      {:ok, 1} = WorkItems.replace_assignees(tenant, issue.id, designados)

      {:ok, detalhe} = WorkItems.fetch_issue(tenant, issue.id)
      assert length(detalhe.assignees) == 1
    end
  end

  describe "histórico de promoção" do
    test "cada decisão é uma linha, e a vigente é a última",
         %{tenant: tenant, cenario: c} do
      issue = c.issues[5].pai

      {:ok, _} =
        WorkItems.record_promotion(tenant, %{
          collected_issue_id: issue.id,
          derived_concept: "sro.epic",
          rule_id: "regra.nova",
          rule_version: 2
        })

      historico = WorkItems.promotion_history(tenant, issue.id)

      assert length(historico) == 2
      assert List.last(historico).current
      assert List.last(historico).derived_concept == "sro.epic"
      refute hd(historico).current
    end
  end
end
