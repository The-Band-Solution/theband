defmodule TheBand.AI.ProviderCredential do
  @moduledoc """
  A credencial do provedor de modelo de linguagem — feature 027.

  **Não é uma ferramenta conectada.** As ferramentas conectadas são fontes de observação; um
  provedor de modelo interpreta o que já foi observado. Ver o moduledoc da migração.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @providers ~w(openai)

  schema "ai_provider_credentials" do
    field :tenant_id, :binary_id
    field :provider, :string
    field :base_url, :string
    field :default_model, :string

    # `redact: true` mantém o segredo fora de `inspect/1` — que é o que vai para o log
    # quando alguém inspeciona o struct num erro.
    field :secret, TheBand.Encrypted.Binary, redact: true
    field :last_four, :string

    field :declared_by_user_id, :binary_id
    field :validated_at, :utc_datetime
    field :last_failure_at, :utc_datetime
    field :last_failure_reason, :string

    timestamps(type: :utc_datetime)
  end

  @spec providers() :: [String.t()]
  def providers, do: @providers

  @doc """
  A chave como ela aparece na tela, e é a **única** forma em que aparece.

  Os quatro últimos caracteres existem para alguém reconhecer qual chave está gravada sem
  que a tela precise decifrar coisa alguma.
  """
  @spec masked(t()) :: String.t()
  def masked(%__MODULE__{last_four: last_four}), do: "••••" <> to_string(last_four)

  @doc """
  O changeset de gravação.

  `last_four` é **derivado** do segredo, e não recebido: um valor recebido poderia não
  corresponder à chave, e a tela passaria a mostrar quatro caracteres que não identificam
  nada.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(cred, attrs) do
    cred
    |> cast(attrs, [
      :tenant_id,
      :provider,
      :base_url,
      :default_model,
      :secret,
      :declared_by_user_id,
      :validated_at,
      :last_failure_at,
      :last_failure_reason
    ])
    |> validate_required([:tenant_id, :provider, :base_url, :secret])
    |> validate_inclusion(:provider, @providers)
    |> validate_length(:secret, min: 20, message: "curta demais para ser uma chave de API")
    |> derivar_last_four()
    |> unique_constraint([:tenant_id, :provider],
      name: :ai_provider_credentials_por_tenant_index
    )
  end

  defp derivar_last_four(changeset) do
    case get_change(changeset, :secret) do
      nil -> changeset
      secret -> put_change(changeset, :last_four, String.slice(secret, -4, 4))
    end
  end
end
