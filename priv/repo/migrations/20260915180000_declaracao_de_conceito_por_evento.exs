defmodule TheBand.Repo.Migrations.DeclaracaoDeConceitoPorEvento do
  @moduledoc """
  O que cada evento da timeline materializa — declarado pela organização, feature 066.

  ## A lista vivia no código

  `github_work_items.ex` promovia cinco tipos a `spo.performed_project_activity` e os demais
  a nulo, com a lista escrita numa cláusula de função. Medido em 2026-09-15: **12 tipos
  coletados**, 5 com conceito e 7 sem.

  A declaração passou ao YAML (`github.timeline_event_vocabulary`), que é o **padrão da
  casa** — e esta tabela é o degrau seguinte: a organização pode discordar do padrão, porque
  o mesmo evento significa coisas diferentes em processos diferentes. *Entrar num quadro* não
  é trabalho aqui; noutra casa, onde o cartão só entra quando alguém pega, pode ser.

  ## Prevalece sobre o padrão, na leitura

  Nada é regravado: a coleta continua gravando o `concept_id` do padrão, e a leitura aplica a
  declaração vigente por cima. Regravar faria revogar uma declaração exigir reescrever
  milhares de linhas — e é o mesmo desenho da declaração de fase por coluna.

  ## Por tenant, e não por quadro

  Os eventos são da organização inteira: `ClosedEvent` não muda de significado conforme o
  quadro. Declarar por quadro criaria a possibilidade de o mesmo evento materializar conceitos
  diferentes na mesma issue, que é o que a casa recusa sintetizar.
  """
  use Ecto.Migration

  def change do
    create table(:spo_event_concept_declarations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # Cru, como a origem nomeia — e sem enum, pela mesma razão do `event_type` da 042:
      # tipo novo do GitHub não pode ser recusado como erro de escrita.
      add :event_type, :string, null: false

      # O id do conceito na rede, ou `nao_nomeado` — a recusa registrada.
      add :target_concept, :string, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:spo_event_concept_declarations, [:tenant_id, :event_type],
             where: "revoked_at IS NULL",
             name: :spo_conceito_vigente_do_evento_index
           )
  end
end
