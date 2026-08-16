defmodule TheBand.Projects.FieldMappingTest do
  @moduledoc """
  O mapeamento campo→atributo — issue #180, FR-024 a FR-027 e FR-046.

  ## As asserções que carregam este arquivo

  1. **a interpretação vem da declaração, nunca do nome** — sem entrada, cru;
  2. **FR-046**: seleção única mapeada para atributo numérico é **recusada** — o valor
     fica cru, e a recusa é silenciosa para a tela (não interpretado) e visível para quem
     compara o tipo declarado com o real;
  3. **o rename não desfaz o mapeamento** — a identidade é o id da origem (FR-027);
  4. **a regra real do tenant valida e resolve** — a sobrescrita
     `github.project_field_mapping.the_band_solution` existe na base e mapeia Estimate.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Projects

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, _admin} = tenant_with_admin()
    %{tenant: tenant}
  end

  @mapeamento %{
    "PVTF_estimate" => %{"attribute" => "sro.user_story.complexity", "field_type" => "NUMBER"},
    "PVTSSF_prio" => %{"attribute" => "sro.user_story.importance", "field_type" => "NUMBER"}
  }

  describe "interpretation_for/3" do
    test "campo mapeado com o tipo certo interpreta" do
      assert Projects.interpretation_for(@mapeamento, "PVTF_estimate", "NUMBER") ==
               "sro.user_story.complexity"
    end

    test "sem entrada, cru — o nome do campo não decide nada" do
      assert Projects.interpretation_for(@mapeamento, "PVTF_importance", "NUMBER") == nil
    end

    test "FR-046: seleção única mapeada para atributo numérico é recusada" do
      # A entrada declara field_type NUMBER; o campo real é SINGLE_SELECT. Honrar o
      # mapeamento afirmaria uma escala que ninguém declarou — P1 não é 1.0.
      assert Projects.interpretation_for(@mapeamento, "PVTSSF_prio", "SINGLE_SELECT") == nil
    end

    test "entrada sem field_type aceita qualquer tipo — a restrição é opt-in" do
      solto = %{"PVTF_x" => %{"attribute" => "sro.user_story.complexity"}}
      assert Projects.interpretation_for(solto, "PVTF_x", "TEXT") == "sro.user_story.complexity"
    end
  end

  describe "a regra real da base" do
    test "a sobrescrita do tenant the-band-solution resolve e mapeia o Estimate" do
      # O slug real vira o sufixo da regra; o tenant do teste tem outro slug e cai na
      # global vazia — os dois caminhos exercitados.
      {:ok, regra} = KnowledgeBase.rule("github.project_field_mapping.the_band_solution")
      valores = get_in(regra, ["rules", "fields", "values"])

      assert %{"attribute" => "sro.user_story.complexity", "field_type" => "NUMBER"} =
               valores["PVTF_lADODw6Ft84BLwWDzg7PAW8"]
    end

    test "tenant sem sobrescrita cai na global, que é vazia de propósito", ctx do
      assert Projects.field_mappings(ctx.tenant) == %{},
             "a global deixou de ser vazia — mapeamento global inferiria para todo tenant"
    end
  end
end
