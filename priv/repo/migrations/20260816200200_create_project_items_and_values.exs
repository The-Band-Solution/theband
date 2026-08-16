defmodule TheBand.Repo.Migrations.CreateProjectItemsAndValues do
  @moduledoc """
  Os itens de cada quadro e os valores de campo — sprint 017, T049, T050 e T051.

  `collected_issue_id` **nulo é rascunho** (FR-022): item sem trabalho associado,
  registrado em vez de descartado — hoje o `... on Issue` o deixa com id nulo e quem
  consome joga fora. Rascunho não promove a nada: é intenção de alguém, não escopo.

  Em `item_field_values`, **`raw_value` é sempre gravado** e `interpreted_as` só
  existe quando há mapeamento declarado (FR-025). `nil` ali não é falha — é o caso
  comum, e é o que a tela mostra como *não interpretado*. Converter por semelhança
  de nome é o antipadrão de `AGENTS.md` §7.7.
  """

  use Ecto.Migration

  def change do
    create table(:project_items, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all),
          null: false

      add :collected_issue_id,
          references(:collected_issues, type: :uuid, on_delete: :nilify_all)

      add :is_draft, :boolean, null: false, default: false

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :source_external_id, :string, null: false

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :project_items,
             [:tenant_id, :source_system, :source_instance, :source_external_id],
             name: :project_items_application_reference_index
           )

    create index(:project_items, [:tenant_id, :observed_project_id],
             name: :project_items_quadro_index
           )

    # Rascunho é rascunho: ou tem issue, ou é draft — as duas coisas juntas seriam
    # um item afirmando trabalho e negando ao mesmo tempo.
    create constraint(:project_items, :project_items_rascunho_sem_issue,
             check: "NOT (is_draft AND collected_issue_id IS NOT NULL)"
           )

    create table(:item_field_values, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :project_item_id,
          references(:project_items, type: :uuid, on_delete: :delete_all),
          null: false

      add :project_field_definition_id,
          references(:project_field_definitions, type: :uuid, on_delete: :delete_all),
          null: false

      add :raw_value, :jsonb, null: false
      add :interpreted_as, :string

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :item_field_values,
             [:tenant_id, :project_item_id, :project_field_definition_id],
             name: :item_field_values_um_por_campo_index
           )
  end
end
