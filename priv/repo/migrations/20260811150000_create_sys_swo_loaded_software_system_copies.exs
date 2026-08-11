defmodule TheBand.Repo.Migrations.CreateSysSwoLoadedSoftwareSystemCopies do
  @moduledoc """
  A tabela do kind referenciado por CMPO (feature 004, T007).

  ## Por que uma tabela de SysSwO numa feature de ingestão do GitHub

  `cmpo.source_repository` é `subkind` de `sys_swo.loaded_software_system_copy`. Pela
  **regra da fronteira** — constituição IX —, atravessar a fronteira de ontologia é
  **referência**: o repositório é um valor de discriminador na tabela do kind, e não
  uma tabela própria de CMPO.

  Criar esta tabela é atender a referência, e ela é criada **uma vez só**. A próxima
  ontologia que precisar de cópia carregada de sistema de software — um ambiente de
  build, um servidor de CI — aponta para ela e acrescenta seu valor de discriminador.
  Nada do que já existe é alterado.

  ## Por que só um conceito da SysSwO foi anotado

  Os outros 10 seguem sem `ontouml_stereotype`, e `derive_information_model.py
  --ontology sys_swo` continua falhando. Isso é correto: anotar a ontologia inteira
  para registrar um repositório seria o pré-requisito disfarçado que o princípio IX
  nomeia.

  ## O único não vale entre tabelas

  A Application Reference é única **dentro** desta tabela. O mesmo `external_id` pode
  designar outro artefato em outra tabela, e em fontes que numeram por tipo — Jira,
  Azure DevOps — a coincidência é rotina. Nunca existirá tabela compartilhada indexada
  por `external_id`; quando compartilhar for necessário, o tipo entra na chave, como
  em `raw_payloads.raw_entity_type`.
  """
  use Ecto.Migration

  def up do
    create table(:sys_swo_loaded_software_system_copies, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:internal_id, :string, null: false)
      add(:record_version, :integer, null: false, default: 1)

      # Discriminador do subkind. `source_repository` é o primeiro valor; outros
      # chegam com as ontologias que referenciarem o mesmo kind.
      add(:type, :string, null: false)

      add(:source_system, :string, null: false)
      add(:source_instance, :string, null: false)
      add(:external_id, :string, null: false)
      add(:collected_at, :utc_datetime, null: false)
      add(:last_observed_at, :utc_datetime)
      add(:no_longer_observed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :sys_swo_loaded_software_system_copies,
             [:tenant_id, :source_system, :source_instance, :external_id],
             name: :sys_swo_copies_application_reference_index
           )

    create index(:sys_swo_loaded_software_system_copies, [:tenant_id, :type])

    create constraint(
             :sys_swo_loaded_software_system_copies,
             :sys_swo_copies_type_check,
             check: "type IN ('source_repository')"
           )
  end

  def down do
    drop table(:sys_swo_loaded_software_system_copies)
  end
end
