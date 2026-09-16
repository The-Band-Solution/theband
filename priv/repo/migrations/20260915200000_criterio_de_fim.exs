defmodule TheBand.Repo.Migrations.CriterioDeFim do
  @moduledoc """
  Qual evento marca o **fim** do trabalho, declarado por quadro — feature 066.

  ## A simetria que faltava

  A feature 042 declara qual evento marca o **começo**, por quadro, com precedência quadro →
  projeto → nulo. O fim nunca teve equivalente: a plataforma assume *a issue fechou*, e nunca
  perguntou a ninguém.

  ## O dado que mostra por que tem de ser por quadro

  Medido em 2026-09-15, itens de quadro × issues fechadas na origem:

      #43 Conecta Fapes .............. 987 itens,  96 fechadas  (10%)
      #19 Conecta Fapes - Delivery ... 589 itens,  24 fechadas  ( 4%)
      #31 DevOps ..................... 662 itens, 631 fechadas  (95%)
      #26 AgentES .................... 498 itens, 471 fechadas  (95%)

  O Conecta fecha o cartão e deixa a issue aberta; o DevOps e o AgentES fecham a issue. Uma
  definição única mentiria para metade dos quadros: o #43 apareceria como quase nada entregue,
  e o #31 como tudo entregue.

  ## E por que não basta a declaração por coluna

  A feature 066 declara o que cada **coluna** significa, e resolve os quadros que têm coluna
  final. Medido no mesmo dia: **13 campos de seleção única não têm nenhuma coluna que signifique
  concluído** — inclusive no #26 AgentES e no #19 Delivery. Neles não há coluna a declarar, e o
  que marca o fim é um **evento**.

  ## O que este critério dá, e o que ele não dá

  Dá o **instante** em que o trabalho terminou — como o critério de início dá o do começo, e é
  o que fecha o cycle time. **Não** diz que o entregável foi aceito: aceitação decorre dos
  critérios (`sro.rule03`) e é a feature 067.
  """
  use Ecto.Migration

  def change do
    create table(:spo_activity_end_criteria, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # Exatamente um dos dois, como na 042: o critério do quadro prevalece sobre o do
      # projeto, e um critério sem alvo valeria para tudo sem ninguém ter dito isso.
      add :project_id, references(:spo_projects, type: :uuid, on_delete: :delete_all)

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all)

      # Cru, como a origem nomeia. Sem enum, pela mesma razão da 042.
      add :event_type, :string, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:spo_activity_end_criteria, :fim_tem_um_alvo_so,
             check: "(project_id IS NULL) <> (observed_project_id IS NULL)"
           )

    create unique_index(:spo_activity_end_criteria, [:tenant_id, :observed_project_id],
             where: "revoked_at IS NULL AND observed_project_id IS NOT NULL",
             name: :spo_fim_vigente_do_quadro_index
           )

    create unique_index(:spo_activity_end_criteria, [:tenant_id, :project_id],
             where: "revoked_at IS NULL AND project_id IS NOT NULL",
             name: :spo_fim_vigente_do_projeto_index
           )
  end
end
