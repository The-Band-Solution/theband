defmodule TheBand.Repo.Migrations.OQuadroEAColunaNaAtividade do
  @moduledoc """
  O quadro e a coluna deixam de viver só dentro do `payload`.

  ## O quadro

  `ProjectV2ItemStatusChangedEvent` diz que o cartão foi para uma coluna, e a consulta
  nunca perguntou **de qual quadro**. Doze quadros têm coluna chamada `Done`, e 286
  issues estão em dois quadros com uma só chegada a `Done` — essa chegada pertence a um
  deles, e a plataforma creditava aos dois.

  O efeito medido em 2026-09-16, no quadro 43: 46 cartões que **não** estão em `Done`
  carregam evento de chegada a `Done` — 16 em In Validation, 13 em Homologation, 7 em In
  Progress, 5 em To Do, 3 em Backlog, 1 em Paused e 1 em Desaprovado.

  São duas colunas, e não uma, pelo mesmo motivo de `performer_id` e `performer_login`:
  o identificador da origem sempre cabe, e a resolução para o quadro observado pode não
  existir ainda.

  ## A coluna

  `status_name` já estava no `payload`. Promovê-la a coluna não é sobre poder consultar —
  já dava. É sobre o planejador ser cego para chave de jsonb: ele estimava 82 linhas onde
  havia 3 294, varria as 46 mil e levava 92 ms. Estimativa errada por 40 vezes escolhe o
  plano errado em qualquer junção.

  O preenchimento retroativo desta sai do próprio `payload`, sem falar com a origem.

  ## O que estas colunas NÃO são

  Elas guardam a **observação** — o cartão foi para uma coluna com este nome, neste
  quadro. Não guardam o **significado**: que isso concluiu o trabalho é declaração da
  organização, resolvida na leitura, e `sro.rule03` proíbe derivar aceite de marcação.
  """
  use Ecto.Migration

  def up do
    alter table(:spo_performed_project_activities) do
      add :board_id, :binary_id
      add :board_external_id, :string
      add :status_name, :string
    end

    create index(:spo_performed_project_activities, [:tenant_id, :board_id])

    create index(:spo_performed_project_activities, [:tenant_id, :status_name],
             where: "status_name IS NOT NULL"
           )

    # Retroativo e exato: o nome da coluna já estava gravado no payload desde a primeira
    # coleta. O quadro não estava, e só volta pela recoleta.
    execute """
    UPDATE spo_performed_project_activities
       SET status_name = payload->>'status'
     WHERE payload->>'status' IS NOT NULL
    """
  end

  def down do
    drop index(:spo_performed_project_activities, [:tenant_id, :status_name],
           where: "status_name IS NOT NULL"
         )

    drop index(:spo_performed_project_activities, [:tenant_id, :board_id])

    alter table(:spo_performed_project_activities) do
      remove :board_id
      remove :board_external_id
      remove :status_name
    end
  end
end
