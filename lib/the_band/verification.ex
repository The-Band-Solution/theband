defmodule TheBand.Verification do
  @moduledoc """
  A leitura da verificação contínua — feature 037.

  Cada função é **número fixo de consultas**; nada consulta por linha. Toda contagem é
  derivada das entradas, nunca de contador guardado — contador nasce depois da coleta e
  mostra zero para o que já existia.

  ## As fases não são somadas em "falhou"

  Interrompido, não executado e expirado são fases próprias (`ciro.interrupted_*`,
  `ciro.unperformed_*`, `ciro.expired_*`), e nenhuma delas é malsucedida: cancelar é
  decisão humana, e contá-la como quebra inflaria a taxa de falha com o que ninguém
  quebrou. A tela mostra as cinco separadas pelo mesmo motivo.

  ## Em andamento não tem fase, e não é ausência de coleta

  `phase` nulo com `run_status` em andamento é processo que ainda não decidiu nada —
  frase diferente de "não coletado". As duas nunca aparecem com o mesmo texto.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  As execuções mais recentes, com a contagem de jobs derivada das entradas.

  Duas consultas: a página e o total. `filtro` aceita `:phase` e `:repository_id`.
  """
  @spec list(Tenant.t(), keyword()) :: [map()]
  def list(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      base(tenant_id)
      |> aplicar_filtros(opts)
      |> order_by([v], desc: v.external_started_at)
      |> limit(^Keyword.get(opts, :limit, 50))
      |> offset(^Keyword.get(opts, :offset, 0))
      |> select([v, r, f], %{
        id: type(v.id, :binary_id),
        workflow_name: v.workflow_name,
        head_sha: v.head_sha,
        head_branch: v.head_branch,
        trigger_event: v.trigger_event,
        run_status: v.run_status,
        conclusion: v.conclusion,
        phase: v.phase,
        process_kinds: v.process_kinds,
        attempt: v.attempt,
        started_at: v.external_started_at,
        finished_at: v.external_finished_at,
        actor_login: v.actor_login,
        actor_person_id: type(v.actor_person_id, :binary_id),
        repository: f.qualified_name,
        jobs:
          fragment(
            "(SELECT count(*) FROM verification_components c WHERE c.collected_verification_id = ? AND c.no_longer_observed_at IS NULL)",
            v.id
          )
      })
    )
  end

  @spec count(Tenant.t(), keyword()) :: integer()
  def count(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.one(tenant_id |> base() |> aplicar_filtros(opts) |> select([v], count(v.id))) || 0
  end

  @doc """
  Quantas execuções em cada fase — o painel do topo.

  **Uma consulta, e cada fase é uma linha própria**, incluindo a chave `nil` das que
  ainda estão em andamento. Colapsar `nil` em zero apagaria o que está rodando agora.
  """
  @spec by_phase(Tenant.t(), keyword()) :: %{(String.t() | nil) => integer()}
  def by_phase(%Tenant{id: tenant_id}, opts \\ []) do
    tenant_id
    |> base()
    |> aplicar_filtros(Keyword.delete(opts, :phase))
    |> group_by([v], v.phase)
    |> select([v], {v.phase, count(v.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Uma execução, com o repositório. `nil` quando não é deste tenant — nunca erro de permissão."
  @spec get(Tenant.t(), Ecto.UUID.t()) :: map() | nil
  def get(%Tenant{id: tenant_id}, id) do
    Repo.one(
      base(tenant_id)
      |> where([v], v.id == type(^id, :binary_id))
      |> select([v, r, f], %{
        id: type(v.id, :binary_id),
        workflow_name: v.workflow_name,
        head_sha: v.head_sha,
        head_branch: v.head_branch,
        trigger_event: v.trigger_event,
        run_status: v.run_status,
        conclusion: v.conclusion,
        phase: v.phase,
        process_kinds: v.process_kinds,
        attempt: v.attempt,
        started_at: v.external_started_at,
        finished_at: v.external_finished_at,
        actor_login: v.actor_login,
        actor_person_id: type(v.actor_person_id, :binary_id),
        repository: f.qualified_name
      })
    )
  end

  @doc "Os jobs de uma execução — os processos componentes que ela materializou."
  @spec components_of(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def components_of(%Tenant{id: tenant_id}, verification_id) do
    Repo.all(
      from c in "verification_components",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.collected_verification_id == type(^verification_id, :binary_id) and
            is_nil(c.no_longer_observed_at),
        order_by: [asc: c.external_started_at, asc: c.job_name],
        select: %{
          id: type(c.id, :binary_id),
          job_name: c.job_name,
          conclusion: c.conclusion,
          phase: c.phase,
          components: c.components,
          step_names: c.step_names,
          started_at: c.external_started_at,
          finished_at: c.external_finished_at
        }
    )
  end

  @doc """
  As execuções que verificaram os commits de uma solicitação de mudança.

  O elo é o `head_sha`: é o mesmo commit que o CI verificou e que a solicitação
  entregou. **Sem tabela de vínculo** porque não há nada a decidir — o SHA é o
  identificador, e inventar uma tabela seria guardar o que a chave já diz.

  Uma consulta. Vazio significa "nenhuma execução coletada verificou estes commits", e
  quem chama distingue isso de "o repositório não tem CI" olhando
  `verifications_collected_at`.
  """
  @spec for_change_request(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def for_change_request(%Tenant{id: tenant_id}, change_request_id) do
    Repo.all(
      from v in "collected_verifications",
        join: co in "collected_commits",
        on: co.sha == v.head_sha and co.tenant_id == v.tenant_id,
        where:
          v.tenant_id == type(^tenant_id, :binary_id) and
            co.change_request_id == type(^change_request_id, :binary_id) and
            is_nil(v.no_longer_observed_at) and is_nil(co.no_longer_observed_at),
        order_by: [desc: v.external_started_at],
        distinct: v.id,
        select: %{
          id: type(v.id, :binary_id),
          workflow_name: v.workflow_name,
          head_sha: v.head_sha,
          run_status: v.run_status,
          conclusion: v.conclusion,
          phase: v.phase,
          attempt: v.attempt,
          started_at: v.external_started_at,
          finished_at: v.external_finished_at
        }
    )
  end

  @doc """
  Os jobs que a regra reconheceu como monolíticos — `ci.ap01.monolithic_job`.

  Agrupado por nome de job, e não por execução: o antipadrão é do **script**, e o mesmo
  job aparece em toda execução do fluxo. Listar por execução repetiria a mesma
  ocorrência centenas de vezes e faria um defeito parecer muitos.
  """
  @spec monolithic_jobs(Tenant.t()) :: [map()]
  def monolithic_jobs(%Tenant{id: tenant_id}) do
    Repo.all(
      from c in "verification_components",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            is_nil(c.no_longer_observed_at) and
            fragment("array_length(?, 1) > 1", c.components),
        group_by: [c.job_name, c.components],
        order_by: [desc: count(c.id)],
        select: %{
          job_name: c.job_name,
          components: c.components,
          occurrences: count(c.id)
        }
    )
  end

  @doc """
  Os jobs cujos componentes a regra não reconheceu — `ci.ap02.unnamed_components`.

  Array vazio é ausência nomeada: o job existe e a regra não soube dizer o que ele
  verifica. Chutar "build" produziria medida inventada, e é justamente o que a máxima
  existe para impedir.

  **Só conta job de execução que é integração contínua.** Um job `sync` numa automação
  de quadro não tem componente de CI porque não é CI — contá-lo produziria 751 defeitos
  falsos, que foi o que o dado de 2026-08-18 mostrou antes desta restrição existir.
  """
  @spec unnamed_jobs(Tenant.t()) :: [map()]
  def unnamed_jobs(%Tenant{id: tenant_id}) do
    Repo.all(
      from c in "verification_components",
        join: v in "collected_verifications",
        on: v.id == c.collected_verification_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            is_nil(c.no_longer_observed_at) and
            fragment("coalesce(array_length(?, 1), 0) = 0", c.components) and
            fragment("? = ANY(?)", "ciro.continuous_integration_process", v.process_kinds),
        group_by: c.job_name,
        order_by: [desc: count(c.id)],
        select: %{job_name: c.job_name, occurrences: count(c.id)}
    )
  end

  @doc """
  Os repositórios observados e o estado da coleta de verificação.

  É o que separa as três frases que a tela nunca pode confundir: **não coletado**
  (`collected_at` nulo), **sem verificação contínua** (percorrido e nenhuma execução), e
  **com execuções**.
  """
  @spec repositories(Tenant.t()) :: [map()]
  def repositories(%Tenant{id: tenant_id}) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where: r.tenant_id == type(^tenant_id, :binary_id) and is_nil(r.excluded_at),
        order_by: [asc: f.qualified_name],
        select: %{
          id: type(r.id, :binary_id),
          qualified_name: f.qualified_name,
          collected_at: r.verifications_collected_at,
          verifications:
            fragment(
              "(SELECT count(*) FROM collected_verifications v WHERE v.observed_repository_id = ? AND v.no_longer_observed_at IS NULL)",
              r.id
            )
        }
    )
  end

  defp base(tenant_id) do
    from v in "collected_verifications",
      join: r in "observed_repositories",
      on: r.id == v.observed_repository_id,
      join: f in "cmpo_source_repositories",
      on: f.id == r.source_repository_id,
      where: v.tenant_id == type(^tenant_id, :binary_id) and is_nil(v.no_longer_observed_at)
  end

  defp aplicar_filtros(query, opts) do
    query
    |> filtrar_fase(Keyword.get(opts, :phase))
    |> filtrar_repositorio(Keyword.get(opts, :repository_id))
    |> filtrar_tipo(Keyword.get(opts, :kind))
  end

  defp filtrar_fase(query, nil), do: query
  # A fase "em andamento" não é um valor: é a ausência dele. Comparar com string
  # devolveria vazio, e a tela diria "nenhuma" para o que está rodando agora.
  defp filtrar_fase(query, "running"), do: where(query, [v], is_nil(v.phase))
  defp filtrar_fase(query, fase), do: where(query, [v], v.phase == ^fase)

  defp filtrar_repositorio(query, nil), do: query

  defp filtrar_repositorio(query, id),
    do: where(query, [v], v.observed_repository_id == type(^id, :binary_id))

  defp filtrar_tipo(query, nil), do: query

  # "Nenhum tipo" é uma resposta, não a ausência de filtro: são as execuções que a rede
  # não sabe nomear, e a tela precisa conseguir listá-las para que sejam vistas.
  defp filtrar_tipo(query, "none"),
    do: where(query, [v], fragment("coalesce(array_length(?, 1), 0) = 0", v.process_kinds))

  defp filtrar_tipo(query, tipo), do: where(query, [v], ^tipo in v.process_kinds)
end
