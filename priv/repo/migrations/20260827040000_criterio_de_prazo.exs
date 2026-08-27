defmodule TheBand.Repo.Migrations.CriterioDePrazo do
  @moduledoc """
  De onde vem o prazo de uma atividade — issue #368.

  ## O GitHub não tem campo de prazo na issue

  A sondagem achou **33 pares (quadro, campo) de data**, em 13 nomes e duas línguas:
  `End date` em 5 quadros, `Target date` em 4, mais `Deadline`, `Vencimento`, `Data Alvo`,
  `Fim`, `Data de Conclusao`. `End Date` e `End date` diferem só na caixa. E o mesmo nome
  significa fim planejado num quadro e fim real noutro.

  Adotar o primeiro campo de data que aparecer faria o mesmo número significar coisas
  diferentes conforme o quadro, e a medida de atraso herdaria a ambiguidade sem declará-la.

  ## Três origens, e elas NÃO se excluem

  Decisão da pessoa mantenedora em 2026-08-26: além do campo do quadro, o prazo pode vir
  do **sprint** ou do **marco**. E, nas palavras dela, *"se uma task está dentro do sprint,
  o prazo dela é do sprint E do milestone"* — as duas valem ao mesmo tempo.

  O dado concorda. Medido no mesmo dia, sobre 5.216 issues:

      com marco ..................... 1.580
      em alguma caixa de tempo ...... 1.689
      COM AS DUAS ...................   304
      com nenhuma das duas .......... 2.251   (43%)
      em MAIS DE UMA caixa de tempo .   640

  **304 issues têm as duas origens ao mesmo tempo, e 640 estão em mais de uma caixa** — e
  depois da #514 algumas dessas caixas são horizonte de planejamento, não sprint. Colapsar
  isso num único "o prazo" escolheria em silêncio qual das datas conta.

  Por isso a tabela permite **mais de um critério vigente por alvo**: o índice parcial é
  sobre (alvo, origem, campo), e não sobre o alvo. A leitura devolve todos os prazos
  aplicáveis com a proveniência junto.

  ## Ausência declarada

  Quadro sem critério nenhum não tem prazo zero: tem prazo **desconhecido**, e 43% das
  issues não alcançam origem alguma. "Este quadro não registra prazo" é resposta válida, e
  é preferível a um palpite — inventar produziria atraso onde não há.

  ## Revogar marca

  Como na 042 e na #514: índice parcial sobre os vigentes, para que revogar preserve o
  começo e redeclarar continue possível.
  """
  use Ecto.Migration

  def change do
    create table(:spo_activity_deadline_criteria, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # Exatamente um dos dois, como na 042: critério do quadro prevalece sobre o do
      # projeto, e um critério sem alvo valeria para tudo sem ninguém ter dito isso.
      add :project_id, references(:spo_projects, type: :uuid, on_delete: :delete_all)

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all)

      # `board_field`, `sprint` ou `milestone`. Sem enum no banco pelo mesmo motivo do
      # `event_type` da 042: origem nova não pode ser recusada como erro de escrita.
      add :source, :string, null: false

      # Só quando a origem é `board_field` — cru, como a origem nomeia o campo.
      add :field_name, :string

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:spo_activity_deadline_criteria, :prazo_tem_um_alvo_so,
             check: "(project_id IS NULL) <> (observed_project_id IS NULL)"
           )

    # `board_field` exige campo; `sprint` e `milestone` não têm campo nenhum a nomear, e
    # um `field_name` ali seria dado que ninguém lê e que diverge em silêncio.
    create constraint(:spo_activity_deadline_criteria, :campo_so_quando_a_origem_e_campo,
             check: "(source = 'board_field') = (field_name IS NOT NULL)"
           )

    # Sobre (alvo, origem, campo) — e NÃO sobre o alvo: sprint e marco valem juntos, e um
    # índice sobre o alvo faria declarar o segundo revogar o primeiro em silêncio.
    create unique_index(
             :spo_activity_deadline_criteria,
             [:tenant_id, :observed_project_id, :source, :field_name],
             where: "revoked_at IS NULL AND observed_project_id IS NOT NULL",
             name: :spo_prazo_vigente_do_quadro_index,
             nulls_distinct: false
           )

    create unique_index(
             :spo_activity_deadline_criteria,
             [:tenant_id, :project_id, :source, :field_name],
             where: "revoked_at IS NULL AND project_id IS NOT NULL",
             name: :spo_prazo_vigente_do_projeto_index,
             nulls_distinct: false
           )
  end
end
