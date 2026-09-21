defmodule TheBand.Repo.Migrations.AsChavesEstrangeirasQueFaltavam do
  @moduledoc """
  Três colunas que apontam para outra tabela e não diziam isso ao banco.

  Achadas ao derivar o modelo de dados em 2026-09-18, comparando as 93 migrações com os 65
  schemas: **63 das 66 tabelas de domínio declaram a chave de `tenant_id`**, e as exceções não
  tinham explicação escrita em migração nenhuma.

  ## `access_scope_grants.tenant_id` e `account_disablements.tenant_id`

  São as duas tabelas de **acesso** — justamente onde um tenant errado custa mais caro. A
  leitura de que seria deliberado não se sustenta: `user_id`, **na mesma tabela e na mesma
  migração**, é declarada. Inconsistência interna na mesma linha de código é descuido, não
  intenção.

  O efeito até aqui era que o banco não impedia uma concessão apontando para tenant
  inexistente. Quem impedia era a aplicação, em `Access.grant/5` — e uma guarda só na aplicação
  é uma guarda que o próximo caminho de escrita não herda.

  ## `spo_performed_project_activities.project_id`

  Nesta a explicação existe e torna a correção segura: `spo_projects` **nasceu um dia depois**
  (`20260815160000`) da migração que criou a coluna (`20260814160000`). Não dava para
  referenciar o que não existia.

  A intenção estava escrita: o comentário daquela migração trata `organization_id` e
  `project_id` **juntos** — *"estão no critério de identidade e aceitam nulo"* — e logo abaixo
  declara uma e não a outra. Esta migração acrescenta o que a ordem impediu.

  ## A regra de exclusão sai do que a casa já faz, e da nulidade da coluna

  **`tenant_id` recebe `:restrict`**, que é o que **61 das 65** chaves de `tenant_id` já usam.
  E não é só seguir a maioria: a coluna é `NOT NULL` nas duas tabelas. `:nilify_all` ali
  falharia na hora de apagar um tenant, com violação de nulo em vez de recusa limpa — um erro
  de banco no lugar de uma regra de negócio.

  **`project_id` recebe `:nilify_all`**, e a diferença é a nulidade: a coluna **aceita nulo** de
  propósito, porque *"nem toda origem futura conhece organização ou projeto"*. É a mesma regra
  que `organization_id`, a irmã declarada na mesma linha de código.

  Apagar o alvo **não pode apagar a ocorrência de atividade** — a ontologia é explícita:
  *"uma atividade removida apagaria o rastro que ela existe para guardar"*. Nulo é ausência
  escrita; a linha some é história perdida.

  ## Conferido antes

  Zero órfãos nas três, medido em 2026-09-18: 0 de 0 linhas nas duas de acesso, e 0 de 46 359
  na de atividades. Sem isso a migração falharia no meio.
  """
  use Ecto.Migration

  def up do
    alter table(:access_scope_grants) do
      modify :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), from: :binary_id
    end

    alter table(:account_disablements) do
      modify :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), from: :binary_id
    end

    alter table(:spo_performed_project_activities) do
      modify :project_id, references(:spo_projects, type: :uuid, on_delete: :nilify_all),
        from: :binary_id
    end
  end

  def down do
    alter table(:spo_performed_project_activities) do
      modify :project_id, :binary_id,
        from: references(:spo_projects, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:account_disablements) do
      modify :tenant_id, :binary_id, from: references(:tenants, type: :uuid, on_delete: :restrict)
    end

    alter table(:access_scope_grants) do
      modify :tenant_id, :binary_id, from: references(:tenants, type: :uuid, on_delete: :restrict)
    end
  end
end
