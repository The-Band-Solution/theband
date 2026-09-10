defmodule TheBand.Repo.Migrations.ContaDesativada do
  @moduledoc """
  A conta desativada — achado **H3, parte B**, 2026-09-09.

  ## O que esta migração é, e o risco que ela NÃO corre

  **Só acréscimo de colunas nulas.** Sem backfill, sem CHECK, sem alterar dado
  existente — é a migração de menor risco possível, e a versão anterior da aplicação
  sobe sobre este esquema sem saber que as colunas existem (runbook §5).

  Isso importa porque o **ensaio de restauração do §6 continua adiado** (a conta no
  destino S3 não existe), e o registro da v0.6.0 escreveu o risco com estas palavras:
  *"o caminho de volta é um backup que nunca foi restaurado"*. Uma migração que altera
  dado, com esse caminho de volta, é aposta; uma que só acrescenta coluna nula, não.

  ## Marca, e nunca `delete`

  A forma é a de `ScopeGrant.revoke_changeset/2` — `disabled_at` e
  `disabled_by_user_id`. Apagar a linha apagaria o registro de que a conta existiu, e é
  exactamente o que um incidente de acesso precisa reconstruir (SC-005 da spec 045).

  ## O índice, e por que é parcial

  A pergunta que a plataforma faz é *"quais contas estão desativadas?"* — e não
  *"quando esta foi desativada?"*. O índice parcial cobre a primeira e custa
  proporcionalmente ao número de desativadas, que é pequeno.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :disabled_at, :utc_datetime
      add :disabled_by_user_id, references(:users, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:users, [:tenant_id, :disabled_at],
             where: "disabled_at IS NOT NULL",
             name: :users_desativadas_por_tenant
           )
  end
end
