defmodule TheBand.Repo.Migrations.CreateArtifactEvaluations do
  @moduledoc """
  As avaliações de artefato — `qapo.artifact_evaluation`, issue #440.

  ## O mapeamento estava pronto e nunca foi coletado

  `github.pull_request_review.to.qapo.artifact_evaluation` declara origem, conceito alvo,
  atributos e relações desde a versão 1. A necessidade de informação
  `review_time_to_first_review` declara a pergunta e quem decide com ela. A medida
  `review_time_to_first_review_duration` declara os dois insumos.

  **Faltava só a tabela.** E os dados vêm na mesma consulta GraphQL que já traz os Pull
  Requests — nenhuma requisição nova por solicitação.

  ## As três limitações do mapeamento viraram coluna

  Cada uma virou estrutura, e não comentário:

    * *"reviews automáticas devem ser classificadas separadamente das humanas"* →
      `author_type`, com o `__typename` cru da origem. Sem ele a plataforma contaria a
      revisão de um bot como revisão humana, e a medida de tempo até a primeira revisão
      mediria o robô;

    * *"aprovação não implica ausência de não conformidades, apenas ausência de bloqueio"* →
      `state` fica **cru** (`APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`, `DISMISSED`), e
      nenhuma coluna afirma "conforme". A interpretação fica ao lado, nunca no lugar;

    * *"um comentário isolado não é uma review"* → só evento de review submetida entra, e é
      por isso que a consulta usa `reviews` e não `reviewThreads`.

  ## `submitted_at` pode ser nulo, e isso não é falha

  Review em rascunho (`PENDING`) existe na origem e não tem instante de submissão. Nulo é
  "não submetida", e a medida de tempo até a primeira revisão precisa excluí-las — o
  mapeamento já dizia "excluir solicitações em rascunho".
  """
  use Ecto.Migration

  def change do
    create table(:collected_artifact_evaluations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :collected_change_request_id,
          references(:collected_change_requests, type: :binary_id, on_delete: :delete_all),
          null: false

      # Cru, como a origem entrega. A tradução para conformidade fica na leitura.
      add :state, :string
      add :body, :text

      # Nulo quando a review não foi submetida (rascunho) — ausência nomeada.
      add :external_submitted_at, :utc_datetime

      add :author_login, :string
      # `User`, `Bot`, `Organization`… O mapeamento manda classificar bot separadamente, e
      # sem este campo a distinção não existiria.
      add :author_type, :string
      add :author_person_id, references(:eo_people, type: :binary_id, on_delete: :nilify_all)

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :raw_payload, :map

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      # Marca, nunca apaga: review dispensada (`DISMISSED`) continua sendo fato sobre o
      # processo, e sumir da origem é informação.
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collected_artifact_evaluations, [:tenant_id, :external_id])
    create index(:collected_artifact_evaluations, [:collected_change_request_id])
    create index(:collected_artifact_evaluations, [:author_person_id])

    alter table(:collected_change_requests) do
      # O total da ORIGEM, para que truncamento nunca seja silencioso — a mesma postura de
      # `commits_total` e `attended_issues_total`. Nulo é "não medido", nunca zero.
      add :reviews_total, :integer
    end

    alter table(:observed_repositories) do
      add :reviews_collected_at, :utc_datetime
    end
  end
end
