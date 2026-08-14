defmodule TheBand.Repo.Migrations.CreateSpoPerformedProjectActivities do
  @moduledoc """
  A primeira materialização de `spo.performed_project_activity`.

  A ontologia diz que este é o *kind* das ocorrências de atividade em toda a rede —
  *"commits, execuções de teste, cerimônias, implantações e inspeções são todos
  especializações deste conceito, e compartilham o mesmo princípio de identidade"*.

  **Esta tabela vai recebê-las.** Por isso ela é modelada pelo critério de identidade
  do conceito, e não pela timeline do GitHub, que é só a primeira origem a chegar.

  O custo está nomeado no plano: o esquema é mais genérico do que a primeira origem
  precisa, e achar as atividades de uma issue exige filtrar por `subject_type` em vez
  de seguir uma chave estrangeira.
  """

  use Ecto.Migration

  def change do
    create table(:spo_performed_project_activities, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # O hash do critério de identidade da ontologia, com representação canônica
      # para os componentes ausentes — é o que faz duas coletas do mesmo evento
      # produzirem uma linha (FR-003).
      add :internal_id, :string, null: false

      # Estão no critério de identidade e aceitam nulo: nem toda origem futura
      # conhece organização ou projeto. Omiti-los agora faria o hash mudar quando
      # fossem preenchidos, quebrando toda referência existente — é o mesmo motivo
      # que a ontologia escreveu para deixar `end_date` fora.
      add :organization_id, references(:eo_organizations, type: :uuid, on_delete: :nilify_all)
      add :project_id, :uuid

      # Texto, e não enum: o conjunto de tipos é do mundo, não do código. Um enum
      # obrigaria migração a cada tipo novo e, pior, faria a coleta FALHAR ao achar
      # um desconhecido — quando a decisão é registrá-lo (FR-005).
      add :activity_type, :string, null: false

      # O conceito da rede, quando houver. Nulo é INFORMAÇÃO: significa "a rede não
      # nomeia este tipo", e é o estado honesto de `labeled` e `cross-referenced`.
      # Preencher com aproximação seria inventar; descartar a linha seria a L57.
      add :concept_id, :string

      # A ontologia declara: "atividades automatizadas não têm executor humano".
      # Medido em 2026-08-14: 160 das 357 movimentações são de robô, então o nulo
      # aqui é o caso comum, e não a exceção.
      add :performer_id, references(:eo_people, type: :uuid, on_delete: :nilify_all)
      add :performer_login, :string

      # O instante individua a ocorrência, e não muda depois: ela aconteceu.
      add :occurred_at, :utc_datetime, null: false

      # Ligação genérica, e não `collected_issue_id`: um commit não tem issue, e a
      # coluna dedicada ficaria nula em metade das linhas quando a segunda origem
      # chegar. A ontologia já declara que ela vai chegar.
      add :subject_type, :string, null: false
      add :subject_id, :uuid, null: false

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      # A origem pode não dar identidade ao evento — está entre os
      # `nullable_components` do critério na própria ontologia.
      add :source_external_id, :string

      # O que a origem mandou e a plataforma ainda não interpreta.
      add :payload, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:spo_performed_project_activities, [:tenant_id, :internal_id],
             name: :spo_performed_project_activities_identity_index
           )

    # A consulta da tela: as atividades de uma entidade, em ordem cronológica.
    # Nome explícito: o implícito passa de 63 caracteres e o Postgres o trunca em
    # silêncio, o que faria dois índices desta tabela colidirem no mesmo nome.
    create index(
             :spo_performed_project_activities,
             [:tenant_id, :subject_type, :subject_id, :occurred_at],
             name: :spo_performed_project_activities_subject_index
           )

    # A contagem por tipo, que alimenta a FR-010 — é o que permite alguém decidir
    # qual movimentação marca o início.
    create index(:spo_performed_project_activities, [:tenant_id, :activity_type])
  end
end
