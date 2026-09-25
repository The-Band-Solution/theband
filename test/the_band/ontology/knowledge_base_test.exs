defmodule TheBand.Ontology.KnowledgeBaseTest do
  @moduledoc """
  `KnowledgeBase.measurement/1` — feature 062, T003.

  O envelope do MCP lê daqui as ressalvas de cada medida (FR-011). A asserção que importa é a de
  conteúdo, e não a de chave: uma função que devolvesse sempre `misinterpretations: []` passaria
  num teste que só conferisse se a chave existe, e o agente receberia a medida sem a ressalva
  que a base declara.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  test "a medida que existe volta com as ressalvas que a base declara" do
    assert {:ok, medida} = KnowledgeBase.measurement("flow.per_person.readings")

    assert medida["id"] == "flow.per_person.readings"
    assert [_ | _] = medida["limitations"], "a medida voltou sem limitations"
    assert [_ | _] = medida["misinterpretations"], "a medida voltou sem misinterpretations"
  end

  test "a medida que não existe devolve :error, como as irmãs" do
    assert KnowledgeBase.measurement("nao.existe") == :error
  end

  test "o identificador de outro tipo não casa com medida" do
    # `profile.thresholds` existe como regra. Buscar medida por ele tem de falhar, e não
    # devolver a regra: o tipo faz parte da chave.
    assert {:ok, _} = KnowledgeBase.rule("profile.thresholds")
    assert KnowledgeBase.measurement("profile.thresholds") == :error
  end
end
