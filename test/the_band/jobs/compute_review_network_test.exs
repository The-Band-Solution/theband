defmodule TheBand.Jobs.ComputeReviewNetworkTest do
  @moduledoc """
  As conferências do job da rede de revisão — feature 073, T018 (FR-010; R4, R6; A10).

  ## As asserções que carregam este arquivo

  1. **A10**: tenant inexistente, tenant suspenso, organização de outro tenant e organização
     inexistente cancelam com o motivo, e **nenhuma** leitura é gravada;
  2. dois `enqueue/2` da mesma organização deixam um job só;
  3. a janela não é argumento.

  **O controle positivo da A10** (o caminho feliz grava as três janelas) é a T019: ele exige os
  parâmetros da base, que ainda não existe (T013). Até lá, a prova de que o caminho de gravação
  funciona é `commands_test.exs`, e a de que o job cancela **antes** de chegar a ele é esta: com a
  base ausente, chegar ao cálculo levantaria, e nenhum destes casos levanta.
  """
  use TheBand.DataCase, async: true

  import Ecto.Query
  import TheBand.ReviewNetworkFixtures, only: [organizacao_com_repositorio: 1]

  alias TheBand.Jobs.ComputeReviewNetwork
  alias TheBand.ReviewNetwork.Schemas.Reading
  alias TheBand.Tenants.Tenant

  defp executar(args), do: ComputeReviewNetwork.perform(%Oban.Job{args: args})

  defp leituras, do: Repo.aggregate(Reading, :count)

  test "A10: tenant inexistente cancela sem gravar" do
    org = organizacao_com_repositorio(tenant_fixture())

    assert executar(%{
             "tenant_id" => Ecto.UUID.generate(),
             "organization_id" => org.organization.id
           }) ==
             {:cancel, :tenant_not_found}

    assert leituras() == 0
  end

  test "A10: tenant suspenso cancela sem gravar" do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)

    {1, _} =
      Repo.update_all(from(t in Tenant, where: t.id == ^tenant.id), set: [status: "suspended"])

    assert executar(%{"tenant_id" => tenant.id, "organization_id" => org.organization.id}) ==
             {:cancel, :tenant_inactive}

    assert leituras() == 0
  end

  test "A10: organização de outro tenant e inexistente cancelam sem gravar" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    org_de_t2 = organizacao_com_repositorio(t2)

    assert executar(%{"tenant_id" => t1.id, "organization_id" => org_de_t2.organization.id}) ==
             {:cancel, :organization_not_found}

    assert executar(%{"tenant_id" => t1.id, "organization_id" => Ecto.UUID.generate()}) ==
             {:cancel, :organization_not_found}

    assert leituras() == 0
  end

  test "dois enqueue da mesma organização deixam um job só; outra organização tem o seu" do
    tenant = tenant_fixture()
    a = organizacao_com_repositorio(tenant)
    b = organizacao_com_repositorio(tenant)

    {:ok, primeiro} = ComputeReviewNetwork.enqueue(tenant.id, a.organization.id)
    {:ok, segundo} = ComputeReviewNetwork.enqueue(tenant.id, a.organization.id)
    {:ok, _} = ComputeReviewNetwork.enqueue(tenant.id, b.organization.id)

    assert segundo.conflict?
    assert segundo.id == primeiro.id

    assert Repo.aggregate(
             from(j in Oban.Job, where: j.worker == "TheBand.Jobs.ComputeReviewNetwork"),
             :count
           ) == 2
  end

  test "a janela não é argumento" do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)

    {:ok, job} = ComputeReviewNetwork.enqueue(tenant.id, org.organization.id)
    assert Map.keys(job.args) |> Enum.sort() == [:organization_id, :tenant_id]
  end
end
