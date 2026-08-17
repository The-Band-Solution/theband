defmodule TheBand.Communication.Schemas.CollectedIssueComment do
  @moduledoc """
  O comentário como a origem o devolveu — a nota da comunicação (feature 030).

  Instância coletada de `cmo.comment`, pelo mapeamento
  `github.issue_comment.to.cmo.comment`. O corpo fica **cru** (texto plano da origem);
  o autor segue a regra dos designados: `author_login` sempre, `author_person_id` só
  quando a pessoa foi coletada — vínculo nunca é inventado.

  Ato de comentar, discussão e participação NÃO têm schema: são derivados deste
  registro na leitura (`cmo.participation_derived_from_acts`), nunca armazenados.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_issue_comments" do
    field :tenant_id, :binary_id
    field :collected_issue_id, :binary_id

    field :body, :string
    field :author_login, :string
    field :author_person_id, :binary_id

    # O instante do ato de comentar (cmo.commenting_act deriva daqui, um por registro).
    field :external_published_at, :utc_datetime
    # A origem entrega o corpo ATUAL e a data da última edição — nunca o histórico.
    # Limitação declarada no mapeamento.
    field :external_edited_at, :utc_datetime

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :raw_payload, :map

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :tenant_id,
      :collected_issue_id,
      :body,
      :author_login,
      :author_person_id,
      :external_published_at,
      :external_edited_at,
      :source_system,
      :source_instance,
      :external_id,
      :raw_payload,
      :collected_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([
      :tenant_id,
      :collected_issue_id,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :external_id])
  end
end
