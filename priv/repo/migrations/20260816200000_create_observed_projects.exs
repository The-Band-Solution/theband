defmodule TheBand.Repo.Migrations.CreateObservedProjects do
  @moduledoc """
  A entidade de quadro — sprint 017, T047, FR-020.

  O quadro (Projects v2) passa a existir como **artefato de fonte**: nome, número e
  organização de origem. Medido em 2026-08-16: 15 dos 26 quadros não deixavam rastro
  na plataforma, porque só quem tinha campo de iteração aparecia — como colunas de
  `sro_sprints`, não como entidade.

  **Nenhuma coluna de promoção, e é decisão.** O quadro é planejamento e visualização,
  nunca o empreendimento — `rules/github_project_board.yaml` nomeia os três conceitos
  que ele NÃO vira. Quem promove é o conteúdo: iteração iniciada vira sprint, futura
  vira processo pretendido, e a atribuição separa os dois backlogs.
  """

  use Ecto.Migration

  def change do
    create table(:observed_projects, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :connected_tool_id,
          references(:connected_tools, type: :uuid, on_delete: :restrict),
          null: false

      add :number, :integer, null: false
      add :title, :string, null: false
      add :closed, :boolean, null: false, default: false

      # Application Reference — sem ela o dado é inválido (AGENTS §1.1).
      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :source_external_id, :string, null: false

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false

      # Quadro que sumiu da origem é marcado, nunca apagado — mesma regra de tudo
      # que é observado.
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :observed_projects,
             [:tenant_id, :source_system, :source_instance, :source_external_id],
             name: :observed_projects_application_reference_index
           )

    create index(:observed_projects, [:tenant_id, :connected_tool_id],
             name: :observed_projects_tool_index
           )
  end
end
