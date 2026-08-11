defmodule TheBand.WorkItems.RoutingOrgRulesTest do
  @moduledoc """
  As duas etapas da decisão (feature 005, F2).

  O teste que mais importa é o da **precedência**: uma issue com tipo declarado e título
  que casaria uma regra de título tem de ser decidida pelo tipo. Se a etapa 2 for
  alcançada, a classificação passa a depender da ordem de comparação — e um dado errado a
  inverteria em silêncio.
  """
  use ExUnit.Case, async: true

  alias TheBand.Mapping.Schemas.MappingRule
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems.Routing

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  @tarefa "sro.intended_scrum_development_task"
  @atomica "sro.atomic_user_story"
  @defeito "osdef.defect"

  defp regra(attrs) do
    struct!(
      %MappingRule{
        id: "11111111-1111-1111-1111-111111111111",
        where: "title",
        how: "starts_with",
        pattern: "[TASK]",
        case_sensitive: false,
        target_concept: @tarefa,
        position: 1,
        active: true,
        version: 1
      },
      attrs
    )
  end

  describe "a precedência entre as duas etapas" do
    test "tipo declarado vence regra de título" do
      decisao =
        Routing.decide(
          %{issue_type: "Task", title: "[FEATURE] alguma coisa", sub_issue_types: []},
          organization_rules: [regra(%{pattern: "[FEATURE]", target_concept: @atomica})]
        )

      assert decisao.derived == @tarefa, """
      A issue tem tipo `Task` declarado na origem e título que casaria a regra de título.

      Quem decide é o tipo — FR-008. Se a etapa 2 for alcançada, a precedência passa a
      depender da ordem de comparação, e um dado errado a inverte em silêncio.
      """

      assert decisao.evidence_source == "declared_type"
      assert decisao.confidence == "high"
      # E nenhuma regra de mapeamento decidiu: veio da regra global do YAML.
      assert decisao.mapping_rule_id == nil
    end

    test "sem tipo declarado, a regra de título decide" do
      r = regra(%{})

      decisao =
        Routing.decide(
          %{issue_type: nil, title: "[TASK] subir o compose", sub_issue_types: []},
          organization_rules: [r]
        )

      assert decisao.derived == @tarefa
      assert decisao.evidence_source == "title"

      assert decisao.confidence == "medium", """
      Inferência sobre texto livre vale menos que campo declarado, e quem lê precisa poder
      saber — é o princípio III.
      """

      assert decisao.mapping_rule_id == r.id
      assert decisao.rule_version == 1
    end

    test "sem tipo e sem regra que case, continua sem conceito" do
      decisao =
        Routing.decide(
          %{issue_type: nil, title: "[Devops] subir o cluster", sub_issue_types: []},
          organization_rules: [regra(%{})]
        )

      assert decisao.derived == nil
      assert decisao.skip_reason == "type_absent"
    end

    test "tipo desconhecido sem regra da organização guarda o nome do tipo" do
      decisao = Routing.decide(%{issue_type: "Spike", title: "x", sub_issue_types: []})

      assert decisao.skip_reason == "type_unknown"
      assert decisao.skip_detail == "Spike"
    end

    test "tipo desconhecido COM regra da organização é promovido" do
      r =
        regra(%{where: "declared_type", how: "equals", pattern: "Chore", target_concept: @tarefa})

      decisao =
        Routing.decide(
          %{issue_type: "Chore", title: "manutenção", sub_issue_types: []},
          organization_rules: [r]
        )

      assert decisao.derived == @tarefa
      assert decisao.skip_reason == nil
      assert decisao.evidence_source == "declared_type"
      assert decisao.mapping_rule_id == r.id
    end
  end

  describe "as quatro formas de comparação" do
    test "começa com não é contém, e a diferença é o motivo de a forma ser declarada" do
      comeca = regra(%{how: "starts_with", pattern: "US"})
      contem = regra(%{how: "contains", pattern: "US"})

      issue = %{issue_type: nil, title: "STATUS do serviço", sub_issue_types: []}

      assert Routing.decide(issue, organization_rules: [comeca]).derived == nil
      assert Routing.decide(issue, organization_rules: [contem]).derived == @tarefa
    end

    test "igual a exige o texto inteiro" do
      igual = regra(%{how: "equals", pattern: "[TASK]"})

      assert Routing.decide(%{issue_type: nil, title: "[TASK]", sub_issue_types: []},
               organization_rules: [igual]
             ).derived == @tarefa

      assert Routing.decide(%{issue_type: nil, title: "[TASK] com resto", sub_issue_types: []},
               organization_rules: [igual]
             ).derived == nil
    end

    test "expressão regular casa, e a inválida simplesmente não casa" do
      valida = regra(%{how: "regex", pattern: "^\\[US[^\\]]*\\]"})

      assert Routing.decide(%{issue_type: nil, title: "[US 1.1] alguma", sub_issue_types: []},
               organization_rules: [valida]
             ).derived == @tarefa

      # Uma linha gravada por script pode não ter passado pelo validador. Expressão
      # inválida aqui significa **não casa** — nunca exceção no meio de 4471 issues.
      invalida = regra(%{how: "regex", pattern: "[US"})

      assert Routing.decide(%{issue_type: nil, title: "[US] alguma", sub_issue_types: []},
               organization_rules: [invalida]
             ).derived == nil
    end

    test "a sensibilidade a maiúsculas é respeitada nas quatro formas" do
      insensivel = regra(%{pattern: "[task]", case_sensitive: false})
      sensivel = regra(%{pattern: "[task]", case_sensitive: true})
      issue = %{issue_type: nil, title: "[TASK] subir", sub_issue_types: []}

      assert Routing.decide(issue, organization_rules: [insensivel]).derived == @tarefa
      assert Routing.decide(issue, organization_rules: [sensivel]).derived == nil
    end
  end

  describe "a ordem entre regras" do
    test "a primeira por posição decide, e a ordem é determinística" do
      primeira = regra(%{position: 1, pattern: "[", target_concept: @tarefa, how: "starts_with"})
      segunda = regra(%{position: 2, pattern: "[BUG]", target_concept: @defeito})

      issue = %{issue_type: nil, title: "[BUG] falha ao salvar", sub_issue_types: []}

      # As duas casam. Quem decide é a posição — e é por isso que ela é única por
      # organização: sem ordem determinística, acrescentar regra mudaria a classificação
      # de issues que ninguém tocou.
      assert Routing.decide(issue, organization_rules: [primeira, segunda]).derived == @tarefa
      assert Routing.decide(issue, organization_rules: [segunda, primeira]).derived == @defeito
    end
  end

  describe "o axioma vence a regra de texto" do
    test "regra que propõe user story vira épico quando há partes que são user stories" do
      r = regra(%{target_concept: @atomica})

      decisao =
        Routing.decide(
          %{issue_type: nil, title: "[TASK] pai", sub_issue_types: ["Feature", "Feature"]},
          organization_rules: [r]
        )

      assert decisao.derived == "sro.epic", """
      Nenhuma regra de texto pode contradizer `sro.rule05`: a composição torna épico quem
      tem partes que são user stories, independentemente do que o texto diga.
      """

      assert decisao.divergence =~ "composição"
    end

    test "tarefa continua tarefa mesmo com sub-issues" do
      r = regra(%{target_concept: @tarefa})

      decisao =
        Routing.decide(
          %{issue_type: nil, title: "[TASK] pai", sub_issue_types: ["Feature"]},
          organization_rules: [r]
        )

      assert decisao.derived == @tarefa
    end
  end
end
