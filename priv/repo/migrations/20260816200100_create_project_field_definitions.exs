defmodule TheBand.Repo.Migrations.CreateProjectFieldDefinitions do
  @moduledoc """
  As definições dos campos configuráveis — sprint 017, T048, FR-023 e FR-027.

  **A identidade é `field_external_id`, nunca o nome.** Renomear "Priority" para
  "Prioridade" atualiza `name` da mesma linha — não cria campo novo, e não invalida o
  mapeamento declarado por tenant. A unicidade inclui o quadro (FR-027a): o id do campo
  é local ao quadro, e tratá-lo como global colidiria quadros diferentes.
  """

  use Ecto.Migration

  def change do
    create table(:project_field_definitions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all),
          null: false

      add :field_external_id, :string, null: false
      add :name, :string, null: false
      add :data_type, :string, null: false

      # Só seleção única tem opções; nos demais fica nulo — ausência real, não lista vazia.
      add :options, :jsonb

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :project_field_definitions,
             [:tenant_id, :observed_project_id, :field_external_id],
             name: :project_field_definitions_identidade_index
           )
  end
end
