defmodule TheBand.Repo.Migrations.IndexDesignacaoPorPessoa do
  @moduledoc """
  O índice que responde a pergunta da página da pessoa (feature 013, T005).

  ## A pergunta que faltava

  `issue_assignees` tinha dois índices, e os dois são por `collected_issue_id`:

      (collected_issue_id, login)
      (collected_issue_id, no_longer_observed_at)

  Os dois respondem **"quem é designado desta issue"**. A página da pessoa faz a pergunta
  inversa — *"quais issues são desta pessoa"* —, e não havia índice para ela.

  Medido no dado real em 2026-08-12:

      Seq Scan on issue_assignees
        Filter: (no_longer_observed_at IS NULL) AND (person_id = …)
        Rows Removed by Filter: 3 882      ← lê 4 232 para devolver 350

  Com o índice, o mesmo acesso vira `Bitmap Index Scan` de 0,036 ms.

  ## `no_longer_observed_at` na segunda posição, e não um índice parcial

  A coluna entra no índice porque a consulta sempre filtra por ela. **Um índice parcial
  `where no_longer_observed_at is null` seria menor e mais rápido** — e responderia só
  metade das perguntas: a designação que acabou também é consultada, porque ausência é
  marcada e não apagada, e quem a exibe precisa achá-la.
  """
  use Ecto.Migration

  def change do
    create index(:issue_assignees, [:person_id, :no_longer_observed_at])
  end
end
