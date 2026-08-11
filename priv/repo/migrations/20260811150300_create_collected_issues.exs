defmodule TheBand.Repo.Migrations.CreateCollectedIssues do
  @moduledoc """
  A issue como a origem a devolveu (feature 004, T013).

  Camada de plataforma: aqui vive o vocabulário do GitHub. O que entra no domínio é o
  **conceito para o qual a issue foi promovida**, e a promoção é registrada à parte.

  ## `issue_type` fica cru, e é anulável

  Normalizar destruiria o dado que a lacuna precisa mostrar: FR-034 manda exibir **o
  nome do tipo encontrado**, e "tipo desconhecido" sem o nome não diz onde a regra
  precisa mudar. Nulo é valor legítimo — organização que não usa tipos.

  ## `observed_repository_id` não é anulável, e é o escopo da ausência

  Toda marca de "não mais observado" se dá **dentro** de um repositório. Sem esta
  coluna, a única forma de escopar seria por tenant — que é exatamente a L19, e numa
  organização de 14 repositórios ela atingiria 13.

  ## `number` não entra no índice único

  O número é único dentro do repositório, e mover a issue cria outro no destino. A
  identidade é o identificador global — FR-008. O número fica para exibir e localizar.

  ## O único não vale entre tabelas

  `collected_issues` e `cmpo_source_repositories` podem ter o mesmo `external_id` sem
  colidir, porque o tipo da entidade está **implícito na tabela** e nenhuma consulta
  cruza as duas por esse campo — FR-008a.

  Em fontes que numeram por tipo, a coincidência é rotina em vez de exceção. A regra
  para quem acrescentar entidade: **nunca uma tabela compartilhada indexada por
  `external_id`**. `raw_payloads` mostra a alternativa, carregando `raw_entity_type`.
  """
  use Ecto.Migration

  def up do
    create table(:collected_issues, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(
        :observed_repository_id,
        references(:observed_repositories, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:number, :integer, null: false)
      add(:title, :text, null: false)
      add(:state, :string, null: false)

      # O nome e o identificador do tipo, como a origem os deu. Anuláveis.
      add(:issue_type, :string)
      add(:issue_type_external_id, :string)

      add(:external_parent_id, :string)
      add(:sub_issue_count, :integer, null: false, default: 0)

      add(:source_system, :string, null: false)
      add(:source_instance, :string, null: false)
      add(:external_id, :string, null: false)
      add(:external_created_at, :utc_datetime)
      add(:collected_at, :utc_datetime, null: false)
      add(:last_observed_at, :utc_datetime)
      add(:no_longer_observed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :collected_issues,
             [:tenant_id, :source_system, :source_instance, :external_id],
             name: :collected_issues_application_reference_index
           )

    create index(:collected_issues, [:tenant_id, :observed_repository_id])
    create index(:collected_issues, [:tenant_id, :issue_type])
  end

  def down do
    drop table(:collected_issues)
  end
end
