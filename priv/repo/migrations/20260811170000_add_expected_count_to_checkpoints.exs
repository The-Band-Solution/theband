defmodule TheBand.Repo.Migrations.AddExpectedCountToCheckpoints do
  @moduledoc """
  O denominador do progresso, vindo da origem (feature 004, pedido de 2026-08-11).

  ## Por que a coluna existe

  A tela de sincronização mostrava **fases**, e não percentual, porque a paginação é por
  cursor: a plataforma não sabe quantas páginas existem antes de pedir a última. Um
  percentual precisaria de um denominador, e inventá-lo produziria número que parece
  informação e não é.

  O GitHub **fornece** o denominador: `repositories.totalCount` e `issues.totalCount`. Esta
  coluna o guarda, e o percentual passa a ser `record_count / expected_count` — os dois
  medidos, nenhum estimado.

  ## Por que é anulável

  Porque nem toda entidade tem total na origem. Onde `expected_count` é nulo, a tela
  **não** mostra percentual: mostra a contagem e o estado da fase. Preencher com uma
  estimativa transformaria ausência de denominador em denominador errado, e o número
  mentiria sem avisar.

  Nenhuma coluna é removida nesta migração.
  """
  use Ecto.Migration

  def up do
    alter table(:sync_checkpoints) do
      add(:expected_count, :integer)
    end
  end

  def down do
    alter table(:sync_checkpoints), do: remove(:expected_count)
  end
end
