defmodule TheBand.Ingestion.ContadorAtomicoTest do
  @moduledoc """
  O contador do sync sob concorrência — ADR 0006, item 2.

  ## Por que este arquivo existe antes de qualquer paralelismo

  `tally/2` era read-modify-write: lia `sync.records_collected`, somava um, gravava. Com
  a coleta sequencial isso bastava e ninguém percebeu. Com duas escritas ao mesmo tempo,
  as duas leem o mesmo valor e uma sobrescreve a outra.

  **O resultado não é erro.** É um número menor do que a realidade, sem nada acusando — e
  a tela de progresso passaria a mentir sobre quanto foi coletado. Contador errado é pior
  do que coleta lenta, e por isso esta mudança precede a concorrência.

  O primeiro teste **reprova** com a implementação antiga. É o que o torna prova, e não
  ilustração.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool

  @concorrentes 20

  setup do
    tenant = tenant_fixture()
    # As tarefas do `async_stream` são processos NOVOS, e não herdam a conexão do
    # sandbox. Sem o `allow/3` com este pid, elas não enxergam nem o tenant recém-criado.
    %{tenant: tenant, sync: sync_em_curso(tenant), owner_pid: self()}
  end

  describe "o incremento é do banco, e não da memória" do
    test "vinte incrementos concorrentes somam vinte", ctx do
      1..@concorrentes
      |> Task.async_stream(
        fn _ ->
          # Cada tarefa recebe a struct do MESMO instante — é exatamente o cenário que
          # a corrida produz: todas leem o mesmo valor antes de qualquer escrita.
          Ecto.Adapters.SQL.Sandbox.allow(Repo, ctx.owner_pid, self())
          Ingestion.tally(ctx.sync, :created)
        end,
        max_concurrency: 10,
        ordered: false
      )
      |> Stream.run()

      final = Repo.get!(Sync, ctx.sync.id)

      assert final.records_collected == @concorrentes, """
      Vinte incrementos concorrentes somaram #{final.records_collected}.

      É a corrida do read-modify-write: as tarefas leem o mesmo valor, somam um, e a
      última escrita apaga as anteriores. O número sai MENOR que a realidade, e nada
      acusa — a tela de progresso mostraria menos do que foi coletado.
      """

      assert final.records_created == @concorrentes
    end

    test "o contador de repositório inalcançável também é atômico", ctx do
      1..@concorrentes
      |> Task.async_stream(
        fn _ ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, ctx.owner_pid, self())
          Ingestion.tally(ctx.sync, :repository_unreachable)
        end,
        max_concurrency: 10,
        ordered: false
      )
      |> Stream.run()

      assert Repo.get!(Sync, ctx.sync.id).repositories_unreachable == @concorrentes
    end

    test "devolve o registro ATUALIZADO, e não a struct que chegou velha", ctx do
      {:ok, _} = Ingestion.tally(ctx.sync, :created)
      {:ok, depois} = Ingestion.tally(ctx.sync, :created)

      assert depois.records_collected == 2, """
      A segunda chamada recebeu a struct original (com zero) e devolveu 1. Quem chama em
      sequência passando a mesma struct veria o contador andar para trás.
      """
    end
  end

  describe "o que NÃO ficou atômico, e está declarado" do
    test "o motivo do pulo continua sendo contado, mesmo sem atomicidade", ctx do
      {:ok, _} = Ingestion.tally(ctx.sync, {:skipped, "sem atividade"})
      {:ok, _} = Ingestion.tally(Repo.get!(Sync, ctx.sync.id), {:skipped, "sem atividade"})

      final = Repo.get!(Sync, ctx.sync.id)

      assert final.skip_reasons == %{"sem atividade" => 2}
      assert final.records_skipped == 2
      assert final.records_collected == 2
    end
  end

  describe "tarefa que morre não vira sucesso (ADR 0006, verificação 3)" do
    test "o `{:exit, _}` do async_stream é tratado, e não ignorado" do
      # Sem o ramo explícito, `Enum.map` sobre o stream recebe `{:exit, motivo}` e quem
      # somasse os resultados quebraria — ou pior, um `Enum.filter` silencioso os
      # descartaria e o resumo diria que todos os repositórios foram alcançados.
      # `async_stream_nolink` do SUPERVISOR, e não `Task.async_stream`: o segundo LINKA a
      # tarefa a quem a criou, e uma exceção derrubaria o processo inteiro em vez de virar
      # `{:exit, _}`. Foi assim que um `KeyError` num repositório matou a coleta toda em
      # 2026-09-04, e é por isso que a coleta passou a usar o supervisor.
      resultados =
        TheBand.Ingestion.TaskSupervisor
        |> Task.Supervisor.async_stream_nolink(
          [:ok, :morre, :ok],
          fn
            :morre -> raise "repositório explodiu"
            :ok -> %{alcancado: true}
          end,
          max_concurrency: 3,
          ordered: false
        )
        |> Enum.map(fn
          {:ok, resultado} -> resultado
          {:exit, _motivo} -> %{alcancado: false}
        end)

      assert Enum.count(resultados, &(&1.alcancado == false)) == 1, """
      A tarefa que levantou não apareceu como não alcançada. É a forma que o
      `async_stream` dá à falha, e tratá-la como sucesso faz o resumo afirmar que um
      repositório foi percorrido quando ele não foi — e a próxima coleta o pularia.
      """

      assert Enum.count(resultados, &(&1.alcancado == true)) == 2, """
      As outras duas tarefas precisam ter concluído. Uma falha isolada não pode derrubar
      o lote — é o acoplamento de destino que a ADR 0006 existe para quebrar.
      """
    end
  end

  defp sync_em_curso(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme-contador"
      })
      |> Repo.insert()

    {:ok, sync} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        status: "running",
        started_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    sync
  end
end
