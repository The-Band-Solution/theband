defmodule TheBand.Ontology.SEON.EO.ReviewNetworkReadsTest do
  @moduledoc """
  As três leituras de EO que a rede de revisão pede — feature 073, T006
  (`contracts/fronteiras.md`, seção EO; R4 da segurança).

  1. `fetch_organization/2` busca por id **e** tenant: a organização de outro tenant e o id
     malformado são `{:error, :not_found}`, o mesmo dos dois;
  2. `account_types/2` não devolve pessoa de outro tenant;
  3. `organization_person_ids/2` não devolve pessoa só de outra organização, nem bot.
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures, only: [pessoa: 2, pessoa: 3]

  alias TheBand.Ontology.SEON.EO

  describe "fetch_organization/2" do
    test "acha a organização do próprio tenant" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant)

      assert {:ok, %{id: id}} = EO.fetch_organization(tenant, org.id)
      assert id == org.id
    end

    test "a organização de outro tenant não existe para este" do
      t1 = tenant_fixture()
      t2 = tenant_fixture()
      org_de_t1 = organization_fixture(t1)

      assert {:ok, _} = EO.fetch_organization(t1, org_de_t1.id)
      assert EO.fetch_organization(t2, org_de_t1.id) == {:error, :not_found}
    end

    test "id malformado e inexistente são o mesmo não encontrado" do
      tenant = tenant_fixture()

      assert EO.fetch_organization(tenant, "não-é-uuid") == {:error, :not_found}
      assert EO.fetch_organization(tenant, Ecto.UUID.generate()) == {:error, :not_found}
      assert EO.fetch_organization(tenant, nil) == {:error, :not_found}
    end
  end

  describe "account_types/2" do
    test "devolve o tipo de cada pessoa do tenant, e omite a de outro" do
      t1 = tenant_fixture()
      t2 = tenant_fixture()
      ana = pessoa(t1, "Ana")
      robo = pessoa(t1, "Robo", "bot")
      de_fora = pessoa(t2, "Fora")

      tipos = EO.account_types(t1, [ana.id, robo.id, de_fora.id])

      assert tipos == %{ana.id => "person", robo.id => "bot"}
    end

    test "lista vazia não consulta" do
      assert EO.account_types(tenant_fixture(), []) == %{}
    end
  end

  describe "organization_person_ids/2" do
    test "só as pessoas, e só as da organização" do
      tenant = tenant_fixture()
      org_a = organization_fixture(tenant)
      org_b = organization_fixture(tenant)

      equipe_a =
        team_fixture(tenant, "T_a_#{System.unique_integer([:positive])}", %{organization: org_a})

      equipe_b =
        team_fixture(tenant, "T_b_#{System.unique_integer([:positive])}", %{organization: org_b})

      ana = pessoa(tenant, "Ana")
      robo = pessoa(tenant, "Robo", "bot")
      bia_so_de_b = pessoa(tenant, "Bia")

      vincular(tenant, ana, equipe_a)
      vincular(tenant, robo, equipe_a)
      vincular(tenant, bia_so_de_b, equipe_b)

      assert EO.organization_person_ids(tenant, org_a.id) == [ana.id]
      assert EO.organization_person_ids(tenant, org_b.id) == [bia_so_de_b.id]
    end
  end

  defp vincular(tenant, pessoa, equipe) do
    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: pessoa.external_id,
        team_external_id: equipe.external_id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com"
      })
  end
end
