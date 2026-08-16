defmodule TheBand.Repo.Migrations.FutureSprintsBecomeIntended do
  @moduledoc """
  Os 26 sprints que nunca aconteceram viram processos pretendidos — sprint 017.

  A feature 024 gravou **toda** iteração como `sro.sprint`, inclusive as futuras — e a
  FR-030 e a SC-009 dizem o contrário: iteração cujo início não chegou é planejamento
  que não foi feito, `spo.specific_intended_project_process`. Medido em 2026-08-16:
  26 dos 220 sprints tinham início no futuro, com 24 vínculos de issue pendurados.

  A correção **move a afirmação para o conceito certo**: cada sprint futuro vira um
  processo pretendido com a mesma Application Reference, e a linha errada sai — junto
  dos vínculos, que afirmavam composição de sprint backlog de um sprint que não
  ocorreu. Sair é aceitável aqui, e só aqui, porque estas tabelas são **derivadas** e
  reproduzíveis da fonte: a coleta seguinte reconstrói o que for verdade. O gate de
  derivação reproduzível existe exatamente para isso.

  `down` é no-op: desfazer recriaria a afirmação errada.
  """

  use Ecto.Migration

  def up do
    execute """
    INSERT INTO spo_intended_project_processes
      (id, tenant_id, internal_id, record_version, title, planned_start_on, duration_days,
       source_system, source_instance, source_external_id, collected_at, last_observed_at,
       inserted_at, updated_at)
    SELECT gen_random_uuid(), s.tenant_id, s.internal_id, 1, s.title, s.started_on,
           s.duration_days, s.source_system, s.source_instance, s.source_external_id,
           s.inserted_at, s.updated_at, now(), now()
    FROM sro_sprints s
    WHERE s.started_on > current_date
    ON CONFLICT DO NOTHING
    """

    # Os vínculos caem por cascade (`on_delete: :delete_all` na FK de sprint_id).
    execute "DELETE FROM sro_sprints WHERE started_on > current_date"
  end

  def down, do: :ok
end
