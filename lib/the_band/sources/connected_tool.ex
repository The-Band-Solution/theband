defmodule TheBand.Sources.ConnectedTool do
  @moduledoc """
  Declaração de que um tenant usa determinada ferramenta, em determinada
  instância (FR-002).

  `tool_type` é enum e não texto livre (FR-003): ferramenta nova é migração
  declarada, não dado solto que ninguém sabe de onde veio. Nesta entrega só
  `github` é coletável, mas o cadastro já acomoda os demais sem mudança
  estrutural.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @tool_types ~w(github gitlab azure_devops jira sonar)
  @statuses ~w(active needs_attention disabled)

  schema "connected_tools" do
    field :tenant_id, :binary_id
    field :tool_type, :string
    field :instance_url, :string
    # Qual organização observar nesta instância. A instância diz onde; não diz qual.
    field :organization_login, :string
    field :status, :string, default: "active"

    field :needs_attention_since, :utc_datetime
    field :needs_attention_reason, :string
    field :last_sync_at, :utc_datetime

    has_many :credentials, TheBand.Sources.ToolCredential, foreign_key: :connected_tool_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [
      :tenant_id,
      :tool_type,
      :instance_url,
      :organization_login,
      :status,
      :needs_attention_since,
      :needs_attention_reason,
      :last_sync_at
    ])
    |> validate_required([:tenant_id, :tool_type, :instance_url])
    |> validate_github_organization()
    |> validate_inclusion(:tool_type, @tool_types)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:tenant_id, :tool_type, :instance_url],
      message: "esta instância já está conectada para esta organização"
    )
  end

  # FR-010 — sem saber qual organização observar, a coleta adivinharia, e trazer
  # dado de organização errada para dentro do tenant é erro que ninguém percebe.
  defp validate_github_organization(changeset) do
    case get_field(changeset, :tool_type) do
      "github" -> validate_required(changeset, [:organization_login])
      _ -> changeset
    end
  end

  @spec tool_types() :: [String.t()]
  def tool_types, do: @tool_types

  @spec collectable?(t()) :: boolean()
  def collectable?(%__MODULE__{tool_type: "github"}), do: true
  def collectable?(_), do: false
end
