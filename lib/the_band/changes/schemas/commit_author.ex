defmodule TheBand.Changes.Schemas.CommitAuthor do
  @moduledoc """
  Quem executou um commit — `cmpo.stakeholder_performed_commit`.

  **Tabela, e não coluna.** A relação declarada tem cardinalidade `many` na origem, e no
  dado real deste repositório **todo** commit tem dois autores: quem escreveu e o agente,
  pelo trailer `Co-Authored-By`. Coluna faria o modelo mentir sobre autoria compartilhada.

  `is_primary` separa o autor que o Git registra dos co-autores do trailer — são fatos
  diferentes sobre a mesma mudança, e achatá-los perderia a distinção.

  `author_email` **nunca vai para tela**: é dado pessoal, e fica no banco só porque é a
  única identificação de quem não tem conta no GitHub.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "commit_authors" do
    field :tenant_id, :binary_id
    field :collected_commit_id, :binary_id

    field :author_login, :string
    field :author_person_id, :binary_id
    field :author_name, :string
    field :author_email, :string
    field :is_primary, :boolean, default: false

    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id collected_commit_id author_login author_person_id author_name
             author_email is_primary collected_at last_observed_at no_longer_observed_at)a

  def changeset(autor, attrs) do
    autor
    |> cast(attrs, @campos)
    |> validate_required([:tenant_id, :collected_commit_id, :collected_at])
  end
end
