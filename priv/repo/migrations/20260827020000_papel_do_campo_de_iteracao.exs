defmodule TheBand.Repo.Migrations.PapelDoCampoDeIteracao do
  @moduledoc """
  A organização declara o que cada campo de iteração significa — issue #514.

  ## O que a coleta fazia sozinha

  `sro_sprints` promovia TODO campo de iteração do Projects v2 a `sro.sprint`. Medido em
  2026-08-26, o par (quadro, campo) mostra que são coisas diferentes:

      DevOps                     Quarter      6 iterações   86 dias de média
      Conecta Fapes - Delivery   Quarter      6 iterações   86 dias
      Zeppelin                   Iteration    4 iterações   14 dias
      [DEPRECATED] ConectaFapes  Sprint      15 iterações   14 dias

  **669 vínculos de issue em 2.685 — 25% — apontam para trimestre lido como sprint.**

  ## Por que a plataforma não escolhe pelo nome

  `Quarter` parece trimestre e `Sprint` parece sprint — mas classificar por padrão de nome
  publicaria a suposição como medida, e o erro cai para o lado barato: o não reconhecido
  alguém corrige, o reconhecido errado vira número. A `FR-007` da feature 022 proíbe a
  plataforma escolher; a 042 seguiu essa regra para o critério de início, e esta tabela é
  a mesma decisão para o papel do campo.

  A tela mostra o **volume e a duração média** de cada campo — informar é diferente de
  recomendar — e a organização declara.

  ## Por quadro E por campo

  O mesmo nome de campo pode significar coisas diferentes em quadros diferentes, e o
  mesmo quadro tem `Sprint` e `Quarter` ao mesmo tempo: os seis quadros com trimestre
  também têm sprint. Declarar por nome de campo, sem o quadro, decidiria por quadros que
  ninguém olhou.

  ## Revogar marca

  A pergunta "desde quando este campo era horizonte" só tem resposta se o encerramento
  preservar o começo. Índice parcial sobre os vigentes, como na 042 — total impediria
  redeclarar depois de revogar.
  """
  use Ecto.Migration

  def change do
    create table(:smpo_iteration_field_roles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all),
          null: false

      # Cru, como a origem nomeia — `Sprint`, `Quarter`, `Iteration`, e o que vier.
      add :field_name, :string, null: false

      # `sprint` ou `planning_horizon`. Sem enum no banco pelo mesmo motivo do
      # `event_type` da 042: papel novo não pode ser recusado como erro.
      add :role, :string, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :smpo_iteration_field_roles,
             [:tenant_id, :observed_project_id, :field_name],
             where: "revoked_at IS NULL",
             name: :smpo_papel_vigente_do_campo_index
           )
  end
end
