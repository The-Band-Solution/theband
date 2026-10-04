defmodule TheBand.Jobs.OrganizacaoInativaTest do
  @moduledoc """
  Organização suspensa não trabalha — issue #1033, achado O7 da avaliação da spec 070.

  Antes desta correção, nenhum worker lia `tenants.status`: a organização suspensa seguia sendo
  coletada a cada cinco minutos e entrava na rodada mensal de perfis, que **envia dado de pessoa
  ao provedor do modelo**.

  ## A guarda que pega o worker novo

  O primeiro teste enumera todo módulo da aplicação que implementa `Oban.Worker` e exige que ele
  esteja classificado aqui: ou trabalha **por tenant**, e tem teste de efeito zero com a
  organização suspensa neste arquivo, ou é **da instalação** (Cron), sem tenant nos argumentos.
  Worker que nasce sem classificação reprova, e quem o escreveu tem de decidir.

  Mox só na borda HTTP. Nenhuma expectativa no mock é a prova de que nada saiu: uma chamada
  inesperada levanta `Mox.UnexpectedCallError`.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.ProfileRunFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Jobs.{ComputeReviewNetwork, RecomputePromotions, ReprocessMappings, SyncGitHubEO}
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Profiles.{Automation, GenerateWorker, RunEntry, Runs, RunWorker}
  alias TheBand.Sources.{ConnectedTool, ToolCredential}
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant

  setup :verify_on_exit!

  # Cada um tem, abaixo, o teste de que a organização suspensa não produz efeito.
  @por_tenant [
    ComputeReviewNetwork,
    GenerateWorker,
    RecomputePromotions,
    ReprocessMappings,
    RunWorker,
    SyncGitHubEO
  ]

  # Não recebem tenant: agem sobre a instalação, e quem filtra é a função que eles chamam —
  # `Ingestion.start_sync/3` para o agendador, `Automation.enabled_tenants/0` para a rodada
  # mensal. Os dois filtros têm teste abaixo.
  @da_instalacao [
    TheBand.Jobs.ApagaSessoesAntigas,
    TheBand.Jobs.ReconcileStuckSyncs,
    TheBand.Jobs.ScheduleDueSyncs,
    TheBand.Profiles.MonthlyWorker
  ]

  defp suspender(%Tenant{id: id}) do
    {1, _} = Repo.update_all(from(t in Tenant, where: t.id == ^id), set: [status: "suspended"])
    :ok
  end

  test "todo worker da aplicação está classificado: por tenant, ou da instalação" do
    {:ok, modulos} = :application.get_key(:the_band, :modules)

    workers =
      modulos
      |> Enum.filter(fn m ->
        Code.ensure_loaded?(m) and
          Oban.Worker in List.flatten(Keyword.get_values(m.module_info(:attributes), :behaviour))
      end)
      |> MapSet.new()

    classificados = MapSet.new(@por_tenant ++ @da_instalacao)

    assert MapSet.size(workers) >= 9, "a enumeração não achou os workers que existem"

    assert MapSet.difference(workers, classificados) == MapSet.new(), """
    Worker sem classificação. Se ele recebe `tenant_id`, confere `Tenants.ensure_active/1` e
    ganha teste de efeito zero neste arquivo. Se age sobre a instalação, vai para
    @da_instalacao, com o filtro que ele usa testado.
    """

    assert MapSet.difference(classificados, workers) == MapSet.new()
  end

  describe "Tenants.ensure_active/1" do
    test "só \"active\" é ativa; suspensa e valor desconhecido não são" do
      assert :ok = Tenants.ensure_active(%Tenant{status: "active"})
      assert {:error, :tenant_inactive} = Tenants.ensure_active(%Tenant{status: "suspended"})
      assert {:error, :tenant_inactive} = Tenants.ensure_active(%Tenant{status: "arquivada"})
    end
  end

  describe "a coleta" do
    setup do
      {tenant, _admin} = tenant_with_admin()
      %{tenant: tenant, tool: ferramenta(tenant)}
    end

    test "o botão é recusado, e nenhum Sync nasce", %{tenant: tenant, tool: tool} do
      suspender(tenant)
      {:ok, tenant} = Tenants.fetch(tenant.id)

      assert {:error, :tenant_inactive} = Ingestion.start_sync(tenant, tool)
      assert Repo.aggregate(from(s in Sync, where: s.tenant_id == ^tenant.id), :count) == 0
    end

    test "o agendador não enfileira a ferramenta vencida", %{tenant: tenant} do
      suspender(tenant)

      assert {:ok, %{enqueued: 0}} = Ingestion.enqueue_due_syncs()
      assert Repo.aggregate(from(s in Sync, where: s.tenant_id == ^tenant.id), :count) == 0
    end

    test "o job em curso fecha interrompido, sem chamar o GitHub", %{tenant: tenant, tool: tool} do
      {:ok, sync} =
        %Sync{}
        |> Sync.changeset(%{
          tenant_id: tenant.id,
          connected_tool_id: tool.id,
          status: "running",
          started_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      suspender(tenant)

      assert {:cancel, :tenant_inactive} =
               SyncGitHubEO.perform(%Oban.Job{
                 args: %{"tenant_id" => tenant.id, "sync_id" => sync.id}
               })

      fechado = Repo.get!(Sync, sync.id)
      assert fechado.status == "interrupted"
      assert fechado.error_reason == "organização suspensa"
    end
  end

  describe "a rodada de perfis, que manda dado de pessoa ao modelo" do
    setup do
      {:ok, _} = KnowledgeBase.load()
      {tenant, admin} = tenant_with_admin()
      cenario = cenario(tenant)
      tenant_com_credencial(tenant)
      %{tenant: tenant, admin: admin, pessoa: cenario.pessoa, repo_id: cenario.repo_id}
    end

    test "a rodada mensal não abre para a organização suspensa, ligada ou não", ctx do
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)
      assert ctx.tenant.id in Enum.map(Automation.enabled_tenants(), & &1.id)

      suspender(ctx.tenant)

      refute ctx.tenant.id in Enum.map(Automation.enabled_tenants(), & &1.id)
    end

    test "rodada aberta antes da suspensão fecha sem chamar o modelo", ctx do
      {:ok, run} = Runs.start(ctx.tenant, trigger: :manual, requested_by: ctx.admin)
      suspender(ctx.tenant)

      assert {:cancel, :tenant_inactive} =
               RunWorker.perform(%Oban.Job{
                 args: %{"tenant_id" => ctx.tenant.id, "run_id" => run.id}
               })

      fechada = Repo.reload!(run)
      assert fechada.outcome == "ended_early"
      assert fechada.ended_reason == "organização suspensa"
      assert Repo.aggregate(from(e in RunEntry, where: e.profile_run_id == ^run.id), :count) == 0
    end

    test "suspensa no meio da rodada, nenhuma pessoa a mais vai ao modelo", ctx do
      pessoa_com_material(ctx.tenant, ctx.repo_id, "segunda")
      {:ok, run} = Runs.start(ctx.tenant, trigger: :manual, requested_by: ctx.admin)

      # A primeira chamada ao modelo suspende a organização, como se o operador agisse durante
      # a rodada. `expect` de UMA chamada: a segunda levantaria, e viraria entrada `failed`.
      expect(TheBand.LLMHTTPMock, :complete, 1, fn _p, _m, _o ->
        suspender(ctx.tenant)
        {:ok, %{text: Jason.encode!(resposta()), model: "m1", usage: %{}}}
      end)

      assert :ok =
               RunWorker.perform(%Oban.Job{
                 args: %{"tenant_id" => ctx.tenant.id, "run_id" => run.id}
               })

      entradas =
        Repo.all(from(e in RunEntry, where: e.profile_run_id == ^run.id, select: e.outcome))

      assert entradas == ["generated"]

      fechada = Repo.reload!(run)
      assert fechada.outcome == "ended_early"
      assert fechada.ended_reason == "organização suspensa"
    end

    test "gerar/3 relê o estado: o tenant carregado antes da suspensão não passa", ctx do
      # O `tenant` em mãos ainda diz "active"; a rodada o carregou antes. Quem decide é o banco.
      suspender(ctx.tenant)
      assert ctx.tenant.status == "active"

      assert {:error, :tenant_inactive} = GenerateWorker.gerar(ctx.tenant, ctx.pessoa.id)
    end

    test "o perfil avulso não é gerado", ctx do
      suspender(ctx.tenant)

      assert {:cancel, :tenant_inactive} =
               GenerateWorker.perform(%Oban.Job{
                 args: %{"tenant_id" => ctx.tenant.id, "person_id" => ctx.pessoa.id}
               })
    end
  end

  describe "o reprocessamento" do
    setup do
      {tenant, _admin} = tenant_with_admin()
      suspender(tenant)
      %{tenant: tenant}
    end

    test "o remapeamento é cancelado", %{tenant: tenant} do
      assert {:cancel, :tenant_inactive} =
               ReprocessMappings.perform(%Oban.Job{args: %{"tenant_id" => tenant.id}})
    end

    test "o cálculo da rede de revisão é cancelado, sem gravar leitura (073)", %{tenant: tenant} do
      assert {:cancel, :tenant_inactive} =
               ComputeReviewNetwork.perform(%Oban.Job{
                 args: %{"tenant_id" => tenant.id, "organization_id" => Ecto.UUID.generate()}
               })

      assert Repo.aggregate("review_network_readings", :count) == 0
    end

    test "o recálculo das promoções é cancelado", %{tenant: tenant} do
      assert {:cancel, :tenant_inactive} =
               RecomputePromotions.perform(%Oban.Job{
                 args: %{"tenant_id" => tenant.id, "organization_id" => Ecto.UUID.generate()}
               })
    end
  end

  defp ferramenta(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme-#{System.unique_integer([:positive])}",
        sync_interval_minutes: 60
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "teste",
        secret: "token-de-teste",
        owner_login: "dono-#{System.unique_integer([:positive])}",
        last_four: "este",
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    tool
  end

  defp resposta do
    %{
      "habilidades" => ["observabilidade com OpenTelemetry"],
      "resumo" => %{"forcas" => "f", "evolucao" => "e", "atencao" => "a"},
      "trajetoria" => [],
      "destaques" => [],
      "lacunas" => [],
      "alocacao" => [],
      "recomendacoes" => [],
      "do_time_nao_da_pessoa" => "x",
      "nao_alcanca" => "y"
    }
  end
end
