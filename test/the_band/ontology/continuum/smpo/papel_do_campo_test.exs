defmodule TheBand.Ontology.Continuum.SMPO.PapelDoCampoTest do
  @moduledoc """
  O papel do campo de iteração — issue #514.

  ## As asserções que carregam este arquivo

  1. **a declaração vale para o que já foi coletado.** Nada é copiado: a mesma linha de
     `sro_sprints` muda de leitura no instante da declaração, e é isso que dispensa
     migração das 27 iterações de trimestre já no banco;
  2. **revogar devolve a linha à leitura de sprint.** Se a revogação deixasse resíduo, o
     trimestre sumiria da contagem de sprint sem aparecer em lugar nenhum;
  3. **declarar num quadro não decide por outro.** Seis quadros têm `Quarter`; a unidade
     é o par (quadro, campo), e vazar entre quadros mediria por quem ninguém olhou;
  4. **a evidência mostra dispersão, não só média.** `Sprint` de 3 a 14 dias e `Quarter`
     de 61 a 92 se distinguem pela faixa; duas médias sozinhas escondem o campo mal usado.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.Continuum.SMPO
  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Projects

  setup do
    tenant = tenant_fixture()
    tool = ferramenta(tenant, "The-Band-Solution")
    user = user_fixture(tenant)

    delivery = quadro(tenant, tool, 6, "Conecta Fapes - Delivery")
    zeppelin = quadro(tenant, tool, 9, "Zeppelin")

    %{tenant: tenant, tool: tool, user: user, delivery: delivery, zeppelin: zeppelin}
  end

  defp quadro(tenant, tool, numero, titulo) do
    agora = DateTime.utc_now(:second)

    {:ok, q} =
      Projects.record_observed_project(tenant, %{
        connected_tool_id: tool.id,
        number: numero,
        title: titulo,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_#{numero}",
        collected_at: agora,
        last_observed_at: agora
      })

    q
  end

  defp campo(tenant, quadro, nome) do
    agora = DateTime.utc_now(:second)

    {:ok, d} =
      Projects.record_field_definition(tenant, %{
        observed_project_id: quadro.id,
        field_external_id: "PVTIF_#{quadro.number}_#{nome}",
        name: nome,
        data_type: "ITERATION",
        collected_at: agora,
        last_observed_at: agora
      })

    d
  end

  defp caixa(ctx, quadro, nome_do_campo, titulo, dias, inicio) do
    {:ok, s} =
      SRO.record_sprint(ctx.tenant, %{
        connected_tool_id: ctx.tool.id,
        board_number: quadro.number,
        board_title: quadro.title,
        field_name: nome_do_campo,
        title: titulo,
        started_on: inicio,
        duration_days: dias,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{quadro.number}_#{titulo}"
      })

    s
  end

  describe "a evidência que a tela mostra" do
    test "traz volume e a faixa de duração, sem recomendar nada", ctx do
      caixa(ctx, ctx.delivery, "Sprint", "Sprint 1", 14, ~D[2026-01-05])
      caixa(ctx, ctx.delivery, "Sprint", "Sprint 2", 3, ~D[2026-01-19])
      caixa(ctx, ctx.delivery, "Quarter", "Q1", 92, ~D[2026-01-01])
      caixa(ctx, ctx.delivery, "Quarter", "Q2", 61, ~D[2026-04-01])

      campos = SMPO.iteration_fields(ctx.tenant, ctx.delivery.id)
      por_nome = Map.new(campos, &{&1.field_name, &1})

      assert por_nome["Sprint"].iteracoes == 2
      assert por_nome["Sprint"].duracao_min == 3
      assert por_nome["Sprint"].duracao_max == 14

      assert por_nome["Quarter"].iteracoes == 2
      assert por_nome["Quarter"].duracao_min == 61
      assert por_nome["Quarter"].duracao_max == 92

      assert Enum.all?(campos, &is_nil(&1.papel)), """
      Um campo veio com papel sem ninguém ter declarado.

      A plataforma não escolhe pelo nome. `Quarter` parece trimestre, e classificar por
      padrão de nome publicaria a suposição como medida — o erro cai para o lado barato,
      porque o reconhecido errado vira número e ninguém volta para conferir.
      """
    end

    test "campo sem iteração nenhuma não aparece — não há o que declarar", ctx do
      campo(ctx.tenant, ctx.delivery, "Quarter")

      assert SMPO.iteration_fields(ctx.tenant, ctx.delivery.id) == []
    end
  end

  describe "declarar vale para o que já foi coletado" do
    test "a mesma linha muda de leitura sem ser copiada", ctx do
      caixa(ctx, ctx.delivery, "Quarter", "Q1", 92, ~D[2026-01-01])
      refute SMPO.horizon_field?(ctx.tenant, ctx.delivery.id, "Quarter")
      assert SMPO.planning_horizons(ctx.tenant) == []

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.delivery.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      assert SMPO.horizon_field?(ctx.tenant, ctx.delivery.id, "Quarter")

      assert [horizonte] = SMPO.planning_horizons(ctx.tenant)

      assert horizonte.title == "Q1", """
      A declaração não alcançou a iteração que já estava no banco.

      Ela precisa alcançar: são 27 trimestres já coletados, e exigir recoleta faria a
      declaração parecer sem efeito justo no momento em que alguém a faz.
      """
    end

    test "revogar devolve a linha à leitura de sprint", ctx do
      caixa(ctx, ctx.delivery, "Quarter", "Q1", 92, ~D[2026-01-01])

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.delivery.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      assert {:ok, 1} =
               SMPO.revoke_field_role(ctx.tenant, ctx.delivery.id, "Quarter", ctx.user.id)

      assert SMPO.planning_horizons(ctx.tenant) == []
      assert SMPO.field_roles(ctx.tenant, ctx.delivery.id) == %{}

      assert [%{field_name: "Quarter", papel: nil}] =
               SMPO.iteration_fields(ctx.tenant, ctx.delivery.id)
    end

    test "revogar o que ninguém declarou não é sucesso silencioso", ctx do
      assert {:error, :not_declared} =
               SMPO.revoke_field_role(ctx.tenant, ctx.delivery.id, "Quarter", ctx.user.id)
    end

    test "redeclarar substitui, e não acumula dois papéis vigentes", ctx do
      caixa(ctx, ctx.delivery, "Quarter", "Q1", 92, ~D[2026-01-01])

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.delivery.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      {:ok, _} =
        SMPO.declare_field_role(ctx.tenant, ctx.delivery.id, "Quarter", "sprint", ctx.user.id)

      assert SMPO.field_roles(ctx.tenant, ctx.delivery.id) == %{"Quarter" => "sprint"}
      assert SMPO.planning_horizons(ctx.tenant) == []
    end

    test "papel que a ontologia não define é recusado", ctx do
      assert {:error, %Ecto.Changeset{}} =
               SMPO.declare_field_role(
                 ctx.tenant,
                 ctx.delivery.id,
                 "Quarter",
                 "trimestre",
                 ctx.user.id
               )
    end
  end

  describe "a unidade é o par (quadro, campo)" do
    test "declarar no Delivery não decide pelo Zeppelin", ctx do
      caixa(ctx, ctx.delivery, "Quarter", "Q1 Delivery", 92, ~D[2026-01-01])
      caixa(ctx, ctx.zeppelin, "Quarter", "Q1 Zeppelin", 90, ~D[2026-01-01])

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.delivery.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      refute SMPO.horizon_field?(ctx.tenant, ctx.zeppelin.id, "Quarter")

      assert [%{title: "Q1 Delivery"}] = SMPO.planning_horizons(ctx.tenant), """
      A declaração de um quadro vazou para outro.

      Seis quadros têm um campo chamado `Quarter`. Declarar por nome sozinho mediria por
      quadros que ninguém abriu — e é justamente o atalho que a #514 existe para não dar.
      """
    end
  end

  describe "a fronteira do tenant" do
    test "outro tenant não vê o horizonte declarado aqui", ctx do
      caixa(ctx, ctx.delivery, "Quarter", "Q1", 92, ~D[2026-01-01])

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.delivery.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      outro = tenant_fixture()

      assert SMPO.planning_horizons(outro) == []
      assert SMPO.field_roles(outro, ctx.delivery.id) == %{}
      assert SMPO.iteration_fields(outro, ctx.delivery.id) == []
    end
  end

  describe "a ponte até as iterações do quadro" do
    test "o id externo do campo declarado é o que separa as iterações", ctx do
      d = campo(ctx.tenant, ctx.delivery, "Quarter")
      campo(ctx.tenant, ctx.delivery, "Sprint")
      caixa(ctx, ctx.delivery, "Quarter", "Q1", 92, ~D[2026-01-01])

      assert SMPO.horizon_field_external_ids(ctx.tenant, ctx.delivery.id) |> MapSet.size() == 0

      # `Sprint` declarado EXPLICITAMENTE como sprint, e não deixado em branco. É a
      # diferença que revela a ponte sem filtro de papel: campo sem declaração nenhuma
      # não tem linha para o join achar, então em branco ele passa por qualquer defeito.
      {:ok, _} =
        SMPO.declare_field_role(ctx.tenant, ctx.delivery.id, "Sprint", "sprint", ctx.user.id)

      {:ok, _} =
        SMPO.declare_field_role(
          ctx.tenant,
          ctx.delivery.id,
          "Quarter",
          "planning_horizon",
          ctx.user.id
        )

      ids = SMPO.horizon_field_external_ids(ctx.tenant, ctx.delivery.id)

      assert MapSet.to_list(ids) == [d.field_external_id], """
      A ponte trouxe o campo errado, ou trouxe mais de um.

      `Sprint` foi declarado sprint e não pode entrar: entrar faria a tela mover o sprint
      backlog inteiro para a seção de horizonte, com a declaração parecendo correta.
      """
    end
  end
end
