defmodule TheBand.Tenants.Schemas.AccountRoleChange do
  @moduledoc """
  O episódio de uma mudança de papel — spec 072 (`data-model.md`). Somente-acréscimo no banco.
  Privado a `TheBand.Tenants`.

  Depende de: nenhuma ontologia.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "account_role_changes" do
    field :tenant_id, :binary_id
    belongs_to :user, TheBand.Tenants.User
    belongs_to :changed_by_user, TheBand.Tenants.User
    field :from_role, :string
    field :to_role, :string
    field :note, :string
    field :txid, :integer, read_after_writes: true

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
