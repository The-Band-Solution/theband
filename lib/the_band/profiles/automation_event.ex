defmodule TheBand.Profiles.AutomationEvent do
  @moduledoc """
  O ato de ligar ou desligar a geração automática de uma organização — feature 027.

  Somente-acréscimo: desligar é um evento novo, nunca a remoção do anterior. O estado atual
  é derivado do evento mais recente, e não guardado em coluna — ver `TheBand.Profiles.Automation`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @events ~w(enabled disabled)

  schema "profile_automation_events" do
    field :tenant_id, :binary_id
    field :event, :string
    field :actor_user_id, :binary_id
    field :occurred_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  O changeset do ato.

  `actor_user_id` é obrigatório aqui **e** no banco. A automação sem autor é o estado sem
  dono que a `FR-018a` existe para impedir: é a única pessoa identificável por trás de todo
  texto que a rodada produzir.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:tenant_id, :event, :actor_user_id, :occurred_at])
    |> validate_required([:tenant_id, :event, :actor_user_id, :occurred_at])
    |> validate_inclusion(:event, @events)
    |> check_constraint(:event, name: :profile_automation_event_valido)
  end
end
