defmodule TheBand.Repo.Migrations.AddIssueDetails do
  @moduledoc """
  Os campos que a origem fornece de uma issue (feature 006, US1).

  ## Por que o corpo é preservado como veio

  Ele é **evidência**. A promoção por padrão de título — feature 005 — se apoia no texto
  como a origem o escreveu, e normalizar destruiria o que sustenta a decisão. O mesmo
  vale para `state_reason`: `COMPLETED` e `NOT_PLANNED` mudam o significado do
  fechamento, e traduzi-los na gravação perderia a distinção.

  ## Contagem de comentários, e não o conteúdo

  A issue `#1` deste repositório tem 48 itens de timeline. Coletá-los multiplicaria o
  consumo da origem por issue, e comentário é entidade própria — com autor, data e
  semântica que merece decisão própria. A contagem responde "houve discussão" sem pagar
  por ela.

  ## Autor e designados NÃO viram coluna

  Autor é uma pessoa; designados são zero ou muitos. Uma coluna guardaria um valor e
  perderia a multiplicidade — é o mesmo motivo pelo qual papel organizacional não é
  coluna em `eo_people`. Ficam em tabelas próprias, na migração seguinte.

  Nenhuma coluna é removida.
  """
  use Ecto.Migration

  def up do
    alter table(:collected_issues) do
      add(:body, :text)
      add(:state_reason, :string)
      add(:author_login, :string)
      add(:author_person_id, references(:eo_people, type: :uuid, on_delete: :nilify_all))
      add(:milestone_title, :string)
      # Os quadros em que a issue aparece, **como referência**. A feature 004 deixou a
      # coleta de quadros fora do escopo (F4), e guardar só o título aqui declara a
      # ligação sem inventar o quadro como entidade — que é o que FR-006 pede ao dizer
      # que nenhum dos dois é promovido.
      add(:project_titles, {:array, :string}, null: false, default: [])
      add(:comment_count, :integer, null: false, default: 0)
      add(:reaction_count, :integer, null: false, default: 0)
      add(:external_updated_at, :utc_datetime)
      add(:external_closed_at, :utc_datetime)
    end

    create index(:collected_issues, [:tenant_id, :author_person_id])
  end

  def down do
    alter table(:collected_issues) do
      remove(:body)
      remove(:state_reason)
      remove(:author_login)
      remove(:author_person_id)
      remove(:milestone_title)
      remove(:project_titles)
      remove(:comment_count)
      remove(:reaction_count)
      remove(:external_updated_at)
      remove(:external_closed_at)
    end
  end
end
