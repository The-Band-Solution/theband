defmodule TheBand.Repo.Migrations.CreateCommitFiles do
  @moduledoc """
  Os arquivos que cada commit tocou — `cmpo.artifact_copy` (feature 035, issue #429).

  O par `[commit, path]` identifica a cópia: o mesmo arquivo em dois commits são **duas
  cópias**, e é a sequência delas que responde "quem mexeu neste arquivo".

  **O conteúdo não entra**, e é postura, não limite técnico: a plataforma registra que o
  arquivo mudou e quanto; o código vive no repositório.
  """
  use Ecto.Migration

  def change do
    create table(:commit_files, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :collected_commit_id,
          references(:collected_commits, type: :uuid, on_delete: :delete_all),
          null: false

      add :path, :text, null: false
      # added | modified | removed | renamed — cru, como a origem entrega.
      add :change, :string
      add :additions, :integer
      add :deletions, :integer
      # Preservado quando a origem informa. A plataforma NÃO afirma que as duas cópias
      # são do mesmo artefato: renomeação é delete+add no Git, e afirmar identidade
      # exigiria heurística de similaridade.
      add :previous_path, :text

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:commit_files, [:tenant_id, :collected_commit_id, :path])
    # O índice que sustenta a pergunta "quem mexeu neste arquivo": busca por caminho.
    create index(:commit_files, [:tenant_id, :path])

    alter table(:collected_commits) do
      # Quando os arquivos deste commit foram percorridos. `nil` = não coletado, que é
      # diferente de "commit sem arquivo" — e a tela precisa da distinção.
      add :files_collected_at, :utc_datetime
    end
  end
end
