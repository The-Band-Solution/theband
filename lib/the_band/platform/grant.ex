defmodule TheBand.Platform.Grant do
  @moduledoc """
  A concessão do papel de operador — spec 070 (`data-model.md` §2). Relator, e não coluna booleana
  (AGENTS §7.7). **Privado ao contexto** `TheBand.Platform`.

  Depende de: nenhuma ontologia.

  O registro é somente-acréscimo no banco: a única alteração aceita é a revogação de uma concessão
  vigente. `granted_by_declared` diz **declarado** de propósito: é o que quem rodou o comando de
  release escreveu, e não um autor autenticado (O11).
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "platform_operator_grants" do
    belongs_to :operator, TheBand.Platform.Operator

    field :granted_at, :utc_datetime
    field :granted_via, :string
    field :granted_by_declared, :string
    field :email_at_grant, :string
    field :revoked_at, :utc_datetime
    field :revoked_via, :string
    field :revoked_by_declared, :string
    field :revoke_note, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
