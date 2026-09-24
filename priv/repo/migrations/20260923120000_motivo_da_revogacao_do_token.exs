defmodule TheBand.Repo.Migrations.MotivoDaRevogacaoDoToken do
  @moduledoc """
  Revogar um token passa a gravar **por quê** — decisão Q4 do protótipo, tomada em 2026-09-23.

  ## O que havia, e por que era omissão

  `revoked_at` e `revoked_by_user_id` gravavam **quem** e **quando**. Faltava a razão — e isso
  era **omissão, não decisão**: ninguém tinha sido perguntado. Uma revogação sem razão é uma
  decisão que ninguém reconstrói seis meses depois.

  ## Duas colunas, e por que não uma

  A **cláusula** é lista fechada, casada uma a uma contra
  `api.access.token_revocation_reason` — `integracao_encerrada`, `suspeita_de_vazamento`,
  `substituido_por_outro`, `outro`. A **nota** é texto livre, opcional.

  Uma coluna só, de texto livre, não responde *"quantas revogações foram por suspeita de
  vazamento neste trimestre?"* — isso é contagem, e contagem sobre texto livre é leitura à
  mão. Uma coluna só, fechada, perde o que a lista não cabe.

  A cláusula que justifica o campo é **`suspeita_de_vazamento`**: é o único caso em que o
  próximo ato muda — girar tudo o que aquela conta alcança, e não só substituir a integração.

  ## O que esta migração NÃO faz

  **Não preenche o passado.** As revogações anteriores a 2026-09-23 ficam com cláusula nula, e
  quem renderiza escreve a ausência — *"no reason recorded · revoked before 23 Sep 2026"*.
  Escolher uma cláusula para elas seria inventar a razão de outra pessoa.

  **Não torna a cláusula obrigatória no banco.** `null: false` reprovaria toda linha já
  existente, e um `default` inventaria a razão delas. A obrigatoriedade vive no changeset da
  revogação nova, onde há quem responda.

  Aditiva: `add` de duas colunas nulas. O rollback as remove e não perde nada além delas.
  """
  use Ecto.Migration

  def change do
    alter table(:api_access_tokens) do
      add :revocation_clause, :string
      add :revocation_note, :text
    end
  end
end
