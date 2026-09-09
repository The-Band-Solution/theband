defmodule TheBand.Repo.Migrations.VinculoObservado do
  @moduledoc """
  O vínculo OBSERVADO — decisão da pessoa mantenedora em 2026-09-06 (specs 055 e 058, emenda).

  ## O que a medida mostrou

  A coleta trazia as 8 equipes do GitHub da `leds-conectafapes` com 59 evidências de vínculo
  (49 pessoas), batendo com a origem. Pela regra da 055, evidência não era vínculo até alguém
  confirmar com papel; ninguém confirmou; as 8 equipes tinham ZERO vínculos vigentes, toda
  medida por equipe saía vazia, e 838 das 1 077 solicitações dos últimos 56 dias (78%) eram
  de autores só com evidência pendente — fora de toda medida por equipe.

  ## O que muda

  A participação observada na ferramenta vira `eo.team_membership` na coleta, como vínculo
  **observado**: `declared_by_user_id` nulo, `organizational_role_id` NULO ("papel não
  declarado"), `started_at` nulo (desconhecido). Quem administra declara o papel depois. O
  relator da ontologia exige pessoa, equipe e papel; a plataforma passa a materializá-lo com
  o papel declaradamente ausente, porque a participação é fato e a medida por equipe é
  impossível sem ela.

  ## O que esta migração faz

  1. `organizational_role_id` passa a aceitar nulo. A validação "declarado exige papel" fica
     no changeset, onde a razão pode ser dita.
  2. Um índice único parcial para o vínculo observado vigente: uma pessoa, uma equipe, um
     vínculo sem papel por vez. O índice existente (`..._vigente_index`) inclui o papel, e
     nulos não colidem em índice único — sem este, a coleta duplicaria.
  3. Promove as evidências vivas ainda não promovidas a vínculos observados, e as aponta.
     `internal_id` determinístico (`observed_<id da evidência>`) para o reprocessamento
     reconhecer em vez de duplicar.
  """
  use Ecto.Migration

  def up do
    alter table(:eo_team_memberships) do
      modify :organizational_role_id, :binary_id, null: true
    end

    create unique_index(
             :eo_team_memberships,
             [:tenant_id, :person_id, :team_id],
             where:
               "ended_at IS NULL AND invalidated_at IS NULL AND organizational_role_id IS NULL",
             name: :eo_team_memberships_observado_vigente_index
           )

    flush()

    # As evidências vivas sem vínculo viram vínculos observados. Uma por (pessoa, equipe): a
    # mesma pessoa pode ter mais de uma evidência viva na mesma equipe só por defeito de dado,
    # e o índice acima recusaria a segunda — `ON CONFLICT DO NOTHING` deixa a primeira.
    execute """
    INSERT INTO eo_team_memberships
      (id, tenant_id, internal_id, record_version, person_id, team_id, organizational_role_id,
       started_at, ended_at, declared_by_user_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), e.tenant_id, 'observed_' || e.id, 1, e.person_id, e.team_id, NULL,
           NULL, NULL, NULL, now(), now()
    FROM eo_team_membership_evidence e
    WHERE e.promoted_membership_id IS NULL
      AND e.no_longer_observed_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM eo_team_memberships m
        WHERE m.tenant_id = e.tenant_id AND m.person_id = e.person_id AND m.team_id = e.team_id
          AND m.ended_at IS NULL AND m.invalidated_at IS NULL
      )
    ON CONFLICT DO NOTHING
    """

    # A evidência aponta para o vínculo que a materializou — o mesmo que `promote_evidence`
    # faz na tela, e o que `pending_evidence` lê para saber o que ainda espera papel.
    execute """
    UPDATE eo_team_membership_evidence e
    SET promoted_membership_id = m.id, updated_at = now()
    FROM eo_team_memberships m
    WHERE e.promoted_membership_id IS NULL
      AND e.no_longer_observed_at IS NULL
      AND m.tenant_id = e.tenant_id AND m.person_id = e.person_id AND m.team_id = e.team_id
      AND m.ended_at IS NULL AND m.invalidated_at IS NULL
    """
  end

  def down do
    # Só o que esta migração criou: os vínculos observados que continuam sem papel e sem
    # autor. Os que ganharam papel depois viraram declaração, e declaração não se desfaz
    # por migração.
    execute """
    UPDATE eo_team_membership_evidence e SET promoted_membership_id = NULL
    FROM eo_team_memberships m
    WHERE e.promoted_membership_id = m.id AND m.internal_id LIKE 'observed_%'
      AND m.organizational_role_id IS NULL AND m.declared_by_user_id IS NULL
    """

    execute """
    DELETE FROM eo_team_memberships
    WHERE internal_id LIKE 'observed_%' AND organizational_role_id IS NULL
      AND declared_by_user_id IS NULL
    """

    drop index(:eo_team_memberships, [:tenant_id, :person_id, :team_id],
           name: :eo_team_memberships_observado_vigente_index
         )

    alter table(:eo_team_memberships) do
      modify :organizational_role_id, :binary_id, null: false
    end
  end
end
