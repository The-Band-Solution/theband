defmodule TheBand.Repo.Migrations.CreateReviewNetworkReadings do
  @moduledoc """
  A leitura vigente da rede de revisão — feature 073, T005. Desenho em
  `specs/073-rede-de-revisao/data-model.md` §1.

  Uma linha por `(tenant, organização observada, janela)`, substituída inteira a cada cálculo e
  nunca editada (FR-011). Guarda ids de pessoa, e nunca nome nem login (R3, R7 da segurança).

  ## As restrições que a avaliação de segurança trouxe

  - **FK composta `(organization_id, tenant_id)`** → `eo_organizations(id, tenant_id)`: sem ela,
    nada impede uma linha com a organização de um tenant e o `tenant_id` de outro. O Postgres exige
    índice único exatamente sobre as colunas referenciadas, e por isso `eo_organizations(id,
    tenant_id)` nasce aqui, redundante com a chave primária (precedente:
    `20260929100000_sessoes_de_usuario.exs`);
  - **índice único `(tenant_id, organization_id, window_days)`**: **uma** leitura vigente, sem
    histórico de quem revisa quem (R7, decisão de 2026-10-03);
  - **`on_delete: :delete_all`** nas duas: a leitura é derivada, e não sobrevive ao tenant nem à
    organização.

  ## O índice em `collected_artifact_evaluations`

  `(tenant_id, external_submitted_at)`: o cálculo recorta por data de envio, e sem ele percorre
  todas as avaliações do tenant pelo prefixo do índice único `(tenant_id, external_id)`. Medido em
  desenvolvimento, 49% das avaliações já estão fora da janela de 180 dias, e a tabela só cresce
  (research.md R10, D8).

  Aditiva: o rollback desfaz a tabela, os dois índices e as restrições, e nada mais.
  """
  use Ecto.Migration

  def change do
    create unique_index(:eo_organizations, [:id, :tenant_id])

    create table(:review_network_readings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false

      add :organization_id,
          references(:eo_organizations,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            on_delete: :delete_all
          ),
          null: false

      add :window_days, :integer, null: false
      add :window_start, :utc_datetime, null: false
      add :window_end, :utc_datetime, null: false
      add :computed_at, :utc_datetime, null: false
      add :edges, :map, null: false
      add :people, :map, null: false
      add :reviews_in_network, :integer, null: false
      add :excluded_self_reviews, :integer, null: false
      add :excluded_bot_or_app, :integer, null: false
      add :excluded_unlinked, :integer, null: false
      add :knowledge_versions, :map, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Nome explícito: o gerado passa de 63 caracteres e o Postgres o trunca, e o changeset não
    # reconheceria a violação.
    create unique_index(:review_network_readings, [:tenant_id, :organization_id, :window_days],
             name: :review_network_readings_vigente_index
           )

    create constraint(:review_network_readings, :review_network_readings_window_days_positive,
             check: "window_days > 0"
           )

    create constraint(:review_network_readings, :review_network_readings_window_ordered,
             check: "window_end > window_start"
           )

    create constraint(:review_network_readings, :review_network_readings_counts_non_negative,
             check:
               "reviews_in_network >= 0 and excluded_self_reviews >= 0 and " <>
                 "excluded_bot_or_app >= 0 and excluded_unlinked >= 0"
           )

    create index(:collected_artifact_evaluations, [:tenant_id, :external_submitted_at])
  end
end
