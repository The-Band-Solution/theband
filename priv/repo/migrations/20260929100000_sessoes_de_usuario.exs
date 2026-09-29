defmodule TheBand.Repo.Migrations.SessoesDeUsuario do
  @moduledoc """
  A tabela de sessões — feature 064, T009, FR-004. O desenho está em
  `specs/064-segredo-em-repouso/data-model.md`, emendado em 2026-09-28 pela avaliação
  `seguranca-us2.md`.

  Uma linha por sessão aberta, e o banco guarda **só o resumo** do token: quem lê um dump,
  mesmo tendo o `SECRET_KEY_BASE`, não monta um cookie válido. Hoje `users.session_token` está
  em claro, e as duas metades bastam.

  ## As colunas que a avaliação trouxe

  - **`tenant_id`, e a FK composta `(user_id, tenant_id)`** (S9, P4). Sem a coluna, não há como
    encerrar as sessões de uma organização. Sem a FK composta, nada impede uma linha com o
    `user_id` de um tenant e o `tenant_id` de outro. A FK exige o índice único
    `users(id, tenant_id)`, criado aqui. Ele é redundante com a chave primária, e existe só
    porque o Postgres exige índice único exatamente sobre as colunas referenciadas.
  - **`password_epoch` na linha, e não no cookie** (S2). No cookie, quem tem o
    `SECRET_KEY_BASE` o reassinaria com a época nova, que é um inteiro adivinhável.
  - **Sem `last_seen_at`** (P2, S10). A validade é absoluta, de 7 dias a contar de
    `inserted_at`. Sem expiração por inatividade, a coluna seria uma escrita por requisição e uma
    trilha de atividade de pessoa em todo backup, sem trabalho nenhum.

  **`bytea`, e não texto**: o resumo é binário. Em hexadecimal, ele dobraria de tamanho e
  convidaria comparação por `==` sobre string.

  **`ended_at` desde o primeiro dia** (FR-015): foi a ausência de `cancelled_at` que tornou
  permanentes quatro jobs do Oban, um deles com segredo (T007).

  Aditiva: cria uma tabela e um índice. O rollback remove os dois, e nada mais.
  """
  use Ecto.Migration

  def change do
    create unique_index(:users, [:id, :tenant_id])

    create table(:user_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :user_id,
          references(:users, type: :uuid, with: [tenant_id: :tenant_id], on_delete: :delete_all),
          null: false

      add :token_hash, :binary, null: false
      add :password_epoch, :integer, null: false
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:user_sessions, [:token_hash])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:tenant_id])
    create index(:user_sessions, [:ended_at])
    create index(:user_sessions, [:inserted_at])
  end
end
