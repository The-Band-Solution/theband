defmodule TheBand.Repo.Migrations.CreateObservedRepositories do
  @moduledoc """
  O que a **plataforma decidiu** sobre cada repositório (feature 004, T009).

  Separado do repositório em si, que é domínio. Aqui vive decisão de quem administra o
  tenant e falha de alcance da credencial — nenhuma das duas é fato do mundo, e por
  isso nenhuma das duas mora em CMPO. É o princípio II: fonte externa não é domínio, e
  decisão da plataforma também não.

  ## Três situações que não se confundem, e duas delas NÃO marcam ausência

      observado      normal                        coleta · marca ausência
      excluído       decisão do tenant             não coleta · NÃO marca
      inacessível    credencial perdeu alcance     não coleta · NÃO marca

  As duas últimas impedem a coleta, e é aí que engana: **a plataforma parou de olhar,
  e isso não é o mesmo que o dado ter sumido** — FR-005 e FR-006. Marcar ausência sem
  ter olhado é a L19 numa forma nova.

  `excluded_by_user_id` não é anulável quando há exclusão: decisão tem autor, e sem
  autor não há como responder "quem decidiu parar de observar este repositório".
  """
  use Ecto.Migration

  def up do
    create table(:observed_repositories, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(:connected_tool_id, references(:connected_tools, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :source_repository_id,
        references(:cmpo_source_repositories, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:excluded_at, :utc_datetime)
      add(:excluded_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all))
      add(:inaccessible_since, :utc_datetime)
      add(:inaccessible_reason, :string)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:observed_repositories, [:connected_tool_id, :source_repository_id])
    create index(:observed_repositories, [:tenant_id, :connected_tool_id])

    create constraint(
             :observed_repositories,
             :observed_repositories_exclusion_has_author,
             check: "excluded_at IS NULL OR excluded_by_user_id IS NOT NULL"
           )
  end

  def down do
    drop table(:observed_repositories)
  end
end
