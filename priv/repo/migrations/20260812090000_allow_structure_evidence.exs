defmodule TheBand.Repo.Migrations.AllowStructureEvidence do
  @moduledoc """
  A terceira fonte de evidência: a estrutura de decomposição (feature 005, regra nova).

  ## Por que `low`, e por que um nível novo

  `high` é campo tipado na ferramenta. `medium` é convenção de título que a organização
  declarou. `structure` não é declaração de ninguém — é consequência de como as issues
  foram ligadas, e a ligação pode simplesmente não ter sido feita.

  O erro conhecido dessa inferência: **uma folha pode ser uma tarefa, e pode ser uma user
  story que ninguém decompôs.** A estrutura não distingue as duas. Gravar `medium` aqui
  diria que essa inferência vale o mesmo que uma convenção declarada, e não vale.

  Os `check_constraint` são reescritos para aceitar os valores novos. Nenhuma coluna é
  removida, e nenhuma linha existente muda.
  """
  use Ecto.Migration

  def up do
    drop(constraint(:issue_promotions, :issue_promotions_evidence_source_known))
    drop(constraint(:issue_promotions, :issue_promotions_confidence_known))

    create(
      constraint(:issue_promotions, :issue_promotions_evidence_source_known,
        check:
          "evidence_source is null or evidence_source in ('declared_type', 'title', 'structure')"
      )
    )

    create(
      constraint(:issue_promotions, :issue_promotions_confidence_known,
        check: "confidence is null or confidence in ('high', 'medium', 'low')"
      )
    )
  end

  def down do
    drop(constraint(:issue_promotions, :issue_promotions_evidence_source_known))
    drop(constraint(:issue_promotions, :issue_promotions_confidence_known))

    create(
      constraint(:issue_promotions, :issue_promotions_evidence_source_known,
        check: "evidence_source is null or evidence_source in ('declared_type', 'title')"
      )
    )

    create(
      constraint(:issue_promotions, :issue_promotions_confidence_known,
        check: "confidence is null or confidence in ('high', 'medium')"
      )
    )
  end
end
