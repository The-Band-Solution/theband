defmodule TheBandWeb.Api.V1.PersonController do
  @moduledoc """
  `GET /api/v1/people` — as pessoas observadas (feature 061, FR-021).

  ## O recorte é o da tela, e a assimetria com o detalhe fica dita

  A tela `/people` **não filtra por `Access`**: ela lista as pessoas do tenant. Quem filtra é
  o **detalhe**, `/people/:id`, que chama `pode_ver/3` antes de mostrar o painel.

  Esta rota espelha a **listagem**, e por isso também não filtra. A rota de detalhe, quando
  existir, precisará do veredito — e é decisão própria, não extensão desta.

  ## `account_type` é a palavra da origem, e não um palpite

  O GitHub diz se a conta é pessoa, robô ou aplicação. Contar robô como pessoa inflaria toda
  medida de quem fez o trabalho — 160 de 357 movimentações medidas numa coleta eram de robô.

  ## `no_longer_observed_at` nulo significa ainda observada

  E **não** que a pessoa sumiu. Ausência escrita, nunca remoção silenciosa.

  ## O corpo carrega o que a tela mostra, e nada além

  Cada campo aqui é uma coluna de `/people`: nome e login, tipo de conta, organizações,
  fonte e instância, identificador na origem, data de coleta. Quem integra vê o mesmo que
  quem abre a tela — duas respostas diferentes para a mesma pergunta seriam duas verdades.

  **`email` fica de fora de propósito.** A tela não o mostra, e ele é dado pessoal que
  ninguém pediu: acrescentá-lo porque a coluna existe no banco alargaria o alcance da rota
  sem que nenhum requisito o justificasse.

  ## A organização de uma pessoa vem das equipes dela, e por isso pode faltar

  Não há vínculo direto entre pessoa e organização nesta ontologia. Quem não está em equipe
  alguma sai com `organizations` vazio **e com a razão escrita** em `organizations_note` —
  ausência escrita, nunca lista vazia sem explicação, que faria parecer que a busca foi
  feita e não achou nada.

  Quem está em mais de uma sai **uma vez**, com todas listadas. A consequência é que somar
  pessoas por organização dá mais que o total de pessoas, e isso está certo.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBand.Changes
  alias TheBand.Communication.Discussions
  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles
  alias TheBand.Profiles.Material
  alias TheBand.Tenants
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.User
  alias TheBand.Verification
  alias TheBand.WorkItems
  alias TheBandWeb.Api.V1.Erro
  alias TheBandWeb.Schemas

  require Logger

  @padrao 50
  @teto 200

  # A razão da ausência, na mesma frase que a tela usa. Ela não é decoração: sem ela, uma
  # lista vazia diria "esta pessoa não tem organização", quando o que houve foi que o
  # vínculo não existe — ele viria das equipes, e a pessoa não está em nenhuma.
  @sem_organizacao "no team — organisation unknown"

  # A escala da série é FIXA em mês nesta fatia, e a resposta declara qual usou. A tela
  # oferece semana, mês e ano; oferecê-las aqui é item próprio. O que não pode faltar é a
  # declaração: uma série sem escala significa coisas diferentes sem avisar.
  @escala :mes
  @rotulo_da_escala "monthly"

  # Os limites que a consulta usa, em dias. Viajam junto do rótulo porque o rótulo é o da
  # tela, em português, e não serve de chave: quem integra ordena e compara pelos limites.
  @limites_das_faixas %{
    "até 7d" => {0, 7},
    "7–30d" => {7, 30},
    "30–90d" => {30, 90},
    "90–180d" => {90, 180},
    "mais de 180d" => {180, nil}
  }

  @nota_das_organizacoes "Two different claims, never summed. `by_membership` climbs " <>
                           "person → team → organisation. `by_work` is observed end to end: " <>
                           "person → issue → repository → organisation. Someone who left " <>
                           "before the platform started observing was never in a team, and " <>
                           "the work stayed."

  @nota_das_contagens "Never summed. Opening an issue and working on it are different " <>
                        "acts, with different participations in the ontology."

  @sem_papel "No role declared for this person. A role is declared on this platform, never " <>
               "observed at the source — an empty list means nobody declared one, not that " <>
               "the person has none."

  @sem_conta "No account on this platform is declared to be this observed person."

  # Os limites que a tela usa. Viajam na resposta em `limit`, porque uma lista truncada em
  # silêncio faz quem integra concluir que aquilo é tudo.
  @discussoes 20
  @mudancas 10
  @issues 25

  @nota_das_mudancas "Four lists, never summed. Opening, reviewing, merging and committing " <>
                       "are distinct acts, and the same change request can appear in more " <>
                       "than one — a total would count it twice."

  @nota_das_issues "The screen's first page. Searching and paging the whole assigned list " <>
                     "is its own resource, and does not exist yet."

  @nota_da_evolucao "One point per generation, oldest first. A month with no generation " <>
                      "is absent, never interpolated: filling it in would claim an " <>
                      "observation that never happened."

  # A razão de `competencies` ser `null` — e não `[]`. Ver `competencias_curtas/1`.
  @sem_leitura "No profile has been generated, so no competency was read. This is absence " <>
                 "of reading, not absence of skill — an empty list would say the record was " <>
                 "read and nothing was demonstrated, which is a different claim."

  @sem_perfil "No profile has been generated for this person. When present it is `derived` " <>
                "— written by a language model from the collected record, never an observation."

  @perfil_derivado "Written by a language model from the collected record. It is derived, " <>
                     "never observed, and it is not evidence of anything the source said"

  tags(["people"])

  operation(:index,
    summary: "People observed at connected tools",
    description: """
    Everyone the platform observed, with the mark of where it learned about them and the
    source's own word for what kind of account it is.

    Mirrors the `/people` screen, which lists the tenant and does not narrow by access. The
    **detail** of a person does narrow — that is a different endpoint, and it does not exist
    yet.

    Every field here is a column of that screen. A person's organisations come from their
    teams: there is no direct link between person and organisation, so whoever is in no team
    comes back with an empty `organizations` and the reason in `organizations_note`. Whoever
    is in more than one comes back **once**, with all of them listed — so people counted per
    organisation add up to more than the total, and that is correct.

    `email` is not returned. The screen does not show it and no requirement asks for it.
    """,
    parameters: [
      page_size: [
        in: :query,
        type: :integer,
        description: "Default 50, maximum 200. A larger value is reduced, not refused.",
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
      ok: {"The people", "application/json", Schemas.People},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro}
    ]
  )

  def index(conn, params) do
    tamanho = tamanho_da_pagina(params)
    cursor = params["after"] || :inicio

    tenant = conn.assigns.current_tenant
    pessoas = EO.list_people(tenant, limit: tamanho + 1, after: cursor)
    {pagina, tem_proxima?} = cortar(pessoas, tamanho)

    # UMA consulta para a página inteira, nunca uma por pessoa (lição L38). É a mesma
    # função que a tela usa, e é de propósito: duas maneiras de responder "de que
    # organização é esta pessoa" divergiriam, e a divergência apareceria como dado.
    ids = Enum.map(pagina, & &1.id)
    orgs = EO.organizations_by_person(tenant, ids)

    # Os perfis vigentes da página inteira numa consulta, como as organizações (L38). As
    # competências saem daí: são leitura pura do perfil, e não uma segunda derivação.
    perfis = EO.current_profiles(tenant, ids)

    json(conn, %{
      data: Enum.map(pagina, &serializar(&1, orgs, perfis)),
      page: %{
        has_next: tem_proxima?,
        next_cursor: if(tem_proxima?, do: List.last(pagina).id),
        total: nil,
        total_note:
          "This API does not count collections. An estimated total is worse than an absent one."
      }
    })
  end

  operation(:show,
    summary: "One person, with everything the person's screen shows",
    description: """
    Mirrors the `/people/:id` screen, including the work panel — and including the access
    verdict that decides whether the work panel exists at all.

    `:id` is the **platform's** identifier, not the source's. A person of another tenant
    answers `404`, the same as one that does not exist: telling them apart would confirm to
    whoever is probing that the id exists somewhere.

    The reach of the request is the reach of **whoever created the token**. A token carries
    no more than its owner sees on the screen, `access.can_see_work` says what the verdict
    was, and a refusal is recorded exactly as the screen records it.
    """,
    parameters: [
      id: [in: :path, type: :string, description: "The person's platform id.", required: true]
    ],
    responses: [
      ok: {"The person", "application/json", Schemas.PersonDetail},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro},
      not_found: {"No such person in this tenant", "application/json", Schemas.Erro}
    ]
  )

  def show(conn, %{"id" => id}) do
    tenant = conn.assigns.current_tenant

    # `Ecto.UUID.cast/1` ANTES da consulta: um id malformado levantaria `Ecto.Query.CastError`
    # e viraria 500. Id que não é id é o mesmo caso de id que não existe — e a mesma resposta
    # de pessoa de outro tenant, que `fetch_person/2` já trata.
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         {:ok, pessoa} <- EO.fetch_person(tenant, uuid) do
      json(conn, %{data: detalhe(conn, tenant, pessoa)})
    else
      _ -> nao_encontrado(conn)
    end
  end

  defp nao_encontrado(conn) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:not_found))
    |> json(Erro.corpo(:not_found, id))
  end

  operation(:nao_permitido, false)

  @doc "A recusa de escrita — FR-017. Ver `TeamController.nao_permitido/2`."
  def nao_permitido(conn, _params) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:method_not_allowed))
    |> put_resp_header("allow", "GET, HEAD")
    |> json(Erro.corpo(:method_not_allowed, id))
  end

  defp tamanho_da_pagina(params) do
    case Integer.parse(to_string(params["page_size"] || "")) do
      {n, _} when n > 0 -> min(n, @teto)
      _ -> @padrao
    end
  end

  defp cortar(pessoas, tamanho) do
    if length(pessoas) > tamanho,
      do: {Enum.take(pessoas, tamanho), true},
      else: {pessoas, false}
  end

  # **`null` e `[]` dizem coisas diferentes, e a diferença é a FR-023.**
  #
  # Sem perfil vigente: `null`, e a razão em `competencies_note` — não houve leitura. Com
  # perfil e nenhum destaque com tarefa concluída: `[]` — houve leitura, e nada foi
  # demonstrado. Achatar as duas em `[]` transformaria lacuna do registro em julgamento da
  # pessoa, que é exactamente o que aquela FR existe para impedir.
  #
  # Aqui vai a forma CURTA — domínio e tarefas. A evidência issue por issue está no detalhe:
  # 80 pessoas × 3 competências × 3 números na listagem seria payload sem consumidor.
  defp competencias_curtas(nil), do: nil

  defp competencias_curtas(perfil) do
    for c <- EO.Profiles.competencies(perfil), do: %{domain: c.nome, completed_tasks: c.tarefas}
  end

  defp serializar(pessoa, orgs, perfis) do
    # `Map.get(orgs, id, [])` e não `orgs[id]`: quem não tem equipe **não está no mapa**, e
    # a consulta em lote documenta isso — a chave ausente não é erro, é o caso comum.
    organizacoes = Map.get(orgs, pessoa.id, [])

    %{
      id: pessoa.id,
      name: pessoa.name,
      login: pessoa.login,
      account_type: pessoa.account_type,
      origin: if(pessoa.source_system, do: "observed", else: "declared"),
      source_system: pessoa.source_system,
      source_instance: pessoa.source_instance,
      external_id: pessoa.external_id,
      organizations: Enum.map(organizacoes, &%{id: &1.id, login: &1.login, name: &1.name}),
      organizations_note: if(organizacoes == [], do: @sem_organizacao),
      competencies: competencias_curtas(perfis[pessoa.id]),
      competencies_note: if(is_nil(perfis[pessoa.id]), do: @sem_leitura),
      collected_at: pessoa.collected_at,
      no_longer_observed_at: pessoa.no_longer_observed_at
    }
  end

  # ------------------------------------------------------------------ o detalhe

  defp detalhe(conn, tenant, pessoa) do
    # O VEREDITO VEM ANTES DA CARGA, e não antes da serialização (issue #369, FR-012).
    #
    # Calcular a vazão, o lead time e os antipadrões de quem não pode vê-los é fazer o
    # trabalho do vazamento e depois esconder o resultado: o custo fica igual e o dado
    # existe em memória. Aqui a recusa poupa as consultas do painel inteiro.
    usuario = conn.assigns.current_user
    {alcance, motivo} = Tenants.pode_ver(tenant, usuario, pessoa.id)

    # A RECUSA REGISTRADA — achado H4, e a FR-024 da spec 045 depende dela.
    #
    # Aquela FR aceita o risco de agregação — alguém que alcança muitos itens reconstrói por
    # acumulação o que o veredito recusa direto — e aponta o registro de acesso como o
    # caminho para percebê-lo. Uma rota de API que recusasse sem registrar abriria esse
    # caminho com MENOS atrito que a tela: um laço sobre a listagem percorre o tenant
    # inteiro sem deixar nada escrito.
    if alcance == :nao do
      AccessEvents.painel_recusado(usuario.id, tenant.id, pessoa.id, motivo)
    end

    ve? = alcance == :ok

    # UMA leitura de cada coisa, e as duas seções que precisam delas compartilham.
    # `repositories_of_person/2` e `CMPO.list_observed/1` alimentam tanto a procedência
    # (`by_work`) quanto o painel de trabalho, e consultá-las duas vezes dobraria o custo
    # da rota sem mudar a resposta.
    #
    # Repare que as duas ficam FORA do veredito: a tela também as calcula sempre. "Trabalhou
    # nesta organização" é procedência, e não o painel que o veredito protege.
    repositorios = WorkItems.repositories_of_person(tenant, pessoa.id)
    observados = Map.new(CMPO.list_observed(tenant), &{&1.observed_repository_id, &1})

    organizacoes = EO.list_person_organizations(tenant, pessoa.id)
    perfil = perfil_da_pessoa(tenant, pessoa.id)
    papeis = EO.list_person_roles(tenant, pessoa.id)

    %{
      id: pessoa.id,
      name: pessoa.name,
      login: pessoa.login,
      account_type: pessoa.account_type,
      origin: if(pessoa.source_system, do: "observed", else: "declared"),
      provenance: %{
        source_system: pessoa.source_system,
        source_instance: pessoa.source_instance,
        external_id: pessoa.external_id,
        first_observed_at: pessoa.collected_at,
        last_observed_at: pessoa.last_observed_at,
        no_longer_observed_at: pessoa.no_longer_observed_at
      },
      organizations: %{
        by_membership: Enum.map(organizacoes, &organizacao/1),
        by_work: organizacoes_do_trabalho(tenant, organizacoes, repositorios, observados),
        note: @nota_das_organizacoes
      },
      teams: Enum.map(EO.list_person_teams(tenant, pessoa.id), &equipe/1),
      roles: Enum.map(papeis, &papel/1),
      roles_note: if(papeis == [], do: @sem_papel),
      account: conta(tenant, pessoa.id),
      profile: perfil,
      profile_note: if(is_nil(perfil), do: @sem_perfil),

      # **FORA do veredito, porque na tela também estão fora.** As duas seções vivem em
      # *Where this came from*, que não é o painel que o veredito protege. Protegê-las aqui
      # estreitaria o alcance pela porta do transporte — o mesmo erro do outro lado.
      discussion_participation: %{
        items:
          Enum.map(
            Discussions.participation_of(tenant, pessoa.id, limit: @discussoes),
            &discussao/1
          ),
        limit: @discussoes
      },
      changes: mudancas(tenant, pessoa.id),
      access: %{can_see_work: ve?, reason: if(not ve?, do: to_string(motivo))},
      work: if(ve?, do: trabalho(tenant, pessoa.id, repositorios, observados))
    }
  end

  # ----------------------------------------------------------------- o trabalho

  # Só é chamada quando o veredito é `:ok` — ver `detalhe/3`.
  defp trabalho(tenant, person_id, repositorios, observados) do
    serie = WorkItems.state_changes_by_period(tenant, person_id, @escala)
    {observada, total} = WorkItems.timeline_coverage(tenant, person_id)
    prazo = WorkItems.prazo_do_trabalho_aberto(tenant, person_id)

    %{
      # As duas contagens NÃO se somam, e a resposta diz isso em `counts_note`. Quem abre
      # uma issue não necessariamente trabalha nela, e a soma não aparece na tela.
      assigned: WorkItems.count_assigned_to(tenant, person_id),
      authored: WorkItems.count_authored_by(tenant, person_id),
      counts_note: @nota_das_contagens,
      open_assigned: total,
      timeline_coverage: %{observed: observada, total: total},
      scale: @rotulo_da_escala,
      series_by_period:
        Enum.map(serie, &%{period: &1.periodo, created: &1.criadas, closed: &1.fechadas}),
      burn:
        Enum.map(
          WorkItems.burn(serie),
          &%{period: &1.periodo, scope: &1.escopo, done: &1.feito, open: &1.aberto}
        ),
      projection: projecao(WorkItems.projecao(serie)),
      deadline: %{
        date: prazo.prazo,
        source: prazo.origem && to_string(prazo.origem),
        without_time_box: prazo.sem_caixa
      },
      age_buckets: Enum.map(WorkItems.open_age_buckets(tenant, person_id), &faixa/1),
      lead_time: lead_time(WorkItems.lead_time(tenant, person_id)),
      verification: verificacao(Verification.por_pessoa(tenant, person_id)),
      change_participation: participacao(Changes.participacao_da_pessoa(tenant, person_id)),
      antipatterns: antipadroes(Antipatterns.detect_for_person(tenant, person_id)),
      repositories: Enum.map(repositorios, &repositorio(&1, observados)),

      # DENTRO do veredito, porque na tela está dentro do painel.
      #
      # `stale_after_days` viaja junto: "parada" não é adjetivo, é um corte em dias, e sem
      # o corte o número não diz nada. Quem integra compara com o próprio critério.
      stale_open: %{
        stale_after_days: Material.stale_days(),
        items: Enum.map(Profiles.stale_open_with_conversation(tenant, person_id), &parada/1)
      },
      issues: %{
        items:
          Enum.map(
            WorkItems.list_issues(tenant, assigned_to: person_id, limit: @issues),
            &issue/1
          ),
        limit: @issues,
        note: @nota_das_issues
      }
    }
  end

  # `null`, e não zero: não há issue concluída, e zero dia de lead time é outra afirmação.
  defp lead_time(nil), do: nil
  defp lead_time(%{count: c, median: m, p85: p}), do: %{count: c, median_days: m, p85_days: p}

  # `unattributed_in_tenant` fica FORA das três primeiras. São execuções que não casam com
  # pessoa alguma, e somá-las às desta pessoa afirmaria medida onde não há.
  defp verificacao(%{passou: p, quebrou: q, outras: o, sem_autoria_no_tenant: s}),
    do: %{passed: p, broke: q, other: o, unattributed_in_tenant: s}

  # Seis leituras que nunca se somam: abrir, integrar, revisar, e os três vereditos.
  defp participacao(%{abriu: ab, integrou: i, revisou: r, endossou: e, objetou: o, absteve: a}),
    do: %{opened: ab, merged: i, reviewed: r, endorsed: e, objected: o, abstained: a}

  # `not_assessed` existe para NÃO virar zero: três issues não avaliadas não são três issues
  # sem antipadrão. Ausência escrita.
  defp antipadroes(%{achados: achados, avaliadas: av, nao_avaliadas: na}),
    do: %{
      findings: Enum.map(achados, &%{id: &1.id, count: &1.count}),
      assessed: av,
      not_assessed: na
    }

  # O rótulo é o da tela, em português. Os limites viajam junto porque é por eles que quem
  # integra ordena e compara — rótulo não é chave estável.
  defp faixa(%{label: rotulo, count: n}) do
    {minimo, maximo} = Map.fetch!(@limites_das_faixas, rotulo)
    %{label: rotulo, min_days: minimo, max_days: maximo, count: n}
  end

  defp projecao({:converge, n}), do: %{type: "converges", periods: n}

  defp projecao({:nao_converge, criadas, fechadas}),
    do: %{type: "does_not_converge", created: criadas, closed: fechadas}

  defp projecao({:alem_do_observado, n, observados}),
    do: %{type: "beyond_observed", periods: n, observed_periods: observados}

  defp projecao(atomo), do: %{type: to_string(atomo)}

  # ------------------------------------------------------------------- pedaços

  defp organizacao(o), do: %{id: o.id, login: o.login, name: o.name}

  defp discussao(d),
    do: %{
      issue_id: d.issue_id,
      number: d.number,
      title: d.title,
      state: d.state,
      # `atos` são POSIÇÕES TOMADAS, e não issues: quem comentou cinco vezes na mesma issue
      # aparece com cinco atos e uma issue. Somá-los como issues inflaria a participação.
      acts: d.atos,
      first_act: d.primeiro,
      last_act: d.ultimo
    }

  # **Quatro listas, nunca somadas.** Abrir, revisar, integrar e commitar são atos
  # distintos, com participações distintas na ontologia — e a mesma solicitação pode
  # aparecer em mais de uma. Um total aqui contaria gente duas vezes.
  defp mudancas(tenant, person_id) do
    m = Changes.by_person(tenant, person_id, limit: @mudancas)

    %{
      opened: Enum.map(m.abertas, &solicitacao/1),
      reviewed: Enum.map(m.revisadas, &solicitacao/1),
      merged: Enum.map(m.integradas, &solicitacao/1),
      commits: Enum.map(m.commits, &commit/1),
      limit: @mudancas,
      note: @nota_das_mudancas
    }
  end

  defp solicitacao(c),
    do: %{
      id: c.id,
      number: c.number,
      title: c.title,
      state: c.state,
      created_at: c.created_at,
      merged_at: c.merged_at
    }

  defp commit(c),
    do: %{
      id: c.id,
      sha: c.sha,
      headline: c.headline,
      committed_at: c.committed_at,
      change_request_number: c.change_request_number,
      primary: c.is_primary
    }

  # `conversation` distingue TRÊS coisas que uma lista de issues paradas achataria:
  # `nao_coletada` (o repositório não teve comentário coletado — lacuna da coleta),
  # `silencio` (foi coletado e não houve ato) e `recente`/`antiga` (houve, e quando).
  # Sem essa distinção, lacuna de coleta leria como silêncio da equipe.
  defp parada(t),
    do: %{
      id: t.id,
      number: t.number,
      title: t.titulo,
      type: t.tipo,
      days_open: t.dias_aberta,
      repository: t.repositorio,
      own_authorship: t.autoria_propria,
      conversation: to_string(t.conversa),
      acts: t.atos,
      last_act: t.ultimo_ato
    }

  defp issue(i),
    do: %{
      id: i.id,
      number: i.number,
      title: i.title,
      state: i.state,
      issue_type: i.issue_type,
      repository_id: i.observed_repository_id
    }

  # Qual conta desta plataforma foi declarada como sendo esta pessoa observada.
  #
  # `link_coverage` vai junto porque um elo ausente é LACUNA, e não zero: "nenhuma conta é
  # esta pessoa" e "duas de sete contas foram declaradas" respondem perguntas diferentes, e
  # sem o denominador a primeira soa como defeito quando é só o estado da declaração.
  #
  # UMA consulta: as contas do tenant vêm inteiras, e tanto "qual delas é esta pessoa"
  # quanto a cobertura saem delas em memória.
  defp conta(tenant, person_id) do
    contas = Tenants.list_users(tenant)
    minha = Enum.find(contas, &(&1.person_id == person_id and User.elo_vigente?(&1)))

    %{
      linked_user_id: minha && minha.id,
      note: if(is_nil(minha), do: @sem_conta),
      link_coverage: %{
        accounts: length(contas),
        declared: Enum.count(contas, &User.elo_vigente?/1)
      }
    }
  end

  # As organizações em que a pessoa TRABALHOU, **menos** aquelas de que ela já é membro.
  # A subtração é o que mantém as duas afirmações separadas: repetir a mesma organização
  # nas duas listas faria quem lê supor que são duas evidências, quando é uma.
  defp organizacoes_do_trabalho(tenant, por_equipe, repositorios, observados) do
    ja_membro = MapSet.new(por_equipe, & &1.id)

    repositorios
    |> Enum.map(&Map.get(observados, &1.observed_repository_id))
    |> Enum.reject(
      &(is_nil(&1) or is_nil(&1.organization_id) or MapSet.member?(ja_membro, &1.organization_id))
    )
    |> Enum.group_by(& &1.organization_id)
    |> Enum.map(fn {organization_id, repos} ->
      %{
        organization: organizacao(EO.fetch_organization!(tenant, organization_id)),
        repositories: length(repos)
      }
    end)
  end

  # Papéis DECLARADOS, vigentes **e** encerrados. Esconder o encerrado apagaria história:
  # quem saiu do papel continua tendo desempenhado, e `ended_at` diz quando parou.
  #
  # **Quem declarou não sai daqui.** A consulta traz o e-mail de quem declarou, e e-mail é o
  # dado que esta rota exclui de propósito — na listagem, pela mesma razão. Expô-lo aqui
  # porque a consulta já o carrega desfaria a decisão por acidente.
  defp papel(r) do
    %{
      id: r.id,
      role_code: r.role_code,
      role_name: r.role_name,
      team_id: r.team_id,
      team_name: r.team_name,
      started_at: r.started_at,
      ended_at: r.ended_at,
      current: is_nil(r.ended_at)
    }
  end

  defp equipe(e) do
    %{
      team_id: e.team_id,
      team_name: e.team_name,
      organization_login: e.organization_login,
      platform_access_level: e.platform_access_level,
      observed_at: e.observed_at,
      last_observed_at: e.last_observed_at,
      no_longer_observed_at: e.no_longer_observed_at,
      promoted: e.promoted?
    }
  end

  defp repositorio(r, observados) do
    obs = Map.get(observados, r.observed_repository_id)

    %{
      repository_id: r.observed_repository_id,
      name: obs && obs.name,
      qualified_name: obs && obs.qualified_name,
      assigned: r.assigned,
      authored: r.authored
    }
  end

  # O perfil é DERIVADO — escrito por um modelo de linguagem —, e a marca viaja no corpo.
  # Entregá-lo sem ela destruiria a distinção que a plataforma inteira existe para manter,
  # e com o agravante de o consumidor previsto ser outro modelo, que o afirmaria como fato.
  defp perfil_da_pessoa(tenant, person_id) do
    case EO.current_profile(tenant, person_id) do
      {:ok, p} -> perfil(tenant, person_id, p)
      {:error, :not_found} -> nil
    end
  end

  defp perfil(tenant, person_id, p) do
    c = p.content

    %{
      origin: "derived",
      origin_note: @perfil_derivado,
      generated_at: p.generated_at,
      model: p.model,
      period: %{from: p.period_from, to: p.period_to},
      # **FR-016.** Sem isto um perfil de dezembro parece atual em junho, e quem lê decide
      # com texto velho sem saber que é velho. Sai da diferença entre o recorte gravado e o
      # que existe hoje.
      tasks_closed_since: Profiles.tasks_since(tenant, person_id, p),
      regeneration_pending: Profiles.pending?(tenant, person_id),
      citations_removed: p.citations_removed,

      # AS COMPETÊNCIAS, e cada uma desce até as issues que a sustentam. A célula é
      # `completed_tasks`: tarefa CONCLUÍDA. Entrega, nunca promessa — tarefa aberta é
      # intenção e não demonstra nada.
      competencies: competencias_longas(p),
      # Os rótulos que o modelo escreveu. **Não são as competências**: não têm contagem nem
      # evidência, e tratá-los como equivalentes daria a mesma autoridade a um domínio com
      # 18 tarefas e a uma palavra solta.
      skills: List.wrap(c["habilidades"]),
      gaps: List.wrap(c["lacunas"]),

      # A ordem dos três é conteúdo, e não alfabética: forças, evolução, atenção. Trocar
      # atenção por forças mudaria o que quem gere lê primeiro.
      summary: %{
        strengths: get_in(c, ["resumo", "forcas"]),
        evolution: get_in(c, ["resumo", "evolucao"]),
        attention: get_in(c, ["resumo", "atencao"])
      },
      allocation: Enum.map(List.wrap(c["alocacao"]), &alocacao/1),
      trajectory: Enum.map(List.wrap(c["trajetoria"]), &trecho_da_trajetoria/1),
      recommendations: List.wrap(c["recomendacoes"]),

      # As três ressalvas que o perfil carrega sobre si mesmo, e elas não são decoração:
      # dizem o que o registro NÃO alcança, o que é do time e não da pessoa, e se houve
      # escrita para outros. Entregar o perfil sem elas entregaria conclusão sem limite.
      limits: %{
        beyond_reach: c["nao_alcanca"],
        team_not_person: c["do_time_nao_da_pessoa"],
        wrote_for_others: c["escreveu_para_outros"]
      },
      evolution_over_time: evolucao(tenant, person_id)
    }
  end

  defp competencias_longas(perfil) do
    for c <- EO.Profiles.competencies(perfil) do
      %{
        domain: c.nome,
        completed_tasks: c.tarefas,
        demonstrated: c.demonstrou,
        evidence_issue_numbers: c.evidencia,
        periods: c.periodos,
        most_recent_period: c.mais_recente
      }
    end
  end

  defp alocacao(a),
    do: %{
      from: a["de"],
      to: a["ate"],
      domain: a["dominio"],
      demonstrated: a["demonstrou"],
      completed_tasks: a["tarefas"]
    }

  defp trecho_da_trajetoria(t),
    do: %{
      period: t["periodo"],
      months: t["meses"],
      text: t["texto"],
      cited_tasks: List.wrap(t["tarefas_citadas"])
    }

  # A série por geração. Mês sem geração NÃO entra: interpolar afirmaria observação que não
  # houve (feature 029, FR-003).
  defp evolucao(tenant, person_id) do
    # **Da mais ANTIGA para a mais recente.** `EO.list_profiles/2` devolve ao contrário — é
    # o que a lista de gerações da tela quer — e uma série temporal ao contrário desenharia
    # a evolução de trás para frente, com a competência parecendo encolher. O teste pegou.
    geracoes = tenant |> EO.list_profiles(person_id) |> Enum.sort_by(& &1.generated_at, DateTime)

    %{
      generations:
        Enum.map(geracoes, fn g ->
          %{
            generated_at: g.generated_at,
            competencies: Map.new(EO.Profiles.competencies(g), &{&1.nome, &1.tarefas})
          }
        end),
      note: @nota_da_evolucao
    }
  end
end
