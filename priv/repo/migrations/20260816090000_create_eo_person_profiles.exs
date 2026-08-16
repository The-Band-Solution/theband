defmodule TheBand.Repo.Migrations.CreateEoPersonProfiles do
  @moduledoc """
  O perfil derivado de uma pessoa — feature 026.

  ## Somente acréscimo, e por que isso não é preciosismo

  Uma geração nova **não apaga** a anterior. Um perfil de agosto e outro de dezembro contam
  algo que nenhum dos dois conta sozinho, e sobrescrever destruiria a única série que esta
  feature produz ao longo do tempo. Por isso não existe `updated_at`: não existe atualização.

  ## O recorte de entrada é coluna, e não JSON

  É o que permite, meses depois, dizer **sobre o que aquele texto falava** — e é consultado
  para comparar o recorte gravado com o que existe hoje, que é a FR-016.

  ## Nenhuma chave estrangeira para as issues

  O perfil descreve um recorte que já passou. Uma issue apagada não deve apagar o perfil que
  a mencionou.
  """

  use Ecto.Migration

  def change do
    create table(:eo_person_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # A identidade é a da plataforma, e **não** o login: troca de login no GitHub não pode
      # apagar o histórico de perfis de alguém.
      add :person_id, references(:eo_people, type: :uuid, on_delete: :delete_all), null: false

      add :generated_at, :utc_datetime, null: false
      add :requested_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      add :model, :string, null: false
      add :body, :text, null: false

      # Zero aqui é medição — "nada foi removido" —, e não ausência de medida.
      add :citations_removed, :integer, null: false, default: 0

      # O recorte
      add :tasks_closed, :integer, null: false
      add :tasks_open, :integer, null: false
      add :tasks_with_body, :integer, null: false
      add :tasks_authored_by_other, :integer, null: false
      add :tasks_shared, :integer, null: false
      add :period_from, :date
      add :period_to, :date
      add :baseline_verdict, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # **Resposta vazia é falha, não perfil.** A constraint fecha o caminho no banco, e não só
    # no changeset: um perfil vazio afirmaria nada com a autoridade de um perfil.
    create constraint(:eo_person_profiles, :eo_person_profiles_body_nao_vazio,
             check: "btrim(body) <> ''"
           )

    create unique_index(:eo_person_profiles, [:tenant_id, :person_id, :generated_at],
             name: :eo_person_profiles_momento_index
           )

    create index(:eo_person_profiles, [:tenant_id, :person_id],
             name: :eo_person_profiles_pessoa_index
           )
  end
end
