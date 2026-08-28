defmodule TheBand.Tenants.User do
  @moduledoc """
  Pessoa usuária da plataforma, ligada a exatamente um tenant.

  `role` distingue quem pode conectar ferramenta e gerenciar credencial
  (`admin`) de quem apenas consulta (`member`) — Assumptions da spec. Um modelo
  de permissões mais rico fica para depois.

  ## `role` daqui NÃO é papel na organização

  Este `role` diz quem pode **mexer** na plataforma. O papel na organização —
  `Developer Role`, `Tech Leader` — vive em `eo_organizational_roles`, e diz o que a pessoa
  **faz**. São vocabulários diferentes com a mesma palavra, e trocá-los daria acesso de
  administração a quem só lidera uma equipe.

  ## `person_id` — quem esta conta é entre as pessoas observadas

  Issue #369. A regra de quem vê o painel de quem depende de saber qual das pessoas
  observadas é quem está logado, e esse elo não vinha de lugar nenhum: o GitHub não entrega
  e-mail, e as 88 pessoas de `eo_people` vieram todas sem.

  O elo é **declarado**, aponta para `eo_people` — que já carrega o id do GitHub como
  critério de identidade — e é revogável. Não é campo de cadastro: é o que decide acesso a
  painel, e por isso guarda quem declarou e quando.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(admin member)

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "member"

    # Feature 045 — credencial e sessão versionada (contracts/auth.md).
    # `password_hash` NULO é conta pré-feature: a entrada recusa com a mensagem
    # única e orienta a procurar quem administra (FR-014). A senha em claro só
    # existe no campo virtual, dura o changeset, e nunca chega a log ou tela.
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :password_set_at, :utc_datetime
    field :must_change_password, :boolean, default: false
    field :session_token, :string, redact: true
    field :logged_in_at, :utc_datetime
    field :failed_attempts, :integer, default: 0
    field :last_failed_at, :utc_datetime

    # Issue #369: qual pessoa observada é esta conta. Aponta para `eo_people`, e não para o
    # id do GitHub cru — aquele já é o critério de identidade de lá, e duas cópias divergem.
    field :person_id, :binary_id
    field :person_declared_by_user_id, :binary_id
    field :person_declared_at, :utc_datetime
    field :person_revoked_by_user_id, :binary_id
    field :person_revoked_at, :utc_datetime

    belongs_to :tenant, TheBand.Tenants.Tenant

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :tenant_id])
    |> validate_required([:email, :tenant_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
  end

  @doc """
  Declara qual pessoa observada é esta conta — issue #369.

  Changeset **separado** do de cadastro: aquele grava nome, e-mail e papel de plataforma;
  este grava um elo que concede acesso a painel. Um só changeset deixaria a edição de nome
  poder mexer em visibilidade sem que ninguém percebesse.
  """
  @spec elo_da_pessoa_changeset(t(), map()) :: Ecto.Changeset.t()
  def elo_da_pessoa_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :person_id,
      :person_declared_by_user_id,
      :person_declared_at,
      :person_revoked_by_user_id,
      :person_revoked_at
    ])
    |> validate_required([:person_id, :person_declared_by_user_id, :person_declared_at])
    |> unique_constraint(:person_id, name: :users_pessoa_observada_vigente_index)
  end

  @doc "O elo está vigente? Declarado e não revogado — as duas coisas, e não só a primeira."
  @spec elo_vigente?(t()) :: boolean()
  def elo_vigente?(%__MODULE__{person_id: id, person_revoked_at: nil}) when not is_nil(id),
    do: true

  def elo_vigente?(_), do: false

  @spec admin?(t()) :: boolean()
  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false

  @doc """
  Define a senha — contracts/auth.md.

  Changeset separado do cadastro pela mesma razão do elo: senha decide entrada,
  e um changeset único deixaria edição de nome tocar credencial sem ninguém ver.
  Mínimo de 12 caracteres, sem exigência de composição (assumption da spec) —
  regra simples e verificável. O hash acontece AQUI: nenhum caminho grava senha
  em claro por esquecimento (mesmo desenho do Vault, FR-003).
  """
  @spec senha_changeset(t(), map(), keyword()) :: Ecto.Changeset.t()
  def senha_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 128)
    |> hash_password(opts)
  end

  defp hash_password(changeset, opts) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password when is_binary(password) ->
        changeset
        |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
        |> put_change(:password_set_at, DateTime.utc_now(:second))
        |> put_change(:must_change_password, Keyword.get(opts, :temporary, false))
        |> put_change(:session_token, novo_token())
        |> delete_change(:password)
    end
  end

  @doc "Token de sessão novo — girá-lo derruba as outras sessões (FR-015)."
  @spec novo_token() :: String.t()
  def novo_token, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
end
