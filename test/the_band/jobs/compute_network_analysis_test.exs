defmodule TheBand.Jobs.ComputeNetworkAnalysisTest do
  @moduledoc """
  As conferências do job da análise de rede, e o encadeamento depois da 073 — feature 076, T013
  (FR-017; R3, R4; A14).

  ## As asserções que carregam este arquivo

  1. **controle positivo**: com tenant e organização válidos, o job chega ao cálculo e devolve
     `:ok` — é o que dá sentido ao "nenhuma leitura" dos casos de cancelamento. Nesta fatia
     nenhuma rede tem fonte ligada (`Inputs`, T028), e por isso o controle de que o cálculo
     **grava** é `commands_test.exs`; aqui o controle é que o job passou das conferências;
  2. **A14**: tenant inexistente, tenant suspenso, organização de outro tenant e organização
     inexistente cancelam com o motivo, e **nenhuma** leitura é gravada;
  3. `network` e `window` nos argumentos são ignorados;
  4. o caminho feliz da 073 enfileira **exatamente um** job da análise, para a mesma organização.

  **Defeito a injetar**: trocar o cancelamento da organização de outro tenant por leitura vazia;
  o caso de outro tenant reprova.
  """
  use TheBand.DataCase, async: false

  import TheBand.ReviewNetworkFixtures

  alias TheBand.Jobs.ComputeNetworkAnalysis
  alias TheBand.Jobs.ComputeReviewNetwork
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Tenants.Tenant

  setup do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  defp executar(args), do: ComputeNetworkAnalysis.perform(%Oban.Job{args: args})

  defp leituras, do: Repo.aggregate(Reading, :count)

  test "controle: tenant e organização válidos passam das conferências e chegam ao cálculo" do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)

    assert executar(%{"tenant_id" => tenant.id, "organization_id" => org.organization.id}) == :ok
  end

  test "A14: tenant inexistente cancela sem gravar" do
    org = organizacao_com_repositorio(tenant_fixture())

    assert executar(%{
             "tenant_id" => Ecto.UUID.generate(),
             "organization_id" => org.organization.id
           }) ==
             {:cancel, :tenant_not_found}

    assert leituras() == 0
  end

  test "A14: tenant suspenso cancela sem gravar" do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)

    {1, _} =
      Repo.update_all(from(t in Tenant, where: t.id == ^tenant.id), set: [status: "suspended"])

    assert executar(%{"tenant_id" => tenant.id, "organization_id" => org.organization.id}) ==
             {:cancel, :tenant_inactive}

    assert leituras() == 0
  end

  test "A14: organização de outro tenant e inexistente cancelam sem gravar" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    org_de_t2 = organizacao_com_repositorio(t2)

    assert executar(%{"tenant_id" => t1.id, "organization_id" => org_de_t2.organization.id}) ==
             {:cancel, :organization_not_found}

    assert executar(%{"tenant_id" => t1.id, "organization_id" => Ecto.UUID.generate()}) ==
             {:cancel, :organization_not_found}

    assert executar(%{"tenant_id" => t1.id, "organization_id" => "nao-e-uuid"}) ==
             {:cancel, :organization_not_found}

    assert leituras() == 0
  end

  test "network e window nos argumentos são ignorados" do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)

    assert executar(%{
             "tenant_id" => tenant.id,
             "organization_id" => org.organization.id,
             "network" => "collab",
             "window" => 36_500
           }) == :ok

    refute Repo.exists?(
             from r in Reading, where: r.network == "collab" or r.window_days == 36_500
           )
  end

  test "o caminho feliz da 073 enfileira exatamente um job da análise" do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)
    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    agora = DateTime.utc_now(:second)
    cr = solicitacao(tenant, org.observed_repository_id, bia, DateTime.add(agora, -5 * 86_400))
    revisao(tenant, cr, ana, DateTime.add(agora, -4 * 86_400))

    args = %{"tenant_id" => tenant.id, "organization_id" => org.organization.id}
    assert ComputeReviewNetwork.perform(%Oban.Job{args: args}) == :ok
    # Duas passadas: a unicidade deixa um só pendente.
    assert ComputeReviewNetwork.perform(%Oban.Job{args: args}) == :ok

    jobs =
      Repo.all(
        from j in Oban.Job,
          where: j.worker == "TheBand.Jobs.ComputeNetworkAnalysis"
      )

    assert [%Oban.Job{queue: "network_analysis", args: job_args}] = jobs
    assert job_args == args
  end
end
