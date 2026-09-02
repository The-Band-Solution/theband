defmodule TheBand.Repo.Migrations.NomeUnicoDaEquipeDeclarada do
  @moduledoc """
  Duas equipes declaradas com o mesmo nome na mesma organização — feature 055,
  FR-001.

  ## Por que índice, e não consulta antes de inserir

  A consulta prévia perde a corrida entre duas abas. A feature 052 provou isso
  quando a garantia contra dois administradores veio dos índices únicos, e não de
  um `SELECT` antes do `INSERT`.

  ## Por que só entre DECLARADAS

  O `WHERE source_instance = 'declared'` é o ponto. Uma equipe declarada com o
  mesmo nome de uma **observada** não é erro: a organização pode ter um time
  interno homônimo ao que o GitHub mostra, e a tela distingue os dois pela
  origem, não pelo nome. Bloquear isso faria a plataforma recusar um fato do
  mundo por causa de um fato da coleta.

  E na direção contrária: incluir as observadas no índice faria a **coleta**
  falhar quando o GitHub tivesse dois times de mesmo nome — a plataforma
  recusando o que a origem afirma, que é o oposto do que ela deve fazer.
  """
  use Ecto.Migration

  def change do
    create unique_index(:eo_teams, [:tenant_id, :organization_id, :name],
             where: "source_instance = 'declared'",
             name: :eo_nome_unico_da_equipe_declarada_index
           )
  end
end
