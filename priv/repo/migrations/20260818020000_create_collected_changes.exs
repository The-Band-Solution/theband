defmodule TheBand.Repo.Migrations.CreateCollectedChanges do
  @moduledoc """
  As mudanças como a origem as entregou — feature 032.

  `collected_change_requests` instancia `cmpo.change_request`; `collected_commits`,
  `cmpo.commit_artifact_copy`. As duas tabelas de vínculo materializam relações
  declaradas: `commit_authors` é `cmpo.stakeholder_performed_commit` (cardinalidade
  `many` na origem — todo commit deste repositório tem dois autores) e
  `change_request_issues` é `sro.change_request_attends_*`.

  Autoria em tabela, e não em coluna, é a decisão que carrega esta migração: coluna
  faria o modelo mentir sobre co-autoria, que é o caso comum aqui.
  """
  use Ecto.Migration

  def change do
    create table(:collected_change_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_repository_id,
          references(:observed_repositories, type: :uuid, on_delete: :delete_all),
          null: false

      add :number, :integer, null: false
      add :title, :text
      add :body, :text
      # OPEN | CLOSED | MERGED — cru, como a origem entrega.
      add :state, :string

      add :source_branch, :string
      add :target_branch, :string
      add :changed_files, :integer

      # Quem submeteu e quem integrou são vínculos DISTINTOS: pedir e integrar são atos
      # diferentes, e a CMPO declara participações separadas para cada um.
      add :author_login, :string
      add :author_person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all)
      add :merged_by_login, :string
      add :merged_by_person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all)

      add :external_created_at, :utc_datetime
      add :external_merged_at, :utc_datetime
      add :external_closed_at, :utc_datetime

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :raw_payload, :map

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collected_change_requests, [:tenant_id, :external_id])
    create index(:collected_change_requests, [:tenant_id, :observed_repository_id])
    create index(:collected_change_requests, [:tenant_id, :author_person_id])
    create index(:collected_change_requests, [:tenant_id, :merged_by_person_id])

    create table(:collected_commits, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_repository_id,
          references(:observed_repositories, type: :uuid, on_delete: :delete_all),
          null: false

      # `zero_or_one` na relação declarada: commit fora de solicitação é representável,
      # e um modelo que o proíbe não mede o trabalho que ninguém revisou.
      add :change_request_id,
          references(:collected_change_requests, type: :uuid, on_delete: :nilify_all)

      add :sha, :string, null: false
      add :message_headline, :text
      add :message_body, :text
      add :additions, :integer
      add :deletions, :integer
      add :changed_files, :integer
      add :external_committed_at, :utc_datetime

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :raw_payload, :map

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collected_commits, [:tenant_id, :external_id])
    create index(:collected_commits, [:tenant_id, :change_request_id])
    create index(:collected_commits, [:tenant_id, :observed_repository_id])

    create table(:commit_authors, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :collected_commit_id,
          references(:collected_commits, type: :uuid, on_delete: :delete_all),
          null: false

      add :author_login, :string
      add :author_person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all)
      add :author_name, :string
      # Dado pessoal: fica no banco porque é a única identificação de quem não tem conta
      # no GitHub, e NUNCA vai para tela. A limitação está no mapeamento.
      add :author_email, :string
      # O autor que o Git registra × os co-autores do trailer Co-Authored-By. São fatos
      # diferentes sobre a mesma mudança, e achatá-los perderia a distinção.
      add :is_primary, :boolean, null: false, default: false

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:commit_authors, [:tenant_id, :collected_commit_id])
    create index(:commit_authors, [:tenant_id, :author_person_id])

    create table(:change_request_issues, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :collected_change_request_id,
          references(:collected_change_requests, type: :uuid, on_delete: :delete_all),
          null: false

      add :collected_issue_id,
          references(:collected_issues, type: :uuid, on_delete: :delete_all),
          null: false

      # Só "closing_reference" por ora — o que a ORIGEM reconheceu. Menção sem closing
      # keyword não entra: mencionar e atender são coisas diferentes.
      add :source, :string, null: false

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:change_request_issues, [
             :tenant_id,
             :collected_change_request_id,
             :collected_issue_id
           ])

    create index(:change_request_issues, [:tenant_id, :collected_issue_id])

    alter table(:observed_repositories) do
      add :changes_collected_at, :utc_datetime
    end
  end
end
