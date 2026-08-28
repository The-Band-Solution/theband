defmodule TheBand.Tenants.Access.ScopeGrant do
  @moduledoc """
  Concessão de escopo de acesso — contrato em
  `specs/045-autenticacao-e-acesso/contracts/access-scopes.md`.

  Só o CONCEDIDO vira linha: escopo derivado é leitura das relações vigentes e
  nunca se grava (FR-020/021). `person` não é concedível — é o piso do elo.
  Revogar preenche `revoked_at`; a linha fica, o histórico também (III).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @levels ~w(team project organization)

  @type t :: %__MODULE__{}

  schema "access_scope_grants" do
    field :tenant_id, :binary_id
    field :user_id, :binary_id
    field :level, :string
    field :target_id, :binary_id

    field :granted_by_user_id, :binary_id
    field :granted_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:tenant_id, :user_id, :level, :target_id, :granted_by_user_id, :granted_at])
    |> validate_required([
      :tenant_id,
      :user_id,
      :level,
      :target_id,
      :granted_by_user_id,
      :granted_at
    ])
    |> validate_inclusion(:level, @levels)
    |> unique_constraint([:tenant_id, :user_id, :level, :target_id],
      name: :access_scope_grants_vigente_index
    )
  end

  @doc "A revogação é marca com autoria, nunca delete."
  def revoke_changeset(grant, actor_id) do
    change(grant,
      revoked_by_user_id: actor_id,
      revoked_at: DateTime.utc_now(:second)
    )
  end

  @spec vigente?(t()) :: boolean()
  def vigente?(%__MODULE__{revoked_at: nil}), do: true
  def vigente?(_), do: false
end
