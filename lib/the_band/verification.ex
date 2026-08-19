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
        # A organização vem separada do `qualified_name` porque a tela filtra por ela: partir a
        # string na barra funcionaria até o dia em que um nome tiver barra, e a coluna existe.
        organization_id: type(f.organization_id, :binary_id),
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
  As solicitações **integradas** com verificação malsucedida — `ci.ap03`, issue #439.

  ## Por que "integrada", e não "vermelha"

  CI vermelho num ramo de proposta é o processo **funcionando**: a verificação pegou o
  problema antes de integrar, que é para isso que ela existe. Contar isso como defeito
  produziria a medida ao contrário — quem empurra cedo e usa o CI como rede acumularia
  vermelhos, e quem desenvolve local e empurra uma vez apareceria impecável.

  O que esta função conta é a verificação que **deixou de ser porta e virou relatório**.

  Só a fase malsucedida entra. Cancelada e não executada são decisões humanas ou condições
  de workflow, e contá-las produziria alarme falso — é o motivo das três fases próprias.

  ## E só execução que É integração contínua

  A primeira versão desta consulta não filtrava por tipo, e o dado real derrubou na hora:
  os três "vermelhos" encontrados eram os fluxos `Card de promoção → Project 43` e
  `Promoção → Project 43` — **automação de quadro**, que nada verifica. Um script de
  rollover quebrado faria a pessoa parecer que sobe código com defeito.

  É a mesma armadilha que `process_kinds` existe para fechar, e ela pegou a própria medida
  que a usaria.
  """
  @spec integrated_with_red(Tenant.t(), keyword()) :: [map()]
  def integrated_with_red(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from c in "collected_change_requests",
        join: co in "collected_commits",
        on: co.change_request_id == c.id,
        join: v in "collected_verifications",
        on: v.head_sha == co.sha and v.tenant_id == co.tenant_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and c.state == "MERGED" and
            is_nil(c.no_longer_observed_at) and is_nil(co.no_longer_observed_at) and
            is_nil(v.no_longer_observed_at) and
            v.phase == "ciro.unsuccessful_continuous_integration_process" and
            fragment("? = ANY(?)", "ciro.continuous_integration_process", v.process_kinds),
        distinct: c.id,
        order_by: [desc: c.external_merged_at],
        limit: ^Keyword.get(opts, :limit, 50),
        select: %{
          id: type(c.id, :binary_id),
          number: c.number,
          title: c.title,
          merged_at: c.external_merged_at,
          author_login: c.author_login,
          author_person_id: type(c.author_person_id, :binary_id),
          merged_by_login: c.merged_by_login,
          merged_by_person_id: type(c.merged_by_person_id, :binary_id),
          sha: co.sha,
          workflow_name: v.workflow_name,
          attempt: v.attempt
        }
    )
  end

  @doc """
  A cobertura pelo **estado da ponta** — `statusCheckRollup`, issue #439.

  ## Por que esta função existe ao lado de `cobertura/1`

  `cobertura/1` mede o que o casamento por `head_sha` alcança, e ele alcança pouco: a execução
  coletada aponta para a ponta do ramo **naquele instante**, então só casa nos commits que foram
  ponta em algum push. Medido em 2026-08-19, para uma pessoa com 415 solicitações integradas:
  **98** caíam nesse buraco e a tela as chamava de "não dá para saber".

  A pessoa mantenedora perguntou se realmente não havia como saber. Não havia com o que eu tinha
  coletado; **há com o que a origem oferece**. `statusCheckRollup` é campo do commit e agrega os
  `check_run` da API de Checks e os `status` da API antiga — as duas camadas que a coleta de
  `workflow_run` não alcança.

  ## As quatro respostas, e nenhuma é "não sei" disfarçada

  | resposta | o que significa |
  |---|---|
  | `verde` | a ponta que entrou tinha verificação bem-sucedida |
  | `vermelha` | tinha verificação **malsucedida** — é a `ci.ap03` respondida direto |
  | `sem_check` | **nenhum check rodou** naquele commit: fato sobre o processo |
  | `nao_medido` | a solicitação foi coletada antes de a plataforma pedir o campo |

  `sem_check` é a que mais importa distinguir. Sem ela, "entrou sem verificação nenhuma" ficaria
  no mesmo balde de "não conseguimos medir" — e são coisas opostas: a primeira é achado sobre a
  organização, a segunda é lacuna nossa.

  ## `PENDING` e `EXPECTED` não são verde nem vermelho

  Existem na origem e significam verificação **em curso** ou **esperada e ausente**. Contá-las de
  um lado ou de outro afirmaria resultado que não houve — é a mesma decisão das cinco fases da
  CIRO.
  """
  @spec cobertura_pela_ponta(Tenant.t()) :: map()
  def cobertura_pela_ponta(%Tenant{id: tenant_id}) do
    linhas =
      Repo.all(
        from c in "collected_change_requests",
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and c.state == "MERGED" and
              is_nil(c.no_longer_observed_at),
          group_by:
            fragment(
              """
              CASE
                WHEN ? IS NULL THEN 'nao_medido'
                WHEN ? IN ('FAILURE','ERROR') THEN 'vermelha'
                WHEN ? = 'SUCCESS' THEN 'verde'
                WHEN ? IS NULL AND ? = 0 THEN 'sem_check'
                ELSE 'em_curso'
              END
              """,
              c.merged_check_contexts,
              c.merged_check_state,
              c.merged_check_state,
              c.merged_check_state,
              c.merged_check_contexts
            ),
          select:
            {fragment(
               """
               CASE
                 WHEN ? IS NULL THEN 'nao_medido'
                 WHEN ? IN ('FAILURE','ERROR') THEN 'vermelha'
                 WHEN ? = 'SUCCESS' THEN 'verde'
                 WHEN ? IS NULL AND ? = 0 THEN 'sem_check'
                 ELSE 'em_curso'
               END
               """,
               c.merged_check_contexts,
               c.merged_check_state,
               c.merged_check_state,
               c.merged_check_state,
               c.merged_check_contexts
             ), count(c.id)}
      )

    Map.new(linhas, fn {chave, quantas} -> {atomo_da_ponta(chave), quantas} end)
  end

  defp atomo_da_ponta("verde"), do: :verde
  defp atomo_da_ponta("vermelha"), do: :vermelha
  defp atomo_da_ponta("sem_check"), do: :sem_check
  defp atomo_da_ponta("em_curso"), do: :em_curso
  defp atomo_da_ponta("nao_medido"), do: :nao_medido

  @doc """
  Por pessoa: quantas solicitações integrou, quantas eram **verificáveis**, e quantas
  entraram vermelhas — issue #439.

  ## O denominador é a parte que impede a injustiça

  `merged` é tudo o que a pessoa propôs e entrou. `verified` é o subconjunto cujos commits
  têm verificação **coletada** — e a diferença entre os dois é "não dá para saber", nunca
  "estava tudo bem". Medido em 2026-08-19: o CI cobre **4 dos 160 repositórios**
  observados, então para a maioria das pessoas `verified` é zero e nenhuma taxa existe.

  Uma taxa calculada sobre `merged` faria quem trabalha em repositório sem CI coletado
  parecer impecável, e quem trabalha no repositório coberto parecer pior. Seria medida
  inventada com dado correto.

  ## Duas colunas de participação, porque são dois atos

  `authored` é quem submeteu (`cmpo.stakeholder_submitted_change_request`) e `integrated` é
  quem integrou (`cmpo.stakeholder_performed_checkin`). Integrar com verificação vermelha é
  decisão de quem integra, não de quem propôs — e a definição de `cmpo.change_request` já
  dizia que o PR "não é o merge, nem a decisão de aprovação". Somar os dois papéis num
  número só apontaria para a pessoa errada.
  """
  @spec red_by_person(Tenant.t()) :: [map()]
  def red_by_person(%Tenant{id: tenant_id}) do
    por_participacao(tenant_id, :autor)
  end

  @doc """
  O mesmo, por quem **integrou** — `cmpo.stakeholder_performed_checkin`.

  ## Por que é consulta separada, e não uma coluna a mais

  Submeter e integrar são atos distintos, com participações distintas na rede. E integrar com
  verificação vermelha é decisão de **quem integra**: a definição de `cmpo.change_request` já
  dizia que o PR "não é o merge, nem a decisão de aprovação".

  Somar os dois papéis num número só apontaria para a pessoa errada — quem propôs pode ter
  aberto a solicitação com o CI vermelho de propósito, para pedir ajuda; quem integrou decidiu
  que entrava assim.
  """
  @spec red_by_integrator(Tenant.t()) :: [map()]
  def red_by_integrator(%Tenant{id: tenant_id}) do
    por_participacao(tenant_id, :integrador)
  end

  # **Mede pelo estado da PONTA, e não pelo casamento por `head_sha`** — issue #439.
  #
  # O casamento por SHA achava 284 solicitações integradas vermelhas; o `statusCheckRollup` da
  # ponta acha 349 — 23% mais, porque alcança os `check_run` da API de Checks e os `status` da
  # API antiga, que a coleta de `workflow_run` não vê.
  #
  # E ele responde o que o casamento não respondia: das 4.734 medidas, **2.038 entraram sem
  # check nenhum**. Pelo caminho antigo, essas apareciam como "não dá para saber".
  #
  # As duas participações compartilham a consulta porque só o campo do agrupamento difere.
  # Duplicá-la faria as duas divergirem no dia em que uma coluna mudasse.
  defp por_participacao(tenant_id, papel) do
    {campo_id, campo_login} =
      case papel do
        :autor -> {:author_person_id, :author_login}
        :integrador -> {:merged_by_person_id, :merged_by_login}
      end

    Repo.all(
      from c in "collected_change_requests",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and c.state == "MERGED" and
            is_nil(c.no_longer_observed_at) and not is_nil(field(c, ^campo_id)),
        group_by: [field(c, ^campo_id), field(c, ^campo_login)],
        order_by: [
          desc_nulls_last:
            fragment(
              "count(?) filter (where ? in ('FAILURE','ERROR'))",
              c.id,
              c.merged_check_state
            ),
          desc: count(c.id)
        ],
        select: %{
          person_id: type(field(c, ^campo_id), :binary_id),
          login: field(c, ^campo_login),
          merged: count(c.id),
          # Verificável é a ponta ter tido check. `contexts > 0` e não `state is not null`: um
          # estado `PENDING` com contextos é verificação em curso, e ela existiu.
          verified:
            fragment("count(?) filter (where coalesce(?, 0) > 0)", c.id, c.merged_check_contexts),
          # **Entrou sem verificação nenhuma** — 2.038 no dado real, 43% do medido. Pelo caminho
          # antigo isso era indistinguível de "não conseguimos medir", e são coisas opostas: a
          # primeira é achado sobre o processo, a segunda é lacuna nossa.
          no_check:
            fragment(
              "count(?) filter (where ? is null and ? = 0)",
              c.id,
              c.merged_check_state,
              c.merged_check_contexts
            ),
          # Coletada antes de a plataforma pedir o campo. Nulo é desconhecido, nunca zero.
          not_measured:
            fragment("count(?) filter (where ? is null)", c.id, c.merged_check_contexts),
          red:
            fragment(
              "count(?) filter (where ? in ('FAILURE','ERROR'))",
              c.id,
              c.merged_check_state
            )
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
  As execuções por **organização** — uma consulta, com as fases separadas.

  Um tenant observa mais de uma organização, e os volumes são muito diferentes: medido em
  2026-08-19, 11.444 execuções numa, 2.421 na segunda e 1.510 na terceira. Uma taxa de quebra
  agregada seria dominada pela maior, e esconderia as outras duas.

  `sem_ci` conta repositórios observados que **nenhuma execução de integração contínua** tocou —
  é ausência nomeada por organização, e não some no total.
  """
  @spec by_organization(Tenant.t()) :: [map()]
  def by_organization(%Tenant{id: tenant_id}) do
    Repo.all(
      from o in "eo_organizations",
        join: f in "cmpo_source_repositories",
        on: f.organization_id == o.id,
        join: r in "observed_repositories",
        on: r.source_repository_id == f.id and is_nil(r.excluded_at),
        left_join: v in "collected_verifications",
        on: v.observed_repository_id == r.id and is_nil(v.no_longer_observed_at),
        where: o.tenant_id == type(^tenant_id, :binary_id),
        group_by: [o.id, o.login],
        order_by: [desc: count(v.id)],
        select: %{
          id: type(o.id, :binary_id),
          login: o.login,
          repositorios: count(r.id, :distinct),
          execucoes: count(v.id),
          bem_sucedidas:
            fragment(
              "count(?) filter (where ? = ?)",
              v.id,
              v.phase,
              "ciro.successful_continuous_integration_process"
            ),
          malsucedidas:
            fragment(
              "count(?) filter (where ? = ?)",
              v.id,
              v.phase,
              "ciro.unsuccessful_continuous_integration_process"
            ),
          # Repositório observado que nenhuma execução de CI tocou. Ausência nomeada por
          # organização: sem isto, "zero execuções" seria indistinguível de "sem repositório".
          repos_sem_ci:
            fragment(
              """
              count(distinct ?) - count(distinct case when ? = ANY(?) then ? end)
              """,
              r.id,
              "ciro.continuous_integration_process",
              v.process_kinds,
              r.id
            )
        }
    )
  end

  @doc """
  As execuções por **repositório**, das mais movimentadas para as menos.

  Uma consulta. `limit` porque são 160 repositórios observados e a tela mostra os que têm volume
  — e o que fica de fora é dito, nunca cortado em silêncio.
  """
  @spec by_repository(Tenant.t(), keyword()) :: [map()]
  def by_repository(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        join: o in "eo_organizations",
        on: o.id == f.organization_id,
        left_join: v in "collected_verifications",
        on: v.observed_repository_id == r.id and is_nil(v.no_longer_observed_at),
        where: r.tenant_id == type(^tenant_id, :binary_id) and is_nil(r.excluded_at),
        group_by: [r.id, f.qualified_name, o.login, r.verifications_collected_at],
        having: count(v.id) > 0,
        order_by: [desc: count(v.id)],
        limit: ^Keyword.get(opts, :limit, 20),
        select: %{
          id: type(r.id, :binary_id),
          qualified_name: f.qualified_name,
          organizacao: o.login,
          collected_at: r.verifications_collected_at,
          execucoes: count(v.id),
          malsucedidas:
            fragment(
              "count(?) filter (where ? = ?)",
              v.id,
              v.phase,
              "ciro.unsuccessful_continuous_integration_process"
            ),
          de_ci:
            fragment(
              "count(?) filter (where ? = ANY(?))",
              v.id,
              "ciro.continuous_integration_process",
              v.process_kinds
            )
        }
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
    |> filtrar_organizacao(Keyword.get(opts, :organization_id))
  end

  defp filtrar_fase(query, nil), do: query
  # A fase "em andamento" não é um valor: é a ausência dele. Comparar com string
  # devolveria vazio, e a tela diria "nenhuma" para o que está rodando agora.
  defp filtrar_fase(query, "running"), do: where(query, [v], is_nil(v.phase))
  defp filtrar_fase(query, fase), do: where(query, [v], v.phase == ^fase)

  defp filtrar_repositorio(query, nil), do: query

  defp filtrar_repositorio(query, id),
    do: where(query, [v], v.observed_repository_id == type(^id, :binary_id))

  defp filtrar_organizacao(query, nil), do: query

  defp filtrar_organizacao(query, id),
    do: where(query, [_v, _r, f], f.organization_id == type(^id, :binary_id))

  defp filtrar_tipo(query, nil), do: query

  # "Nenhum tipo" é uma resposta, não a ausência de filtro: são as execuções que a rede
  # não sabe nomear, e a tela precisa conseguir listá-las para que sejam vistas.
  defp filtrar_tipo(query, "none"),
    do: where(query, [v], fragment("coalesce(array_length(?, 1), 0) = 0", v.process_kinds))

  defp filtrar_tipo(query, tipo), do: where(query, [v], ^tipo in v.process_kinds)
end
