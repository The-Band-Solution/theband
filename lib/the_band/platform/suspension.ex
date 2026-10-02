defmodule TheBand.Platform.Suspension do
  @moduledoc """
  O episódio de suspensão de uma organização — spec 070 (`data-model.md` §4). **Privado ao
  contexto** `TheBand.Platform`.

  Depende de: nenhuma ontologia.

  Uma metade abre (quem suspendeu, quando, por quê) e a outra fecha (quem reativou). Um aberto por
  organização, e nada se reescreve: o banco só aceita fechar um episódio aberto. A razão vem da
  lista fechada `platform.tenant_suspension` da base de conhecimento.

  `tenant_id` é a única referência a `Tenants`, e só como chave: nenhum `belongs_to :tenant`, para
  o `%Tenant{}` não ficar a um `preload` de distância (constituição, princípio X, letra D).
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "tenant_suspensions" do
    field :tenant_id, :binary_id
    field :suspended_at, :utc_datetime
    belongs_to :suspended_by_operator, TheBand.Platform.Operator
    field :suspend_reason, :string
    field :suspend_note, :string
    field :reactivated_at, :utc_datetime
    belongs_to :reactivated_by_operator, TheBand.Platform.Operator
    field :reactivate_reason, :string
    field :reactivate_note, :string

    timestamps(type: :utc_datetime)
  end
end
