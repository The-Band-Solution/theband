defmodule TheBand.Ingestion.EnqueueFailureTest do
  @moduledoc """
  O trabalho que não nasce (T006).

  **É o terceiro caminho de travamento**, e a análise da feature 008 o achou lendo a abertura
  da execução: `Repo.insert()` e `Oban.insert()` são operações separadas, e o resultado da
  segunda ia para o vazio. Se ela falhasse, o registro ficava `running` sem nada para
  executá-lo — e o índice único bloqueava a ferramenta.

  Não está nos 5 trabalhos descartados nem no órfão medido no dado real, porque **ninguém
  saberia se já aconteceu**.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ingestion
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  # Um módulo que **não** é worker Oban. É a falha real: dois dos cinco descartes no banco de
  # desenvolvimento vêm de `module is not a worker: TheBand.Jobs.SyncGithubSRO`, um módulo que
  # nunca existiu no repositório.
  defmodule NaoEhWorker do
    def new(_args), do: %{nao: :sou_worker}
  end

  setup do
    tenant = tenant_fixture()
    %{tenant: tenant, tool: ferramenta(tenant)}
  end

  test "criação de trabalho que falha não deixa execução presa", ctx do
    assert {:error, :enqueue_failed} =
             Ingestion.start_sync(ctx.tenant, ctx.tool, worker: NaoEhWorker)

    presas = Enum.filter(Ingestion.list_syncs(ctx.tenant), &(&1.status == "running"))

    assert presas == [], """
    A execução ficou `running` depois de a criação do trabalho falhar.

    O índice único parcial passa a bloquear a ferramenta, e não há trabalho para encerrar o
    registro — é o defeito da issue #175 por outra porta, e o pior deles: ninguém saberia,
    porque o retorno do enfileiramento era descartado.

    A asserção que importa é a **ausência de `running`**, não o valor devolvido.
    """
  end

  test "a execução encerrada diz que o trabalho não pôde ser criado", ctx do
    {:error, :enqueue_failed} = Ingestion.start_sync(ctx.tenant, ctx.tool, worker: NaoEhWorker)

    assert [sync] = Ingestion.list_syncs(ctx.tenant)
    assert sync.status == "interrupted"

    assert sync.error_reason == "o trabalho que a executaria não pôde ser criado", """
    O motivo precisa dizer que o trabalho **nunca existiu**.

    Deixar isto para a reconciliação daria o motivo errado: "o processo que a executava não
    existe mais" afirma que houve processo.
    """
  end

  test "a ferramenta aceita coleta nova em seguida, sem esperar a reconciliação", ctx do
    {:error, :enqueue_failed} = Ingestion.start_sync(ctx.tenant, ctx.tool, worker: NaoEhWorker)

    # Sem o encerramento na hora, esta chamada devolveria `:already_running` — e ficaria
    # devolvendo isso pelos próximos 5 minutos, até o trabalho periódico rodar.
    assert {:error, :enqueue_failed} =
             Ingestion.start_sync(ctx.tenant, ctx.tool, worker: NaoEhWorker),
           """
           A segunda tentativa foi recusada por já existir execução em andamento.

           O encerramento acontece na hora justamente para isso: quem tenta de novo não espera
           o trabalho periódico.
           """
  end

  defp ferramenta(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme"
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "teste",
        secret: "token-de-teste",
        last_four: "este",
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    TheBand.Sources.fetch_connected_tool(tenant, tool.id) |> then(fn {:ok, t} -> t end)
  end
end
