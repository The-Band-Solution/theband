defmodule TheBand.Tenants.Access.OrganizationAccountDeclaration do
  @moduledoc """
  A declaração de que uma pessoa observada é, na verdade, a **conta da organização** — feature
  076, T025 (`data-model.md` §2; research.md R14; R8 da segurança).

  Relator com autoria e revogação, como `ScopeGrant`: revogar preenche `revoked_at`, e a linha
  fica. **Nunca** em `eo_people.account_type`, que a coleta reescreve.

  Privado a `TheBand.Tenants`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "organization_account_declarations" do
    field :tenant_id, :binary_id
    field :person_id, :binary_id
    field :reason, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "A declaração nova. O motivo é obrigatório, e espaço não é motivo."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(declaracao, attrs) do
    declaracao
    |> cast(attrs, [:tenant_id, :person_id, :reason, :declared_by_user_id, :declared_at])
    |> update_change(:reason, &String.trim/1)
    |> validate_required([:tenant_id, :person_id, :reason, :declared_by_user_id, :declared_at])
    |> foreign_key_constraint(:person_id,
      name: :organization_account_declarations_person_id_fkey
    )
    |> unique_constraint(:person_id, name: :organization_account_declarations_vigente_index)
    |> check_constraint(:reason, name: :organization_account_declarations_reason_present)
  end

  @doc "A revogação é marca com autoria, nunca delete."
  @spec revoke_changeset(t(), Ecto.UUID.t()) :: Ecto.Changeset.t()
  def revoke_changeset(declaracao, actor_id) do
    declaracao
    |> change(revoked_by_user_id: actor_id, revoked_at: DateTime.utc_now(:second))
    |> check_constraint(:revoked_at, name: :organization_account_declarations_revoked_after)
  end
end
