defmodule TheBand.WorkItems.Schemas.IssueAssignee do
  @moduledoc """
  Quem a origem diz estar designado para a issue.

  `person_id` **anulável é declaração, não falha**: quando a pessoa designada não foi
  coletada — conta fora da organização, ou coleta de pessoas mais antiga que a de issues
  —, o login fica preservado e o vínculo fica visivelmente ausente. Criar a pessoa a
  partir da issue produziria registro sem a proveniência que a coleta de EO dá.
  `no_longer_observed_at` marca a designação que a origem deixou de trazer. **Nunca se apaga
  dados**: quem foi responsável por uma issue é parte de como o trabalho aconteceu, e apagar
  destruiria a resposta de "quem estava nisto em março".
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "issue_assignees" do
    field :tenant_id, :binary_id
    field :collected_issue_id, :binary_id
    field :login, :string
    field :person_id, :binary_id

    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(assignee, attrs) do
    assignee
    |> cast(attrs, [:tenant_id, :collected_issue_id, :login, :person_id, :no_longer_observed_at])
    |> validate_required([:tenant_id, :collected_issue_id, :login])
    |> unique_constraint([:collected_issue_id, :login])
  end
end
