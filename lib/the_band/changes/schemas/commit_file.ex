defmodule TheBand.Changes.Schemas.CommitFile do
  @moduledoc """
  O arquivo que um commit tocou — `cmpo.artifact_copy` (feature 035, issue #429).

  A CMPO já tinha o conceito, e a relação `cmpo.commit_produced_artifact_copy` fecha o
  par que existia pela metade: `commit_sends_copy_to_target_branch` dizia para onde a
  cópia vai sem dizer de onde vem.

  **O conteúdo não é guardado.** A plataforma registra que o arquivo mudou e quanto; o
  código vive no repositório. Guardar o diff faria dela um espelho de código, e nada no
  produto consome isso.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "commit_files" do
    field :tenant_id, :binary_id
    field :collected_commit_id, :binary_id

    field :path, :string
    field :change, :string
    field :additions, :integer
    field :deletions, :integer
    field :previous_path, :string

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id collected_commit_id path change additions deletions previous_path
             collected_at last_observed_at no_longer_observed_at)a

  def changeset(arquivo, attrs) do
    arquivo
    |> cast(attrs, @campos)
    |> validate_required([:tenant_id, :collected_commit_id, :path, :collected_at])
    |> unique_constraint([:tenant_id, :collected_commit_id, :path])
  end
end
