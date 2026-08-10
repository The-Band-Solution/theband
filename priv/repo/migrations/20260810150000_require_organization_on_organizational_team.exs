defmodule TheBand.Repo.Migrations.RequireOrganizationOnOrganizationalTeam do
  @moduledoc """
  A restrição que o derivador pediu, aplicada depois do retrofito (T007 e T011).

      check: organization_id IS NOT NULL OR type <> 'organizational_team'

  ## Por que está separada da criação da coluna

  A T007 mandava criar coluna e restrição juntos, e não é possível num banco
  povoado: as equipes já coletadas eram todas `organizational_team` sem organização,
  e o Postgres recusou com `ERROR 23514 (check_violation)`. O retrofito que preenche
  a coluna é a T011, de outra fase.

  A separação virou vantagem. **Esta migração é a verificação do retrofito**: se
  qualquer equipe organizacional ficar sem organização, ela se recusa a aplicar, e a
  falha aparece onde alguém a vê em vez de virar linha inválida tolerada.

  Estado ao aplicar, medido em 2026-08-10:

      organizacao       | equipes
      ------------------+--------
      leds-conectafapes |       8
      The-Band-Solution |       2

      equipes sem organização: 0

  ## O que a restrição admite, de propósito

  `project_team` sem organização continua válida. A relação parte de
  `eo.organizational_team`, e equipe de projeto entre organizações não pertence a uma
  só — obrigar a coluna para todo subtipo afirmaria o contrário.

  Isso é o que separa esta restrição de um `NOT NULL`: a obrigatoriedade é do
  subtipo, e o discriminador é quem diz qual subtipo a linha é.
  """
  use Ecto.Migration

  def up do
    create constraint(
             :eo_teams,
             :eo_teams_organizational_team_has_organization,
             check: "organization_id IS NOT NULL OR type <> 'organizational_team'"
           )
  end

  def down do
    drop constraint(:eo_teams, :eo_teams_organizational_team_has_organization)
  end
end
