defmodule TheBand.Repo.Migrations.WidenErrorColumns do
  @moduledoc """
  Motivo de falha vira `text`.

  `varchar(255)` truncava a única informação que explica por que a sincronização
  falhou — e, pior, o `INSERT` estourava, trocando a mensagem de erro real por um
  erro de banco. Diagnóstico não cabe em limite arbitrário.
  """

  use Ecto.Migration

  def change do
    alter table(:syncs) do
      modify :error_reason, :text, from: :string
    end

    alter table(:connected_tools) do
      modify :needs_attention_reason, :text, from: :string
    end
  end
end
