defmodule TheBand.SemanticIntegrationTest do
  @moduledoc """
  FR-017 e SC-007 — reprocessar mapeamento corrigido sem consultar a origem.

  A garantia central é verificada pela **ausência** de expectativa no Mox da borda
  HTTP: `verify_on_exit!` mais nenhuma expectativa registrada significa que
  qualquer chamada ao GitHub faz o teste falhar por si só. Não é inspeção de
  código nem promessa em comentário.
  """

  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.SemanticIntegration
  alias TheBand.Sources.ConnectedTool

  setup :verify_on_exit!

  defp raw_user(tenant, sync_id, external_id, node) do
    {:ok, raw} =
      RawData.store(%{
        tenant_id: tenant.id,
        sync_id: sync_id,
        raw_entity_type: "github.user",
        external_id: external_id,
        payload: node,
        mapping_id: "github.user.to.eo.person",
        mapping_version: 1,
        source_system: "github",
        source_instance: "https://github.com",
        collected_at: DateTime.utc_now(:second)
      })

    raw
  end

  defp sync_fixture(tenant) do
    # Instância única por chamada: o índice de unicidade da ferramenta é por
    # (tenant, tipo, instância), e um teste que precisa de duas sincronizações
    # não deveria esbarrar nele.
    instance = "https://github-#{System.unique_integer([:positive])}.example"

    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: instance,
        organization_login: "org"
      })
      |> Repo.insert()

    {:ok, sync} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        status: "completed",
        started_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    sync
  end

  describe "sem dado coletado" do
    test "devolve :no_raw_payloads em vez de um relatório de zeros" do
      tenant = tenant_fixture()

      assert {:error, :no_raw_payloads} = SemanticIntegration.reprocess_mappings(tenant)
    end
  end

  describe "reprocessamento (FR-017, SC-007)" do
    setup do
      tenant = tenant_fixture()
      sync = sync_fixture(tenant)

      raw_user(tenant, sync.id, "U_1", %{
        "__typename" => "User",
        "id" => "U_1",
        "login" => "ana",
        "name" => "Ana Souza"
      })

      raw_user(tenant, sync.id, "U_2", %{
        "__typename" => "Bot",
        "id" => "U_2",
        "login" => "dependabot[bot]",
        "name" => nil
      })

      %{tenant: tenant}
    end

    test "cria os registros a partir do payload preservado, sem chamar a origem", %{
      tenant: tenant
    } do
      # Nenhuma expectativa registrada no Mox: qualquer chamada HTTP derruba este
      # teste. É assim que SC-007 é verificado.
      assert {:ok, report} = SemanticIntegration.reprocess_mappings(tenant)

      assert report.reprocessed == 2
      assert report.created == 2
      assert report.skipped == 0

      assert EO.count_people(tenant, account_type: "person") == 1
      assert EO.count_people(tenant, account_type: ["bot", "app"]) == 1
    end

    test "conta de automação é classificada pelo __typename do payload", %{tenant: tenant} do
      {:ok, _} = SemanticIntegration.reprocess_mappings(tenant)

      assert [bot] = EO.list_people(tenant, account_type: "bot")
      assert bot.login == "dependabot[bot]"
      # Conta sem nome preenchido é registrada mesmo assim, pelo login.
      assert bot.name == "dependabot[bot]"
    end

    test "reprocessar duas vezes não altera nada na segunda", %{tenant: tenant} do
      {:ok, primeiro} = SemanticIntegration.reprocess_mappings(tenant)
      assert primeiro.created == 2

      {:ok, segundo} = SemanticIntegration.reprocess_mappings(tenant)

      assert segundo.reprocessed == 2
      assert segundo.created == 0
      assert segundo.updated == 0
      assert segundo.unchanged == 2
    end

    test "preserva collected_at original — reprocessar não é observar de novo", %{tenant: tenant} do
      {:ok, _} = SemanticIntegration.reprocess_mappings(tenant)
      [pessoa] = EO.list_people(tenant, search: "ana")
      coletado_em = pessoa.collected_at

      {:ok, _} = SemanticIntegration.reprocess_mappings(tenant)
      [depois] = EO.list_people(tenant, search: "ana")

      assert depois.collected_at == coletado_em
    end

    test "restringe a um tipo quando pedido", %{tenant: tenant} do
      assert {:error, :no_raw_payloads} =
               SemanticIntegration.reprocess_mappings(tenant, raw_entity_type: "github.team")
    end

    test "payload sem mapping_id entra em skipped, e o lote segue", %{tenant: tenant} do
      sync = sync_fixture(tenant)

      {:ok, _} =
        RawData.store(%{
          tenant_id: tenant.id,
          sync_id: sync.id,
          raw_entity_type: "github.user",
          external_id: "U_3",
          payload: %{"id" => "U_3", "login" => "sem-mapa"},
          mapping_id: nil,
          source_system: "github",
          source_instance: "https://github.com",
          collected_at: DateTime.utc_now(:second)
        })

      assert {:ok, report} = SemanticIntegration.reprocess_mappings(tenant)

      assert report.reprocessed == 3
      assert report.skipped == 1
      assert report.created == 2
      assert map_size(report.skip_reasons) == 1
    end
  end

  describe "isolamento entre tenants" do
    test "reprocessar um tenant não toca no outro" do
      um = tenant_fixture("um")
      outro = tenant_fixture("outro")
      sync = sync_fixture(um)

      raw_user(um, sync.id, "U_1", %{"id" => "U_1", "login" => "ana", "name" => "Ana"})

      {:ok, _} = SemanticIntegration.reprocess_mappings(um)

      assert EO.count_people(um) == 1
      assert EO.count_people(outro) == 0
      assert {:error, :no_raw_payloads} = SemanticIntegration.reprocess_mappings(outro)
    end
  end
end
