defmodule TheBand.Ingestion do
  @moduledoc """
  Orquestra a coleta: abre a sincronização, acompanha o progresso e fecha com o
  relatório de FR-028.

  Uma sincronização por ferramenta de cada vez (FR-018), garantida em dois
  níveis: índice único parcial no banco e `unique` no worker Oban. A corrida
  existe nos dois — a segunda requisição HTTP e o segundo job enfileirado.
  """

  import Ecto.Query

  alias TheBand.Ingestion.Checkpoint
  alias TheBand.Ingestion.Sync
  alias TheBand.Jobs.SyncGitHubEO
  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Tenants.Tenant

  @topic "syncs"

  @doc "Assina as atualizações de progresso de um tenant, para a tela acompanhar ao vivo."
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, @topic <> ":" <> tenant_id)

  @spec broadcast(Ecto.UUID.t(), term()) :: :ok
  def broadcast(tenant_id, message),
    do: Phoenix.PubSub.broadcast(TheBand.PubSub, @topic <> ":" <> tenant_id, message)

  @doc """
  Abre uma sincronização e enfileira o trabalho.

  Devolve `{:error, :already_running}` quando já existe uma em curso — a segunda
  **não** inicia em paralelo, e quem chamou é informado em vez de ver duas
  coletas disputando a mesma janela de API.
  """
  @spec start_sync(Tenant.t(), ConnectedTool.t()) ::
          {:ok, Sync.t()} | {:error, :already_running | :no_active_credential | term()}
  def start_sync(%Tenant{id: tenant_id} = tenant, %ConnectedTool{} = tool) do
    case Sources.active_credential(tool) do
      nil ->
        {:error, :no_active_credential}

      credential ->
        attrs = %{
          tenant_id: tenant_id,
          connected_tool_id: tool.id,
          credential_id: credential.id,
          status: "running",
          started_at: DateTime.utc_now(:second)
        }

        %Sync{}
        |> Sync.changeset(attrs)
        |> Repo.insert()
        |> handle_open(tenant)
    end
  end

  defp handle_open({:ok, sync}, tenant) do
    enqueue(tenant, sync)
    {:ok, sync}
  end

  # O índice único parcial é a defesa que impede duas coletas simultâneas; aqui
  # ele é traduzido no motivo que a tela precisa exibir.
  defp handle_open({:error, %Ecto.Changeset{errors: errors}}, _tenant) do
    if Keyword.has_key?(errors, :connected_tool_id),
      do: {:error, :already_running},
      else: {:error, :invalid}
  end

  defp enqueue(%Tenant{id: tenant_id}, %Sync{id: sync_id}) do
    %{"tenant_id" => tenant_id, "sync_id" => sync_id}
    |> SyncGitHubEO.new()
    |> Oban.insert()
  end

  # ------------------------------------------------------------------- leitura

  @spec list_syncs(Tenant.t(), keyword()) :: [Sync.t()]
  def list_syncs(%Tenant{id: tenant_id}, opts \\ []) do
    query =
      from s in Sync,
        where: s.tenant_id == ^tenant_id,
        order_by: [desc: s.started_at]

    query = if opts[:limit], do: limit(query, ^opts[:limit]), else: query
    Repo.all(query)
  end

  @spec fetch_sync(Tenant.t(), Ecto.UUID.t()) :: {:ok, Sync.t()} | {:error, :not_found}
  def fetch_sync(%Tenant{id: tenant_id}, id) do
    case Repo.one(from s in Sync, where: s.tenant_id == ^tenant_id and s.id == ^id) do
      nil -> {:error, :not_found}
      sync -> {:ok, sync}
    end
  end

  @spec running_sync(ConnectedTool.t()) :: Sync.t() | nil
  def running_sync(%ConnectedTool{id: tool_id}) do
    Repo.one(from s in Sync, where: s.connected_tool_id == ^tool_id and s.status == "running")
  end

  @spec list_checkpoints(Sync.t()) :: [Checkpoint.t()]
  def list_checkpoints(%Sync{id: sync_id}) do
    Repo.all(from c in Checkpoint, where: c.sync_id == ^sync_id, order_by: c.entity_type)
  end

  # ------------------------------------------------------------------ progresso

  @doc """
  Grava o checkpoint de uma página **já processada** (R5, SC-006).

  Chamado depois do processamento, nunca antes.
  """
  @spec checkpoint_page(Sync.t(), String.t(), String.t() | nil, non_neg_integer()) ::
          {:ok, Checkpoint.t()} | {:error, Ecto.Changeset.t()}
  def checkpoint_page(%Sync{} = sync, entity_type, cursor, record_count) do
    existing =
      Repo.one(
        from c in Checkpoint, where: c.sync_id == ^sync.id and c.entity_type == ^entity_type
      )

    attrs = %{
      tenant_id: sync.tenant_id,
      sync_id: sync.id,
      entity_type: entity_type,
      cursor: cursor,
      page_count: ((existing && existing.page_count) || 0) + 1,
      record_count: ((existing && existing.record_count) || 0) + record_count,
      last_page_at: DateTime.utc_now(:second),
      status: if(cursor, do: "running", else: "completed")
    }

    (existing || %Checkpoint{})
    |> Checkpoint.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Cursor de onde retomar, quando a coleta foi interrompida (FR-015)."
  @spec resume_cursor(Sync.t(), String.t()) :: String.t() | nil
  def resume_cursor(%Sync{id: sync_id}, entity_type) do
    Repo.one(
      from c in Checkpoint,
        where: c.sync_id == ^sync_id and c.entity_type == ^entity_type,
        select: c.cursor
    )
  end

  @doc "Acumula o resultado de uma escrita no relatório da sincronização (FR-028)."
  @spec tally(Sync.t(), :created | :updated | :unchanged | {:skipped, String.t()}) ::
          {:ok, Sync.t()} | {:error, Ecto.Changeset.t()}
  def tally(%Sync{} = sync, outcome) do
    attrs =
      case outcome do
        :created ->
          %{
            records_collected: sync.records_collected + 1,
            records_created: sync.records_created + 1
          }

        :updated ->
          %{
            records_collected: sync.records_collected + 1,
            records_updated: sync.records_updated + 1
          }

        :unchanged ->
          %{records_collected: sync.records_collected + 1}

        {:skipped, reason} ->
          %{
            records_collected: sync.records_collected + 1,
            records_skipped: sync.records_skipped + 1,
            skip_reasons: Map.update(sync.skip_reasons, reason, 1, &(&1 + 1))
          }
      end

    sync |> Sync.changeset(attrs) |> Repo.update()
  end

  @spec finish(Sync.t(), :completed | :failed | :interrupted, keyword()) ::
          {:ok, Sync.t()} | {:error, Ecto.Changeset.t()}
  def finish(%Sync{} = sync, status, opts \\ []) do
    attrs =
      %{
        status: to_string(status),
        finished_at: DateTime.utc_now(:second),
        error_reason: opts[:error_reason]
      }
      |> then(fn attrs ->
        case opts[:memberships_pending_role] do
          nil -> attrs
          n -> Map.put(attrs, :memberships_pending_role, n)
        end
      end)

    sync |> Sync.changeset(attrs) |> Repo.update()
  end

  @spec reload(Sync.t()) :: Sync.t()
  def reload(%Sync{id: id}), do: Repo.get!(Sync, id)
end
