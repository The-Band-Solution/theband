defmodule TheBand.Sources.ToolCredential do
  @moduledoc """
  Credencial de acesso a uma ferramenta conectada.

  O segredo é cifrado pelo `Ecto.Type` (FR-005), nunca pelo código de aplicação.
  `last_four` existe só para distinguir uma credencial da outra na interface
  (FR-007) — quatro caracteres não reduzem materialmente o espaço de busca de um
  token de 40.

  `@derive {Inspect, except: [:secret]}` cumpre FR-008 no lugar onde o vazamento
  costuma acontecer: um `inspect/1` numa mensagem de erro, num log de exceção ou
  numa telemetria escrita às pressas.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Inspect, except: [:secret]}

  @type t :: %__MODULE__{}

  schema "tool_credentials" do
    field :tenant_id, :binary_id
    field :connected_tool_id, :binary_id

    field :label, :string
    field :secret, TheBand.Encrypted.Binary, redact: true
    field :last_four, :string
    field :active, :boolean, default: true
    field :validated_at, :utc_datetime
    field :scopes, {:array, :string}, default: []
    field :last_failure_at, :utc_datetime
    field :last_failure_reason, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [
      :tenant_id,
      :connected_tool_id,
      :label,
      :secret,
      :last_four,
      :active,
      :validated_at,
      :scopes,
      :last_failure_at,
      :last_failure_reason
    ])
    |> validate_required([
      :tenant_id,
      :connected_tool_id,
      :label,
      :secret,
      :last_four,
      :validated_at
    ])
  end

  @doc """
  Máscara exibível da credencial (FR-007).

  É a única forma pela qual o segredo sai do módulo.
  """
  @spec masked(t()) :: String.t()
  def masked(%__MODULE__{last_four: last_four}), do: "••••••••••••••••" <> to_string(last_four)

  @doc "Extrai os quatro últimos caracteres para exibição."
  @spec last_four(String.t()) :: String.t()
  def last_four(secret) when is_binary(secret) and byte_size(secret) >= 4,
    do: binary_part(secret, byte_size(secret) - 4, 4)

  def last_four(_), do: "????"
end
