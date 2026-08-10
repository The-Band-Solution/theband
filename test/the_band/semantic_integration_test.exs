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

  describe "retrofito da organização das equipes (T011, FR-023)" do
    setup do
      tenant = tenant_fixture()

      # A ferramenta conectada é quem sempre soube qual organização estava sendo
      # observada. O payload da equipe **não** traz esse dado, e é exatamente essa
      # a situação das equipes já coletadas.
      instance = "https://github-#{System.unique_integer([:positive])}.example"

      {:ok, tool} =
        %ConnectedTool{}
        |> ConnectedTool.changeset(%{
          tenant_id: tenant.id,
          tool_type: "github",
          instance_url: instance,
          organization_login: "alfa"
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

      {:ok, org} =
        EO.upsert_organization_from_source(tenant, %{
          name: "Alfa",
          login: "alfa",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "O_alfa",
          collected_at: DateTime.utc_now(:second)
        })

      %{tenant: tenant, sync: sync, org: org, instance: instance}
    end

    defp raw_team(tenant, sync_id, external_id, payload) do
      {:ok, raw} =
        RawData.store(%{
          tenant_id: tenant.id,
          sync_id: sync_id,
          raw_entity_type: "github.team",
          external_id: external_id,
          payload: payload,
          mapping_id: "github.team.to.eo.organizational_team",
          mapping_version: 1,
          source_system: "github",
          source_instance: "https://github.com",
          collected_at: DateTime.utc_now(:second)
        })

      raw
    end

    # `project_team`, e não `organizational_team`, e a razão é o próprio sucesso da
    # feature: a restrição do banco passou a recusar equipe organizacional sem
    # organização, então o estado que o retrofito conserta **não é mais alcançável**
    # por nenhum caminho de escrita.
    #
    # Isto é o que se pode e o que não se pode afirmar. Estes testes provam o
    # mecanismo — a corrente percorrida, o relatório, e zero consultas à origem. O
    # conserto das equipes organizacionais reais foi provado por execução: 10 de 10 no
    # banco de desenvolvimento, e a migração da restrição recusaria aplicar se alguma
    # tivesse ficado. Retrofito é migração de uma vez só, não caminho permanente.
    defp equipe_sem_organizacao(tenant, external_id) do
      {:ok, team} =
        EO.upsert_team_from_source(tenant, %{
          type: "project_team",
          name: "Time #{external_id}",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: external_id,
          collected_at: DateTime.utc_now(:second)
        })

      team
    end

    test "atribui a organização sem consultar a origem", ctx do
      # Nenhuma expectativa registrada no Mox: qualquer chamada ao GitHub derruba
      # este teste sozinho. É a garantia de FR-023, não uma promessa no comentário.
      equipe = equipe_sem_organizacao(ctx.tenant, "T_1")
      raw_team(ctx.tenant, ctx.sync.id, "T_1", %{"id" => "T_1", "slug" => "time"})

      assert is_nil(equipe.organization_id)

      assert {:ok, report} = SemanticIntegration.backfill_team_organizations(ctx.tenant)
      assert report.teams == 1
      assert report.assigned == 1
      assert report.unresolved == 0

      assert [%{organization_id: org_id}] = EO.list_teams(ctx.tenant)
      assert org_id == ctx.org.id
    end

    test "equipe sem payload preservado fica sem organização, e o relatório diz", ctx do
      equipe_sem_organizacao(ctx.tenant, "T_orfa")

      assert {:ok, report} = SemanticIntegration.backfill_team_organizations(ctx.tenant)
      assert report.assigned == 0
      assert report.unresolved == 1
      assert map_size(report.reasons) == 1

      # Não adivinhada: preencher pelo nome inventaria o vínculo que esta feature
      # existe para corrigir.
      assert [%{organization_id: nil}] = EO.list_teams(ctx.tenant)
    end

    test "organização de origem ausente da base não é inventada", ctx do
      equipe_sem_organizacao(ctx.tenant, "T_2")
      raw_team(ctx.tenant, ctx.sync.id, "T_2", %{"id" => "T_2"})

      # A organização observada existe com login "alfa"; se a ferramenta apontasse
      # para outra, não haveria a que ligar.
      Repo.update_all(TheBand.Sources.ConnectedTool, set: [organization_login: "inexistente"])

      assert {:ok, report} = SemanticIntegration.backfill_team_organizations(ctx.tenant)
      assert report.assigned == 0
      assert report.unresolved == 1
    end

    test "rodar de novo não muda nada", ctx do
      equipe_sem_organizacao(ctx.tenant, "T_3")
      raw_team(ctx.tenant, ctx.sync.id, "T_3", %{"id" => "T_3"})

      {:ok, primeiro} = SemanticIntegration.backfill_team_organizations(ctx.tenant)
      {:ok, segundo} = SemanticIntegration.backfill_team_organizations(ctx.tenant)

      assert primeiro.assigned == 1
      # Nada pendente na segunda: o retrofito só olha o que está sem organização.
      assert segundo.teams == 0
      assert segundo.assigned == 0
    end

    test "não atravessa tenant", ctx do
      equipe_sem_organizacao(ctx.tenant, "T_4")
      raw_team(ctx.tenant, ctx.sync.id, "T_4", %{"id" => "T_4"})
      outro = tenant_fixture("outra-org")

      assert {:ok, %{teams: 0, assigned: 0}} =
               SemanticIntegration.backfill_team_organizations(outro)
    end
  end
end
