defmodule TheBand.Ontology.AxiomasAlcancaveisTest do
  @moduledoc """
  Os axiomas da tese são alcançáveis por consulta — issue #320.

  ## O defeito que este arquivo trava

  `sro_axioms.yaml` e `spo_axioms.yaml` usam a chave de topo `rules:`, que não era nenhum dos
  nove tipos que o carregador reconhecia. Os nove axiomas caíam em `:unknown`: estavam na base,
  passavam na validação, e **nenhuma consulta por tipo os alcançava**.

  A `sro.rule07` — cuja violação a tela de processo exibe — funcionava porque estava escrita no
  código, e não porque a plataforma a lia da base. O princípio IV diz que a semântica vive no
  YAML; ela vivia, e ninguém conseguia perguntar a ela.

  **É o inverso da L57.** Lá, uma verificação filtrava um tipo que ninguém produzia e devolvia
  verde percorrendo lista vazia. Aqui um tipo era produzido e ninguém conseguia filtrá-lo. As
  duas têm a mesma forma: nada erra, nada avisa, e a consulta devolve o que não existe.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  setup_all do
    {:ok, artifacts} = KnowledgeBase.load()
    %{artifacts: artifacts}
  end

  test "nenhum arquivo de axioma é classificado como desconhecido", %{artifacts: artifacts} do
    desconhecidos =
      artifacts
      |> Enum.filter(&(&1.kind == :unknown))
      |> Enum.map(& &1.path)

    assert Enum.filter(desconhecidos, &String.contains?(&1, "axioms")) == [],
           """
           Um arquivo de axiomas voltou a cair em `:unknown`.

           Isso não quebra nada e não avisa nada: a base carrega, a validação passa, e os
           axiomas simplesmente somem de toda consulta por tipo.
           """
  end

  test "os axiomas têm tipo próprio, e não se misturam às regras de derivação", %{
    artifacts: artifacts
  } do
    axiomas = Enum.filter(artifacts, &(&1.kind == :axiom))
    derivacoes = Enum.filter(artifacts, &(&1.kind == :derivation_rule))

    assert length(axiomas) == 2, "os dois arquivos de axioma — SRO e SPO"
    assert derivacoes != []

    refute Enum.any?(derivacoes, &String.contains?(&1.path, "axioms")),
           """
           Um axioma foi classificado como regra de derivação.

           Axioma vem da tese e diz o que a rede afirma ser verdade; regra de derivação é
           decisão da plataforma sobre como derivar um valor. Juntos num tipo só, quem
           perguntasse "quais regras a plataforma decidiu" receberia os axiomas junto.
           """
  end

  describe "consultar os axiomas" do
    test "a lista devolve cada axioma, e não os dois arquivos que os contêm" do
      axiomas = KnowledgeBase.axioms()

      assert length(axiomas) == 9, "sete da SRO e dois da SPO"
      assert Enum.all?(axiomas, &is_map/1)
      assert Enum.all?(axiomas, &Map.has_key?(&1, "id"))
    end

    test "a `sro.rule07` é alcançável pela base, e não só pelo código" do
      assert {:ok, axioma} = KnowledgeBase.axiom("sro.rule07.task_never_meets_epic")

      assert axioma["ontology"] == "sro"
      assert axioma["statement"]["pt-BR"] =~ "épico"

      assert axioma["provenance"]["source_type"] == "thesis",
             "o que distingue axioma de regra de derivação é vir da tese"
    end

    test "identificador que não existe devolve erro, e não o axioma mais parecido" do
      assert :error = KnowledgeBase.axiom("sro.rule99.inexistente")
      assert :error = KnowledgeBase.axiom("sro.rule07")
    end
  end
end
