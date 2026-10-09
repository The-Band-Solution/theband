defmodule TheBand.Repo.Migrations.BackfillIssueAccountTypes do
  @moduledoc """
  Preenche o tipo da conta das issues já coletadas a partir do payload bruto — feature 076, T022
  (`specs/076-analise-de-rede/data-model.md` §3; research.md R13).

  ## De onde vem o tipo

  Do payload bruto **mais recente** de cada issue em `raw_payloads` (`raw_entity_type =
  'github.issue'`), casado por **`tenant_id`, `source_instance` e `external_id` juntos**: o mesmo
  `external_id` pode existir em dois tenants (dois tenants observando a mesma organização), e o
  payload de um nunca decide o tipo do outro. Os responsáveis casam pelo `login` dentro do payload
  da mesma issue.

  A regra é a de `Mapper.account_type/1`, escrita em SQL porque a migração não chama código da
  aplicação (o código muda; a migração tem de dar o mesmo resultado para sempre): `Bot` → `bot`,
  `App` → `app`, login com sufixo `[bot]` → `bot`, o resto → `person`. O teste da T022 confere as
  duas contra os mesmos nós.

  ## O que fica nulo

  A linha sem payload, e o autor apagado na origem (`author` nulo): nulo é *"não se sabe"*, e a
  leitura conta quantas classificou assim (`provenance.account_type_unknown`).

  `down/0` explícito: anula as duas colunas. Não apaga nada que a coleta tenha gravado **antes**
  desta migração, porque antes dela as colunas não existiam.
  """
  use Ecto.Migration

  # A regra de `Mapper.account_type/1`, sobre um nó jsonb.
  @tipo """
  case
    when NO->>'__typename' = 'Bot' then 'bot'
    when NO->>'__typename' = 'App' then 'app'
    when NO->>'login' like '%[bot]' then 'bot'
    else 'person'
  end
  """

  # O payload mais recente de cada issue, por tenant, instância e id da origem.
  @recentes """
  select distinct on (tenant_id, source_instance, external_id)
         tenant_id, source_instance, external_id, payload
    from raw_payloads
   where raw_entity_type = 'github.issue'
   order by tenant_id, source_instance, external_id, collected_at desc, inserted_at desc
  """

  @doc "O SQL que preenche o tipo de quem abriu a issue. Público para o teste da T022."
  def sql_autores do
    """
    update collected_issues ci
       set author_account_type = #{String.replace(@tipo, "NO", "rp.payload->'author'")}
      from (#{@recentes}) rp
     where rp.tenant_id = ci.tenant_id
       and rp.source_instance = ci.source_instance
       and rp.external_id = ci.external_id
       and ci.author_account_type is null
       and jsonb_typeof(rp.payload->'author') = 'object'
    """
  end

  @doc "O SQL que preenche o tipo de cada responsável. Público para o teste da T022."
  def sql_responsaveis do
    """
    update issue_assignees a
       set account_type = #{String.replace(@tipo, "NO", "n.node")}
      from collected_issues ci,
           (#{@recentes}) rp,
           lateral jsonb_array_elements(
             case jsonb_typeof(rp.payload->'assignees'->'nodes')
               when 'array' then rp.payload->'assignees'->'nodes'
               else '[]'::jsonb
             end
           ) as n(node)
     where ci.id = a.collected_issue_id
       and ci.tenant_id = a.tenant_id
       and rp.tenant_id = ci.tenant_id
       and rp.source_instance = ci.source_instance
       and rp.external_id = ci.external_id
       and n.node->>'login' = a.login
       and a.account_type is null
    """
  end

  def up do
    execute(sql_autores())
    execute(sql_responsaveis())
  end

  def down do
    execute("update collected_issues set author_account_type = null")
    execute("update issue_assignees set account_type = null")
  end
end
