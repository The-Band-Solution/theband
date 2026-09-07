defmodule TheBand.Repo.Migrations.ConcessaoDeGestaoDaEstrutura do
  @moduledoc """
  Que papel confere **gerir a estrutura** de uma equipe — spec 060, FR-080 a FR-082.

  ## O que vigorava, e o que ele custou

  `Tenants.Access.pode_declarar_estrutura/4` autorizava a conta **administradora** ou a conta
  com escopo `organization`/`project`. Na prática, só a administradora: escopo de conta é
  concedido para **ver**, e quase ninguém o tem.

  Medido em 2026-09-06, na organização `leds-conectafapes`: 59 participações observadas nos
  times do GitHub e **nenhum papel declarado**. A estrutura não era mantida porque quem a
  conhece — quem coordena a equipe — não podia declará-la.

  Decisão da pessoa mantenedora em 2026-09-07: administrador **e** um papel de gestor da
  equipe, por concessão. Lista fechada; não há terceiro caminho.

  ## Por que irmã, e não uma coluna na tabela de visibilidade

  `eo_role_visibility_grants` confere **ver**. A spec 045 (FR-022) separa ver de mexer de
  propósito, e uma coluna `kind` numa tabela chamada *visibility* faria caber ali o que não é
  visibilidade — além de obrigar o índice parcial vigente a mudar de forma.

  As duas nascem declaradas juntas na base (`eo/modules/role_grants.yaml`): a de visibilidade
  existia no código desde 2026-08-27 **sem conceito na base**, e declarar as duas de uma vez
  fecha a lacuna em vez de dobrá-la.

  ## Por que do PAPEL, e nunca da conta

  Pelo mesmo motivo da irmã: papel é o que a organização reconhece, e a pessoa alcança pelo
  vínculo **vigente** com ele. Concedida à conta, a permissão sobreviveria à troca de papel
  da pessoa — e ninguém notaria.

  E nunca por **nome**: `Tech Lead` parece liderança e pode ser senioridade técnica. Aqui o
  erro é mais caro que na visibilidade — excesso de visibilidade concedido ninguém reclama;
  excesso de gestão concedido **reescreve a estrutura** de quem não deveria.

  ## Revogar marca

  Índice parcial sobre as vigentes, como na irmã. "Desde quando esse papel geria a equipe"
  só tem resposta se o encerramento preservar o começo — e retirar poder de escrita é
  exatamente o que se audita.
  """
  use Ecto.Migration

  def change do
    create table(:eo_role_structure_management_grants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :organizational_role_id,
          references(:eo_organizational_roles, type: :uuid, on_delete: :delete_all),
          null: false

      # `team` ou `organization`. Sem enum no banco, como nas irmãs: escopo novo não pode ser
      # recusado como erro de escrita.
      add :scope, :string, null: false

      # Quem concedeu NUNCA é nulo, e `restrict` em vez de `nilify_all`: concessão de gestão
      # sem autor é a que mais precisa de autor, e apagá-lo quando a pessoa usuária sai
      # levaria embora exatamente o rastro que a auditoria procura.
      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :restrict), null: false

      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :restrict)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :eo_role_structure_management_grants,
             [:tenant_id, :organizational_role_id, :scope],
             where: "revoked_at IS NULL",
             name: :eo_concessao_de_gestao_vigente_index
           )
  end
end
