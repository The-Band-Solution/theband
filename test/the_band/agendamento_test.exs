defmodule TheBand.AgendamentoTest do
  @moduledoc """
  A coleta periódica e o aviso de falha repetida — issue #443.

  ## As asserções que carregam este arquivo

  1. **sem intervalo, nada é enfileirado** — nulo é manual, e ligar automático em toda
     ferramenta cadastrada gastaria a janela de rate limit sem ninguém pedir;
  2. **coleta em andamento não é reenfileirada** — sem essa guarda, coleta que leva mais que
     o intervalo rodaria duas vezes e o número dobrado pareceria plausível (L02);
  3. **ferramenta recém-configurada é coletada já**, sem esperar um intervalo inteiro;
  4. **falha isolada não avisa; três seguidas avisam** — e a mensagem diz quantas, o limiar e
     o motivo da origem;
  5. **coleta em andamento não interrompe nem conta na sequência** — ela não decidiu nada;
  6. o aviso é **aviso, não bloqueio**: a ferramenta marcada continua sendo enfileirada.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Sources
  alias TheBand.Sources.{ConnectedTool, ToolCredential}

  setup do
    {tenant, admin} = tenant_with_admin()
    %{tenant: tenant, admin: admin, tool: ferramenta(tenant)}
  end

  defp ferramenta(tenant, login \\ "acme") do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: login
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "teste",
        secret: "token",
        last_four: "oken",
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    tool
  end

  defp coleta(ctx, status, quando, motivo \\ nil) do
    {:ok, s} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: ctx.tenant.id,
        connected_tool_id: ctx.tool.id,
        status: status,
        started_at: quando,
        finished_at: if(status == "running", do: nil, else: quando),
        error_reason: motivo
      })
      |> Repo.insert()

    s
  end

  defp com_intervalo(tool, minutos, ultima \\ nil) do
    {:ok, t} = Sources.set_sync_interval(tool, minutos)

    if ultima do
      {:ok, t} = t |> ConnectedTool.changeset(%{last_sync_at: ultima}) |> Repo.update()
      t
    else
      t
    end
  end

  describe "o agendador" do
    test "sem intervalo não enfileira nada — nulo é manual", ctx do
      assert ctx.tool.sync_interval_minutes == nil
      assert {:ok, %{enqueued: 0, skipped_running: 0}} = Ingestion.enqueue_due_syncs()
    end

    test "ferramenta recém-configurada é coletada já, sem esperar um intervalo", ctx do
      # Esperar um intervalo inteiro faria "a cada 6 horas" significar "em 6 horas".
      com_intervalo(ctx.tool, 360)

      assert {:ok, %{enqueued: 1}} = Ingestion.enqueue_due_syncs()
    end

    test "dentro do intervalo, não enfileira", ctx do
      com_intervalo(ctx.tool, 360, DateTime.add(DateTime.utc_now(:second), -60, :minute))

      assert {:ok, %{enqueued: 0}} = Ingestion.enqueue_due_syncs()
    end

    test "passado o intervalo, enfileira", ctx do
      com_intervalo(ctx.tool, 60, DateTime.add(DateTime.utc_now(:second), -61, :minute))

      assert {:ok, %{enqueued: 1}} = Ingestion.enqueue_due_syncs()
    end

    test "coleta em andamento não é reenfileirada", ctx do
      # A guarda que impede o defeito da L02: coleta que leva mais que o intervalo rodaria
      # duas vezes, e o número dobrado pareceria plausível.
      com_intervalo(ctx.tool, 15, DateTime.add(DateTime.utc_now(:second), -60, :minute))
      coleta(ctx, "running", DateTime.utc_now(:second))

      assert {:ok, %{enqueued: 0, skipped_running: 1}} = Ingestion.enqueue_due_syncs()
    end

    test "a próxima coleta tem três respostas, e nenhuma é texto", ctx do
      assert Ingestion.proxima_coleta(ctx.tool) == :manual

      recem = com_intervalo(ctx.tool, 360)
      assert Ingestion.proxima_coleta(recem) == :vencida

      dentro = com_intervalo(ctx.tool, 360, DateTime.add(DateTime.utc_now(:second), -1, :minute))
      assert {:em, segundos} = Ingestion.proxima_coleta(dentro)
      assert segundos > 0
    end

    test "o intervalo recusa abaixo de 15 minutos, e diz por quê", ctx do
      assert {:error, changeset} = Sources.set_sync_interval(ctx.tool, 5)

      assert %{sync_interval_minutes: [mensagem]} =
               Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)

      assert mensagem =~ "15 minutos"
    end

    test "string vazia é manual, e é diferente de zero", ctx do
      com_intervalo(ctx.tool, 60)
      {:ok, t} = Sources.set_sync_interval(ctx.tool, "")

      assert t.sync_interval_minutes == nil
      # Zero seria "a cada zero minutos", que não existe.
      assert {:error, _} = Sources.set_sync_interval(t, 0)
    end
  end

  describe "o aviso de falha repetida" do
    test "uma falha não avisa, três seguidas avisam", ctx do
      coleta(ctx, "interrupted", horas_atras(3), "primeira")
      assert {:ok, %{flagged: 0}} = Ingestion.flag_tools_failing_repeatedly()
      assert recarregar(ctx.tool).needs_attention_since == nil

      coleta(ctx, "interrupted", horas_atras(2), "segunda")
      coleta(ctx, "interrupted", horas_atras(1), "a última falha")

      assert {:ok, %{flagged: 1}} = Ingestion.flag_tools_failing_repeatedly()

      tool = recarregar(ctx.tool)
      assert tool.needs_attention_since
      # A mensagem diz os três: quantas, o limiar e o motivo da origem.
      assert tool.needs_attention_reason =~ "3 coletas seguidas"
      assert tool.needs_attention_reason =~ "a partir de 3"
      assert tool.needs_attention_reason =~ "a última falha"
    end

    test "uma coleta completa no meio quebra a sequência", ctx do
      coleta(ctx, "interrupted", horas_atras(4), "x")
      coleta(ctx, "interrupted", horas_atras(3), "x")
      coleta(ctx, "completed", horas_atras(2))
      coleta(ctx, "interrupted", horas_atras(1), "x")

      # A mais recente falhou, mas não são três seguidas.
      assert {:ok, %{flagged: 0}} = Ingestion.flag_tools_failing_repeatedly()
    end

    test "coleta em andamento não conta nem interrompe a sequência", ctx do
      coleta(ctx, "interrupted", horas_atras(4), "x")
      coleta(ctx, "interrupted", horas_atras(3), "x")
      coleta(ctx, "interrupted", horas_atras(2), "x")
      # Em andamento não decidiu nada: tratá-la como sucesso limparia o aviso de quem está
      # falhando agora.
      coleta(ctx, "running", horas_atras(1))

      assert {:ok, %{flagged: 1}} = Ingestion.flag_tools_failing_repeatedly()
    end

    test "voltar a completar limpa o aviso", ctx do
      for h <- [4, 3, 2], do: coleta(ctx, "interrupted", horas_atras(h), "x")
      assert {:ok, %{flagged: 1}} = Ingestion.flag_tools_failing_repeatedly()

      coleta(ctx, "completed", horas_atras(1))

      assert {:ok, %{cleared: 1}} = Ingestion.flag_tools_failing_repeatedly()
      assert recarregar(ctx.tool).needs_attention_since == nil
    end

    test "o aviso é aviso, não bloqueio: a marcada continua sendo enfileirada", ctx do
      for h <- [4, 3, 2], do: coleta(ctx, "interrupted", horas_atras(h), "x")
      assert {:ok, %{flagged: 1}} = Ingestion.flag_tools_failing_repeatedly()

      com_intervalo(ctx.tool, 60, horas_atras(2))

      # Parar de tentar transformaria falha transitória em permanente.
      assert {:ok, %{enqueued: 1}} = Ingestion.enqueue_due_syncs()
    end

    test "ferramenta sem coleta nenhuma não é marcada", ctx do
      # Nunca coletada não é "falhando": é "não tentada". Marcar afirmaria falha inexistente.
      assert {:ok, %{flagged: 0, cleared: 0}} = Ingestion.flag_tools_failing_repeatedly()
      assert recarregar(ctx.tool).needs_attention_since == nil
    end
  end

  defp horas_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n, :hour)

  defp recarregar(tool), do: Repo.one!(from t in ConnectedTool, where: t.id == ^tool.id)
end
