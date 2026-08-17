defmodule TheBand.Repo.Migrations.CreateCollectedIssueComments do
  @moduledoc """
  A nota da comunicação — feature 030, mapeamento `github.issue_comment.to.cmo.comment`.

  O comentário como a origem entregou: corpo em texto plano, autor pela regra dos
  designados (login sempre; pessoa só quando coletada), e as três marcas de observação —
  sumiço é `no_longer_observed_at`, nunca DELETE. Ato, discussão e participação NÃO têm
  tabela: são derivados na leitura (cmo.participation_derived_from_acts).
  """
  use Ecto.Migration

  def change do
    create table(:collected_issue_comments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :collected_issue_id,
          references(:collected_issues, type: :uuid, on_delete: :delete_all),
          null: false

      add :body, :text
      add :author_login, :string
      add :author_person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all)

      add :external_published_at, :utc_datetime
      add :external_edited_at, :utc_datetime

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :raw_payload, :map

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collected_issue_comments, [:tenant_id, :external_id])
    create index(:collected_issue_comments, [:tenant_id, :collected_issue_id])
    # A participação agrega por pessoa — a consulta da página da pessoa vive neste índice.
    create index(:collected_issue_comments, [:tenant_id, :author_person_id])

    alter table(:observed_repositories) do
      # Ao lado de issues_collected_at: decide o incremental E qual frase o vazio da
      # tela usa — "discussão não coletada" × "sem comentários" são estados distintos.
      add :comments_collected_at, :utc_datetime
    end
  end
end
