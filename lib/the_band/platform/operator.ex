defmodule TheBand.Platform.Operator do
  @moduledoc """
  O operador da plataforma — spec 070 (`data-model.md` §1). **Privado ao contexto**
  `TheBand.Platform`: ninguém de fora lê nem grava por este schema.

  Depende de: nenhuma ontologia. Não é conta de organização e não tem `tenant_id` (FR-011).

  Os campos de segredo têm `redact: true`, e `inspect/1` não os mostra. `totp_secret` tem também
  `load_in_query: false` (seguranca-totp.md, T4): o Cloak decifra no carregamento, e sem isso todo
  `%Operator{}` lido para conferir uma sessão traria o segredo em claro na memória da requisição. Só
  `Credentials` o lê, por `select` explícito.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "platform_operators" do
    field :email, :string
    field :name, :string
    field :password_hash, :string, redact: true
    field :password_epoch, :integer, default: 0
    field :setup_code_hash, :binary, redact: true
    field :setup_code_expires_at, :utc_datetime
    field :failed_attempts, :integer, default: 0
    field :last_failed_at, :utc_datetime
    field :logged_in_at, :utc_datetime
    field :totp_secret, TheBand.Encrypted.Binary, redact: true, load_in_query: false
    field :totp_confirmed_at, :utc_datetime
    field :totp_last_used_step, :integer
    field :second_factor_failures, :integer, default: 0
    field :enrollment_code_hash, :binary, redact: true
    field :enrollment_code_expires_at, :utc_datetime
    field :ack_code_hash, :binary, redact: true
    field :ack_code_expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  A política de senha do operador: 12 a 128 caracteres, a mesma das contas de organização
  (`User.senha_changeset/3`). Devolve o hash, ou o changeset com o erro, sem gravar nada.
  """
  @spec validar_senha(String.t()) :: {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def validar_senha(senha) do
    {%{}, %{password: :string}}
    |> cast(%{password: senha}, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 128)
    |> case do
      %{valid?: true} -> {:ok, Bcrypt.hash_pwd_salt(senha)}
      invalido -> {:error, invalido}
    end
  end
end
