defmodule TheBand.Repo.Migrations.CreateSroSprints do
  @moduledoc """
  A caixa de tempo — `sro.sprint`.

  **É a primeira tabela SRO deste repositório.** O prefixo, a forma do critério de
  identidade e o tratamento da ausência serão copiados pelas irmãs — sprint backlog,
  cerimônia, entregável —, e por isso valem uma leitura mais atenta do que o tamanho
  da migração sugere.

  ## O critério é `external`, e não `composite_hash`

  A iteração do Projects v2 **tem identificador próprio na origem**, ao contrário do
  evento de timeline que a feature 022 registrou. Então a identidade é a Application
  Reference, e é isso que protege das edições que a origem permite: `title`,
  `started_on` e `duration_days` mudam quando alguém renomeia `Sprint 38` ou corrige
  a data, e um hash sobre eles criaria uma caixa órfã a cada correção.
  """

  use Ecto.Migration

  def change do
    create table(:sro_sprints, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :internal_id, :string, null: false

      add :connected_tool_id,
          references(:connected_tools, type: :uuid, on_delete: :delete_all),
          null: false

      # O quadro, e não o repositório: a caixa de tempo pertence ao quadro, que cruza
      # repositórios. É por isso que a coleta dela não cabe na janela da feature 020.
      add :board_number, :integer, null: false
      add :board_title, :string

      # **O nome do campo, como a origem o nomeia.** Todo campo de iteração vira
      # sprint por decisão da pessoa mantenedora, mas `Quarter` de 90 dias e `Sprint`
      # de 14 precisam continuar distinguíveis: somá-los sem saber produziria uma
      # contagem que mistura granularidades. Medido em 2026-08-15: quatro quadros têm
      # os dois campos ao mesmo tempo.
      add :field_name, :string, null: false
      add :title, :string, null: false

      add :started_on, :date, null: false

      # **A duração da ITERAÇÃO, nunca a configurada no campo.** Medido: `Sprint 10`
      # tem 3 dias num campo de 14, e `Quarter 1` tem 61 num de 90. Gravar a do campo
      # faria a série mentir sobre o período coberto.
      add :duration_days, :integer, null: false

      # Derivado de início mais duração menos um. A origem não o fornece, e calcular
      # é aritmética — não inferência.
      add :ended_on, :date, null: false

      # A origem separa `iterations` de `completedIterations`, e as duas entram.
      add :completed, :boolean, null: false, default: false

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :source_external_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sro_sprints, [:tenant_id, :internal_id],
             name: :sro_sprints_identity_index
           )

    create index(:sro_sprints, [:tenant_id, :connected_tool_id, :board_number],
             name: :sro_sprints_board_index
           )

    create table(:sro_sprint_issues, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :sprint_id, references(:sro_sprints, type: :uuid, on_delete: :delete_all), null: false

      add :collected_issue_id,
          references(:collected_issues, type: :uuid, on_delete: :delete_all),
          null: false

      add :observed_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false

      # Ausência marca, nunca apaga: issue que saiu de um sprint continua tendo
      # estado nele, e a linha é o que preserva isso.
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # **Muitos-para-muitos porque a medida obrigou.** No quadro DevOps,
    # 527 + 203 = 730 vínculos sobre 677 itens: a mesma issue está num `Sprint` e num
    # `Quarter`. Uma coluna `sprint_id` em `collected_issues` teria de escolher uma
    # das duas, e não há regra que justifique a escolha — o Produtos Internos inverte
    # a proporção, com `Quarter` em 15 itens e `Sprint` em 3.
    create unique_index(:sro_sprint_issues, [:tenant_id, :sprint_id, :collected_issue_id],
             name: :sro_sprint_issues_par_index
           )

    create index(:sro_sprint_issues, [:tenant_id, :collected_issue_id],
             name: :sro_sprint_issues_issue_index
           )
  end
end
