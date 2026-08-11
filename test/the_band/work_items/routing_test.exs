defmodule TheBand.WorkItems.RoutingTest do
  @moduledoc """
  A decisão de promoção, contra os seis casos estruturais do dado real (T023).

  Medidos pela API em 2026-08-11, no repositório `theband`:

      #  1  39 partes  {Feature, Task}  → ÉPICO
      #  3   9 partes  {Task}           → ATÔMICA  ← o que não pode passar por acidente
      #  4  20 partes  {Task}           → ATÔMICA
      #  5   8 partes  {Task}           → ATÔMICA
      # 79   8 partes  {Feature, Task}  → ÉPICO
      # 98   2 partes  {Feature}        → ÉPICO

  **Três `Feature` com sub-issues que não são épicos**, porque as partes são tarefas.
  Se `#3` der épico, 78 tarefas passam a se ligar a épicos e violam `sro.rule07` — e
  nenhum outro número compensa.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems.Routing

  @tenant "github.issue_type_routing.the_band_solution"

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  defp issue(tipo, tipos_das_partes),
    do: %{issue_type: tipo, sub_issue_types: tipos_das_partes}

  describe "os seis casos reais" do
    test "#1 — Feature com 39 partes, Feature e Task: ÉPICO" do
      partes = List.duplicate("Task", 30) ++ List.duplicate("Feature", 9)
      assert Routing.decide(issue("Feature", partes)).derived == "sro.epic"
    end

    test "#3 — Feature com 9 partes, TODAS Task: ATÔMICA" do
      decisao = Routing.decide(issue("Feature", List.duplicate("Task", 9)))

      assert decisao.derived == "sro.atomic_user_story", """
      A issue #3 tem nove sub-issues, todas do tipo Task, e é ATÔMICA.

      Tarefa ATENDE a user story — sro.intended_task_planned_to_meet_user_story —, não
      a compõe. Se ela virar épico, as 78 tarefas desta organização passam a se ligar a
      épicos, violando sro.rule07, e o esforço é contado duas vezes: no épico e nas
      partes.

      É o erro mais fácil de cometer nesta regra, e o único que nenhum outro número
      compensa.
      """
    end

    test "#4 e #5 — Feature com partes só Task: ATÔMICA" do
      assert Routing.decide(issue("Feature", List.duplicate("Task", 20))).derived ==
               "sro.atomic_user_story"

      assert Routing.decide(issue("Feature", List.duplicate("Task", 8))).derived ==
               "sro.atomic_user_story"
    end

    test "#79 — Feature com Feature e Task entre as partes: ÉPICO" do
      assert Routing.decide(issue("Feature", ["Feature", "Task", "Task"])).derived ==
               "sro.epic"
    end

    test "#98 — Feature com 2 partes Feature: ÉPICO" do
      assert Routing.decide(issue("Feature", ["Feature", "Feature"])).derived == "sro.epic"
    end
  end

  describe "as rotas por declaração" do
    test "Bug vira defeito, sem depender de estrutura" do
      assert Routing.decide(issue("Bug", [])).derived == "osdef.defect"
      assert Routing.decide(issue("Bug", ["Task", "Feature"])).derived == "osdef.defect"
    end

    test "Task vira tarefa pretendida" do
      assert Routing.decide(issue("Task", [])).derived ==
               "sro.intended_scrum_development_task"
    end

    test "Feature sem partes vira atômica" do
      assert Routing.decide(issue("Feature", [])).derived == "sro.atomic_user_story"
    end
  end

  describe "a lacuna, e o nome do tipo" do
    test "tipo nulo não promove nada" do
      decisao = Routing.decide(issue(nil, []))

      assert decisao.derived == nil
      assert decisao.skip_reason == "type_absent"
    end

    test "tipo desconhecido não promove, e guarda O NOME" do
      decisao = Routing.decide(issue("Spike", []))

      assert decisao.derived == nil
      assert decisao.skip_reason == "type_unknown"

      assert decisao.skip_detail == "Spike", """
      A lacuna não guardou o nome do tipo encontrado.

      "tipo desconhecido: 14" não diz onde a regra precisa mudar. "tipo desconhecido:
      Spike (9), Chore (5)" diz.
      """
    end
  end

  describe "a divergência é registrada, não silenciada" do
    test "Epic sem partes: atômica, com a divergência" do
      decisao = Routing.decide(issue("Epic", []))

      assert decisao.declared == "sro.epic"
      assert decisao.derived == "sro.atomic_user_story"
      assert decisao.divergence =~ "não existe épico sem partes"
    end

    test "Epic com partes que são tarefas: atômica, com a divergência" do
      decisao = Routing.decide(issue("Epic", ["Task", "Task"]))

      assert decisao.derived == "sro.atomic_user_story"
      assert decisao.divergence
    end

    test "issue concordante não tem divergência" do
      refute Routing.decide(issue("Feature", [])).divergence
      refute Routing.decide(issue("Bug", [])).divergence
    end

    test "a MESMA issue diverge pela regra global e não diverge pela do tenant" do
      partes = ["Feature"]

      global = Routing.decide(issue("Feature", partes))
      tenant = Routing.decide(issue("Feature", partes), tenant_rule_id: @tenant)

      # As duas derivam épico — a estrutura é a mesma. O que muda é se houve
      # contradição com o rótulo:
      #
      #   global   lista `Feature` só como atômica → o rótulo afirmou, e a estrutura
      #            contradisse. Divergência, e é o sinal de "user story que cresceu e
      #            virou épico sem ninguém retipar";
      #   tenant   lista `Feature` como épico OU atômica → o rótulo não afirmou qual, e
      #            a estrutura completou o que ele não disse. Não há o que divergir.
      assert global.derived == "sro.epic"
      assert tenant.derived == "sro.epic"

      assert global.divergence
      refute tenant.divergence
    end
  end

  describe "a regra e a versão vêm do YAML" do
    test "toda decisão carrega qual regra decidiu, e em que versão" do
      decisao = Routing.decide(issue("Feature", []))

      assert decisao.rule_id == "github.issue_type_routing"
      assert is_integer(decisao.rule_version)
    end
  end
end
