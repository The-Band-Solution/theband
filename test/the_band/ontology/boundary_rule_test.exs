defmodule TheBand.Ontology.BoundaryRuleTest do
  @moduledoc """
  A regra da fronteira, travada onde ela pode ser desfeita (feature 004, T002).

  **Constituição IX**: dentro de uma ontologia aplicam-se as técnicas de
  transformação; ao atravessar a fronteira aplica-se **referência** — e qual das duas
  vale é decidido pelo estereótipo declarado, nunca pela ferramenta.

  ## Por que o teste é sobre o YAML, e não sobre a saída do derivador

  A saída do derivador é conferida pelo gate de reprodutibilidade, que roda em
  `mix gates`. O que este teste trava é a **declaração**, porque é ela que decide, e
  porque as duas formas de desfazê-la são silenciosas:

    * trocar `cmpo.source_repository` para `kind` — a derivação continua passando, e
      CMPO ganha uma tabela própria. A referência se parte em duas, e "todas as
      cópias carregadas de sistema de software" passa a exigir união;
    * remover o estereótipo de `sys_swo.loaded_software_system_copy` — a derivação de
      CMPO volta a declarar exigência pendente, e o repositório fica sem tabela para
      referenciar.

  Nenhuma das duas quebra teste de aplicação. As duas quebram este.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  @subkind "cmpo.source_repository"
  @kind_referenciado "sys_swo.loaded_software_system_copy"

  setup_all do
    {:ok, artifacts} = KnowledgeBase.load()

    concepts =
      artifacts
      |> Enum.filter(&(&1.kind == :module))
      |> Enum.flat_map(&(&1.payload["concepts"] || []))
      |> Map.new(&{&1["id"], &1})

    %{concepts: concepts}
  end

  defp classification(concepts, id), do: concepts[id]["classification"] || %{}

  describe "o repositório materializa por referência" do
    test "é subkind, e não kind", %{concepts: concepts} do
      cl = classification(concepts, @subkind)

      assert cl["ontouml_stereotype"] == "subkind", """
      #{@subkind} deixou de ser subkind.

      Como kind ele ganharia tabela própria em CMPO, e a mesma coisa passaria a ter
      duas tabelas: a de sys_swo.loaded_software_system_copy e a de CMPO. "Todas as
      cópias carregadas de sistema de software" exigiria união, e a próxima ontologia
      que precisar do conceito encontraria dois lugares para apontar em vez de um.

      A referência é a decisão da constituição IX e do ADR 0004 D9.
      """
    end

    test "o pai está em outra ontologia, e é isso que faz a referência atravessar",
         %{concepts: concepts} do
      cl = classification(concepts, @subkind)

      assert cl["parent"] == @kind_referenciado
      assert ontology_of(@subkind) != ontology_of(@kind_referenciado)
    end
  end

  describe "o kind referenciado é materializável" do
    test "tem estereótipo, e é kind", %{concepts: concepts} do
      cl = classification(concepts, @kind_referenciado)

      assert cl["ontouml_stereotype"] == "kind", """
      #{@kind_referenciado} perdeu o estereótipo de kind.

      Sem ele a derivação de CMPO volta a declarar exigência pendente, e
      #{@subkind} fica sem tabela para referenciar — o repositório seria uma linha
      numa tabela que não existe.

      Ele é kind porque não declara supertipo: fornece o próprio princípio de
      identidade.
      """
    end

    test "não declara supertipo, o que torna `kind` a única leitura", %{concepts: concepts} do
      refute classification(concepts, @kind_referenciado)["parent"]
    end
  end

  describe "a exigência foi atendida por conceito, não por ontologia" do
    test "os demais conceitos da SysSwO seguem sem estereótipo", %{concepts: concepts} do
      sem_estereotipo =
        concepts
        |> Enum.filter(fn {id, c} ->
          ontology_of(id) == "sys_swo" and
            is_nil((c["classification"] || %{})["ontouml_stereotype"])
        end)
        |> Enum.map(&elem(&1, 0))

      # Não é lacuna a fechar: é a constituição IX funcionando. Anotar a ontologia
      # inteira para registrar um repositório seria o pré-requisito disfarçado que o
      # princípio nomeia. Se alguém anotar os dez, este teste avisa — e a decisão
      # passa a ser deliberada em vez de arrastada por uma feature de ingestão.
      assert length(sem_estereotipo) == 10, """
      A quantidade de conceitos da SysSwO sem estereótipo mudou: #{length(sem_estereotipo)}.

      Se subiu, alguém removeu a anotação de #{@kind_referenciado}.
      Se caiu, alguém anotou conceitos além do que a referência exigia — o que pode
      estar certo, e precisa ser decisão declarada em vez de efeito colateral.

      Sem estereótipo: #{Enum.join(sem_estereotipo, ", ")}
      """
    end
  end

  defp ontology_of(concept_id), do: concept_id |> String.split(".") |> hd()
end
