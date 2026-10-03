defmodule TheBand.Repo.Migrations.DataDaTrocaDaChaveDoModelo do
  @moduledoc """
  064/T019, FR-018 — a chave do provedor de modelos troca na **mesma linha** (`AI.put/3` faz
  `insert_or_update`), e até aqui a troca só reescrevia `validated_at`: a data em que a chave
  anterior passou a valer se perdia, e regravar a mesma chave zerava a contagem.

  `secret_set_at` é quando o segredo atual foi gravado; `previous_secret_set_at`, desde quando
  valia o que ele substituiu. **Nenhuma das duas é segredo**: são datas, e sozinhas não abrem
  nada.

  As linhas existentes **não** são preenchidas: o `nil` cai, em `Credenciais.Idade`, no
  `validated_at`, que é a data em que aquela chave foi gravada. Preencher copiaria o mesmo valor
  e esconderia que a data é inferida.

  A credencial de ferramenta não ganha coluna: a troca dela já é uma linha nova.
  """
  use Ecto.Migration

  def change do
    alter table(:ai_provider_credentials) do
      add :secret_set_at, :utc_datetime
      add :previous_secret_set_at, :utc_datetime
    end
  end
end
