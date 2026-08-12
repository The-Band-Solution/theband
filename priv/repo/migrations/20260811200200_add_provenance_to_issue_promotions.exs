defmodule TheBand.Repo.Migrations.AddProvenanceToIssuePromotions do
  @moduledoc """
  De onde veio a evidência, e com que confiança (feature 005, T003).

  ## As três colunas são anuláveis, e isso é declaração

  As promoções já gravadas foram decididas **antes** desta feature existir. Preencher
  `evidence_source` retroativamente afirmaria que alguém verificou de onde cada uma veio
  — e ninguém verificou. Elas ficam nulas, e a tela diz "não informado".

  ## Confiança é nível, nunca número

  `high` para decisão por tipo declarado; `medium` para inferência sobre título. É o
  vocabulário que a base de conhecimento já usa.

  Um número — "confiança 0,7" — seria inventado, e viraria meta: alguém o otimizaria
  escrevendo regras mais amplas, e a medida deixaria de medir.

  ## Por que a fonte é coluna, e não derivada da regra

  A promoção **sobrevive à regra**. A regra pode ser desativada, e a promoção que ela
  produziu continua sendo um fato: "esta issue foi promovida por inferência de título em
  tal data". Derivar a fonte no momento da leitura daria resposta diferente depois de a
  regra mudar.

  Nenhuma coluna é removida.
  """
  use Ecto.Migration

  def up do
    alter table(:issue_promotions) do
      add(:evidence_source, :string)
      add(:confidence, :string)

      add(
        :mapping_rule_id,
        references(:issue_mapping_rules, type: :uuid, on_delete: :nilify_all)
      )
    end

    create index(:issue_promotions, [:tenant_id, :evidence_source])

    create constraint(:issue_promotions, :issue_promotions_evidence_source_known,
             check: "evidence_source is null or evidence_source in ('declared_type', 'title')"
           )

    create constraint(:issue_promotions, :issue_promotions_confidence_known,
             check: "confidence is null or confidence in ('high', 'medium')"
           )
  end

  def down do
    drop constraint(:issue_promotions, :issue_promotions_confidence_known)
    drop constraint(:issue_promotions, :issue_promotions_evidence_source_known)
    drop index(:issue_promotions, [:tenant_id, :evidence_source])

    alter table(:issue_promotions) do
      remove(:evidence_source)
      remove(:confidence)
      remove(:mapping_rule_id)
    end
  end
end
