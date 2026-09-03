defmodule TheBand.Repo.Migrations.ComposicaoDeEquipesEOEquivoco do
  @moduledoc """
  Equipe dentro de equipe, e o vínculo que nunca vigeu — feature 055.

  ## Duas coisas, e a segunda é a que decide o desenho

  A composição é estrutura nova. O **equívoco** é o que separa *sair* de *ser
  apagado*, e é o requisito mais caro desta feature: o SC-003 exige que um painel
  de período anterior a uma saída mostre **exatamente o mesmo número** antes e
  depois. Uma linha removida muda todos os números de todos os períodos.

  ## Por que a composição é tabela, e não `parent_team_id` em `eo_teams`

  Uma coluna não carrega **quem declarou** nem **quando** — é a versão booleana do
  relator, o antipadrão nomeado em `AGENTS.md` §7.7. E amarra a uma composição por
  equipe, quando a estrutura real não é árvore: a mesma célula pode compor duas
  frentes ao mesmo tempo, e `eo.team_part_of_team` declara cardinalidade
  muitos-para-muitos justamente por isso.

  ## Por que três colunas para o equívoco, e não `ended_at = started_at`

  "Durou zero" e "nunca existiu" são fatos diferentes sobre a organização, e a
  diferença entre eles é **a razão** — que `ended_at = started_at` não guarda. Sem
  a razão, um engano registrado no mesmo dia da entrada fica indistinguível de
  alguém que entrou e saiu no mesmo dia.

  ## O que estas colunas custam

  **Vigente passa a ser `ended_at` nulo E `invalidated_at` nulo.** Toda consulta
  de vínculo vigente ganha a segunda condição, e ela reaparece em cada consulta
  nova. É o custo declarado da decisão 2 do `plan.md`, e a tarefa T008 existe para
  varrer o que já estava escrito com uma condição só.

  ## Nenhuma linha é removida

  Não há `on_delete: :delete_all` para as equipes aqui: `restrict`. Apagar equipe
  que tem composição levaria embora o registro de que a estrutura existiu — e o
  que se audita é justamente quando ela mudou.
  """
  use Ecto.Migration

  def change do
    create table(:eo_team_compositions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # A equipe que FAZ PARTE, e a que CONTÉM. Os dois lados com `restrict` pelo
      # motivo do moduledoc: a composição é registro de estrutura, não ponteiro.
      add :part_team_id, references(:eo_teams, type: :uuid, on_delete: :restrict), null: false
      add :whole_team_id, references(:eo_teams, type: :uuid, on_delete: :restrict), null: false

      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :restrict), null: false
      add :ended_by_user_id, references(:users, type: :uuid, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    # A mesma composição não vigora duas vezes. Índice, e não consulta prévia: a
    # consulta prévia perde a corrida entre duas abas — foi o que a 052 provou.
    create unique_index(
             :eo_team_compositions,
             [:tenant_id, :part_team_id, :whole_team_id],
             where: "ended_at IS NULL",
             name: :eo_composicao_vigente_de_equipe_index
           )

    create index(:eo_team_compositions, [:tenant_id, :whole_team_id])
    create index(:eo_team_compositions, [:tenant_id, :part_team_id])

    # O ciclo NÃO é impedido aqui. Índice não vê caminho, e a recusa é da
    # aplicação — está dito na relação da ontologia e no contrato da feature.

    alter table(:eo_team_memberships) do
      add :invalidated_at, :utc_datetime
      add :invalidated_by_user_id, references(:users, type: :uuid, on_delete: :restrict)
      add :invalidation_reason, :text
    end

    # O ÍNDICE DE VIGÊNCIA TAMBÉM PRECISA CONHECER A INVALIDAÇÃO.
    #
    # `eo_team_memberships_vigente_index` nasceu em 2026-08-14 com
    # `where: "ended_at IS NULL"`. Sem o segundo termo, um vínculo invalidado
    # continuaria ocupando a vaga única — e **vincular de novo depois de corrigir
    # um engano seria recusado pelo banco**, deixando quem errou sem saída.
    #
    # É o custo da decisão 2 do plano aparecendo onde ninguém procuraria: a
    # segunda condição de "vigente" não vive só nas consultas, vive no índice.
    drop index(:eo_team_memberships, [:tenant_id, :person_id, :team_id, :organizational_role_id],
           name: :eo_team_memberships_vigente_index
         )

    create unique_index(
             :eo_team_memberships,
             [:tenant_id, :person_id, :team_id, :organizational_role_id],
             where: "ended_at IS NULL AND invalidated_at IS NULL",
             name: :eo_team_memberships_vigente_index
           )

    # O trio anda junto: ou os três nulos, ou os três preenchidos. Um equívoco sem
    # autor ou sem razão é a metade do registro que não serve para nada depois.
    create constraint(
             :eo_team_memberships,
             :eo_equivoco_do_vinculo_completo,
             check: """
             (invalidated_at IS NULL AND invalidated_by_user_id IS NULL AND invalidation_reason IS NULL)
             OR
             (invalidated_at IS NOT NULL AND invalidated_by_user_id IS NOT NULL AND invalidation_reason IS NOT NULL)
             """
           )
  end
end
