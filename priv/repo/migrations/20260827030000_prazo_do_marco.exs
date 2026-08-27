defmodule TheBand.Repo.Migrations.PrazoDoMarco do
  @moduledoc """
  O prazo do marco, e a identidade dele — issue #368.

  ## O GitHub não tem campo de prazo na issue

  A sondagem achou 33 pares (quadro, campo) de data em 13 nomes e duas línguas — `End
  date` é fim planejado num quadro e fim real noutro, com o mesmo nome. Decisão da pessoa
  mantenedora em 2026-08-26: além do campo do quadro, **o prazo pode vir do sprint ou do
  marco**, e quem declara quais valem é a organização.

  O marco é onde a data mora no GitHub, e ela não estava sendo coletada: a consulta pedia
  `milestone { title }` e nada mais.

  ## Por que o id, e não só o título

  Título de marco é renomeável. Chavear prazo por string perderia o marco no rename, e a
  issue apareceria sem prazo de um dia para o outro sem nada ter mudado na origem.

  ## Ausência é nula, nunca hoje

  `milestone_due_on` nulo é marco sem prazo declarado — 1.580 issues têm marco, e quantas
  delas têm data é o que esta coleta vai revelar. Preencher com a data de criação, ou com
  hoje, produziria atraso onde não há.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_issues) do
      add :milestone_external_id, :string
      add :milestone_due_on, :date
    end
  end
end
