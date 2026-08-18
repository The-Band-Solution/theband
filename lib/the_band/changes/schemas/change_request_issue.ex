defmodule TheBand.Changes.Schemas.ChangeRequestIssue do
  @moduledoc """
  A solicitação atende o item de escopo — `sro.change_request_attends_*`.

  `source` guarda **como** o vínculo foi reconhecido, e por ora só existe um valor:
  `"closing_reference"` — o que a ORIGEM reconheceu das closing keywords. Menção sem
  keyword não entra: mencionar e atender são coisas diferentes, e a diferença é a mesma
  que existe entre citar e fechar.

  Medido em 2026-08-17: um PR com quatorze issues listadas em `Closes #411 #412 …` teve
  **uma** reconhecida — a palavra-chave vale para o número imediatamente seguinte.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "change_request_issues" do
    field :tenant_id, :binary_id
    field :collected_change_request_id, :binary_id
    field :collected_issue_id, :binary_id
    field :source, :string, default: "closing_reference"

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id collected_change_request_id collected_issue_id source collected_at
             last_observed_at no_longer_observed_at)a

  def changeset(vinculo, attrs) do
    vinculo
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :collected_change_request_id,
      :collected_issue_id,
      :source,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :collected_change_request_id, :collected_issue_id])
  end
end
