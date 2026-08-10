defmodule TheBand.Repo.Migrations.AddDerivedOrganizationToTeams do
  @moduledoc """
  Cria `eo_teams.organization_id` **conforme a saída do derivador** (T007, FR-001).

  A coluna anterior foi escrita de memória. Esta é conferida linha a linha contra
  `python3 scripts/derive_information_model.py --ontology eo`, que produz:

      ┌─ eo_teams   (eo.team, kind)
      │    type                   enum      NOT NULL  {organizational_team, project_team}
      │    organization_id        uuid      NULL      → FK (association)
      │    check: organization_id IS NOT NULL OR type <> 'organizational_team'
      └─

      eo.organizational_team_belongs_to_organization: associação →
        eo_teams.organization_id anulável, obrigatória quando type='organizational_team'

  Conferir contra a saída, e não escrever de memória, é literalmente o erro que esta
  feature corrige.

  ## Por que anulável, com restrição condicional

  A relação parte de `eo.organizational_team`, um subkind **elevado** a `eo.team`.
  Uma coluna `NOT NULL` na tabela do kind obrigaria todo subtipo a tê-la, e isso é
  falso: `eo.project_team` liga-se a um projeto, e equipe de projeto entre
  organizações não pertence a uma organização só.

  Então a coluna é anulável e a obrigatoriedade fica ligada ao discriminador. O
  efeito é o que importa: **gravar equipe organizacional sem organização é recusado
  pelo banco**, não pela aplicação. Validação em changeset é contornável por qualquer
  caminho que não passe por ele — script, console, correção manual.

  ## `on_delete`

  `restrict`, e não `nilify_all` como na coluna anterior. Anular a organização de uma
  equipe organizacional produziria exatamente a linha que a restrição proíbe: apagar
  a organização passaria a falhar no `check` em vez de falhar na referência, com
  mensagem que não diz o que aconteceu. Recusar a exclusão diz.

  ## A restrição **não** está aqui, e a ordem das tarefas estava errada

  A T007 mandava criar coluna e `check_constraint` juntos. Não é possível: as 10
  equipes já coletadas são todas `organizational_team` com `organization_id` nula, e o
  Postgres recusa criar a restrição sobre linhas que a violam — verificado, com
  `ERROR 23514 (check_violation)`.

  O retrofito que preenche a coluna é a T011, **depois** desta fase. Então a restrição
  ganhou migração própria, aplicada após o retrofito, e isso é melhor do que um
  contorno: ela passa a ser **a verificação do retrofito**. Se qualquer equipe
  organizacional ficar sem organização, a migração se recusa a aplicar, e a falha
  aparece no lugar certo em vez de virar linha inválida tolerada.
  """
  use Ecto.Migration

  def up do
    alter table(:eo_teams) do
      add(:organization_id, references(:eo_organizations, type: :binary_id, on_delete: :restrict))
    end

    create index(:eo_teams, [:tenant_id, :organization_id])
  end

  def down do
    drop index(:eo_teams, [:tenant_id, :organization_id])
    alter table(:eo_teams), do: remove(:organization_id)
  end
end
