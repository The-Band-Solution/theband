defmodule TheBand.Repo.Migrations.CreateCmpoSourceRepositories do
  @moduledoc """
  A extensão do repositório, em CMPO (feature 004, T008).

  ## Por que existe uma tabela de extensão

  Um `subkind` cujo kind vive em outra ontologia contribui um valor de discriminador
  na tabela do kind — e, quando tem atributos próprios, ganha tabela de extensão na
  ontologia dona, ligada por chave estrangeira (ADR 0004 D9).

  **A extensão só existe porque o conceito declara atributos.** Sem eles, o subkind
  contribuiria apenas o discriminador e desapareceria. Foi o que acontecia antes de
  `cmpo.source_repository` declarar `name`, `url` e os demais.

  Os atributos são o que **qualquer hospedagem de Git** fornece, não o que o GitHub
  fornece. A identidade — Application Reference, `tenant_id`, `internal_id` — vive na
  tabela do kind, que é onde ela pertence.

  ## `archived_at` não é `no_longer_observed_at`

  Arquivado é **fato da origem**: o GitHub diz. Não mais observado é **inferência da
  plataforma**: comparou coletas e não achou. Um repositório arquivado continua sendo
  observado, e suas issues continuam consultáveis.

  E a exclusão decidida pelo tenant é uma **terceira** coisa, que vive em
  `observed_repositories` porque é decisão de quem administra, não fato do mundo.

  ## Nenhum booleano `is_fork`

  Ser fork é dizer que esta cópia deriva de **outra cópia** — relação, não
  propriedade. Um booleano guardaria que existe origem e perderia qual é: é o
  antipadrão "booleano no lugar do relator". Fica pendente até a relação
  cópia-deriva-de-cópia ser declarada em CMPO.

  ## `default_branch` guarda o nome, não uma referência

  A relação existe na base — `cmpo.branch_belongs_to_repository` —, e apontar para ela
  exigiria coletar ramos, que está fora do escopo desta feature. O nome responde o que
  a tela precisa hoje, e a coluna sai quando a relação entrar.
  """
  use Ecto.Migration

  def up do
    create table(:cmpo_source_repositories, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(
        :loaded_software_system_copy_id,
        references(:sys_swo_loaded_software_system_copies, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:organization_id, references(:eo_organizations, type: :uuid, on_delete: :restrict),
        null: false
      )

      add(:name, :string, null: false)
      add(:qualified_name, :string, null: false)
      add(:url, :string, null: false)
      add(:description, :text)
      add(:primary_language, :string)
      add(:default_branch, :string)
      add(:archived_at, :utc_datetime)
      add(:external_created_at, :utc_datetime)
      add(:last_pushed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cmpo_source_repositories, [:loaded_software_system_copy_id])
    create index(:cmpo_source_repositories, [:tenant_id, :organization_id])
  end

  def down do
    drop table(:cmpo_source_repositories)
  end
end
