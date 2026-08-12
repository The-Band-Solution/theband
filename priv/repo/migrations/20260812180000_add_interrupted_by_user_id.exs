defmodule TheBand.Repo.Migrations.AddInterruptedByUserId do
  @moduledoc """
  Quem encerrou a execução — e o nulo é afirmação, não lacuna.

  | valor | significa |
  |---|---|
  | preenchido | **uma pessoa** decidiu encerrar, e o registro diz quem |
  | nulo, com `status = interrupted` | **a plataforma** encerrou, porque o trabalho não existia mais |

  **Sem check constraint exigindo autor**, e a diferença em relação a
  `observed_repositories_exclusion_has_author` é o ponto: exclusão só acontece por decisão
  de alguém, e encerramento acontece também pela plataforma. Exigir autor forçaria uma das
  duas mentiras — um usuário-sistema falso, ou a decisão atribuída a quem não a tomou.

  `on_delete: :nilify_all` porque o encerramento **aconteceu**: apagar a pessoa não desfaz o
  fato, e a plataforma não apaga registro de coleta.
  """
  use Ecto.Migration

  def change do
    alter table(:syncs) do
      add :interrupted_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
