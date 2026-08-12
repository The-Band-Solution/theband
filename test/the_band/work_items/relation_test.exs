defmodule TheBand.WorkItems.RelationTest do
  @moduledoc """
  `Axioms.relacao/2` — qual relação o vínculo é (T001).

  ## Os dois `nil` que este teste separa

  Em `rule07/2`, `nil` no conceito do pai significa **não tem pai**. Em `relacao/2` significa **o
  pai existe e não foi promovido**. Confundi-los faria a tela dizer *task without parent* sobre uma
  issue que **tem** pai — e o caso está asserido abaixo, porque é o erro mais fácil de cometer aqui.

  ## E o que este teste recusa

  Nenhum caso devolve `:composicao` para filha promovida a defeito. A rede de ontologias não nomeia
  essa relação, e encaixá-la em composição daria à tela uma convicção que a rede não sustenta.
  """
  use ExUnit.Case, async: true

  alias TheBand.WorkItems.Axioms

  @tarefa "sro.intended_scrum_development_task"
  @user_story "sro.atomic_user_story"
  @epico "sro.epic"
  @defeito "osdef.defect"

  describe "atendimento" do
    test "tarefa sob user story atende — são 1 136 vínculos no dado real" do
      assert Axioms.relacao(@tarefa, @user_story) == :atendimento
    end

    test "tarefa sob defeito também atende — são 7" do
      assert Axioms.relacao(@tarefa, @defeito) == :atendimento
    end
  end

  describe "composição" do
    test "user story sob épico compõe — são 178" do
      assert Axioms.relacao(@user_story, @epico) == :composicao
    end

    test "épico sob épico compõe — são 14" do
      assert Axioms.relacao(@epico, @epico) == :composicao
    end

    test "user story sob user story compõe — são 5, e quem decide é o conceito da filha" do
      assert Axioms.relacao(@user_story, @user_story) == :composicao
    end
  end

  describe "violação" do
    test "tarefa sob épico viola a sro.rule07 — são 293" do
      assert Axioms.relacao(@tarefa, @epico) == {:violacao, :task_parent_is_epic}
    end

    test "a decisão é do axioma que já existia, não de uma segunda implementação" do
      # Se `rule07/2` mudar, `relacao/2` muda com ela. É a FR-006, e é o que impede a coluna de
      # avisar sobre uma issue que o painel da mesma tela declara correta.
      assert Axioms.rule07(@tarefa, @epico) == {:violation, :task_parent_is_epic}
      assert Axioms.relacao(@tarefa, @epico) == {:violacao, :task_parent_is_epic}
    end
  end

  describe "o que a ontologia não nomeia" do
    test "filha promovida a defeito não é composição nem atendimento — são 33" do
      assert Axioms.relacao(@defeito, @epico) == :nao_nomeada
      assert Axioms.relacao(@defeito, @user_story) == :nao_nomeada
      assert Axioms.relacao(@defeito, @defeito) == :nao_nomeada
    end

    test "nenhum pai transforma defeito em composição" do
      for pai <- [@epico, @user_story, @tarefa, @defeito, "sro.sprint"] do
        refute Axioms.relacao(@defeito, pai) == :composicao
      end
    end
  end

  describe "os dois nil, e a ordem das cláusulas que os separa" do
    test "pai sem conceito não é 'tarefa sem pai'" do
      assert Axioms.relacao(@tarefa, nil) == :pai_sem_conceito

      # O caminho errado, para deixar claro o que está sendo evitado: passar esse `nil` ao axioma
      # devolveria a violação de quem **não tem** pai.
      assert Axioms.rule07(@tarefa, nil) == {:violation, :task_without_parent}
    end

    test "filha sem conceito não é decidível, e a tela não inventa" do
      assert Axioms.relacao(nil, @epico) == :filha_sem_conceito
    end

    test "sem os dois conceitos, a filha manda — é dela que a relação depende" do
      assert Axioms.relacao(nil, nil) == :filha_sem_conceito
    end
  end
end
