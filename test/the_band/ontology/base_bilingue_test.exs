defmodule TheBand.Ontology.BaseBilingueTest do
  @moduledoc """
  A base bilíngue — 075, #1312. Contrato em
  `specs/075-site-de-desenvolvedores/contracts/base-bilingue.md`.

  A justificativa e as limitações de um mapeamento passaram de string a "string ou mapa de
  idioma". O que se prova aqui é o que não pode mudar com isso: o schema aceita as duas formas
  e recusa a terceira, a justificativa vazia continua reprovada mesmo dentro do mapa, e quem
  lia português continua recebendo string em português.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SchemaCheck
  alias TheBand.Ontology.YamlLoader
  alias TheBand.Ontology.YamlValidator
  alias TheBand.SemanticIntegration.Mapper

  # Os schemas reais, e não uma cópia: a forma testada é a que o gate aplica.
  defp schemas do
    {:ok, artefatos} = YamlLoader.load_all()
    Enum.filter(artefatos, &String.starts_with?(&1.path, "schemas/"))
  end

  defp mapeamento(semantica, limitacoes) do
    data = %{
      "mapping" => %{"id" => "m.bilingue", "version" => 1, "status" => "proposed"},
      "source" => %{"provider" => "github", "entity" => "x"},
      "target" => %{"ontology" => "eo", "concept" => "eo.person"},
      "semantics" => Map.merge(%{"equivalence" => "partial"}, semantica),
      "identity" => %{"external_id_path" => "id"},
      "limitations" => limitacoes,
      "provenance" => %{"preserve_raw_payload" => true, "required_fields" => ["source_system"]}
    }

    %{
      kind: :mapping,
      id: "m.bilingue",
      path: "fake/m.yaml",
      data: data,
      payload: YamlLoader.payload(data, :mapping)
    }
  end

  defp forma(semantica, limitacoes),
    do: SchemaCheck.problems(schemas() ++ [mapeamento(semantica, limitacoes)])

  describe "pt_br/1" do
    test "a string é o próprio português" do
      assert KnowledgeBase.pt_br("Não é o merge.") == "Não é o merge."
    end

    test "do mapa de idioma sai o pt-BR, e nunca o en" do
      assert KnowledgeBase.pt_br(%{"pt-BR" => "Não é o merge.", "en" => "It is not the merge."}) ==
               "Não é o merge."
    end

    test "mapa sem pt-BR falha alto, em vez de virar texto vazio" do
      assert_raise FunctionClauseError, fn -> KnowledgeBase.pt_br(%{"en" => "only English"}) end
    end
  end

  describe "o schema do mapeamento" do
    test "aceita justificativa e limitação em string, como a base nasceu" do
      assert forma(%{"justification" => "j"}, ["l"]) == []
    end

    test "aceita justificativa e limitação em mapa de idioma" do
      assert forma(%{"justification" => %{"pt-BR" => "j", "en" => "j"}}, [
               %{"pt-BR" => "l", "en" => "l"},
               "só português"
             ]) == []
    end

    test "recusa o mapa sem pt-BR: seria tradução sem original" do
      problemas = forma(%{"justification" => %{"en" => "j"}}, ["l"])
      assert Enum.any?(problemas, &(&1 =~ "semantics.justification"))
    end

    test "recusa o mapa com idioma que o schema não declara" do
      problemas = forma(%{"justification" => "j"}, [%{"pt-BR" => "l", "es" => "l"}])
      assert Enum.any?(problemas, &(&1 =~ "limitations.0"))
    end
  end

  test "justificativa em mapa com pt-BR vazio é a mesma ausência que a string vazia" do
    artefato = mapeamento(%{"justification" => %{"pt-BR" => "  ", "en" => "j"}}, ["l"])

    {:error, problemas} = YamlValidator.validate([artefato])

    assert Enum.any?(problemas, &(&1 =~ "mapeamento não declara `semantics.justification`"))
  end

  test "as limitações que o Mapper devolve são string em português, venha o item como vier" do
    for %{"mapping" => %{"id" => id}, "limitations" => cruas} <- KnowledgeBase.list(:mapping) do
      lidas = Mapper.limitations(id)

      assert Enum.all?(lidas, &is_binary/1), "#{id}: o Mapper vazou o mapa de idioma"
      assert lidas == Enum.map(cruas, &KnowledgeBase.pt_br/1)
    end
  end
end
