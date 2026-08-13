defmodule TheBand.Mapping.Queries do
  @moduledoc """
  Leituras de Mapping. A fronteira é `TheBand.Mapping`.

  **Nenhuma função devolve `Ecto.Query`**: quem recebe query compõe sobre ela e, ao
  compor, contorna o filtro de tenant.
  """

  import Ecto.Query

  alias TheBand.Mapping.Schemas.MappingRule
  alias TheBand.Mapping.Schemas.UnmappedPatternDecision
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssuePromotion

  @amostra 200

  @doc """
  As regras da organização **na ordem em que são aplicadas**.

  A ordem é `position`, e é única por organização — sem isso, acrescentar regra mudaria a
  classificação sem ninguém ver.

  `opts[:only_active]` traz só as vigentes; o padrão traz todas, porque a tela precisa
  mostrar as desativadas para permitir reativá-las.
  """
  @spec list_rules(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def list_rules(%Tenant{id: tenant_id}, organization_id, opts \\ []) do
    consulta =
      from r in MappingRule,
        left_join: p in IssuePromotion,
        on: p.mapping_rule_id == r.id,
        where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id,
        group_by: r.id,
        order_by: [asc: r.position],
        select: %{
          id: r.id,
          where: r.where,
          how: r.how,
          pattern: r.pattern,
          case_sensitive: r.case_sensitive,
          target_concept: r.target_concept,
          position: r.position,
          active: r.active,
          version: r.version,
          catalog_key: r.catalog_key,
          created_by_id: r.created_by_id,
          inserted_at: r.inserted_at,
          deactivated_at: r.deactivated_at,
          promoted_count: count(p.id)
        }

    consulta
    |> then(fn q -> if opts[:only_active], do: where(q, [r], r.active), else: q end)
    |> Repo.all()
  end

  @doc """
  As regras vigentes como a decisão as consome — struct, ordenada, só as ativas.

  Separada de `list_rules/3` porque as duas respondem perguntas diferentes: esta alimenta
  `Routing.decide/2`, e a outra desenha a tela. Uma função só carregaria contagens que a
  decisão não usa, a cada issue.
  """
  @spec active_rules(Tenant.t(), Ecto.UUID.t()) :: [MappingRule.t()]
  def active_rules(%Tenant{id: tenant_id}, organization_id) do
    Repo.all(
      from r in MappingRule,
        where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id and r.active,
        order_by: [asc: r.position]
    )
  end

  @spec fetch_rule(Tenant.t(), Ecto.UUID.t()) :: {:ok, MappingRule.t()} | {:error, :not_found}
  def fetch_rule(%Tenant{id: tenant_id}, rule_id) do
    case Repo.get_by(MappingRule, id: rule_id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      regra -> {:ok, regra}
    end
  end

  @doc """
  Os padrões declarados como **não sendo tipo**, ainda vigentes.

  Revertidos não aparecem: a reversão os devolve à lista de pendências.
  """
  @spec list_not_a_type(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_not_a_type(%Tenant{id: tenant_id}, organization_id) do
    Repo.all(
      from d in UnmappedPatternDecision,
        where:
          d.tenant_id == ^tenant_id and d.organization_id == ^organization_id and
            is_nil(d.reverted_at),
        order_by: [asc: d.pattern],
        select: %{
          id: d.id,
          pattern: d.pattern,
          decided_by_id: d.decided_by_id,
          decided_at: d.decided_at,
          note: d.note
        }
    )
  end

  @doc """
  Uma amostra de títulos reais da organização, para medir o custo de uma expressão.

  Títulos reais, e não string sintética: uma expressão rápida em `"abc"` pode ser lenta no
  título de 200 caracteres que o time escreve.
  """
  @spec title_sample(Tenant.t(), Ecto.UUID.t()) :: [String.t()]
  def title_sample(%Tenant{} = tenant, organization_id) do
    ids = repositorios_da_organizacao(tenant, organization_id)

    Repo.all(
      from i in CollectedIssue,
        where: i.tenant_id == ^tenant.id and i.observed_repository_id in ^ids,
        order_by: [desc: fragment("length(?)", i.title)],
        limit: @amostra,
        select: i.title
    )
  end

  @doc """
  As issues da organização com o que a decisão precisa — tipo, título e partes.

  Devolve mapas, e não structs: a decisão consome tipo, título e os tipos das partes, e
  carregar a issue inteira multiplicaria o custo por 4471.
  """
  @spec issues_for_decision(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def issues_for_decision(%Tenant{} = tenant, organization_id) do
    ids = repositorios_da_organizacao(tenant, organization_id)

    Repo.all(
      from i in CollectedIssue,
        where: i.tenant_id == ^tenant.id and i.observed_repository_id in ^ids,
        order_by: [asc: i.observed_repository_id, asc: i.number, asc: i.id],
        select: %{
          id: i.id,
          number: i.number,
          title: i.title,
          issue_type: i.issue_type,
          observed_repository_id: i.observed_repository_id
        }
    )
  end

  @doc """
  Quanto do trabalho da organização ainda não tem conceito, e por quê.

  Responde a pergunta que abre a tela — FR-034: *"quanto falta?"*. Sem o total, "12 tipos
  desconhecidos" não diz se o problema é grande ou marginal.

  Os tipos desconhecidos vêm **com o nome**: "tipo desconhecido: 37" não diz onde a regra
  precisa mudar, e "Chore (17), Refactor (16), Hotfix (4)" diz.
  """
  @spec gap_summary(Tenant.t(), Ecto.UUID.t()) :: map()
  def gap_summary(%Tenant{} = tenant, organization_id) do
    ids = repositorios_da_organizacao(tenant, organization_id)

    vigentes =
      from p in subquery(promocoes_vigentes(tenant.id)),
        join: i in CollectedIssue,
        on: i.id == p.collected_issue_id,
        where: i.observed_repository_id in ^ids

    total = Repo.one(from p in subquery(vigentes), select: count(p.collected_issue_id))

    promovidas =
      Repo.one(
        from p in subquery(vigentes),
          where: not is_nil(p.derived_concept),
          select: count(p.collected_issue_id)
      )

    tipos =
      Repo.all(
        from p in subquery(vigentes),
          where: p.skip_reason == "type_unknown" and not is_nil(p.skip_detail),
          group_by: p.skip_detail,
          order_by: [desc: count(p.collected_issue_id)],
          select: {p.skip_detail, count(p.collected_issue_id)}
      )

    %{total: total, promovidas: promovidas, sem_conceito: total - promovidas, tipos: tipos}
  end

  # A vigente é a última por `inserted_at` — a L20 vale aqui como em todo lugar que lê
  # "a última". O desempate por `id` é o mesmo de `WorkItems.Queries`: com `utc_datetime_usec` o
  # empate é impossível na prática, e a ordem deixa de depender disso.
  #
  # ## Esta é a **segunda** definição da mesma decisão, e ela fica declarada
  #
  # A primeira vive em `WorkItems.Queries`. Duas definições para a mesma pergunta discordam no dia
  # em que uma é corrigida — e foi o que quase aconteceu na feature 013: a de lá virou resolução
  # lateral por issue, e esta continuaria varrendo o tenant com outra ordem.
  #
  # **Reusar exigiria expor a subconsulta pela fronteira pública de WorkItems**, e função que
  # devolve `Ecto.Query` é o que a ADR 0003 proíbe: quem recebe compõe por cima e contorna o filtro
  # de tenant. Entre furar a fronteira e duplicar quinze linhas, duplica-se — **e se registra**.
  #
  # A forma aqui continua sendo `DISTINCT ON` porque a pergunta é outra: este módulo **agrega** as
  # promoções de uma organização inteira, e não decora as linhas que uma tela exibe. Lateral por
  # linha só ganha quando há poucas linhas para decorar.
  defp promocoes_vigentes(tenant_id) do
    from p in IssuePromotion,
      where: p.tenant_id == ^tenant_id,
      distinct: p.collected_issue_id,
      order_by: [asc: p.collected_issue_id, desc: p.inserted_at, desc: p.id]
  end

  @doc """
  Os identificadores de repositório observado da organização.

  Vem por `CMPO.list_observed/2`, e não por junção: `Mapping` alcançar
  `observed_repositories` quebraria a fronteira que a ADR 0003 impõe, e passaria a
  quebrar a cada mudança na derivação de CMPO.
  """
  @spec repositorios_da_organizacao(Tenant.t(), Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def repositorios_da_organizacao(%Tenant{} = tenant, organization_id) do
    tenant
    |> CMPO.list_observed()
    |> Enum.filter(&(&1.organization_id == organization_id))
    |> Enum.map(& &1.observed_repository_id)
  end
end
