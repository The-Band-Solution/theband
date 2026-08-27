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

  @doc """
  O desfecho das verificações que dispararam sobre commits desta pessoa — feature 044.

  ## A ligação, e o que ela perde

  `commit_authors.author_person_id` → `collected_commits.sha` →
  `collected_verifications.head_sha`. Medido em 2026-08-27: **8.358 de 15.671 execuções**
  casam com commit de pessoa identificada — **47% não casam**, por três razões, e nenhuma é
  defeito:

    1. execução disparada por evento **sem commit** — `schedule`, `workflow_dispatch`;
    2. commit cujo autor nunca foi promovido a pessoa;
    3. commit de robô.

  `sem_autoria_no_tenant` devolve essa parcela para a tela pôr **ao lado** dos números, e
  nunca descontada deles (`FR-010` da spec 044).

  ## Co-autoria CONTA

  `commit_authors` traz `is_primary`, e o filtro **não** o usa: `cmpo.stakeholder_performed_commit`
  declara `many` na origem, e ignorar o co-autor apagaria participação real. A consequência
  é que a soma das páginas excede o total do tenant, e isso é fato — a mesma limitação que
  `flow.throughput.rate` já declara para o nível `person`.

  ## `skipped` e `cancelled` NÃO são passou nem quebrou

  As duas palavras afirmam resultado, e pular ou cancelar não é resultado. Elas vão para
  `outras`, e somá-las a qualquer um dos dois afirmaria verificação onde ninguém verificou
  (`FR-004`).

  ## Conta EXECUÇÕES, e não commits

  Nova tentativa gera execução nova sobre o mesmo commit. Somar as duas e chamar de
  "commits que quebraram" afirmaria dois commits onde houve um (`FR-005`).
  """
  @spec por_pessoa(Tenant.t(), Ecto.UUID.t()) :: %{
          passou: non_neg_integer(),
          quebrou: non_neg_integer(),
          outras: non_neg_integer(),
          sem_autoria_no_tenant: non_neg_integer()
        }
  def por_pessoa(%Tenant{id: tenant_id}, person_id) do
    tenant_id
    |> execucoes_com_autoria()
    |> desfechos_de(person_id)
    |> Repo.one()
  end

  # A passagem e as contagens ficam em funções separadas porque juntas passam do teto de
  # complexidade do Credo — e a divisão é a mesma que a leitura pede: onde o dado está, e
  # o que se pergunta a ele.
  defp execucoes_com_autoria(tenant_id) do
    from v in "collected_verifications",
      # `left_join` nos três, e não `join`: a mesma passagem responde os números DELA e a
      # parcela do tenant que não casa com pessoa alguma. Com `join`, a segunda pergunta
      # exigiria uma segunda ida ao banco — e a página da pessoa está no teto medido.
      left_join: cm in "collected_commits",
      # O REPOSITÓRIO entra na junção, e não só o `sha`.
      #
      # Sem ele a mesma soma casa com commit de qualquer repositório do tenant — fork,
      # espelho, ou um repositório que recebeu o mesmo commit por cherry-pick. Medido em
      # 2026-08-27: **3 execuções** eram atribuídas ao commit de OUTRO repositório.
      #
      # Três em 8.662 é pouco, e é atribuição errada do mesmo jeito: a execução aparece
      # na página de quem não a disparou.
      on:
        cm.sha == v.head_sha and cm.tenant_id == v.tenant_id and
          cm.observed_repository_id == v.observed_repository_id,
      left_join: ca in "commit_authors",
      on:
        ca.collected_commit_id == cm.id and ca.tenant_id == cm.tenant_id and
          not is_nil(ca.author_person_id) and is_nil(ca.no_longer_observed_at),
      where: v.tenant_id == type(^tenant_id, :binary_id) and is_nil(v.no_longer_observed_at)
  end

  defp desfechos_de(query, person_id) do
    from [v, _cm, ca] in query,
      select: %{
        # `count(:distinct)` é obrigatório: um commit com dois autores produz duas linhas
        # para a mesma execução, e sem ele a contagem dobraria para quem tem co-autoria.
        passou:
          filter(
            count(v.id, :distinct),
            ca.author_person_id == type(^person_id, :binary_id) and v.conclusion == "success"
          ),
        quebrou:
          filter(
            count(v.id, :distinct),
            ca.author_person_id == type(^person_id, :binary_id) and v.conclusion == "failure"
          ),
        outras:
          filter(
            count(v.id, :distinct),
            ca.author_person_id == type(^person_id, :binary_id) and
              (is_nil(v.conclusion) or v.conclusion not in ["success", "failure"])
          ),
        # A parcela do TENANT, e não da pessoa: é contexto sobre o alcance da medida, e o
        # mesmo número aparece em toda página.
        sem_autoria_no_tenant: filter(count(v.id, :distinct), is_nil(ca.id))
      }
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
  A cobertura pelo **estado da ponta** — `statusCheckRollup`, issue #439.

  ## Por que ela substituiu o casamento por `head_sha`, e não convive com ele

  O casamento por SHA errava nas duas direções, e a segunda é a que condena.

  **Deixava passar**: a execução coletada aponta para a ponta do ramo **naquele instante**, então
  só casa nos commits que foram ponta em algum push. Medido em 2026-08-19, para uma pessoa com
  415 solicitações integradas: **98** caíam nesse buraco e a tela as chamava de "não dá para
  saber". A pessoa mantenedora perguntou se realmente não havia como saber. Não havia com o que
  eu tinha coletado; **há com o que a origem oferece**.

  **E supercontava**: qualquer execução vermelha em *qualquer* commit do PR marcava a solicitação
  como integrada vermelha, inclusive a vermelha consertada antes do merge. Das 208 vermelhas que
  só ele achava, **198 estão verdes na ponta** — conferido no `#13`, 33 commits, três vermelhas
  no meio, ponta verde com 2 contextos. Contar isso é a medida ao contrário, e é exatamente o que
  a tela declara recusar.

  Por isso as duas não convivem: a antiga foi **removida**, e não deixada ao lado como segunda
  opinião. Duas medidas com sobreposição de 115 em 469 não são precisões diferentes do mesmo
  fenômeno — são fenômenos diferentes, e manter as duas convidaria a somá-las.

  `statusCheckRollup` é campo do commit e agrega os `check_run` da API de Checks e os `status` da
  API antiga — as duas camadas que a coleta de `workflow_run` não alcança.

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
  # Os dois caminhos não medem a mesma coisa. Medido em 2026-08-19, sobre 4.819 integradas: o
  # casamento por SHA acha 323 vermelhas, o rollup acha 261, e só 115 estão nos dois.
  #
  # **O casamento superconta.** Das 208 que só ele acha, 198 estão VERDES na ponta — a vermelha
  # estava num commit intermediário e o PR foi consertado antes de entrar. As 139 que só o rollup
  # acha são o que `workflow_run` não alcança: `check_run` e `status`.
  #
  # E ele responde o que o casamento não respondia: das 4.878, **2.024 entraram sem
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
          # **Entrou sem verificação nenhuma** — 2.024 no dado real, 41% do total. Pelo caminho
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
        join: v in "collected_verifications",
        on: v.id == c.collected_verification_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            is_nil(c.no_longer_observed_at) and
            fragment("array_length(?, 1) > 1", c.components),
        # **Pelo ARQUIVO, não só pelo nome do job** — issue #440. O antipadrão é propriedade do
        # script, e o nome do job é proxy: dois repositórios com um job chamado `build` viravam a
        # mesma linha, e a máxima não dizia o que corrigir.
        #
        # `workflow_path` sai de `workflow_run.path`, que já estava no payload preservado de todas
        # as 15.375 execuções: 104 definições distintas explicam o corpus inteiro.
        group_by: [v.workflow_path, c.job_name, c.components],
        order_by: [desc: count(c.id)],
        select: %{
          workflow_path: v.workflow_path,
          job_name: c.job_name,
          components: c.components,
          occurrences: count(c.id),
          repositorios: count(v.observed_repository_id, :distinct)
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
