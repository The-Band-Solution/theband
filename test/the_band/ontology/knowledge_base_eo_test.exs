defmodule TheBand.Ontology.KnowledgeBaseEOTest do
  @moduledoc """
  Invariantes da declaração de EO na base de conhecimento (feature 002, F1).

  **Por que existe um teste sobre YAML.** A tarefa T001 mandava verificar a relação
  nova pela saída de `mix knowledge.graph`, e ela não serve: a task imprime uma
  linha sobre integridade de dependências entre ontologias, não a lista de relações.
  Verificar por ali seria dizer que passou sem olhar o que importa.

  O que importa são as três decisões da relação, e cada uma tem um jeito conhecido
  de ser desfeita por engano — é o que estes testes travam.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  @relation "eo.organizational_team_belongs_to_organization"

  setup_all do
    {:ok, artifacts} = KnowledgeBase.load()

    relations =
      artifacts
      |> Enum.filter(&(&1.kind == :module))
      |> Enum.flat_map(&(&1.payload["relations"] || []))

    concepts =
      artifacts
      |> Enum.filter(&(&1.kind == :module))
      |> Enum.flat_map(&(&1.payload["concepts"] || []))

    %{relations: relations, concepts: concepts}
  end

  defp relation(relations, id), do: Enum.find(relations, &(&1["id"] == id))

  describe "eo.organizational_team_belongs_to_organization (T001, FR-001)" do
    test "existe", %{relations: relations} do
      assert relation(relations, @relation),
             "a relação não está declarada; nenhuma coluna que dependa dela pode existir (ADR 0004 D4)"
    end

    test "sai do subkind, não do kind", %{relations: relations} do
      assert %{"source" => "eo.organizational_team", "target" => "eo.organization"} =
               relation(relations, @relation)
    end

    test "é association, não part_whole", %{relations: relations} do
      assert %{"type" => "association"} = relation(relations, @relation)
    end

    test "é many para one", %{relations: relations} do
      assert %{"cardinality" => %{"source" => "many", "target" => "one"}} =
               relation(relations, @relation)
    end

    test "declara proveniência própria, porque não vem de SEON", %{relations: relations} do
      assert %{"provenance" => %{"source_type" => "project_decision"}} =
               relation(relations, @relation)
    end
  end

  describe "o que a relação nova não pode ter desfeito" do
    # Estes dois são o risco R1 escrito como teste. Declarar a relação como
    # `part_whole` faria o derivador gerar a chave estrangeira sem tocar nele — é o
    # atalho tentador — e apagaria a distinção que EO faz entre unidade
    # organizacional, que é parte da organização, e equipe, que é coletivo de
    # pessoas ligado a ela. As duas coisas passariam a ser a mesma.
    test "unidade organizacional continua sendo parte da organização", %{relations: relations} do
      assert %{"type" => "part_whole"} =
               relation(relations, "eo.organizational_unit_part_of_organization")
    end

    test "nenhuma outra relação liga equipe a organização", %{relations: relations} do
      ligacoes =
        Enum.filter(relations, fn r ->
          r["target"] == "eo.organization" and r["source"] in ~w(eo.team eo.organizational_team)
        end)

      assert Enum.map(ligacoes, & &1["id"]) == [@relation],
             "duas relações ligando equipe a organização produziriam duas colunas na derivação"
    end

    test "eo.team não recebeu a relação, para não obrigar equipe de projeto", %{
      relations: relations
    } do
      refute Enum.any?(
               relations,
               &(&1["source"] == "eo.team" and &1["target"] == "eo.organization")
             ),
             "em eo.team, a relação obrigaria eo.project_team a ter organização — falso em projeto entre organizações"
    end
  end
end
