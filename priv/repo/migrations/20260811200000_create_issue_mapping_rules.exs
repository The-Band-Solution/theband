defmodule TheBand.Repo.Migrations.CreateIssueMappingRules do
  @moduledoc """
  A regra de mapeamento que uma organização declarou (feature 005, T001).

  ## Por que `created_by_id` é obrigatório

  Mapeamento é **decisão**, não configuração. Uma regra sem autor não tem a quem
  perguntar "por que isto é uma user story" — e o catálogo, que poderia ser a porta para
  regras com autor "sistema", só é materializado por uma ação de alguém.

  ## Por que `position` é único por organização

  A ordem entre regras que casam a mesma issue precisa ser determinística **e visível**.
  Sem o índice único, duas regras na mesma posição fariam a classificação depender do
  plano de execução — é a mesma classe de defeito da L20.

  ## Desativar não apaga

  A promoção que a regra produziu aponta para ela. Apagar a regra tornaria a
  proveniência ilegível: "promovida pela regra que não existe mais".

  Nenhuma coluna é removida por esta migração.
  """
  use Ecto.Migration

  def up do
    create table(:issue_mapping_rules, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:organization_id, references(:eo_organizations, type: :uuid, on_delete: :delete_all),
        null: false
      )

      # Onde procura: no tipo declarado, ou no título. São evidências de força
      # diferente, e é por isso que a coluna existe em vez de a regra olhar os dois.
      add(:where, :string, null: false)
      # Como compara: equals, starts_with, contains, regex.
      add(:how, :string, null: false)
      add(:pattern, :text, null: false)
      add(:case_sensitive, :boolean, null: false, default: false)

      # Identificador de conceito da base de conhecimento — texto, nunca chave
      # estrangeira: conceito vive em YAML, não em tabela.
      add(:target_concept, :string, null: false)

      add(:position, :integer, null: false)
      add(:active, :boolean, null: false, default: true)
      add(:deactivated_at, :utc_datetime)
      add(:deactivated_by_id, references(:users, type: :uuid, on_delete: :nilify_all))

      add(:created_by_id, references(:users, type: :uuid, on_delete: :restrict), null: false)

      # De qual entrada do catálogo veio, quando veio. É `(where, how, pattern)`
      # normalizado — **nunca** o índice na lista: reordenar o YAML não pode desligar
      # decisões já tomadas.
      add(:catalog_key, :string)
      add(:version, :integer, null: false, default: 1)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:issue_mapping_rules, [:organization_id, :where, :how, :pattern],
             name: :issue_mapping_rules_comparison_index
           )

    create unique_index(:issue_mapping_rules, [:organization_id, :position])
    create index(:issue_mapping_rules, [:tenant_id, :organization_id, :active])

    create constraint(:issue_mapping_rules, :issue_mapping_rules_where_known,
             check: "\"where\" in ('declared_type', 'title')"
           )

    create constraint(:issue_mapping_rules, :issue_mapping_rules_how_known,
             check: "how in ('equals', 'starts_with', 'contains', 'regex')"
           )
  end

  def down do
    drop table(:issue_mapping_rules)
  end
end
