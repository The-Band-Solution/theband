defmodule TheBand.WorkItems.DivergenceKindTest do
  @moduledoc """
  O **tipo** da divergência, ao lado da frase que a explica.

  A frase serve para entender uma issue; o tipo serve para contar. Sem ele, "quantas issues
  têm tarefa com partes?" exigiria casar substring — e substring quebra na primeira vez que
  alguém melhorar a redação.

  E o tipo carrega a distinção que a frase escondia: em dois casos a plataforma **mudou** o
  conceito por axioma, em dois outros ela o **manteve** de propósito.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Mapping
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems
  alias TheBandWeb.ConceptLabel

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, org: cenario.organization.id, cenario: cenario, user: user_fixture(tenant)}
  end

  describe "o tipo classifica o que a frase explica" do
    test "tarefa com partes é task_with_parts, e o conceito foi mantido",
         %{tenant: t, org: org, user: u, cenario: c} do
      {pai, _} = arvore(t, c)

      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{
            where: "title",
            how: "starts_with",
            pattern: pai.title,
            target_concept: "sro.intended_scrum_development_task"
          },
          u.id
        )

      linha =
        t
        |> Mapping.decidir_lote(org, Mapping.active_rules(t, org))
        |> Enum.find(&(&1.issue.id == pai.id))

      assert linha.decisao.divergence_kind == "task_with_parts"
      refute ConceptLabel.divergencia_mudou_conceito?("task_with_parts")
    end

    test "épico sem partes é epic_without_parts, e o conceito foi decidido pelo axioma" do
      decisao =
        WorkItems.decide(%{issue_type: "Epic", title: "x", sub_issue_types: []},
          tenant_rule_id: "github.issue_type_routing.the_band_solution"
        )

      assert decisao.divergence_kind == "epic_without_parts"
      assert decisao.derived == "sro.atomic_user_story"

      assert ConceptLabel.divergencia_mudou_conceito?("epic_without_parts"), """
      Aqui a plataforma MUDOU o conceito, porque `sro.rule05` contradiz o rótulo. Ler isso
      como sinal faria alguém supor que nada aconteceu.
      """
    end

    test "sem divergência, não há tipo", %{tenant: t, cenario: c} do
      {:ok, detalhe} = WorkItems.fetch_issue(t, c.issues[201].pai.id)

      assert detalhe.divergence_reason == nil
      assert detalhe.divergence_kind == nil
    end
  end

  describe "contar por tipo" do
    test "agrupa as issues por tipo de divergência", %{tenant: t} do
      por_tipo = WorkItems.count_divergences_by_kind(t)

      assert is_map(por_tipo)
      assert Enum.all?(Map.keys(por_tipo), &is_binary/1)

      # A contagem é sobre a promoção vigente, e bate com a listagem.
      total_listado = length(WorkItems.list_divergences(t))
      assert Enum.sum(Map.values(por_tipo)) <= total_listado
    end
  end

  describe "o rótulo" do
    test "traduz os cinco tipos, e devolve o identificador quando não conhece" do
      for tipo <- ~w(epic_without_parts composition_makes_epic task_with_parts
                     user_story_without_parts label_vs_structure) do
        assert ConceptLabel.divergencia(tipo) != tipo
      end

      assert ConceptLabel.divergencia("tipo_novo_qualquer") == "tipo_novo_qualquer"
      assert ConceptLabel.divergencia(nil) == nil
    end
  end

  describe "gravar a divergência" do
    test "issue que só ganhou divergência é regravada", %{tenant: t, org: org} do
      # O recálculo compara a decisão com a vigente. Sem a divergência na comparação, uma
      # issue cujo conceito não muda nunca recebe a divergência descoberta depois — e no
      # dado real isso deixou 469 user stories folhas sem o sinal que já era calculado.
      {:ok, primeira} = Mapping.recompute(t, org)
      assert primeira.written > 0

      com_divergencia =
        t
        |> Mapping.decidir_lote(org, Mapping.active_rules(t, org))
        |> Enum.count(&(&1.decisao.divergence_kind != nil))

      gravadas = map_size(WorkItems.count_divergences_by_kind(t))

      assert com_divergencia == 0 or gravadas > 0, """
      A decisão calculou #{com_divergencia} divergências e o banco tem #{gravadas} tipos
      gravados. Calcular e não gravar é pior que não calcular: a tela mostra zero, e quem
      lê conclui que não há divergência nenhuma.
      """
    end
  end

  defp arvore(tenant, cenario) do
    n = System.unique_integer([:positive])

    {:ok, pai} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: n,
        title: "com partes #{n}",
        state: "OPEN",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_div_#{n}"
      })

    m = System.unique_integer([:positive])

    {:ok, filho} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: m,
        title: "parte #{m}",
        state: "OPEN",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_div_#{m}"
      })

    {:ok, _} =
      WorkItems.record_decomposition_link(tenant, %{
        parent_issue_id: pai.id,
        child_issue_id: filho.id
      })

    {pai, filho}
  end
end
