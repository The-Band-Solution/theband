defmodule TheBand.Repo.Migrations.ConcessaoDeVisibilidade do
  @moduledoc """
  Que papel confere ver o painel de trabalho de quem — issue #369.

  ## O que vigorava, e vigorava por omissão

  `specs/023-painel-da-pessoa/spec.md` trazia `[NEEDS CLARIFICATION]` desde 2026-08-14.
  Enquanto ninguém decidia, a regra era a do roteador: `require_user` e nada além —
  **toda pessoa autenticada via o painel de qualquer outra do tenant**. Era a terceira
  opção da pergunta, escolhida sem que ninguém a escolhesse.

  Decisão da pessoa mantenedora em 2026-08-26: **a própria pessoa, o líder da equipe dela,
  e o responsável da organização.** E, no mesmo dia: os papéis de liderança são
  `Tech Leader` e `Team Leader`.

  ## Por que uma concessão declarada, e não o nome do papel

  `Tech Leader` parece liderança. `Coordenador` também. E a mesma organização pode ter um
  `Tech Lead` que é senioridade técnica e não chefia ninguém.

  Classificar por nome já é proibido nesta base — foi o que a #514 e a #368 estabeleceram
  —, e aqui o erro é mais caro que nas outras: **excesso de visibilidade concedido ninguém
  reclama.** Quem recebe acesso a mais não abre chamado, e o defeito fica.

  Papel também é renomeável: `rename_role/4` existe e é usado. Casar por string faria a
  visibilidade mudar sozinha no dia em que alguém corrigisse um acento.

  ## Dois escopos, e não um booleano

  `team` — vê quem está nas equipes em que essa pessoa tem o papel.
  `organization` — vê quem está na organização.

  Não é um `is_leader` booleano pelo motivo de sempre nesta base: um booleano perde **quem
  concedeu e quando**, e numa decisão de visibilidade essa é a pergunta que mais se faz
  depois. É relator, e não atributo.

  ## Revogar marca

  Índice parcial sobre as vigentes. "Desde quando esse papel via o time" só tem resposta se
  o encerramento preservar o começo — e retirar acesso é justamente o que se audita.
  """
  use Ecto.Migration

  def change do
    create table(:eo_role_visibility_grants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :organizational_role_id,
          references(:eo_organizational_roles, type: :uuid, on_delete: :delete_all),
          null: false

      # `team` ou `organization`. Sem enum no banco pelo mesmo motivo das irmãs desta base:
      # escopo novo não pode ser recusado como erro de escrita.
      add :scope, :string, null: false

      # Quem concedeu NUNCA é nulo, e `restrict` em vez de `nilify_all`: concessão de
      # visibilidade sem autor é a que mais precisa de autor, e apagá-lo quando a pessoa
      # usuária sai levaria embora exatamente o rastro que a auditoria procura.
      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :restrict), null: false

      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :restrict)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :eo_role_visibility_grants,
             [:tenant_id, :organizational_role_id, :scope],
             where: "revoked_at IS NULL",
             name: :eo_concessao_vigente_do_papel_index
           )
  end
end
