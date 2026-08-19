defmodule TheBand.Configuration do
  @moduledoc """
  A leitura das linhas de desenvolvimento — `cmpo.branch`, feature 039.

  ## O que esta leitura responde, e o que ela NÃO responde

  Responde **o presente**: que linhas estão abertas, quais estão paradas, quais são
  protegidas. Medido em 2026-08-19: 339 branches em 65 repositórios, e **140 sem commit há
  mais de 90 dias**.

  Não responde o passado. Branch mergeada é apagada na origem, e o histórico dela vive no
  `source_branch` das solicitações de mudança — 2.461 nomes distintos, contra 339 branches
  vivas. Uma solicitação aponta para um nome que pode não ter entidade, e
  `entidade_da_branch/3` devolve `nil` nesse caso em vez de inventar uma.

  ## Parada não é abandonada

  A plataforma sabe quando foi o último commit; não sabe se alguém pretende voltar. Então
  nenhuma função aqui devolve "abandonada" — devolvem `dias_sem_commit`, e quem lê decide.
  Chamar de abandonada seria afirmar intenção que a origem não registra.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  As branches de um repositório, da mais recentemente tocada para a mais antiga.

  Uma consulta. `dias_sem_commit` é derivado no banco — a alternativa seria calcular por
  linha em Elixir, o que dá o mesmo número e obriga a tela a repetir a conta.
  """
  @spec branches_of(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def branches_of(%Tenant{id: tenant_id}, observed_repository_id) do
    Repo.all(
      from b in "cmpo_branches",
        where:
          b.tenant_id == type(^tenant_id, :binary_id) and
            b.observed_repository_id == type(^observed_repository_id, :binary_id) and
            is_nil(b.no_longer_observed_at),
        order_by: [desc_nulls_last: b.head_committed_at],
        select: %{
          id: type(b.id, :binary_id),
          name: b.name,
          head_sha: b.head_sha,
          head_committed_at: b.head_committed_at,
          is_default: b.is_default,
          is_protected: b.is_protected,
          dias_sem_commit:
            fragment(
              "case when ? is null then null else extract(day from (now() - ?))::int end",
              b.head_committed_at,
              b.head_committed_at
            )
        }
    )
  end

  @doc """
  O painel de um repositório — **uma consulta**.

  `paradas` usa 90 dias por ser o corte que a organização já usa em outras medidas, e o
  número vai declarado na tela: corte escondido faz quem lê achar que é propriedade do dado.
  """
  @spec resumo_do_repositorio(Tenant.t(), Ecto.UUID.t()) :: map()
  def resumo_do_repositorio(%Tenant{id: tenant_id}, observed_repository_id) do
    Repo.one(
      from b in "cmpo_branches",
        where:
          b.tenant_id == type(^tenant_id, :binary_id) and
            b.observed_repository_id == type(^observed_repository_id, :binary_id) and
            is_nil(b.no_longer_observed_at),
        select: %{
          vivas: count(b.id),
          protegidas: fragment("count(?) filter (where ?)", b.id, b.is_protected),
          paradas:
            fragment(
              "count(?) filter (where ? < now() - interval '90 days')",
              b.id,
              b.head_committed_at
            ),
          # Branch sem data de commit é a que a origem não soube datar — ausência nomeada,
          # não zero dias.
          sem_data: fragment("count(?) filter (where ? is null)", b.id, b.head_committed_at)
        }
    ) || %{vivas: 0, protegidas: 0, paradas: 0, sem_data: 0}
  end

  @doc """
  A entidade de uma branch citada por nome — ou `nil`.

  **`nil` é a resposta correta para branch apagada**, e é o caso comum: das 2.461 branches
  de origem que as solicitações citam, a maioria já foi mergeada e removida. Criar uma
  entidade para o nome afirmaria que a linha ainda existe.
  """
  @spec entidade_da_branch(Tenant.t(), Ecto.UUID.t(), String.t() | nil) :: map() | nil
  def entidade_da_branch(_tenant, _repo_id, nome) when nome in [nil, ""], do: nil

  def entidade_da_branch(%Tenant{id: tenant_id}, observed_repository_id, nome) do
    Repo.one(
      from b in "cmpo_branches",
        where:
          b.tenant_id == type(^tenant_id, :binary_id) and
            b.observed_repository_id == type(^observed_repository_id, :binary_id) and
            b.name == ^nome and is_nil(b.no_longer_observed_at),
        select: %{id: type(b.id, :binary_id), name: b.name, is_protected: b.is_protected}
    )
  end

  @doc """
  O estado da coleta por repositório — as três frases que a tela nunca pode confundir.

  **Não coletado** (`collected_at` nulo), **coletado e sem branch** (impossível na prática,
  mas representável), e **coletado com branches**. `total` é o que a origem informou, e
  comparado com `vivas` revela truncamento.
  """
  @spec estado_da_coleta(Tenant.t()) :: [map()]
  def estado_da_coleta(%Tenant{id: tenant_id}) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where: r.tenant_id == type(^tenant_id, :binary_id) and is_nil(r.excluded_at),
        order_by: [asc: f.qualified_name],
        select: %{
          id: type(r.id, :binary_id),
          qualified_name: f.qualified_name,
          collected_at: r.branches_collected_at,
          total: r.branches_total,
          vivas:
            fragment(
              "(SELECT count(*) FROM cmpo_branches b WHERE b.observed_repository_id = ? AND b.no_longer_observed_at IS NULL)",
              r.id
            )
        }
    )
  end
end
