defmodule TheBand.Platform.OperatorSession do
  @moduledoc """
  A sessão do operador da plataforma — spec 070 (`data-model.md` §3). Tabela própria, separada de
  `user_sessions`, e lida só por `TheBand.Platform.Sessions`. **Privado ao contexto**.

  Depende de: nenhuma ontologia.

  O banco guarda só o resumo do token (`token_hash`, `redact: true`), como em `user_sessions`.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "platform_operator_sessions" do
    belongs_to :operator, TheBand.Platform.Operator

    field :token_hash, :binary, redact: true
    field :password_epoch, :integer
    field :ended_at, :utc_datetime
    field :last_seen_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
