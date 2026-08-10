defmodule TheBand.Repo.Migrations.ScopeConnectedToolUniquenessByOrganization do
  @moduledoc """
  A organização observada entra na chave de unicidade.

  A restrição anterior era `(tenant_id, tool_type, instance_url)`, de quando
  `organization_login` ainda não existia. O efeito era que uma organização cliente
  conseguia registrar **um único** `https://github.com` — e portanto observar uma
  única organização. O domínio não pede esse limite: uma empresa costuma ter mais
  de uma organização na mesma instância.

  `NULLS NOT DISTINCT` é necessário porque `organization_login` é anulável, para
  ferramentas futuras que não tenham esse conceito. Sem ele o Postgres trataria
  cada `NULL` como distinto, e a mesma ferramenta sem organização poderia ser
  cadastrada várias vezes — exatamente a duplicata que a restrição existe para
  impedir.

  Contrato: `specs/001-github-eo-ingestion/contracts/connected-tools.md`.
  """

  use Ecto.Migration

  def up do
    drop unique_index(:connected_tools, [:tenant_id, :tool_type, :instance_url])

    create unique_index(
             :connected_tools,
             [:tenant_id, :tool_type, :instance_url, :organization_login],
             name: :connected_tools_identity_index,
             nulls_distinct: false
           )
  end

  def down do
    drop unique_index(
           :connected_tools,
           [:tenant_id, :tool_type, :instance_url, :organization_login],
           name: :connected_tools_identity_index
         )

    create unique_index(:connected_tools, [:tenant_id, :tool_type, :instance_url])
  end
end
