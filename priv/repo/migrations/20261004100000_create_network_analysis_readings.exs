defmodule TheBand.Repo.Migrations.CreateNetworkAnalysisReadings do
  @moduledoc """
  A leitura vigente da análise de rede — feature 076, T009. Desenho em
  `specs/076-analise-de-rede/data-model.md` §1.

  Uma linha por `(tenant, organização observada, rede, janela)`, substituída inteira a cada
  cálculo que muda a impressão digital (R4), e nunca editada além de `checked_at`. Guarda ids de
  pessoa, e nunca nome nem login (R9, R10 da segurança). Percentil e papel **não** estão aqui: são
  derivados na leitura (R17).

  ## As restrições

  - **FK composta `(organization_id, tenant_id)`** → `eo_organizations(id, tenant_id)`, como a 073:
    sem ela, nada impede uma linha com a organização de um tenant e o `tenant_id` de outro. O
    índice único `eo_organizations(id, tenant_id)` já existe (073);
  - **índice único `(tenant_id, organization_id, network, window_days)`**: uma leitura vigente por
    rede. Com a rede na chave, o cálculo da designação não pode apagar a de revisão (A21);
  - **`network` em `('review', 'assignment')`**: as duas redes de
    `network.analysis.parameters.networks`. Valor novo entra por versão da regra **e** migração,
    nunca por digitação (estado como string livre, §7.7);
  - **contagens `>= 0`** e **`checked_at >= computed_at`**;
  - **`on_delete: :delete_all`** nas duas: a leitura é derivada, e não sobrevive ao tenant nem à
    organização.

  Aditiva: o rollback desfaz a tabela, o índice e as restrições, e nada mais.
  """
  use Ecto.Migration

  def change do
    create table(:network_analysis_readings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false

      add :organization_id,
          references(:eo_organizations,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            on_delete: :delete_all
          ),
          null: false

      add :network, :text, null: false
      add :window_days, :integer, null: false
      add :window_start, :utc_datetime, null: false
      add :window_end, :utc_datetime, null: false
      add :computed_at, :utc_datetime, null: false
      add :checked_at, :utc_datetime, null: false
      add :source_computed_at, :utc_datetime
      add :fingerprint, :text, null: false
      add :edges, :map, null: false
      add :exclusions, :map, null: false
      add :people_without_edges, :integer
      add :nodes, :map, null: false
      add :communities, :map, null: false
      add :measures, :map, null: false
      add :provenance, :map, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Nome explícito: o gerado passa de 63 caracteres e o Postgres o trunca, e o changeset não
    # reconheceria a violação.
    create unique_index(
             :network_analysis_readings,
             [:tenant_id, :organization_id, :network, :window_days],
             name: :network_analysis_readings_vigente_index
           )

    create constraint(:network_analysis_readings, :network_analysis_readings_network_allowed,
             check: "network in ('review', 'assignment')"
           )

    create constraint(:network_analysis_readings, :network_analysis_readings_window_days_positive,
             check: "window_days > 0"
           )

    create constraint(:network_analysis_readings, :network_analysis_readings_window_ordered,
             check: "window_end > window_start"
           )

    create constraint(:network_analysis_readings, :network_analysis_readings_checked_after,
             check: "checked_at >= computed_at"
           )

    create constraint(:network_analysis_readings, :network_analysis_readings_counts_non_negative,
             check: "people_without_edges is null or people_without_edges >= 0"
           )
  end
end
