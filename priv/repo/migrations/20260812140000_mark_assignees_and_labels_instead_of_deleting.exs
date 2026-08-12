defmodule TheBand.Repo.Migrations.MarkAssigneesAndLabelsInsteadOfDeleting do
  @moduledoc """
  Designado e rótulo passam a ser **marcados** como ausentes, nunca apagados.

  ## O que muda, e por que é correção e não feature

  Na feature 006 eu decidi que `replace_assignees/3` e `replace_labels/3` **apagariam** o que a
  origem não trouxesse mais. A justificativa foi que designação é atributo do agora, e o histórico
  ficaria no payload bruto.

  A pessoa mantenedora enunciou a regra da plataforma: **nunca se apaga dados.** Essa era
  exatamente a condição de reversão que a pesquisa daquela feature registrou, e ela foi atendida.

  ## Por que a regra está certa e eu estava errado

  Reconstruir "quem estava designado em março" a partir de payload bruto é possível e é uma
  resposta de arqueologia: exige ler JSON de coleta, saber qual execução olhar, e confiar que o
  payload daquele momento foi preservado.

  Marcar custa uma coluna e responde por consulta. E designação **é** fato histórico: quem foi
  responsável por uma issue é parte de como o trabalho aconteceu.

  ## A mesma coluna que o resto da plataforma usa

  `no_longer_observed_at` é o nome que `collected_issues`, `decomposition_links` e
  `sys_swo_loaded_software_system_copies` já usam para a mesma coisa. Um nome diferente aqui faria
  parecer outro conceito.

  Nenhuma coluna é removida, e nenhuma linha existente é alterada: as que existem hoje são
  vigentes, e continuam.
  """
  use Ecto.Migration

  def up do
    alter table(:issue_assignees) do
      add(:no_longer_observed_at, :utc_datetime)
    end

    alter table(:issue_labels) do
      add(:no_longer_observed_at, :utc_datetime)
    end

    # A consulta da tela filtra por vigência, e o índice acompanha o filtro.
    create index(:issue_assignees, [:collected_issue_id, :no_longer_observed_at])
    create index(:issue_labels, [:collected_issue_id, :no_longer_observed_at])
  end

  def down do
    drop index(:issue_labels, [:collected_issue_id, :no_longer_observed_at])
    drop index(:issue_assignees, [:collected_issue_id, :no_longer_observed_at])

    alter table(:issue_labels) do
      remove(:no_longer_observed_at)
    end

    alter table(:issue_assignees) do
      remove(:no_longer_observed_at)
    end
  end
end
