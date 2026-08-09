defmodule TheBand.Sources do
  @moduledoc """
  Ferramentas conectadas e credenciais (US1).

  A credencial é **validada contra a ferramenta antes de ser gravada** (FR-006).
  Quando a validação falha, nada é gravado — nem a ferramenta, nem a credencial.
  Gravar a ferramenta e deixar a credencial para depois produziria uma conexão
  meio-feita que ninguém sabe se funciona.
  """

  import Ecto.Query

  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.Tenants.Tenant

  # ---------------------------------------------------------------------- leitura

  @spec list_connected_tools(Tenant.t()) :: [ConnectedTool.t()]
  def list_connected_tools(%Tenant{id: tenant_id}) do
    Repo.all(
      from t in ConnectedTool,
        where: t.tenant_id == ^tenant_id,
        order_by: [asc: t.tool_type, asc: t.instance_url],
        preload: [:credentials]
    )
  end

  @spec fetch_connected_tool(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, ConnectedTool.t()} | {:error, :not_found}
  def fetch_connected_tool(%Tenant{id: tenant_id}, id) do
    query =
      from t in ConnectedTool,
        where: t.tenant_id == ^tenant_id and t.id == ^id,
        preload: [:credentials]

    case Repo.one(query) do
      # FR-027 — id de outro tenant devolve :not_found, nunca o registro.
      nil -> {:error, :not_found}
      tool -> {:ok, tool}
    end
  end

  @spec active_credential(ConnectedTool.t()) :: ToolCredential.t() | nil
  def active_credential(%ConnectedTool{id: tool_id}) do
    Repo.one(
      from c in ToolCredential,
        where: c.connected_tool_id == ^tool_id and c.active == true,
        order_by: [desc: c.validated_at],
        limit: 1
    )
  end

  # --------------------------------------------------------------------- escrita

  @doc """
  Conecta uma ferramenta validando a credencial antes de gravar (FR-006).

  Devolve `{:error, :unauthorized}` ou `{:error, {:missing_scopes, escopos}}`
  quando a validação falha — e **nada** é gravado nesses casos.
  """
  @spec connect_tool(Tenant.t(), map()) ::
          {:ok, %{tool: ConnectedTool.t(), credential: ToolCredential.t()}}
          | {:error, term()}
  def connect_tool(%Tenant{} = tenant, attrs) do
    with {:ok, %{scopes: scopes}} <-
           Client.verify_credential(field(attrs, "instance_url"), field(attrs, "secret")) do
      insert_tool_and_credential(tenant, attrs, scopes)
    end
  end

  @doc """
  Acrescenta outra credencial a uma ferramenta já conectada (FR-004).

  As credenciais coexistem e são ativáveis e desativáveis de forma independente,
  porque credenciais diferentes enxergam conjuntos diferentes.
  """
  @spec add_credential(Tenant.t(), ConnectedTool.t(), map()) ::
          {:ok, ToolCredential.t()} | {:error, term()}
  def add_credential(%Tenant{id: tenant_id}, %ConnectedTool{} = tool, attrs) do
    secret = field(attrs, "secret")

    with {:ok, %{scopes: scopes}} <- Client.verify_credential(tool.instance_url, secret) do
      tenant_id
      |> credential_changeset(tool.id, attrs, scopes)
      |> Repo.insert()
    end
  end

  @spec set_credential_active(ToolCredential.t(), boolean()) ::
          {:ok, ToolCredential.t()} | {:error, Ecto.Changeset.t()}
  def set_credential_active(%ToolCredential{} = credential, active?) do
    credential |> ToolCredential.changeset(%{active: active?}) |> Repo.update()
  end

  @doc """
  Marca a ferramenta como precisando de atenção (FR-009).

  Registra data e motivo, e **não** toca nas demais ferramentas do tenant — a
  falha de uma credencial não é motivo para interromper as outras coletas.
  """
  @spec mark_needs_attention(ConnectedTool.t(), String.t()) ::
          {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
  def mark_needs_attention(%ConnectedTool{} = tool, reason) do
    tool
    |> ConnectedTool.changeset(%{
      status: "needs_attention",
      needs_attention_since: DateTime.utc_now(:second),
      needs_attention_reason: reason
    })
    |> Repo.update()
  end

  @spec clear_needs_attention(ConnectedTool.t()) ::
          {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
  def clear_needs_attention(%ConnectedTool{} = tool) do
    tool
    |> ConnectedTool.changeset(%{
      status: "active",
      needs_attention_since: nil,
      needs_attention_reason: nil
    })
    |> Repo.update()
  end

  @spec touch_last_sync(ConnectedTool.t()) ::
          {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
  def touch_last_sync(%ConnectedTool{} = tool) do
    tool
    |> ConnectedTool.changeset(%{last_sync_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  defp insert_tool_and_credential(%Tenant{id: tenant_id}, attrs, scopes) do
    tool_attrs = %{
      tenant_id: tenant_id,
      tool_type: field(attrs, "tool_type", "github"),
      instance_url: field(attrs, "instance_url"),
      organization_login: field(attrs, "organization_login")
    }

    # Ferramenta e credencial entram na mesma transação: gravar a ferramenta e
    # deixar a credencial para depois produziria uma conexão meio-feita que
    # ninguém sabe se funciona.
    Repo.transaction(fn ->
      with {:ok, tool} <- insert_tool(tool_attrs),
           {:ok, credential} <-
             Repo.insert(credential_changeset(tenant_id, tool.id, attrs, scopes)) do
        %{tool: tool, credential: credential}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_tool(tool_attrs) do
    %ConnectedTool{}
    |> ConnectedTool.changeset(tool_attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:updated_at]},
      conflict_target: [:tenant_id, :tool_type, :instance_url],
      returning: true
    )
  end

  defp credential_changeset(tenant_id, tool_id, attrs, scopes) do
    secret = field(attrs, "secret")

    ToolCredential.changeset(%ToolCredential{}, %{
      tenant_id: tenant_id,
      connected_tool_id: tool_id,
      label: field(attrs, "label", "credencial principal"),
      secret: secret,
      last_four: ToolCredential.last_four(secret),
      scopes: scopes,
      validated_at: DateTime.utc_now(:second)
    })
  end

  # Os atributos chegam da tela com chave string e dos testes com átomo. Ler os
  # dois formatos num lugar só evita espalhar `attrs["x"] || attrs[:x]`.
  defp field(attrs, key, default \\ nil) do
    case Map.get(attrs, key) do
      nil -> Map.get(attrs, String.to_existing_atom(key), default)
      value -> value
    end
  end
end
