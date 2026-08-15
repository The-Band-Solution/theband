defmodule TheBand.Repo.Migrations.CreateSpoProjects do
  @moduledoc """
  O projeto, a hierarquia e os repositórios dele — feature 025.

  ## Três tabelas, e nenhuma coluna `project_id` na issue

  *"As issues dos repositórios são issues do projeto"* é uma **travessia**, e não uma
  associação nova: projeto → repositórios → issues. Guardar na issue duplicaria o fato,
  e as duas fontes discordariam no dia em que alguém movesse um repositório de projeto.

  ## A fase não é coluna

  Simples e complexo são `phase` de `spo.project`, e a fase é **consequência de ter
  partes** — não um tipo escolhido no cadastro. Por isso não há coluna de tipo: a
  resposta sai de haver ou não filhos, e um campo gravado divergiria da estrutura no
  primeiro dia.
  """

  use Ecto.Migration

  def change do
    create table(:spo_projects, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :name, :string, null: false
      add :started_on, :date
      add :ended_on, :date

      # Projeto é **declaração**, e não observação: decisão tem autor.
      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      # O pai, e a coluna é o que materializa "no máximo um pai vigente" —
      # `spo.rule02.project_has_at_most_one_parent`. Uma tabela de associação permitiria
      # dois pais e exigiria índice parcial para proibir; a coluna torna impossível.
      #
      # **O ciclo continua possível** — `A → B → C → A` tem um pai por projeto — e é
      # `spo.rule01` que o proíbe, verificado no comando antes de persistir. Constraint
      # de banco não alcança fecho transitivo.
      add :parent_id, references(:spo_projects, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:spo_projects, [:tenant_id, :name], name: :spo_projects_name_index)
    create index(:spo_projects, [:tenant_id, :parent_id], name: :spo_projects_parent_index)

    create table(:spo_project_repositories, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :project_id, references(:spo_projects, type: :uuid, on_delete: :delete_all), null: false

      add :observed_repository_id,
          references(:observed_repositories, type: :uuid, on_delete: :delete_all),
          null: false

      add :linked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :linked_at, :utc_datetime, null: false

      # Desfazer **marca**, e nunca apaga — com autor, como a alocação de papel. Trocar
      # de projeto preserva os dois registros.
      add :unlinked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :unlinked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # **Parcial sobre os vigentes.** O vínculo encerrado precisa continuar existindo, e um
    # índice sobre todas as linhas impediria reassociar um repositório que já saiu.
    create unique_index(
             :spo_project_repositories,
             [:tenant_id, :project_id, :observed_repository_id],
             where: "unlinked_at IS NULL",
             name: :spo_project_repositories_vigente_index
           )

    create index(:spo_project_repositories, [:tenant_id, :observed_repository_id],
             name: :spo_project_repositories_repo_index
           )
  end
end
