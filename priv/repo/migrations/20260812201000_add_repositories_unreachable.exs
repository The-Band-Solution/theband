defmodule TheBand.Repo.Migrations.AddRepositoriesUnreachable do
  @moduledoc """
  Quantos repositórios a execução **não alcançou**.

  Não existia, e por isso 39 repositórios caíram em 2026-08-11 e a coleta concluiu com
  **sucesso e 100% de progresso** — o denominador do percentual conta só o que a plataforma
  decidiu olhar, então ele nunca detecta o que ela deixou de olhar.

  **Padrão zero, e aqui zero é fato, não ausência**: uma coleta que alcançou todos os
  repositórios não alcançou zero deles. O que era ausência é a coluna não existir.

  O risco é o inverso, e está declarado: se alguém esquecer de incrementar, o zero **afirma**
  que tudo foi alcançado. Por isso o número é escrito **a cada falha**, nunca no fim — coleta
  interrompida antes do fim ficaria com zero.
  """
  use Ecto.Migration

  def change do
    alter table(:syncs) do
      add :repositories_unreachable, :integer, null: false, default: 0
    end
  end
end
