defmodule TheBand.Repo.Migrations.CreateEoTeamMembershipEvidence do
  @moduledoc """
  Materializa `observed_link` da regra `github.team_membership_evidence`.

  O nome vem de `persisted_as` na própria regra — ver D-1 no plan.md, que
  substitui o `eo_observed_team_links` proposto em research.md R7.

  Por que tabela separada de `eo_team_memberships`: o GitHub fornece pessoa e
  equipe, e não o papel. Gravar membership com papel nulo violaria o relator e
  faria toda consulta de papel tratar o caso nulo, espalhando pela aplicação a
  consequência de uma limitação da fonte.
  """

  use Ecto.Migration

  def change do
    create table(:eo_team_membership_evidence, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :person_id, references(:eo_people, type: :uuid, on_delete: :delete_all), null: false
      add :team_id, references(:eo_teams, type: :uuid, on_delete: :delete_all), null: false

      # Os identificadores externos ficam aqui além das chaves internas: a
      # evidência precisa ser rastreável à origem mesmo antes de resolver a
      # chave interna.
      add :person_external_id, :string, null: false
      add :team_external_id, :string, null: false

      # FR-020 — nível de acesso na plataforma, NUNCA papel organizacional.
      # Promovê-lo a eo_organizational_roles produziria um catálogo que não
      # corresponde a função nenhuma.
      add :platform_access_level, :string, null: false

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :observed_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime, null: false
      # Ausência não é remoção: o vínculo é marcado, nunca apagado.
      add :no_longer_observed_at, :utc_datetime

      # FR-021 — a lacuna é medida pela contagem de linhas com este campo nulo.
      add :promoted_membership_id,
          references(:eo_team_memberships, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :eo_team_membership_evidence,
             [
               :tenant_id,
               :source_system,
               :source_instance,
               :person_external_id,
               :team_external_id
             ],
             name: :eo_team_membership_evidence_application_reference_index
           )

    create constraint(:eo_team_membership_evidence, :eo_evidence_access_level_check,
             check: "platform_access_level in ('MAINTAINER','MEMBER')"
           )

    create index(:eo_team_membership_evidence, [:tenant_id, :promoted_membership_id])
  end
end
