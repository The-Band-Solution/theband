defmodule TheBand.Repo.Migrations.AllowEvidenceWithoutAccessLevel do
  @moduledoc """
  `platform_access_level` passa a ser anulável, exigida só quando a origem a fornece
  (T008, FR-006).

  ## O que muda, e por quê

  Hoje a coluna é `NOT NULL` com `check` restringindo a `MAINTAINER` ou `MEMBER`. Isso
  vale para vínculo observado no GitHub, onde o nível vem no payload. Não vale para a
  **equipe derivada**: ela não existe na ferramenta de origem, então o vínculo entre a
  pessoa e ela também não — e a origem não tem nível de acesso a informar sobre um
  vínculo que ela não conhece.

  Gravar `MEMBER` para preencher inventaria dado. `MEMBER` significa "observado como
  membro comum no GitHub", e usá-lo para "não há nível porque não há vínculo na origem"
  faria as duas coisas ficarem indistinguíveis em qualquer consulta futura. **Ausência
  é nula** (research.md R2).

  ## A obrigatoriedade não desaparece, fica condicional

      platform_access_level IS NOT NULL OR source_system <> 'github'

  Vínculo do GitHub sem nível continua recusado **pelo banco**: se a coleta deixar de
  ler o campo, ou um mapeamento errar o caminho, a gravação falha em vez de produzir
  nulo silencioso. É a mesma razão de a restrição anterior existir — o que muda é que
  ela passa a valer onde faz sentido.

  A restrição de valores permanece, e agora admite nulo: nível preenchido continua
  tendo de ser `MAINTAINER` ou `MEMBER`, e não qualquer string.

  ## Por que `source_system` e não uma coluna nova

  Um `derived: boolean` diria a mesma coisa duas vezes e permitiria discordar de si
  mesmo — vínculo com `source_system = 'the_band'` e `derived = false`. O sistema de
  origem já responde de onde o registro veio, e a proveniência é obrigatória em toda
  linha da base.
  """
  use Ecto.Migration

  def up do
    drop constraint(:eo_team_membership_evidence, "eo_evidence_access_level_check")

    alter table(:eo_team_membership_evidence) do
      modify(:platform_access_level, :string, null: true)
    end

    create constraint(
             :eo_team_membership_evidence,
             :eo_evidence_access_level_check,
             check:
               "platform_access_level IS NULL OR platform_access_level IN ('MAINTAINER', 'MEMBER')"
           )

    create constraint(
             :eo_team_membership_evidence,
             :eo_evidence_github_has_access_level,
             check: "platform_access_level IS NOT NULL OR source_system <> 'github'"
           )
  end

  def down do
    drop constraint(:eo_team_membership_evidence, :eo_evidence_github_has_access_level)
    drop constraint(:eo_team_membership_evidence, :eo_evidence_access_level_check)

    alter table(:eo_team_membership_evidence) do
      modify(:platform_access_level, :string, null: false)
    end

    create constraint(
             :eo_team_membership_evidence,
             :eo_evidence_access_level_check,
             check: "platform_access_level IN ('MAINTAINER', 'MEMBER')"
           )
  end
end
