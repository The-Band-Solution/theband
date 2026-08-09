defmodule TheBand.Repo.Migrations.CreateEoInformationModel do
  @moduledoc """
  Modelo de informação da Enterprise Ontology, derivado por `one table per kind`
  (ADR 0004). Conferido contra `derive_information_model.py --ontology eo`:
  10 conceitos produzem 6 tabelas.

  O que **não** vira tabela, e por quê:

    * `eo.organizational_team` e `eo.project_team` são `subkind` — absorvidos em
      `eo_teams.type`;
    * `eo.team_member` é `role` — absorvido em `eo_people`, materializando pelo
      relator `eo_team_memberships`, nunca por coluna booleana;
    * `eo.organizational_unit` é não-sortal — achatado para as subclasses.

  `eo_organizational_roles`, `eo_team_memberships` e `eo_sectors` nascem vazias
  nesta feature: o GitHub não fornece papel organizacional. Criar a tabela vazia
  é deliberado — omitir porque a primeira fonte não a alimenta faria a próxima
  fonte exigir migração.
  """

  use Ecto.Migration

  def change do
    # ------------------------------------------------------------ eo.organization
    create table(:eo_organizations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      add :name, :string
      add :login, :string

      add :parent_organization_id,
          references(:eo_organizations, type: :uuid, on_delete: :nilify_all)

      # Application Reference — sem ela o registro é inválido, não incompleto.
      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :collected_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :eo_organizations,
             [:tenant_id, :source_system, :source_instance, :external_id],
             name: :eo_organizations_application_reference_index
           )

    # ------------------------------------------------------------------ eo.person
    create table(:eo_people, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      add :name, :string, null: false
      add :email, :string
      add :login, :string
      # FR-022 — automação é registrada e classificada separadamente, e não conta
      # como pessoa em nenhuma contagem apresentada.
      add :account_type, :string, null: false, default: "person"

      add :organization_id, references(:eo_organizations, type: :uuid, on_delete: :nilify_all)

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:eo_people, [:tenant_id, :source_system, :source_instance, :external_id],
             name: :eo_people_application_reference_index
           )

    create constraint(:eo_people, :eo_people_account_type_check,
             check: "account_type in ('person','bot','app')"
           )

    # ------------------------------------------------------------------ eo.sector
    create table(:eo_sectors, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      add :name, :string, null: false

      add :organization_id, references(:eo_organizations, type: :uuid, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    # ------------------------------------------------------- eo.organizational_role
    create table(:eo_organizational_roles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      # Papel é linha, não valor de enum (ADR 0004, D6): papel novo é um INSERT,
      # e cada organização define os seus.
      add :code, :string, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:eo_organizational_roles, [:tenant_id, :code])

    # -------------------------------------------------------------------- eo.team
    create table(:eo_teams, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      # Discriminador dos dois subkinds. FR-023: o GitHub alimenta sempre
      # `organizational_team`; promover a `project_team` exige vínculo efetivo
      # com projeto ou repositório, ou declaração do tenant.
      add :type, :string, null: false, default: "organizational_team"
      add :name, :string, null: false
      add :slug, :string

      add :organization_id, references(:eo_organizations, type: :uuid, on_delete: :nilify_all)

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      add :no_longer_observed_at, :utc_datetime
      add :external_created_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:eo_teams, [:tenant_id, :source_system, :source_instance, :external_id],
             name: :eo_teams_application_reference_index
           )

    create constraint(:eo_teams, :eo_teams_type_check,
             check: "type in ('organizational_team','project_team')"
           )

    # --------------------------------------------------------- eo.team_membership
    # O relator de três termos: pessoa, equipe e papel. Nenhum é opcional — uma
    # alocação sem papel não responde nenhuma das perguntas que a alocação existe
    # para responder.
    create table(:eo_team_memberships, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :internal_id, :string, null: false
      add :record_version, :integer, null: false, default: 1

      add :person_id, references(:eo_people, type: :uuid, on_delete: :delete_all), null: false
      add :team_id, references(:eo_teams, type: :uuid, on_delete: :delete_all), null: false

      add :organizational_role_id,
          references(:eo_organizational_roles, type: :uuid, on_delete: :restrict),
          null: false

      # FR-024 — a API do GitHub não informa quando a pessoa entrou no time.
      # Ficam nulos, e o histórico de alocação não é reconstituível dessa fonte.
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:eo_team_memberships, [:tenant_id, :team_id])
    create index(:eo_team_memberships, [:tenant_id, :person_id])
  end
end
