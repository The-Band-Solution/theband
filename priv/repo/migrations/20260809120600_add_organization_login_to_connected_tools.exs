defmodule TheBand.Repo.Migrations.AddOrganizationLoginToConnectedTools do
  @moduledoc """
  Qual organização observar na instância.

  A instância diz **onde** o GitHub roda; não diz **qual** organização coletar, e
  uma credencial costuma enxergar mais de uma. Sem este campo a coleta teria de
  adivinhar — e adivinhar aqui traria dado de organização errada para dentro do
  tenant, que é exatamente o tipo de erro que ninguém percebe até ser tarde.
  """

  use Ecto.Migration

  def change do
    alter table(:connected_tools) do
      add :organization_login, :string
    end
  end
end
