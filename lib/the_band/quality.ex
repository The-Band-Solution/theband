defmodule TheBand.Quality do
  @moduledoc """
  A leitura das avaliações de artefato — `qapo.artifact_evaluation`, feature 039.

  ## O que a QAPO obriga esta leitura a não afirmar

  `qapo.artifact_evaluation` é a atividade que "avalia objetivamente a aderência". Ela não
  atesta conformidade: o mapeamento declara que **aprovação é ausência de bloqueio, não
  ausência de não conformidade**. Então nenhuma função aqui devolve "conforme" — devolvem o
  estado cru, e a tela mostra o que a origem disse.

  ## Bot é separado de pessoa em toda contagem

  A limitação do mapeamento manda classificá-los à parte, e o motivo é a medida: se a
  primeira "revisão" de uma solicitação foi um bot, o tempo até a primeira revisão humana
  continua correndo. Somá-los mediria o robô.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @humano "User"

  @doc """
  As avaliações de uma solicitação, em ordem de submissão.

  Uma consulta. Vazio significa "nenhuma avaliação coletada", e quem chama distingue isso
  de "não revisada" olhando `reviews_total` da solicitação — as duas frases nunca são a
  mesma.
  """
  @spec for_change_request(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def for_change_request(%Tenant{id: tenant_id}, change_request_id) do
    Repo.all(
      from a in "collected_artifact_evaluations",
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and
            a.collected_change_request_id == type(^change_request_id, :binary_id) and
            is_nil(a.no_longer_observed_at),
        order_by: [asc_nulls_last: a.external_submitted_at],
        select: %{
          id: type(a.id, :binary_id),
          state: a.state,
          body: a.body,
          submitted_at: a.external_submitted_at,
          author_login: a.author_login,
          author_type: a.author_type,
          author_person_id: type(a.author_person_id, :binary_id)
        }
    )
  end

  @doc """
  O tempo até a primeira revisão **humana** — a medida
  `review_time_to_first_review_duration`, que estava escrita e sem dado.

  Devolve uma linha por solicitação avaliada, com o intervalo em segundos entre a abertura e
  a primeira avaliação submetida por pessoa.

  ## Os três filtros são da medida, não da conveniência

  `submitted_at` não nulo exclui rascunho — a medida diz "excluir solicitações em rascunho".
  `author_type = "User"` exclui bot — "revisões automáticas devem ser excluídas ou
  classificadas separadamente". E `min` porque a pergunta é sobre a **primeira**.

  Solicitação sem avaliação humana **não aparece**: ela não tem tempo até a primeira
  revisão, e devolvê-la com zero afirmaria revisão instantânea.
  """
  @spec time_to_first_review(Tenant.t(), keyword()) :: [map()]
  def time_to_first_review(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from c in "collected_change_requests",
        join: a in "collected_artifact_evaluations",
        on: a.collected_change_request_id == c.id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at) and
            is_nil(a.no_longer_observed_at) and not is_nil(a.external_submitted_at) and
            a.author_type == @humano,
        group_by: [c.id, c.number, c.title, c.external_created_at],
        order_by: [desc: c.external_created_at],
        limit: ^Keyword.get(opts, :limit, 50),
        select: %{
          id: type(c.id, :binary_id),
          number: c.number,
          title: c.title,
          opened_at: c.external_created_at,
          first_review_at: min(a.external_submitted_at),
          seconds:
            fragment(
              "extract(epoch from (min(?) - ?))::bigint",
              a.external_submitted_at,
              c.external_created_at
            )
        }
    )
  end

  @doc """
  O tempo até a primeira revisão humana das solicitações **desta equipe** — feature 058, US1.

  ## O recorte é pela ABERTURA, e isso é a medida, não uma escolha de consulta

  A solicitação conta para a equipe quando quem a abriu pertencia a ela **na data
  em que a abriu**. Recortar pela data da revisão mediria a equipe de quem
  **revisa** — e a medida se chama *tempo até a primeira revisão*, que é uma
  espera de quem abriu.

  A consequência é a que o SC-002 pede: registrar a saída de alguém **não altera**
  nenhum valor já apresentado para um período encerrado. A vigência é avaliada
  contra a data do evento, e não contra hoje.

  `started_at` nulo **é membro** — desconhecido nunca é "nunca pertenceu", a
  mesma convenção de `team_members_at/3` (feature 057).

  ## A espera em curso não é omitida, e não é zero

  Solicitação ainda sem revisão humana volta como `{:aguardando, dias}`.
  Omiti-las faria a mediana **melhorar** quanto pior a equipe estivesse: as que
  ninguém revisou são justamente as que mais interessam, e a medida andaria para o
  lado errado sem ninguém notar (FR-004, SC-003).

  Contá-las como zero seria pior ainda — afirmaria revisão instantânea onde não
  houve revisão nenhuma.

  ## Só revisão humana encerra a contagem

  `author_type == "User"` é o filtro que este módulo já aplica em
  `time_to_first_review/2`, e aqui ele é **consumido**, não redefinido: duas
  definições do que é uma revisão divergiriam na primeira correção.

  Uma consulta. `opts` aceita `:desde` e `:ate`, sobre a data de **abertura**.
  """
  @type espera :: %{
          change_request_id: Ecto.UUID.t(),
          numero: integer(),
          titulo: String.t(),
          aberta_em: DateTime.t(),
          autor_person_id: Ecto.UUID.t() | nil,
          autor_login: String.t() | nil,
          estado: {:revisada, float()} | {:aguardando, non_neg_integer()}
        }

  @spec team_time_to_first_review(Tenant.t(), Ecto.UUID.t(), keyword()) :: [espera()]
  def team_time_to_first_review(%Tenant{id: tenant_id}, team_id, opts \\ []) do
    tenant_id
    |> abertas_por_quem_pertencia(team_id)
    |> com_primeira_revisao_humana()
    |> aplicar_janela(opts)
    |> limit(^Keyword.get(opts, :limit, 200))
    |> Repo.all()
    |> Enum.map(&com_estado/1)
  end

  # O RECORTE: solicitação cujo autor pertencia à equipe na data de ABERTURA dela.
  #
  # As três condições de vigência ficam em `where` encadeados, e não amontoadas no
  # `on` do join — a consulta inteira num `from` só passou dos 9 de complexidade que
  # o Credo aceita, e o gate estava certo: a regra do recorte é o que esta função é,
  # e ler o resto junto escondia isso.
  defp abertas_por_quem_pertencia(tenant_id, team_id) do
    from(c in "collected_change_requests",
      join: m in "eo_team_memberships",
      on: m.person_id == c.author_person_id and m.tenant_id == c.tenant_id,
      where:
        c.tenant_id == type(^tenant_id, :binary_id) and
          m.team_id == type(^team_id, :binary_id) and
          is_nil(c.no_longer_observed_at)
    )
    |> where([_c, m], is_nil(m.invalidated_at))
    |> where([c, m], is_nil(m.started_at) or m.started_at <= c.external_created_at)
    |> where([c, m], is_nil(m.ended_at) or m.ended_at > c.external_created_at)
  end

  # `left_join`, e não `join`: a solicitação sem revisão humana **tem de vir**, com
  # `min` nulo. Um join interno a deixaria de fora, e a mediana melhoraria quanto
  # pior a equipe estivesse.
  defp com_primeira_revisao_humana(query) do
    query
    |> join(:left, [c, _m], a in "collected_artifact_evaluations",
      on:
        a.collected_change_request_id == c.id and is_nil(a.no_longer_observed_at) and
          not is_nil(a.external_submitted_at) and a.author_type == @humano
    )
    |> group_by([c], [
      c.id,
      c.number,
      c.title,
      c.external_created_at,
      c.author_person_id,
      c.author_login
    ])
    |> order_by([c], desc: c.external_created_at)
    |> select([c, _m, a], %{
      change_request_id: type(c.id, :binary_id),
      numero: c.number,
      titulo: c.title,
      # `type/2` porque a consulta é sobre a TABELA, e não sobre um schema: sem ele
      # o Postgres devolve `NaiveDateTime`, e a conta de dias da espera em curso
      # explode com `FunctionClauseError` em vez de errar o número — pego por teste.
      aberta_em: type(c.external_created_at, :utc_datetime),
      autor_person_id: type(c.author_person_id, :binary_id),
      autor_login: c.author_login,
      primeira_revisao_em: min(a.external_submitted_at),
      segundos:
        fragment(
          "extract(epoch from (min(?) - ?))::bigint",
          a.external_submitted_at,
          c.external_created_at
        )
    })
  end

  @doc """
  A mesma espera, **agrupada por quem abriu** — feature 058, T010.

  As duas contagens **não somam**, e quem apresenta precisa dizer isso: a mesma
  solicitação tem um autor só, então aqui não há dupla contagem — mas a mediana
  por pessoa e a da equipe respondem perguntas diferentes, e ninguém deve tentar
  reconciliá-las (FR-005, FR-020).

  Devolve uma lista de `%{autor_person_id, autor_login, esperas}`, ordenada por
  login. Reusa `team_time_to_first_review/3` — **mesma consulta**, agrupada em
  memória: uma segunda consulta com outro filtro produziria dois números com o
  mesmo rótulo, que é a L67.
  """
  @spec team_time_to_first_review_by_person(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def team_time_to_first_review_by_person(%Tenant{} = tenant, team_id, opts \\ []) do
    tenant
    |> team_time_to_first_review(team_id, opts)
    |> agrupar_por_pessoa()
  end

  @doc """
  O agrupamento por autor de uma lista já carregada — **puro**, sem consulta.

  Existe para a tela: ela mostra as duas leituras na mesma seção, e chamar
  `team_time_to_first_review_by_person/3` depois de `team_time_to_first_review/3`
  gastaria uma segunda consulta com o mesmo filtro. Duas consultas com o mesmo
  rótulo é como dois números com o mesmo rótulo começam a divergir.
  """
  @spec agrupar_por_pessoa([espera()]) :: [map()]
  def agrupar_por_pessoa(esperas) do
    esperas
    |> Enum.group_by(&{&1.autor_person_id, &1.autor_login})
    |> Enum.map(fn {{person_id, login}, delas} ->
      %{autor_person_id: person_id, autor_login: login, esperas: delas}
    end)
    |> Enum.sort_by(&(&1.autor_login || ""))
  end

  @doc """
  A mediana das esperas **já encerradas**, em horas.

  `nil` quando nenhuma foi revisada — e `nil` é a ausência dita, nunca zero: zero
  afirmaria revisão instantânea. As em curso não entram no cálculo porque a
  espera delas ainda não terminou; elas aparecem **ao lado**, contadas, e é isso
  que impede a medida de melhorar quando a equipe piora.
  """
  @spec mediana_em_horas([espera()]) :: float() | nil
  def mediana_em_horas(esperas) do
    horas =
      esperas
      |> Enum.flat_map(fn
        %{estado: {:revisada, h}} -> [h]
        _ -> []
      end)
      |> Enum.sort()

    case horas do
      [] -> nil
      lista -> Float.round(mediana(lista), 1)
    end
  end

  defp mediana(lista) do
    n = length(lista)
    meio = div(n, 2)

    if rem(n, 2) == 1 do
      Enum.at(lista, meio)
    else
      (Enum.at(lista, meio - 1) + Enum.at(lista, meio)) / 2
    end
  end

  # Sem revisão humana, a espera está EM CURSO — e o relator diz há quantos dias,
  # que é a informação que faz alguém agir. `nil` viraria "—" na tela, e a linha
  # pareceria um defeito de coleta.
  defp com_estado(%{primeira_revisao_em: nil, aberta_em: aberta} = linha) do
    dias = DateTime.diff(DateTime.utc_now(), aberta, :second) |> div(86_400) |> max(0)

    linha
    |> Map.drop([:segundos, :primeira_revisao_em])
    |> Map.put(:estado, {:aguardando, dias})
  end

  defp com_estado(%{segundos: segundos} = linha) do
    linha
    |> Map.drop([:segundos, :primeira_revisao_em])
    |> Map.put(:estado, {:revisada, Float.round(segundos / 3600, 1)})
  end

  defp aplicar_janela(query, opts) do
    query
    |> entao(Keyword.get(opts, :desde), &where(&1, [c], c.external_created_at >= ^&2))
    |> entao(Keyword.get(opts, :ate), &where(&1, [c], c.external_created_at < ^&2))
  end

  defp entao(query, nil, _fun), do: query
  defp entao(query, valor, fun), do: fun.(query, valor)

  @doc """
  O painel: quantas solicitações foram avaliadas por pessoa, por bot, e quantas por ninguém.

  **Uma consulta**, e as três colunas nunca somam entre si porque medem coisas diferentes.
  `nao_medido` é solicitação coletada antes de a plataforma guardar `reviews_total` — nulo é
  desconhecido, nunca zero.
  """
  @spec resumo(Tenant.t()) :: map()
  def resumo(%Tenant{id: tenant_id}) do
    linhas =
      Repo.all(
        from c in "collected_change_requests",
          left_join: a in "collected_artifact_evaluations",
          on: a.collected_change_request_id == c.id and is_nil(a.no_longer_observed_at),
          where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at),
          group_by: c.id,
          select: %{
            total: c.reviews_total,
            humanas: fragment("count(?) filter (where ? = ?)", a.id, a.author_type, @humano),
            de_bot: fragment("count(?) filter (where ? <> ?)", a.id, a.author_type, @humano)
          }
      )

    %{
      avaliadas_por_pessoa: Enum.count(linhas, &(&1.humanas > 0)),
      so_por_bot: Enum.count(linhas, &(&1.humanas == 0 and &1.de_bot > 0)),
      sem_avaliacao: Enum.count(linhas, &(&1.total == 0)),
      nao_medido: Enum.count(linhas, &is_nil(&1.total))
    }
  end

  @doc """
  Quem revisou o quê — a participação `qapo.stakeholder_performed_artifact_evaluation`.

  Bot aparece com `person_id` nulo e não é somado a pessoa: forçar uma pessoa para o robô
  inventaria participação que não existe.
  """
  @spec by_reviewer(Tenant.t(), keyword()) :: [map()]
  def by_reviewer(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from a in "collected_artifact_evaluations",
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and is_nil(a.no_longer_observed_at) and
            not is_nil(a.external_submitted_at),
        group_by: [a.author_login, a.author_type, a.author_person_id],
        order_by: [desc: count(a.id)],
        limit: ^Keyword.get(opts, :limit, 50),
        select: %{
          login: a.author_login,
          author_type: a.author_type,
          person_id: type(a.author_person_id, :binary_id),
          evaluations: count(a.id),
          approved: fragment("count(?) filter (where ? = 'APPROVED')", a.id, a.state),
          changes_requested:
            fragment("count(?) filter (where ? = 'CHANGES_REQUESTED')", a.id, a.state)
        }
    )
  end
end
