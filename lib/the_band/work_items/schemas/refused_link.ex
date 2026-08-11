defmodule TheBand.WorkItems.Schemas.RefusedLink do
  @moduledoc """
  Um vínculo que a plataforma recusou, com o motivo — e o caminho, quando é ciclo.

  Existe porque nomear o caminho que fecha o ciclo é exigência, e um vínculo descartado
  em memória não tem como ser nomeado depois da coleta.

  **As issues envolvidas permanecem coletadas.** Recusa-se o vínculo, nunca a issue:
  ela existe na origem, e esconder dado observado por causa de relação inválida seria
  pior que registrar a relação inválida.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @reasons ~w(cycle out_of_scope task_meets_epic)

  schema "refused_links" do
    field :tenant_id, :binary_id
    field :parent_issue_id, :binary_id
    field :child_issue_id, :binary_id
    field :child_external_id, :string

    field :reason, :string
    field :cycle_path, :string
    field :refused_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec reasons() :: [String.t()]
  def reasons, do: @reasons

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :tenant_id,
      :parent_issue_id,
      :child_issue_id,
      :child_external_id,
      :reason,
      :cycle_path,
      :refused_at
    ])
    |> validate_required([:tenant_id, :reason, :refused_at])
    |> validate_inclusion(:reason, @reasons)
    |> check_constraint(:reason, name: :refused_links_reason_check)
  end
end
