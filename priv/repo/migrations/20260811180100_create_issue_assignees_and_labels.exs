defmodule TheBand.Repo.Migrations.CreateIssueAssigneesAndLabels do
  @moduledoc """
  Designados e rótulos de uma issue (feature 006, US1).

  ## Por que tabelas, e não colunas

  Uma issue tem **zero ou muitos** designados, e zero ou muitos rótulos. Uma coluna
  guardaria um e perderia o resto; um array perderia a ligação com a pessoa coletada.

  É o mesmo raciocínio da ADR 0004 D5, que mantém papel organizacional fora de
  `eo_people`: multiplicidade e vínculo pedem tabela.

  ## O rótulo é preservado e NÃO é promovido

  Um rótulo `bug` **não** faz a issue um defeito. Quem decide é o tipo declarado ou a
  regra da organização — feature 005. Promover rótulo por semelhança de nome é o
  antipadrão que o princípio I proíbe, e é exatamente o que esta tabela existe para
  registrar sem fazer.

  ## `person_id` é anulável, e é declaração

  Quando a pessoa designada ainda não foi coletada, o login é preservado e o vínculo fica
  **declaradamente ausente**. Criar a pessoa a partir da issue produziria registro sem a
  proveniência que a coleta de EO dá.
  """
  use Ecto.Migration

  def up do
    create table(:issue_assignees, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:collected_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:login, :string, null: false)
      add(:person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create unique_index(:issue_assignees, [:collected_issue_id, :login])

    create table(:issue_labels, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:collected_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:name, :string, null: false)
      add(:color, :string)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:issue_labels, [:collected_issue_id, :name])
    create index(:issue_labels, [:tenant_id, :name])
  end

  def down do
    drop table(:issue_labels)
    drop table(:issue_assignees)
  end
end
