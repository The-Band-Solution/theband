defmodule TheBand.Repo.Migrations.CreateDecompositionLinks do
  @moduledoc """
  Os vínculos de decomposição, e os recusados (feature 004, T015).

  ## Sem `check_constraint` de aciclicidade, de propósito

  O axioma `sro.rule04` diz o porquê, por extenso:

  > Verificar no comando de registro, antes de persistir. Uma constraint de banco
  > sozinha não pega ciclo transitivo em auto-relacionamento; é preciso checar o
  > caminho até a raiz.

  Uma constraint aqui daria a impressão de proteção sem proteger — e alguém confiaria
  nela. A verificação vive em `record_decomposition_link/2`.

  ## Por que os recusados são persistidos

  FR-017 manda **nomear o caminho** que fecha o ciclo, e um vínculo descartado em
  memória não tem como ser nomeado depois da coleta.

  **As duas issues permanecem coletadas**: recusa-se o vínculo, nunca a issue. Ela
  existe no GitHub, e esconder dado observado por causa de relação inválida seria pior
  que registrar a relação inválida.

  ## Uma previsão declarada, com critério de reversão

  O plano registra `refused_links` como **previsão** e não como problema existente:
  nunca observei ciclo de sub-issues em dado real. Se a tabela continuar vazia em todos
  os tenants depois de duas coletas reais, o registro passa a ser uma contagem no
  relatório do `sync` em vez de tabela.
  """
  use Ecto.Migration

  def up do
    create table(:decomposition_links, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:parent_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:child_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:observed_at, :utc_datetime, null: false)
      add(:last_observed_at, :utc_datetime, null: false)
      add(:no_longer_observed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:decomposition_links, [:parent_issue_id, :child_issue_id])
    create index(:decomposition_links, [:tenant_id, :child_issue_id])

    create constraint(
             :decomposition_links,
             :decomposition_links_no_self_parent,
             check: "parent_issue_id <> child_issue_id"
           )

    create table(:refused_links, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:parent_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all))
      add(:child_issue_id, references(:collected_issues, type: :uuid, on_delete: :delete_all))

      # Quando a parte está fora do escopo observado, ela não tem linha em
      # `collected_issues` — e é por isso que o identificador externo é gravado aqui.
      add(:child_external_id, :string)

      add(:reason, :string, null: false)
      add(:cycle_path, :text)
      add(:refused_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime)
    end

    create index(:refused_links, [:tenant_id, :reason])

    create constraint(
             :refused_links,
             :refused_links_reason_check,
             check: "reason IN ('cycle', 'out_of_scope', 'task_meets_epic')"
           )
  end

  def down do
    drop table(:refused_links)
    drop table(:decomposition_links)
  end
end
