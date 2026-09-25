defmodule TheBandWeb.Api.V1.TeamController do
  @moduledoc """
  `GET /api/v1/teams` — a primeira rota da API pública (feature 061, US2).

  ## O recorte é o da tela, e isso fica dito

  As equipes são as **do tenant do token**. A tela `/teams` recorta por tenant e **não filtra
  por `Access`** — chama `EO.list_teams(tenant, ...)` e mais nada. Esta rota espelha a tela,
  que é o requisito (FR-026).

  **Não é frouxidão da API**: é a mesma resposta que a pessoa vê logada. Se a tela passar a
  filtrar, esta rota muda junto, e o teste de contrato apanha a divergência.

  ## Cursor, e não deslocamento

  Deslocamento pula ou repete linha quando a coleção muda entre páginas. O cursor é o último
  identificador visto, e a ordem é estável por ele.

  ## A escrita não responde

  Só `GET` e `HEAD`. Nenhum método de escrita tem autor honesto para a proveniência — FR-017.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles
  alias TheBand.Quality
  alias TheBand.Tenants
  alias TheBand.Tenants.AccessEvents
  alias TheBand.WorkItems.TeamWork
  alias TheBandWeb.Api.V1.Erro
  alias TheBandWeb.Schemas

  require Logger

  @padrao 50
  @teto 200

  # A janela das medidas: 56 dias, fixa nesta fatia e **declarada na resposta**. Escolher o
  # período é trabalho separado; o que não pode faltar é dizer qual foi — uma medida sobre
  # uma janela não declarada responde outra pergunta sem avisar.
  @janela_em_dias 56

  # O limite das esperas por revisão, e a razão de ele viajar na resposta: uma mediana sobre
  # 200 de 500 é OUTRA medida, apresentada com o mesmo rótulo (achado da revisão de segurança
  # do PR #798). Por isso pedimos uma a mais que o limite, para saber se cortou.
  @limite_de_esperas 200

  # O roster TEM total, ao contrário das listagens. A razão do `null` lá era o custo de
  # contar uma coleção que cresce sem teto; aqui a coleção é uma equipe, o número já é o do
  # cabeçalho da tela, e omiti-lo faria quem integra recontar do jeito errado.
  @nota_do_total_do_roster "Counted, unlike the collection listings: a team's roster is " <>
                             "bounded, and this is the same number the screen's header " <>
                             "shows. On a composed team it covers the team and its parts."

  @nota_da_composicao "The roster of a composed team is the team plus its parts with a " <>
                        "current composition. There is one definition of *who belongs " <>
                        "here*, and every count uses it."

  @nota_do_trabalho "`open` and `closed_in_window` are never summed: one is a state now, " <>
                      "the other a count over a window."

  @nota_das_medianas "Two medians, side by side and never summed. One answers *how long " <>
                       "what was reviewed took*, in hours; the other *how long what was " <>
                       "not reviewed has been waiting*, in days. A request still waiting " <>
                       "is not a wait of zero, and dropping it would make the median " <>
                       "improve as the team got worse. `null` is absence stated, never zero."

  @nota_do_corte "When true, the list was cut, and any statistic over it answers a " <>
                   "different question than the same statistic over the whole."

  @nota_da_cobertura "Whoever has no profile is **named**, never summed as zero. Absence " <>
                       "of a profile is absence of reading, so team coverage is a floor " <>
                       "and never a ceiling."

  tags(["teams"])

  operation(:index,
    summary: "Teams of the token's tenant",
    description: """
    Every team the owner account sees on screen, with the mark of where it came from.

    The collection carries **no total** — it carries *has next page*, and says it carries no
    total. An estimated total is worse than an absent one.
    """,
    parameters: [
      page_size: [
        in: :query,
        type: :integer,
        description:
          "Default 50, maximum 200. A larger value is reduced to the maximum, not refused.",
        required: false
      ],
      after: [
        in: :query,
        type: :string,
        description: "Opaque cursor from the previous page's `next_cursor`.",
        required: false
      ]
    ],
    responses: [
      ok: {"The teams", "application/json", Schemas.Teams},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro}
    ]
  )

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    tamanho = tamanho_da_pagina(params)

    # Pede UM a mais que a página para saber se há próxima sem contar a coleção — que é o
    # que torna possível não devolver total sem mentir sobre a existência da página seguinte.
    # `:inicio` e não `nil`: nulo significaria "sem cursor", e a listagem voltaria à ordem
    # por nome da tela — a primeira página numa ordem e as seguintes noutra.
    cursor = params["after"] || :inicio
    equipes = EO.list_teams(tenant, limit: tamanho + 1, after: cursor)
    {pagina, tem_proxima?} = cortar(equipes, tamanho)

    json(conn, %{
      data: Enum.map(pagina, &serializar/1),
      page: %{
        has_next: tem_proxima?,
        next_cursor: if(tem_proxima?, do: List.last(pagina).id),
        total: nil,
        total_note:
          "This API does not count collections. An estimated total is worse than an absent one."
      }
    })
  end

  # FORA da descrição, de propósito: `operation false` diz ao gerador para ignorar esta
  # ação. Ela não é um endpoint — é a recusa dos métodos que o endpoint não tem, e
  # documentá-la como operação faria o Swagger oferecer `POST /teams` para ser experimentado.
  operation(:show,
    summary: "One team, with its composition and the reach it defines",
    description: """
    Mirrors `/teams/:id`. Unlike the listing, the detail **narrows by access**:
    `Tenants.pode_ver_equipe/3`, which has four paths — administration, a grant over this
    team, a grant over its organisation, or being a current member.

    Out of reach answers `404`, the same as a team that does not exist: a `403` would
    confirm the team exists, and for whoever is probing that is half the answer.
    """,
    parameters: [
      id: [in: :path, type: :string, description: "The team's platform id.", required: true]
    ],
    responses: [
      ok: {"The team", "application/json", Schemas.TeamDetail},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro},
      not_found: {"No such team within reach", "application/json", Schemas.Erro}
    ]
  )

  def show(conn, %{"id" => id}) do
    com_equipe(conn, id, fn tenant, equipe, motivo ->
      escopo = EO.team_roster_scope(tenant, equipe.id)
      partes = EO.team_parts(tenant, equipe.id)
      totais = EO.team_roster_totals(tenant, equipe.id, escopo: escopo)

      json(conn, %{data: detalhe(tenant, equipe, partes, totais, motivo)})
    end)
  end

  operation(:members,
    summary: "Who belongs to this team, and by which claim",
    description: """
    The roster, as the *structure* tab shows it. `origin` lives on each membership and not
    on the person: someone can be **observed** in one team and **declared** in another, and
    both claims hold at once.

    On a composed team the roster is the team plus its parts — the same reach the header
    counts, so the two never disagree.
    """,
    parameters: [
      id: [in: :path, type: :string, description: "The team's platform id.", required: true],
      page_size: [
        in: :query,
        type: :integer,
        description: "Default 50, maximum 200.",
        required: false
      ],
      after: [in: :query, type: :string, description: "Opaque cursor.", required: false]
    ],
    responses: [
      ok: {"The roster", "application/json", Schemas.TeamMembers},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro},
      not_found: {"No such team within reach", "application/json", Schemas.Erro}
    ]
  )

  def members(conn, %{"id" => id} = params) do
    com_equipe(conn, id, fn tenant, equipe, _motivo ->
      tamanho = tamanho_da_pagina(params)
      escopo = EO.team_roster_scope(tenant, equipe.id)

      # O roster pagina por DESLOCAMENTO, e não por cursor: ele é uma agregação por pessoa
      # sobre várias equipes, e não uma tabela com id ordenável. Dizer o contrário — expor
      # um `next_cursor` que na verdade é um deslocamento — faria quem integra confiar numa
      # estabilidade que não existe.
      pagina = EO.list_team_roster(tenant, equipe.id, escopo: escopo, limit: tamanho + 1)
      {linhas, tem_proxima?} = cortar(pagina, tamanho)

      json(conn, %{
        data: Enum.map(linhas, &membro/1),
        page: %{
          has_next: tem_proxima?,
          next_cursor: nil,
          total: EO.count_team_roster(tenant, equipe.id, escopo: escopo),
          total_note: @nota_do_total_do_roster
        }
      })
    end)
  end

  operation(:measures,
    summary: "The team's measures, as the dashboard shows them",
    description: """
    What an integration takes to a panel of its own. The window is **56 days, fixed and
    declared**: a measure over an undeclared window answers a different question without
    saying so.

    `time_to_first_review` says whether the list was **cut**, because a median over 200 of
    500 is a different measure wearing the same label.

    `skills.without_profile` comes **named**, never summed as zero: absence of a profile is
    absence of reading, so the coverage is a floor and never a ceiling.
    """,
    parameters: [
      id: [in: :path, type: :string, description: "The team's platform id.", required: true]
    ],
    responses: [
      ok: {"The measures", "application/json", Schemas.TeamMeasures},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro},
      not_found: {"No such team within reach", "application/json", Schemas.Erro}
    ]
  )

  def measures(conn, %{"id" => id}) do
    com_equipe(conn, id, fn tenant, equipe, _motivo ->
      json(conn, %{data: medidas(tenant, equipe)})
    end)
  end

  operation(:nao_permitido, false)

  @doc """
  A recusa de escrita — FR-017, e ela é do desenho, não da falta de implementação.

  **Não há autor honesto para a proveniência de uma escrita feita por token.** A plataforma
  registra quem declarou cada coisa, e um token é credencial de integração: atrás dele pode
  estar um painel, um script noturno ou um agente. Gravar "declarado por" com o nome da
  conta dona afirmaria algo que ninguém fez.
  """
  def nao_permitido(conn, _params) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:method_not_allowed))
    |> put_resp_header("allow", "GET, HEAD")
    |> json(Erro.corpo(:method_not_allowed, id))
  end

  # Pedido acima do teto é REDUZIDO ao teto, e não recusado: quem pede 1 000 quer o máximo
  # que puder ter, e recusar vira erro de parâmetro sem informação nova.
  defp tamanho_da_pagina(params) do
    case Integer.parse(to_string(params["page_size"] || "")) do
      {n, _} when n > 0 -> min(n, @teto)
      _ -> @padrao
    end
  end

  defp cortar(equipes, tamanho) do
    if length(equipes) > tamanho,
      do: {Enum.take(equipes, tamanho), true},
      else: {equipes, false}
  end

  # A MARCA DE ORIGEM viaja com cada equipe. A plataforma inteira existe para separar o que
  # foi observado do que foi declarado, e entregar sem a marca destruiria a distinção
  # exatamente no ponto de entrega — com o agravante de o consumidor previsto ser um modelo,
  # que afirmaria o dado sem ela.
  defp serializar(equipe) do
    observada? = not is_nil(equipe.source_system)

    %{
      id: equipe.id,
      name: equipe.name,
      slug: equipe.slug,
      origin: if(observada?, do: "observed", else: "declared"),
      source_system: equipe.source_system,
      collected_at: equipe.collected_at
    }
  end

  # ------------------------------------------------- o alcance, antes de qualquer leitura

  # **O veredito vem antes da carga**, e a recusa é `404` — nunca `403`.
  #
  # `403` diria "existe, e você não pode": para quem varre, é metade da resposta. `404` é a
  # mesma coisa que a rota devolve para equipe inexistente e para equipe de outro tenant, e
  # as três respostas são indistinguíveis de propósito.
  #
  # `fetch_team/2` já trata id malformado e outro tenant — resgata `CastError` e devolve
  # `:not_found`, que é por onde um id inventado cairia em `500`.
  defp com_equipe(conn, id, fun) do
    tenant = conn.assigns.current_tenant

    user = conn.assigns.current_user

    with {:ok, equipe} <- EO.fetch_team(tenant, id),
         {:ok, motivo} <- Tenants.pode_ver_equipe(tenant, user, equipe.id) do
      fun.(tenant, equipe, motivo)
    else
      # **A recusa deixa rastro** — feature 062, T022, achado N6. Antes, este `404` não
      # registrava nada, e a pergunta "esta credencial tentou ler qual equipe?" não tinha
      # resposta. Inexistente, de outro tenant e fora do alcance registram o mesmo motivo, porque
      # a resposta é a mesma.
      _ ->
        :ok = AccessEvents.equipe_recusada(user.id, tenant.id, id, :fora_do_alcance)
        nao_encontrado(conn)
    end
  end

  defp nao_encontrado(conn) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:not_found))
    |> json(Erro.corpo(:not_found, id))
  end

  # ------------------------------------------------------------------------- o detalhe

  defp detalhe(tenant, equipe, partes, totais, motivo) do
    %{
      id: equipe.id,
      name: equipe.name,
      slug: equipe.slug,
      origin: if(equipe.source_system, do: "observed", else: "declared"),
      provenance: %{
        source_system: equipe.source_system,
        source_instance: equipe.source_instance,
        external_id: equipe.external_id,
        first_observed_at: equipe.collected_at,
        last_observed_at: equipe.last_observed_at,
        no_longer_observed_at: equipe.no_longer_observed_at
      },
      organization: organizacao(tenant, equipe.organization_id),
      composition: %{
        is_composed: partes != [],
        parts: Enum.map(partes, &%{team_id: &1.team_id, name: &1.name, since: &1.desde}),
        note: @nota_da_composicao
      },
      # `current`, `left` e `mistakes` NUNCA se somam. *Saiu* diz que o vínculo existiu e
      # terminou; *equívoco* diz que nunca devia ter sido afirmado. Somá-los apagaria a
      # distinção que a revogação existe para manter — revogar marca, nunca apaga.
      roster: %{
        current: totais.vigentes,
        left: totais.sairam,
        mistakes: totais.equivocos
      },
      memberships_pending_role: EO.count_memberships_pending_role(tenant, team_id: equipe.id),
      # O motivo fica no vocabulário da REGRA — `escopo_de_equipe`, `vinculo_vigente` —, e
      # não é traduzido. Ele nomeia qual das quatro cláusulas de `pode_ver_equipe/3`
      # concedeu, e traduzir criaria um segundo nome para a mesma cláusula: quem lê o log
      # e quem lê a resposta deixariam de falar a mesma coisa.
      access: %{reason: to_string(motivo)}
    }
  end

  defp organizacao(_tenant, nil), do: nil

  defp organizacao(tenant, organization_id) do
    o = EO.fetch_organization!(tenant, organization_id)
    %{id: o.id, login: o.login, name: o.name}
  end

  # ------------------------------------------------------------------------- o roster

  defp membro(m) do
    %{
      person_id: m.person_id,
      name: m.name,
      login: m.login,
      situation: situacao(m.situacao),
      direct: m.direta?,
      squads: m.squads,
      memberships: Enum.map(m.vinculos, &vinculo/1)
    }
  end

  # A marca vive no VÍNCULO, e não na pessoa: alguém pode ser observado numa equipe e
  # declarado noutra, e as duas afirmações valem ao mesmo tempo.
  #
  # **Quem declarou não sai.** O campo é um endereço de e-mail, e e-mail é o dado que esta
  # API exclui de propósito — nas pessoas, pela mesma razão.
  defp vinculo(v) do
    %{
      membership_id: v.membership_id,
      team_id: v.team_id,
      team_name: v.team_name,
      origin: origem(v.origem),
      role: v.role && %{id: v.role.id, code: v.role.code, name: v.role.name},
      started_at: v.started_at,
      # `ended_at` diz *saiu*. `mistake` diz *nunca devia ter sido afirmado*. Achatá-los
      # faria história virar erro, e erro virar história.
      #
      # **Quem encerrou e quem invalidou NÃO saem** — defeito achado em 2026-09-25 pela revisão
      # de segurança do MCP (N1, N2). O domínio carrega o e-mail dos dois, e esta função o
      # repassava: `mistake` saía com `por: <e-mail>`, e `ended_at` saía como a tupla
      # `{:declarado, <e-mail>, …}`, que o Jason não serializa, e a rota dava 500 para toda
      # equipe com alguém que saiu. O `@moduledoc` do schema já dizia que e-mail não sai.
      ended_at: data_da_saida(v.fim),
      end_origin: origem_da_saida(v.fim),
      mistake: equivoco(v.equivoco),
      declared_at: v.declared_at,
      current: v.vigente?,
      direct: v.direta?
    }
  end

  # A saída, **sem o autor**. A origem fica, porque é a distinção da FR-022: a data de uma
  # saída pela coleta é quando a plataforma parou de ver, e não quando a pessoa saiu.
  # Casadas uma a uma: forma nova no domínio reprova aqui, em vez de sair crua.
  defp data_da_saida(nil), do: nil
  defp data_da_saida({:declarado, _autor, _registrado, quando}), do: quando
  defp data_da_saida({:coleta, quando}), do: quando
  defp data_da_saida({:sem_autor, quando}), do: quando

  defp origem_da_saida(nil), do: nil
  defp origem_da_saida({:declarado, _autor, _registrado, _quando}), do: "declared"
  defp origem_da_saida({:coleta, _quando}), do: "no_longer_observed"
  defp origem_da_saida({:sem_autor, _quando}), do: "declared_without_author"

  # O equívoco, **sem quem o marcou**: a razão e a data.
  defp equivoco(nil), do: nil
  defp equivoco(%{razao: razao, em: em}), do: %{reason: razao, at: em}

  # ------------------------------------------------------------------------ as medidas

  defp medidas(tenant, equipe) do
    agora = DateTime.utc_now(:second)
    desde = DateTime.add(agora, -@janela_em_dias, :day)

    instantaneo = TeamWork.snapshot(tenant, equipe.id, agora, desde: desde)
    tarefas = TeamWork.open_tasks_by_person(tenant, equipe.id, agora)

    # UMA a mais que o limite, para saber se cortou. Sem isso o corte é silencioso.
    carregadas =
      Quality.team_time_to_first_review(tenant, equipe.id,
        desde: desde,
        ate: agora,
        limit: @limite_de_esperas + 1
      )

    truncou? = length(carregadas) > @limite_de_esperas
    cobertura = Profiles.team_coverage(tenant, equipe.id)

    %{
      window: %{days: @janela_em_dias, from: desde, to: agora},
      work: %{
        members: instantaneo.membros,
        open: instantaneo.abertas,
        closed_in_window: instantaneo.fechadas_na_janela,
        stale: instantaneo.paradas,
        no_work: instantaneo.sem_trabalho?,
        note: @nota_do_trabalho
      },
      open_by_person:
        for {person_id, lista} <- tarefas, lista != [] do
          %{person_id: person_id, tasks: Enum.map(lista, &tarefa/1)}
        end,
      time_to_first_review: medianas(Enum.take(carregadas, @limite_de_esperas), truncou?),
      skills: %{
        members: cobertura.membros,
        with_profile: cobertura.com_perfil,
        # **NOMEADO, nunca somado como zero** — FR-004 da feature 029.
        without_profile:
          Enum.map(cobertura.sem_perfil, &%{person_id: &1.person_id, name: &1.name}),
        competencies:
          Enum.map(cobertura.competencias, fn c ->
            %{
              domain: c.nome,
              people: c.total_pessoas,
              completed_tasks: c.tarefas_somadas
            }
          end),
        coverage_note: @nota_da_cobertura,
        summary:
          Enum.map(Profiles.team_summary(cobertura), &%{type: to_string(&1.tipo), text: &1.frase})
      }
    }
  end

  # **AS DUAS MEDIANAS LADO A LADO, e nunca somadas.** Uma responde *quanto demorou o que
  # foi revisado*; a outra, *há quanto tempo espera o que não foi*. São perguntas
  # diferentes, com denominadores diferentes, e por isso cada uma leva o seu.
  #
  # `null` em qualquer das duas é a ausência DITA, nunca zero: zero afirmaria revisão
  # instantânea, ou espera instantânea.
  defp medianas(esperas, truncou?) do
    {aguardando, revisadas} = Enum.split_with(esperas, &match?({:aguardando, _}, &1.estado))

    %{
      items: Enum.map(esperas, &espera/1),
      reviewed: %{
        count: length(revisadas),
        median_hours: Quality.mediana_em_horas(esperas)
      },
      waiting: %{
        count: length(aguardando),
        median_days: Quality.mediana_da_espera_em_dias(esperas)
      },
      medians_note: @nota_das_medianas,
      limit: @limite_de_esperas,
      truncated: truncou?,
      truncated_note: @nota_do_corte
    }
  end

  # **A API fala UMA língua.** O domínio escreve em português — `:declarado`, `:vigente` —
  # e `to_string/1` derramaria isso no corpo: a listagem de equipes já devolve `observed` e
  # `declared`, e duas palavras para a mesma marca na mesma API fariam quem integra casar
  # pelas duas, ou pior, por uma só.
  #
  # Casadas uma a uma, e não traduzidas por tabela: átomo novo no domínio reprova aqui em
  # vez de sair cru na resposta.
  defp origem(:observado), do: "observed"
  defp origem(:declarado), do: "declared"

  defp situacao(:vigente), do: "current"
  defp situacao(:saiu), do: "left"
  defp situacao(:equivoco), do: "mistake"

  defp tarefa(t),
    do: %{
      issue_id: t.issue_id,
      external_id: t.external_id,
      title: t.titulo,
      concept: t.conceito,
      open_for_days: t.aberta_ha_dias,
      stale: t.parada?
    }

  # **Dois estados, e eles não se achatam num número só.**
  #
  # `reviewed` traz as HORAS que a espera levou; `waiting` traz os DIAS que ela já leva e
  # ainda não terminou. Um campo único de "segundos" afirmaria que a segunda terminou.
  #
  # E a espera em curso **não é omitida**: sem ela a mediana melhoraria quanto pior a
  # equipe estivesse, porque as que ninguém revisou são justamente as que mais interessam.
  # Contá-la como zero seria pior — afirmaria revisão instantânea onde não houve revisão.
  defp espera(e) do
    %{
      change_request_id: e.change_request_id,
      number: e.numero,
      title: e.titulo,
      opened_at: e.aberta_em,
      author_person_id: e.autor_person_id,
      author_login: e.autor_login
    }
    |> Map.merge(estado_da_espera(e.estado))
  end

  defp estado_da_espera({:revisada, horas}),
    do: %{state: "reviewed", waited_hours: horas, waiting_for_days: nil}

  defp estado_da_espera({:aguardando, dias}),
    do: %{state: "waiting", waited_hours: nil, waiting_for_days: dias}
end
