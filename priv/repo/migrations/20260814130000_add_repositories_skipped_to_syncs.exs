defmodule TheBand.Repo.Migrations.AddRepositoriesSkippedToSyncs do
  @moduledoc """
  Quantos repositórios a coleta pulou por não terem recebido push desde a última revisão.

  **Coluna, e não derivação**, pelo mesmo motivo de `repositories_unreachable`: é contagem de
  uma execução que já terminou, e reconstruí-la depois exigiria guardar por repositório o que
  a execução decidiu — que é o dado que a coluna resume.

  `default: 0` é honesto aqui: toda execução gravada até hoje percorreu tudo, e zero pulados é
  o que de fato aconteceu nelas.
  """

  use Ecto.Migration

  def change do
    alter table(:syncs) do
      add :repositories_skipped, :integer, null: false, default: 0
    end
  end
end
