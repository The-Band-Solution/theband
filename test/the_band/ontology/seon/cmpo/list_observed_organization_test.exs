defmodule TheBand.Ontology.SEON.CMPO.ListObservedOrganizationTest do
  @moduledoc """
  `CMPO.list_observed/2` com `organization_id:` — feature 073, T007. A rede de revisão é por
  organização observada (R4), e o filtro é no banco.
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures, only: [organizacao_com_repositorio: 2]

  alias TheBand.Ontology.SEON.CMPO

  test "com organization_id, só os repositórios daquela organização" do
    tenant = tenant_fixture()
    a = organizacao_com_repositorio(tenant, "org-a-#{System.unique_integer([:positive])}")
    b = organizacao_com_repositorio(tenant, "org-b-#{System.unique_integer([:positive])}")

    so_a = CMPO.list_observed(tenant, organization_id: a.organization.id)
    assert Enum.map(so_a, & &1.observed_repository_id) == [a.observed_repository_id]

    so_b = CMPO.list_observed(tenant, organization_id: b.organization.id)
    assert Enum.map(so_b, & &1.observed_repository_id) == [b.observed_repository_id]

    # Sem a opção, o resultado é o de hoje: as duas.
    assert length(CMPO.list_observed(tenant)) == 2
  end
end
