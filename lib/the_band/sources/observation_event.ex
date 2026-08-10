defmodule TheBand.Sources.ObservationEvent do
  @moduledoc """
  Uma transição de observação de ferramenta conectada — append-only (T005, FR-014).

  `ended` e `resumed`. O **estado** da observação não mora aqui: sai do último evento,
  por `TheBand.Sources.observation_ended?/1`. É a ADR 0004 D7 aplicada ao caso que ela
  cobre — evento registra o que ocorreu, situação é derivada.

  ## Sem `update_changeset`, de propósito

  Não existe caminho para alterar um evento. Se um encerramento foi registrado errado, a
  correção é um evento novo: atualizar reescreveria o passado. O schema não declara
  `updated_at`, e a tabela também não o tem.

  ## `impact` guarda o que foi contado no instante

  E não o que uma consulta de hoje devolveria. Uma coleta posterior muda os números, e o
  que interessa no registro é o que a pessoa viu antes de confirmar.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @events ~w(ended resumed)

  schema "tool_observation_events" do
    field :tenant_id, :binary_id
    field :connected_tool_id, :binary_id

    field :event, :string
    field :occurred_at, :utc_datetime

    # Anulável: uma retomada pode vir de processo, e inventar um autor seria pior que
    # declarar que não há.
    field :actor_user_id, :binary_id

    field :reason, :string
    field :impact, :map

    # Microssegundo, e não segundo: dois eventos do mesmo segundo empatariam, e o
    # estado derivado do "último evento" passaria a depender de acidente do plano de
    # execução. Mesma classe do defeito de escolha de credencial do sprint 001.
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc "Os dois eventos possíveis."
  @spec events() :: [String.t()]
  def events, do: @events

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :tenant_id,
      :connected_tool_id,
      :event,
      :occurred_at,
      :actor_user_id,
      :reason,
      :impact
    ])
    |> validate_required([:tenant_id, :connected_tool_id, :event, :occurred_at])
    |> validate_inclusion(:event, @events)
    # A restrição vive **também** no banco, e é ela que vale quando a escrita não passa
    # por este changeset — script, console, correção manual.
    |> check_constraint(:event,
      name: :tool_observation_events_event_check,
      message: "só 'ended' e 'resumed' existem como transição de observação"
    )
  end
end
