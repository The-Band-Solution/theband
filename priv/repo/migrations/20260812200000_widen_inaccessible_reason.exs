defmodule TheBand.Repo.Migrations.WidenInaccessibleReason do
  @moduledoc """
  `inaccessible_reason` deixa de ter limite arbitrário.

  **Medido em 2026-08-12**: o maior motivo gravado tem **181** caracteres, e o da falha
  interna do GitHub — com o prefixo que a plataforma acrescenta — dá **~228**. São **27 de
  folga**, num texto que a origem controla e que carrega um identificador de incidente de
  tamanho variável.

  Sem `validate_length` no changeset, o valor longo vai ao banco e **levanta**. O tratamento
  de erro da coleta cobre changeset inválido, não exceção do driver: a fase cairia, e o erro
  no log seria do banco em vez da origem.

  É a **L05** literal — `varchar(255)` em coluna de diagnóstico troca o erro real por um erro
  de banco —, e a lição já concluiu que coluna de diagnóstico não tem limite arbitrário.

  A truncagem continua existindo, e vive **na borda**, onde a mensagem é montada. A coluna
  deixa de ser a defesa porque ela nunca deveria ter sido.
  """
  use Ecto.Migration

  def up do
    alter table(:observed_repositories) do
      modify :inaccessible_reason, :text
    end
  end

  # A volta trunca o que não couber: `varchar(255)` recusaria o valor longo, e a migração
  # falharia no meio em vez de reverter.
  def down do
    execute "UPDATE observed_repositories SET inaccessible_reason = left(inaccessible_reason, 255)"

    alter table(:observed_repositories) do
      modify :inaccessible_reason, :string
    end
  end
end
