defmodule TheBand.Repo.Migrations.RevogacaoPorSuspensao do
  @moduledoc """
  A revogação de token pela suspensão da organização — spec 070, T047 (`data-model.md` §6; FR-013,
  O12).

  Migração **de `Tenants`**, porque `api_access_tokens` é de `Tenants` (achado L1): a `Platform` não
  altera tabela alheia. A FK para `tenant_suspensions` é a segunda exceção declarada à letra D do
  princípio X, só no banco (`plan.md`, Constitution Check). É integridade referencial, e não leitura:
  `Tenants` recebe o id do episódio por argumento.

  Os dois `CHECK`s juntos dizem que a cláusula `organizacao_suspensa` existe **se e só se** há um
  episódio apontado. As linhas antigas, com cláusula e suspensão nulas, passam pelos dois.
  """
  use Ecto.Migration

  def change do
    alter table(:api_access_tokens) do
      add :revoked_by_suspension_id,
          references(:tenant_suspensions, type: :binary_id, on_delete: :restrict)
    end

    create constraint(:api_access_tokens, :api_access_tokens_suspensao_tem_clausula,
             check:
               "revoked_by_suspension_id IS NULL OR revocation_clause = 'organizacao_suspensa'"
           )

    create constraint(:api_access_tokens, :api_access_tokens_clausula_tem_suspensao,
             check:
               "revocation_clause IS DISTINCT FROM 'organizacao_suspensa' OR " <>
                 "revoked_by_suspension_id IS NOT NULL"
           )
  end
end
