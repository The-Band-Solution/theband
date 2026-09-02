defmodule TheBand.Ontology.SEON.EO.EquipeDaEstruturaTest do
  @moduledoc """
  Feature 055, US1 — a organização cria a equipe que o GitHub não conhece.

  **A equipe da estrutura não é a equipe de projeto**, e a diferença não é
  cosmética: `create_declared_team/3` nasce `project_team` **sem organização**,
  porque o que justifica aquele tipo é o vínculo com projeto. A desta feature tem
  organização e é `organizational_team`.

  Os dois primeiros casos existem para que ninguém generalize as duas numa função
  só: as invariantes se contradizem — organização nula é *exigida* lá e
  *proibida* aqui.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  describe "a equipe da estrutura (FR-001)" do
    test "nasce com organização, tipo organizacional e autor" do
      tenant = tenant_fixture()
      autor = user_fixture(tenant)
      org = organization_fixture(tenant)

      assert {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Plataforma", autor.id)

      assert equipe.name == "Plataforma"
      assert equipe.organization_id == org.id
      assert equipe.type == "organizational_team"
      assert equipe.declared_by_user_id == autor.id
    end

    test "a proveniência diz que foi declarada, não observada (FR-002)" do
      tenant = tenant_fixture()
      autor = user_fixture(tenant)
      org = organization_fixture(tenant)

      {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Dados", autor.id)

      # É por aqui que a tela distingue as duas origens. Sem isso, uma equipe
      # declarada apareceria como se o GitHub a tivesse mostrado.
      assert equipe.source_system == "the_band"
      assert equipe.source_instance == "declared"
    end

    test "sem organização é recusado — a equipe da estrutura pertence a uma" do
      tenant = tenant_fixture()
      autor = user_fixture(tenant)

      assert {:error, _} = EO.declare_structural_team(tenant, nil, "Solta", autor.id)
    end

    test "nome repetido na MESMA organização é recusado, dizendo a razão (FR-001)" do
      # Dois times com o mesmo nome na mesma organização tornam impossível saber
      # de qual deles um painel fala.
      tenant = tenant_fixture()
      autor = user_fixture(tenant)
      org = organization_fixture(tenant)

      {:ok, _} = EO.declare_structural_team(tenant, org.id, "Plataforma", autor.id)

      assert {:error, motivo} = EO.declare_structural_team(tenant, org.id, "Plataforma", autor.id)
      assert motivo =~ "já"
    end

    test "o mesmo nome em organizações DIFERENTES é permitido" do
      tenant = tenant_fixture()
      autor = user_fixture(tenant)
      org_a = organization_fixture(tenant, "acme")
      org_b = organization_fixture(tenant, "globex")

      assert {:ok, _} = EO.declare_structural_team(tenant, org_a.id, "Plataforma", autor.id)
      assert {:ok, _} = EO.declare_structural_team(tenant, org_b.id, "Plataforma", autor.id)
    end
  end

  describe "a equipe de projeto continua como estava (decisão 4 do plano)" do
    test "create_declared_team segue nascendo project_team e sem organização" do
      tenant = tenant_fixture()
      autor = user_fixture(tenant)

      {:ok, equipe} = EO.create_declared_team(tenant, "Time do projeto X", autor.id)

      assert equipe.type == "project_team"
      assert is_nil(equipe.organization_id)
    end
  end
end
