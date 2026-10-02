defmodule TheBand.Platform.RecoveryCode do
  @moduledoc """
  Um código de recuperação do segundo fator — spec 070 (`data-model.md` §1a). **Privado ao
  contexto** `TheBand.Platform`.

  Depende de: nenhuma ontologia.

  Guardado só como resumo (`code_hash`, `redact: true`). Um código termina **usado** (`used_at`) ou
  **invalidado** (`invalidated_at`), nunca os dois (seguranca-totp.md, T8): assim "algum código foi
  usado por alguém?" se responde pelo banco, e não só pelo log.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "platform_operator_recovery_codes" do
    belongs_to :operator, TheBand.Platform.Operator

    field :code_hash, :binary, redact: true
    field :used_at, :utc_datetime
    field :invalidated_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
