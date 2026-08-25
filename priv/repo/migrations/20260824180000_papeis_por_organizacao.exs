defmodule TheBand.Repo.Migrations.PapeisPorOrganizacao do
  @moduledoc """
  O papel passa a ser da organização — issue #317.

  ## A cadeia que esta migração destrava

  Medido em 2026-08-24: **12 equipes, 101 evidências de vínculo, 0 vínculos, 0 papéis**. E
  `eo_team_memberships.organizational_role_id` é `NOT NULL`.

  A cadeia estava parada no primeiro elo: sem papel cadastrado, nenhuma evidência vira
  vínculo, e as equipes ficam vazias. Consequência — quatro das cinco medidas declaram
  `team`, e nenhuma calculava.

  ## Por que `organization_id` nasce obrigatória

  A equipe já tem `organization_id`; o papel não tinha. Um papel cadastrado vazaria para as
  três organizações do tenant, que não compartilham vocabulário nenhum — é a mesma classe do
  defeito de escopo da issue #446, onde filtrar por tenant no lugar de organização fez a
  coleta percorrer 480 repositórios em vez de 160.

  Nulo significaria "papel de todo o tenant", que é exatamente o comportamento a corrigir.
  Manter a opção manteria o defeito disponível.

  **E há zero linhas para migrar.** É a única janela em que `NOT NULL` sai de graça; em
  qualquer momento futuro custaria decidir o que fazer com as linhas existentes.

  ## O índice era o bloqueio, e não uma melhoria

  `UNIQUE (tenant_id, code)` impedia o catálogo em todas as organizações: a **segunda**
  organização a materializar `scrum_master` bateria na constraint.

  Perde-se a garantia de que um código é único no tenant. É deliberado — dois papéis de mesmo
  código em organizações diferentes **são papéis diferentes**.

  ## Uma origem só, e a `CHECK` que a garante

  `catalog_concept_id` preenchido significa que o papel veio da rede — `sro.scrum_master_role`
  e os outros três filhos de `sro.scrum_role`. `declared_by_user_id` preenchido significa que
  alguém o escreveu na tela.

  Exatamente um dos dois. Sem a `CHECK`, um papel poderia afirmar as duas origens, e a tela
  não teria o que mostrar como proveniência.

  É a mesma forma do `catalog_key` nulável em `issue_mapping_rules`, que já distingue regra
  de catálogo de regra escrita à mão.
  """
  use Ecto.Migration

  def up do
    alter table(:eo_organizational_roles) do
      # Sem `default`: as linhas existentes são zero, e um default sobreviveria à migração
      # convidando linhas futuras a herdarem organização errada.
      add :organization_id, references(:eo_organizations, type: :uuid, on_delete: :delete_all),
        null: false

      # `sro.product_owner_role` e afins. Nulo = declarado por pessoa.
      add :catalog_concept_id, :string
      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :updated_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      # Ocultar de uma organização. Ocultar NÃO é apagar: papel do catálogo vem da rede, e
      # vínculos que já o usam continuam válidos.
      add :hidden_at, :utc_datetime
    end

    # O índice antigo impedia o catálogo em todas as organizações.
    drop unique_index(:eo_organizational_roles, [:tenant_id, :code])

    create unique_index(:eo_organizational_roles, [:tenant_id, :organization_id, :code],
             name: :eo_organizational_roles_por_organizacao_index
           )

    create index(:eo_organizational_roles, [:tenant_id, :organization_id, :catalog_concept_id],
             name: :eo_organizational_roles_catalogo_index
           )

    create constraint(:eo_organizational_roles, :papel_tem_uma_origem_so,
             check: "num_nonnulls(catalog_concept_id, declared_by_user_id) = 1"
           )
  end

  def down do
    drop constraint(:eo_organizational_roles, :papel_tem_uma_origem_so)

    drop index(:eo_organizational_roles, [:tenant_id, :organization_id, :catalog_concept_id],
           name: :eo_organizational_roles_catalogo_index
         )

    drop unique_index(:eo_organizational_roles, [:tenant_id, :organization_id, :code],
           name: :eo_organizational_roles_por_organizacao_index
         )

    create unique_index(:eo_organizational_roles, [:tenant_id, :code])

    alter table(:eo_organizational_roles) do
      remove :hidden_at
      remove :updated_by_user_id
      remove :declared_by_user_id
      remove :catalog_concept_id
      remove :organization_id
    end
  end
end
