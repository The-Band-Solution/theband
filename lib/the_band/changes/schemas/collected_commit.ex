defmodule TheBand.Changes.Schemas.CollectedCommit do
  @moduledoc """
  O commit como a origem o entregou — `cmpo.commit_artifact_copy`, o **ato**.

  A CMPO desfaz a ambiguidade que o Git tem: "commit" é o ato (action) ou a cópia
  versionada (`cmpo.artifact_copy`, object)? Este schema é o ato. A cópia por arquivo não
  é coletada — limitação declarada no mapeamento.

  `change_request_id` é anulável porque a relação declarada tem `zero_or_one` no destino:
  commit direto na branch existe, e um modelo que o proíbe não mede o trabalho que
  ninguém revisou.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_commits" do
    field :tenant_id, :binary_id
    field :observed_repository_id, :binary_id
    field :change_request_id, :binary_id

    field :sha, :string
    field :message_headline, :string
    field :message_body, :string
    field :additions, :integer
    field :deletions, :integer
    field :changed_files, :integer
    field :external_committed_at, :utc_datetime

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :raw_payload, :map

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_repository_id change_request_id sha message_headline
             message_body additions deletions changed_files external_committed_at
             source_system source_instance external_id raw_payload collected_at
             last_observed_at no_longer_observed_at)a

  def changeset(commit, attrs) do
    commit
    |> cast(attrs, @campos)
    |> validate_required([
      :tenant_id,
      :observed_repository_id,
      :sha,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
  end
end
