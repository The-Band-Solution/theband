defmodule TheBand.Repo.Migrations.CreateIssuePromotions do
  @moduledoc """
  A decisão da plataforma sobre o que uma issue é (feature 004, T014).

  ## Por que uma tabela, e não uma coluna na issue

  Uma coluna `promoted_to` guardaria o resultado e perderia a **divergência** — que é o
  dado mais interessante para quem administra o processo, e o que FR-035 manda mostrar
  na tela. Épico abandonado sem decomposição e user story que virou épico sem retipagem
  só aparecem porque a estrutura vence o rótulo, e desapareceriam se a plataforma
  gravasse apenas o destino.

  ## Três estados, e o desenho os distingue

      derived_concept preenchido, skip_reason nulo         promovida
      derived_concept nulo, skip_reason preenchido         não promovida, com o motivo
      divergence_reason preenchido                         promovida CONTRA o rótulo

  ## Append-only, e a vigente é a última

  Uma issue que ganha sub-issues entre duas coletas muda de conceito. A coleta seguinte
  grava **nova linha**, e não atualiza a anterior — FR-019. Atualizar reescreveria o
  passado, e a pergunta "como esta issue estava classificada em março" desapareceria.
  Mesma razão de `tool_observation_events` não ter `updated_at`.

  `inserted_at` em microssegundo, e não em segundo: duas promoções do mesmo segundo
  empatariam, e a "vigente" passaria a depender do plano de execução. É a L20.

  ## `rule_version` não é anulável

  É o que permite responder "por que esta issue foi classificada assim em março" depois
  de a regra mudar — e ela vai mudar, tem `status: proposed`.

  ## Esta migração NÃO cria `sro_user_stories.status`

  A saída do derivador imprime essa coluna, porque `epic` e `atomic_user_story` são
  `phase`. **Ela não é criada aqui, e não deve ser criada depois** sem uma decisão
  própria: a classificação é situação, e situação é derivada (ADR 0004 D7). A issue #98
  deste repositório nasceu sem partes e ganhou duas no mesmo dia — um valor gravado na
  primeira coleta estaria errado na segunda.

  Está escrito aqui porque a ausência de uma coluna que o derivador imprime parece
  esquecimento, e a próxima pessoa a acrescentaria achando que faltava.
  """
  use Ecto.Migration

  def up do
    create table(:issue_promotions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:collected_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:declared_concept, :string)
      add(:derived_concept, :string)
      add(:target_table, :string)
      add(:target_id, :uuid)

      add(:rule_id, :string, null: false)
      add(:rule_version, :integer, null: false)

      add(:divergence_reason, :text)
      add(:skip_reason, :string)
      add(:skip_detail, :string)

      add(:promoted_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:issue_promotions, [:collected_issue_id, :inserted_at])
    create index(:issue_promotions, [:tenant_id, :derived_concept])
    create index(:issue_promotions, [:tenant_id, :skip_reason])

    create constraint(
             :issue_promotions,
             :issue_promotions_promoted_xor_skipped,
             check: """
             (derived_concept IS NOT NULL AND skip_reason IS NULL)
             OR (derived_concept IS NULL AND skip_reason IS NOT NULL)
             """
           )
  end

  def down do
    drop table(:issue_promotions)
  end
end
