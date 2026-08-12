defmodule TheBand.Repo.Migrations.CreateUnmappedPatternDecisions do
  @moduledoc """
  O registro de que um padrão **não** designa tipo (feature 005, T002).

  ## Por que uma tabela para dizer "não"

  `[Devops]` tem 340 issues, `[Back-end]` 256, `[Front-end]` 237 — cerca de 1274 issues
  cujo prefixo diz **quem faz** ou **em que área**, não **o que é**.

  Sem este registro, esses padrões ficam para sempre na lista de pendências. Duas
  consequências, e a segunda é a pior: a lista deixa de ser lida, e a insistência empurra
  alguém a mapear área como tipo — 340 user stories que são rótulos de equipe.

  Conceito errado é pior que conceito ausente: a medida passa a existir e a mentir.

  ## `reverted_at` existe porque a decisão pode estar errada

  Alguém pode marcar como "não é tipo" o que é. Reverter devolve o padrão à lista, e o
  registro de quem decidiu o quê permanece — a reversão é um fato novo, não um apagamento.
  """
  use Ecto.Migration

  def up do
    create table(:unmapped_pattern_decisions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:organization_id, references(:eo_organizations, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:pattern, :text, null: false)
      add(:decided_by_id, references(:users, type: :uuid, on_delete: :restrict), null: false)
      add(:decided_at, :utc_datetime, null: false)
      add(:reverted_at, :utc_datetime)
      add(:reverted_by_id, references(:users, type: :uuid, on_delete: :nilify_all))
      add(:note, :text)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:unmapped_pattern_decisions, [:organization_id, :pattern])
  end

  def down do
    drop table(:unmapped_pattern_decisions)
  end
end
