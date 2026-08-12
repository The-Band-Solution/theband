defmodule TheBand.Repo.Migrations.AddIssuesCollectedAt do
  @moduledoc """
  A única coisa que a plataforma não sabe: se a fase de issues já rodou para o
  repositório.

  Sem a coluna, "repositório com zero issues" tem dois significados indistinguíveis — a
  coleta rodou e não achou nada, ou a coleta nunca rodou. A tela mostraria `0` para os
  dois, e é ausência desenhada como quantidade, o que o design system proíbe.

  **Anulável de propósito.** `nil` é a informação, não a falta dela: os 135 repositórios
  existentes ficam nulos porque nenhuma coleta anterior registrou a data, e é verdade.

  Nenhuma coluna removida, nenhum índice novo — a consulta filtra por
  `observed_repository_id`, que já é indexado.
  """
  use Ecto.Migration

  def change do
    alter table(:observed_repositories) do
      add :issues_collected_at, :utc_datetime
    end
  end
end
