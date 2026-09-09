defmodule TheBand.Repo.Migrations.DonoDoTokenNaCredencial do
  @moduledoc """
  O login do dono do token passa a ser gravado na credencial — ADR 0007, decisão 1.

  ## Por que a coluna existe

  A cota primária do GitHub é por **usuário autenticado**, não por token: dois tokens do
  mesmo usuário, em duas ferramentas ou dois tenants, dividem as mesmas 5 000 requisições
  por hora. `verify_credential/2` já recebia o login em toda validação e o descartava em
  três lugares. Sem ele, nada no modelo consegue dizer quais ferramentas competem pela
  mesma cota.

  ## Por que nulo

  As credenciais que já existem não têm o dado, e ele só se descobre com uma chamada à
  origem usando o segredo decifrado — `Sources.descobrir_dono/1`, disparada pelo job de
  coleta, e não por esta migração. Uma migração que chamasse o GitHub falharia sem rede e
  precisaria da chave mestra no momento do deploy.

  ## Por que o índice

  A pergunta "quem divide cota comigo?" é por tenant e por dono
  (`Sources.credenciais_com_mesmo_dono/1`).
  """
  use Ecto.Migration

  def change do
    alter table(:tool_credentials) do
      add :owner_login, :string
    end

    create index(:tool_credentials, [:tenant_id, :owner_login])
  end
end
