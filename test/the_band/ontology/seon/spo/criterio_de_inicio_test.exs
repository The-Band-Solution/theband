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

  import Ecto.Query

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

    %{tenant: tenant, user: user, projeto: projeto, tool: cenario.tool, cenario: cenario}
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

  describe "a escala" do
    test "o quadro vence o projeto", ctx do
      {:ok, q} = quadro(ctx, "Delivery", 1)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, q.id, ctx.user.id)

      issue = issue_no_quadro(ctx, q, "AssignedEvent")

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, q.id}, "AssignedEvent", ctx.user.id)

      assert %{^issue => {:ok, _quando, origem}} = SPO.resolve_start(ctx.tenant, [issue])
      assert {:board, _, "Delivery"} = origem
    end

    test "quadro SEM critério não vence — vale o do projeto", ctx do
      {:ok, q} = quadro(ctx, "Sem critério", 1)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, q.id, ctx.user.id)

      issue = issue_no_quadro(ctx, q, @evento)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:project, ctx.projeto.id}, @evento, ctx.user.id)

      assert %{^issue => {:ok, _quando, {:project, _, "Conecta Fapes"}}} =
               SPO.resolve_start(ctx.tenant, [issue])
    end

    test "sem critério algum, a ausência tem nome", ctx do
      {:ok, q} = quadro(ctx, "Delivery", 1)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, q.id, ctx.user.id)
      issue = issue_no_quadro(ctx, q, @evento)

      assert %{^issue => {:missing, :sem_criterio}} = SPO.resolve_start(ctx.tenant, [issue])
    end

    test "critério declarado, evento não coletado para AQUELA issue", ctx do
      {:ok, q} = quadro(ctx, "Delivery", 1)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, q.id, ctx.user.id)

      # A issue existe no quadro, mas sem o evento que o critério pede.
      issue = issue_no_quadro(ctx, q, "AssignedEvent")

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, q.id}, @evento, ctx.user.id)

      assert %{^issue => {:missing, {:evento_nao_coletado, @evento}}} =
               SPO.resolve_start(ctx.tenant, [issue])
    end
  end

  describe "o desempate" do
    test "vence o quadro de vínculo mais recente", ctx do
      {:ok, antigo} = quadro(ctx, "Antigo", 1)
      {:ok, novo} = quadro(ctx, "Novo", 2)

      {:ok, v1} = SPO.link_board(ctx.tenant, ctx.projeto.id, antigo.id, ctx.user.id)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, novo.id, ctx.user.id)

      # Recua o vínculo do antigo, para as datas diferirem de verdade.
      recuar(v1.id, -3600)

      issue = issue_no_quadro(ctx, antigo, @evento)
      item_no_quadro(ctx, issue, novo)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, antigo.id}, @evento, ctx.user.id)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, novo.id}, "AssignedEvent", ctx.user.id)

      assert %{^issue => {:missing, {:evento_nao_coletado, "AssignedEvent"}}} =
               SPO.resolve_start(ctx.tenant, [issue]),
             """
             **Venceu o quadro mais recente.** Ele pede `AssignedEvent`, que esta issue não
             tem — e o resultado é a ausência daquele evento, não o critério do quadro antigo.

             Se o desempate tivesse escolhido o antigo, viria `{:ok, ...}`.
             """
    end

    test "empate real NÃO é desempatado — vira ambíguo", ctx do
      {:ok, um} = quadro(ctx, "Um", 1)
      {:ok, outro} = quadro(ctx, "Outro", 2)

      {:ok, v1} = SPO.link_board(ctx.tenant, ctx.projeto.id, um.id, ctx.user.id)
      {:ok, v2} = SPO.link_board(ctx.tenant, ctx.projeto.id, outro.id, ctx.user.id)

      # Associação em lote: os dois no mesmo instante. É o jeito natural de povoar um projeto.
      igualar(v1.id, v2.id)

      issue = issue_no_quadro(ctx, um, @evento)
      item_no_quadro(ctx, issue, outro)

      {:ok, _} = SPO.declare_start_criterion(ctx.tenant, {:board, um.id}, @evento, ctx.user.id)

      {:ok, _} =
        SPO.declare_start_criterion(ctx.tenant, {:board, outro.id}, "AssignedEvent", ctx.user.id)

      assert %{^issue => {:missing, {:criterio_ambiguo, quadros}}} =
               SPO.resolve_start(ctx.tenant, [issue])

      assert length(quadros) == 2, """
      **A plataforma não desempata.** Escolher o primeiro faria o que a FR-007 da feature 022
      proíbe, num lugar onde ninguém procuraria.

      E o retorno nomeia OS DOIS quadros: sem isso, quem administra sabe que há problema e não
      sabe onde.
      """

      assert Enum.all?(quadros, &Map.has_key?(&1, :title))
    end
  end

  describe "vale a primeira ocorrência" do
    test "tarefa que voltou ao Backlog e saiu de novo começou quando começou", ctx do
      {:ok, q} = quadro(ctx, "Delivery", 1)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, q.id, ctx.user.id)
      {:ok, _} = SPO.declare_start_criterion(ctx.tenant, {:board, q.id}, @evento, ctx.user.id)

      issue = issue_no_quadro(ctx, q, @evento)

      # A primeira ocorrência recua uma hora; a que já existe fica sendo a segunda.
      primeira = DateTime.add(DateTime.utc_now(:second), -3600, :second)
      atividade_da_issue(ctx.tenant, issue, @evento, primeira)

      assert %{^issue => {:ok, quando, _}} = SPO.resolve_start(ctx.tenant, [issue])

      # `occurred_at` é `NaiveDateTime` na coluna, e a comparação tem de ser na mesma moeda.
      esperado = DateTime.to_naive(primeira)

      assert NaiveDateTime.compare(NaiveDateTime.truncate(quando, :second), esperado) == :eq, """
      **A FR-011.** Recomeçar não apaga o começo: uma tarefa que voltou ao Backlog e saiu de
      novo começou na PRIMEIRA vez.

      Com `max` em vez de `min`, o início viraria a última movimentação — e o cycle time de
      quem retrabalha apareceria menor do que foi.
      """
    end
  end

  describe "o custo da leitura" do
    test "não cresce com o número de issues", ctx do
      {:ok, q} = quadro(ctx, "Delivery", 1)
      {:ok, _} = SPO.link_board(ctx.tenant, ctx.projeto.id, q.id, ctx.user.id)
      {:ok, _} = SPO.declare_start_criterion(ctx.tenant, {:board, q.id}, @evento, ctx.user.id)

      uma = for _ <- 1..1, do: issue_no_quadro(ctx, q, @evento)
      cinquenta = for _ <- 1..50, do: issue_no_quadro(ctx, q, @evento)

      assert consultas(fn -> SPO.resolve_start(ctx.tenant, uma) end) ==
               consultas(fn -> SPO.resolve_start(ctx.tenant, cinquenta) end),
             """
             **Sem isto a decisão do plano se inverte.** Resolver na leitura só se sustenta em
             lote: com 19.200 atividades, uma consulta por issue seria N+1, e `start_date`
             teria de ser gravado.
             """
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

  # Usa uma issue que o `cenario_real` já criou, e a põe no quadro. Criar issue nova exigiria
  # replicar a gravação inteira da coleta, e o teste não é sobre isso.
  defp issue_no_quadro(ctx, quadro, tipo_de_evento) do
    issue_id = proxima_issue(ctx)
    item_no_quadro(ctx, issue_id, quadro)
    atividade_da_issue(ctx.tenant, issue_id, tipo_de_evento)
    issue_id
  end

  defp proxima_issue(ctx) do
    usadas = Process.get(:issues_usadas, MapSet.new())

    id =
      Repo.one!(
        from i in "collected_issues",
          where: i.tenant_id == type(^ctx.tenant.id, :binary_id),
          where: i.id not in type(^MapSet.to_list(usadas), {:array, :binary_id}),
          limit: 1,
          select: type(i.id, :binary_id)
      )

    Process.put(:issues_usadas, MapSet.put(usadas, id))
    id
  end

  defp item_no_quadro(ctx, issue_id, quadro) do
    agora = DateTime.utc_now(:second)

    Repo.insert_all("project_items", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(ctx.tenant.id),
        observed_project_id: Ecto.UUID.dump!(quadro.id),
        collected_issue_id: Ecto.UUID.dump!(issue_id),
        is_draft: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{System.unique_integer([:positive])}",
        collected_at: agora,
        last_observed_at: agora,
        inserted_at: agora,
        updated_at: agora
      }
    ])
  end

  defp atividade_da_issue(tenant, issue_id, tipo, quando \\ nil) do
    agora = quando || DateTime.utc_now(:second)

    Repo.insert_all("spo_performed_project_activities", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(tenant.id),
        internal_id: "a-#{System.unique_integer([:positive])}",
        activity_type: tipo,
        occurred_at: agora,
        subject_type: "issue",
        subject_id: Ecto.UUID.dump!(issue_id),
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "E_#{System.unique_integer([:positive])}",
        inserted_at: agora,
        updated_at: agora
      }
    ])
  end

  defp recuar(vinculo_id, segundos) do
    Repo.update_all(
      from(v in "spo_project_boards", where: v.id == type(^vinculo_id, :binary_id)),
      set: [linked_at: DateTime.add(DateTime.utc_now(:second), segundos, :second)]
    )
  end

  defp igualar(a, b) do
    quando = DateTime.utc_now(:second)

    for id <- [a, b] do
      Repo.update_all(
        from(v in "spo_project_boards", where: v.id == type(^id, :binary_id)),
        set: [linked_at: quando]
      )
    end
  end

  # Conta as consultas de uma função — o mesmo padrão que `verification` usa.
  defp consultas(fun) do
    ref = make_ref()
    pai = self()

    :telemetry.attach(
      "conta-#{inspect(ref)}",
      [:the_band, :repo, :query],
      fn _e, _m, _md, _c -> send(pai, {ref, :query}) end,
      nil
    )

    fun.()
    :telemetry.detach("conta-#{inspect(ref)}")
    contar(ref, 0)
  end

  defp contar(ref, n) do
    receive do
      {^ref, :query} -> contar(ref, n + 1)
    after
      0 -> n
    end
  end
end
