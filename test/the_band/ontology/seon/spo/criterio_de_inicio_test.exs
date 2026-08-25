defmodule TheBand.Ontology.SEON.SPO.CriterioDeInicioTest do
  @moduledoc """
  O critério de início — feature 042, issue #370.

  ## O que estes casos protegem

  Que a plataforma **não escolha** — nem o critério, nem o desempate. Que redeclarar preserve
  quem declarou antes. E que o alvo seja exatamente um.

  Os três são decisões que um refactor bem-intencionado desfaz sem parecer erro.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Ontology.SEON.SPO.Schemas.ActivityStartCriterion

  @evento "ProjectV2ItemStatusChangedEvent"

  setup do
    tenant = tenant_fixture()
    user = user_fixture(tenant)
    cenario = cenario_real(tenant)

    {:ok, projeto} = SPO.create_project(tenant, %{name: "Conecta Fapes"}, user.id)

    # A coleta precisa ter o evento, senão `declare/4` recusa — é a FR-012.
    atividade(tenant, @evento, 5)
    atividade(tenant, "AssignedEvent", 2)

    %{tenant: tenant, user: user, projeto: projeto, tool: cenario.tool}
  end

  describe "declarar" do
    test "grava com autor e data", ctx do
      assert {:ok, criterio} =
               SPO.declare_start_criterion(
                 ctx.tenant,
                 {:project, ctx.projeto.id},
                 @evento,
                 ctx.user.id
               )

      assert criterio.event_type == @evento
      assert criterio.declared_by_user_id == ctx.user.id
      assert criterio.declared_at
      refute criterio.revoked_at
    end

    test "tipo que a coleta não traz é recusado, sem levantar", ctx do
      assert {:error, :unknown_event_type} =
               SPO.declare_start_criterion(
                 ctx.tenant,
                 {:project, ctx.projeto.id},
                 "EventoQueNaoExiste",
                 ctx.user.id
               )
    end

    test "redeclarar revoga o anterior, e NÃO o sobrescreve", ctx do
      {:ok, primeiro} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      {:ok, segundo} =
        SPO.declare_start_criterion(
          ctx.tenant,
          {:project, ctx.projeto.id},
          "AssignedEvent",
          ctx.user.id
        )

      refute primeiro.id == segundo.id

      assert Repo.aggregate(ActivityStartCriterion, :count) == 2, """
      **Duas linhas, uma revogada.** A FR-010 manda preservar quem declarou antes —
      sobrescrever apagaria o histórico da decisão, e "desde quando este critério vale"
      deixaria de ter resposta.
      """

      vigente = SPO.start_criterion_for(ctx.tenant, {:project, ctx.projeto.id})
      assert vigente.id == segundo.id
      assert vigente.event_type == "AssignedEvent"
    end
  end

  describe "revogar" do
    test "marca, e a linha continua", ctx do
      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      assert {:ok, revogado} =
               SPO.revoke_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, ctx.user.id)

      assert revogado.revoked_at
      assert revogado.revoked_by_user_id == ctx.user.id

      assert Repo.aggregate(ActivityStartCriterion, :count) == 1
      assert is_nil(SPO.start_criterion_for(ctx.tenant, {:project, ctx.projeto.id}))
    end

    test "redeclarar depois de revogar é aceito", ctx do
      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      {:ok, _} = SPO.revoke_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, ctx.user.id)

      assert {:ok, _} =
               SPO.declare_start_criterion(
                 ctx.tenant,
                 {:project, ctx.projeto.id},
                 @evento,
                 ctx.user.id
               ),
             """
             O índice único é **parcial sobre os vigentes**. Um índice total impediria
             redeclarar depois de revogar, e a revogação viraria decisão irreversível.
             """
    end
  end

  describe "um alvo só" do
    test "critério sem alvo é recusado", ctx do
      changeset =
        ActivityStartCriterion.changeset(%ActivityStartCriterion{}, %{
          tenant_id: ctx.tenant.id,
          event_type: @evento,
          declared_at: DateTime.utc_now(:second)
        })

      refute changeset.valid?
      assert errors_on(changeset)[:project_id]
    end

    test "critério com os dois alvos é recusado", ctx do
      {:ok, quadro} = quadro(ctx, "Delivery", 1)

      changeset =
        ActivityStartCriterion.changeset(%ActivityStartCriterion{}, %{
          tenant_id: ctx.tenant.id,
          project_id: ctx.projeto.id,
          observed_project_id: quadro.id,
          event_type: @evento,
          declared_at: DateTime.utc_now(:second)
        })

      refute changeset.valid?, """
      Projeto **ou** quadro, nunca os dois. Um critério que valesse para ambos entraria na
      escala de precedência duas vezes, e a ordem ficaria indefinida.
      """
    end
  end

  describe "os tipos de evento oferecidos" do
    test "vêm da coleta, com volume, e sem recomendação", ctx do
      tipos = SPO.collected_event_types(ctx.tenant)

      assert [%{event_type: @evento, occurrences: 5} | _] = tipos, "ordenados por volume"

      refute Enum.any?(tipos, &Map.has_key?(&1, :suggested)), """
      **Mostrar volume é informar; recomendar é escolher.** A FR-007 da feature 022 proíbe a
      plataforma escolher, e um campo `suggested` seria escolher com passos extras.
      """
    end

    test "tipo ausente da coleta não é oferecido", ctx do
      tipos = Enum.map(SPO.collected_event_types(ctx.tenant), & &1.event_type)
      refute "ClosedEvent" in tipos
    end
  end

  describe "quais quadros ignoram o projeto" do
    test "lista só os que declararam critério próprio", ctx do
      {:ok, com} = quadro(ctx, "Com critério", 1)
      {:ok, sem} = quadro(ctx, "Sem critério", 2)

      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, com.id, ctx.user.id)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, sem.id, ctx.user.id)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, com.id}, "AssignedEvent", ctx.user.id)

      assert [encontrado] = SPO.boards_overriding(ctx.tenant, ctx.projeto.id)

      assert encontrado.title == "Com critério", """
      **A FR-014.** A tela precisa dizer quais quadros vão ignorar a declaração do projeto
      ANTES de a pessoa gravar — depois seria informação inútil.
      """

      assert encontrado.event_type == "AssignedEvent"
      refute encontrado.id == sem.id
    end
  end

  # ---------------------------------------------------------------- auxiliares

  defp atividade(tenant, tipo, quantas) do
    agora = DateTime.utc_now(:second)

    Repo.insert_all(
      "spo_performed_project_activities",
      for n <- 1..quantas do
        %{
          id: Ecto.UUID.bingenerate(),
          tenant_id: Ecto.UUID.dump!(tenant.id),
          internal_id: "#{tipo}-#{n}",
          activity_type: tipo,
          occurred_at: agora,
          subject_type: "issue",
          subject_id: Ecto.UUID.bingenerate(),
          source_system: "github",
          source_instance: "https://github.com",
          source_external_id: "#{tipo}-#{n}",
          inserted_at: agora,
          updated_at: agora
        }
      end
    )
  end

  defp quadro(ctx, titulo, numero) do
    TheBand.Projects.record_observed_project(ctx.tenant, %{
      connected_tool_id: ctx.tool.id,
      number: numero,
      title: titulo,
      closed: false,
      source_system: "github",
      source_instance: "https://github.com",
      source_external_id: "PVT_#{numero}",
      collected_at: DateTime.utc_now(:second),
      last_observed_at: DateTime.utc_now(:second)
    })
  end
end
