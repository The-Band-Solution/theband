defmodule TheBand.Ingestion.GithubWorkItems do
  @moduledoc """
  Coleta repositórios e issues de uma organização observada (feature 004, F2 e F3).

  ## Por que não é um worker Oban próprio

  Era, e virou fase da sincronização existente. Decisão da pessoa mantenedora:
  **sincronizar traz tudo**.

  Dois workers produziriam dois registros de `sync` para uma única ação de quem opera, e
  a pergunta "o que esta sincronização trouxe" passaria a ter duas respostas parciais.
  Pior: a tela de sincronizações mostraria duas linhas por coleta, e quem lesse
  concluiria que houve duas.

  Uma fase da mesma execução mantém um registro, um relatório, e a ordem garantida —
  pessoas e equipes antes de repositórios e issues, o que importa porque a organização
  precisa existir para o repositório apontar para ela.

  ## A ordem, e ela é a regra

  1. **repositórios** — descobertos a partir da organização, sem exigir conectar cada um;
  2. **issues, por repositório** — e o repositório é o **escopo da marca de ausência**;
  3. **vínculos de decomposição** — depois de todas as issues existirem, porque uma parte
     pode ser coletada depois do pai;
  4. **promoção** — por último, porque ela depende dos vínculos: épico é derivado das
     partes, e classificar antes de conhecê-las daria atômica para tudo.

  Inverter 3 e 4 é o defeito silencioso desta coleta: cada issue funcionaria, e a
  classificação sairia errada em todas as que têm partes.

  ## A marca de ausência é por repositório

  `mark_issues_no_longer_observed/3` e `mark_decomposition_links_no_longer_observed/3` são
  chamadas **uma vez por repositório coletado**, com o id dele. Chamar por tenant marcaria
  o que esta execução nunca olhou — a L19 numa organização de 14 repositórios atingiria 13.

  Repositório excluído pelo tenant ou inacessível **não é coletado e não é marcado**: a
  plataforma parou de olhar, e isso não é o mesmo que o dado ter sumido.

  **O vínculo é marcado no escopo do repositório do pai**, e depois de `vincular/2`. A
  ordem contra a promoção é carga, não estilo: `classification/2` conta **só vínculos
  vigentes**, e promover antes de marcar classificaria um pai como épico por causa de
  partes que a origem não declara mais. Marcar dentro de `coletar_issues/2` garante que
  toda marca aconteceu antes de `promover/2`, que roda depois de todos os repositórios.
  """
  require Logger

  alias TheBand.Ingestion
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Mapping
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.SemanticIntegration.Mapper
  alias TheBand.WorkItems

  @page_size 50

  @doc """
  Coleta repositórios e issues, como fase da sincronização em andamento.

  Recebe o mesmo `ctx` da coleta de EO — tenant, sync, tool e token — e devolve o que
  coletou, para o relatório. **Não** encerra o `sync`: quem encerra é a sincronização,
  uma vez só.
  """
  @spec collect(map()) :: {:ok, map()} | {:error, term()}
  def collect(ctx) do
    run(Map.put_new(ctx, :started_at, ctx.sync.started_at))
  end

  defp run(ctx) do
    # O mapa login → pessoa vem **uma vez**, e não por issue: 4455 issues resolvendo
    # autor e designados por consulta seriam 4455 idas ao banco só para isso.
    ctx = Map.put(ctx, :pessoas, EO.person_ids_by_login(ctx.tenant))

    with {:ok, organization} <- organizacao(ctx),
         {:ok, repositorios} <- coletar_repositorios(ctx, organization) do
      # **O `ctx` é fiado, e não fixo.** O mapa login → pessoa nasce antes do primeiro repositório,
      # e a coleta passou a criar pessoas: sem fiar, quem nascesse no repositório 3 não existiria no
      # mapa ao coletar o 4, e as issues dela ficariam sem vínculo até a coleta seguinte — em alguns
      # repositórios sim, em outros não, na mesma execução e sem erro nenhum.
      {resultado, _ctx} = Enum.map_reduce(repositorios, ctx, &coletar_issues(&2, &1))

      # **Depois de todas as marcas de ausência**, e isso é carga: a classificação conta só
      # vínculos vigentes, e promover antes de marcar afirmaria épico por parte largada.
      promover(ctx, organization)

      {:ok,
       %{
         organization_id: organization.id,
         repositories: length(repositorios),
         issues: Enum.sum(Enum.map(resultado, & &1.coletadas)),
         unreachable: Enum.count(resultado, &(&1.alcancado == false)),
         decomposition_links_absent: Enum.sum(Enum.map(resultado, & &1.vinculos_ausentes))
       }}
    end
  end

  # A organização já foi coletada pela ingestão de EO. Aqui ela é só localizada — criar
  # outra faria a mesma organização existir duas vezes.
  defp organizacao(ctx) do
    case EO.fetch_organization_by_login(ctx.tenant.id, ctx.tool.organization_login) do
      nil -> {:error, {:organization_not_found, ctx.tool.organization_login}}
      organization -> {:ok, organization}
    end
  end

  # ------------------------------------------------------------------ repositórios

  defp coletar_repositorios(ctx, organization) do
    with {:ok, nodes, total} <-
           paginar(ctx, "repositories", %{organization: ctx.tool.organization_login}) do
      repositorios =
        Enum.map(nodes, fn node ->
          {:ok, repo} = gravar_repositorio(ctx, organization, node)
          {:ok, observado} = CMPO.observe_repository(ctx.tenant, ctx.tool.id, repo.id)
          ctx.sync |> Ingestion.reload() |> Ingestion.tally(:unchanged)
          %{repo: repo, observed_repository_id: observado.id, node: node}
        end)

      # Checkpoint **depois** de processar, nunca antes — e é o que a tela lê para dizer
      # em que fase a coleta está. Sem ele, o progresso seria um spinner sem informação.
      Ingestion.checkpoint_page(ctx.sync, "github.repository", nil, length(nodes), total)
      Ingestion.broadcast(ctx.tenant.id, {:sync_progress, ctx.sync.id, "github.repository"})

      # Só os coletáveis seguem: excluído e inacessível ficam de fora, e nenhum dos dois
      # tem a ausência marcada por causa disso.
      coletaveis =
        ctx.tenant
        |> CMPO.list_collectable(ctx.tool.id)
        |> MapSet.new(& &1.observed_repository_id)

      {:ok, Enum.filter(repositorios, &MapSet.member?(coletaveis, &1.observed_repository_id))}
    end
  end

  defp gravar_repositorio(ctx, organization, node) do
    now = DateTime.utc_now(:second)

    RawData.store(%{
      tenant_id: ctx.tenant.id,
      sync_id: ctx.sync.id,
      raw_entity_type: "github.repository",
      external_id: node["id"],
      payload: node,
      mapping_id: "github.repository.to.cmpo.source_repository",
      mapping_version: 3,
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      collected_at: now
    })

    CMPO.upsert_source_repository_from_source(ctx.tenant, %{
      organization_id: organization.id,
      name: node["name"],
      qualified_name: node["nameWithOwner"],
      url: node["url"],
      description: node["description"],
      primary_language: get_in(node, ["primaryLanguage", "name"]),
      default_branch: get_in(node, ["defaultBranchRef", "name"]),
      archived_at: parse_datetime(node["archivedAt"]),
      external_created_at: parse_datetime(node["createdAt"]),
      last_pushed_at: parse_datetime(node["pushedAt"]),
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      external_id: node["id"]
    })
  end

  # ------------------------------------------------------------------------ issues

  defp coletar_issues(ctx, %{repo: repo, observed_repository_id: observado_id, node: node}) do
    [owner, name] = String.split(node["nameWithOwner"], "/", parts: 2)

    case paginar(ctx, "issues", %{owner: owner, name: name}) do
      {:ok, nodes, total} ->
        # **Antes de gravar as issues**, e não depois: `gravar_issue/3` lê `ctx.pessoas[login]` na
        # mesma passada, e registrar a pessoa depois deixaria `author_person_id` nulo com a pessoa
        # já existindo.
        ctx = observar_quem_trabalhou(ctx, nodes)

        # Alcançou: se estava marcado como inacessível, a marca sai. A cura é a própria
        # coleta — ninguém precisa lembrar de destravar.
        #
        # Tolerante a `:not_found` pelo mesmo motivo que a marcação abaixo: o repositório
        # pode sair da observação **durante** a fase, e um `{:ok, _} =` aqui derrubava a
        # coleta inteira por causa de um. Foi um teste desta feature que achou.
        registrar_ou_seguir(CMPO.clear_inaccessible(ctx.tenant, observado_id), repo.name)

        gravadas = Enum.map(nodes, &gravar_issue(ctx, observado_id, &1))
        vincular(ctx, nodes)

        # O esperado de issues é a SOMA dos repositórios, e cada chamada acrescenta o
        # total daquele. Guardar só o do primeiro faria a barra passar de 100%.
        Ingestion.checkpoint_page(ctx.sync, "github.issue", nil, length(nodes), total)

        # A data vai no **mesmo ponto** que o checkpoint da fase, e é de propósito: dois
        # pontos diferentes é como a data fica gravada para uns repositórios e não para
        # outros — e aí a tela afirma coleta que não houve, que é pior que não saber.
        marcar_issues_coletadas(ctx, observado_id, repo.name)

        # A tela recebe o nome do repositório: "coletando issues" sem dizer de qual, numa
        # organização de 121 repositórios, não informa nada.
        Ingestion.broadcast(
          ctx.tenant.id,
          {:sync_progress, ctx.sync.id, "github.issue:#{repo.name}"}
        )

        # Por repositório, e é a L19 impedida: só o que foi olhado é marcado.
        {:ok, _} =
          WorkItems.mark_issues_no_longer_observed(ctx.tenant, observado_id, ctx.started_at)

        # **Depois de `vincular/2`, nunca antes.** Antes marcaria todos os vínculos e a
        # renovação limparia parte, deixando dois estados para o mesmo fato dentro da
        # mesma execução.
        ausentes = marcar_vinculos_ausentes(ctx, observado_id, repo.name)

        {%{
           repositorio: repo.name,
           coletadas: length(gravadas),
           alcancado: true,
           vinculos_ausentes: ausentes
         }, ctx}

      {:error, reason} ->
        # Falha **transitória** não marca nada: marcar tira o repositório de
        # `list_collectable/2`, e nenhuma coleta seguinte o olha de novo. Um `:nxdomain`
        # de um instante já custou 38 repositórios e 899 issues fora de observação.
        #
        # Permanente marca, e aí está certo: credencial recusada ou repositório que não
        # existe encontrariam o mesmo na próxima vez.
        if Client.transient?(reason) do
          Logger.warning(
            "falha transitória em #{repo.name}: #{Client.describe_error(reason)} — " <>
              "não marcado como inacessível"
          )
        else
          {:ok, _} =
            CMPO.mark_inaccessible(ctx.tenant, observado_id, Client.describe_error(reason))

          Logger.warning("repositório inacessível: #{repo.name}")
        end

        # Registrado **agora**, no instante da falha, e não no fim da fase: se a execução for
        # interrompida, o número precisa dizer o que falhou até aqui. Zero num registro
        # interrompido afirmaria que tudo foi alcançado.
        ctx.sync |> Ingestion.reload() |> Ingestion.tally(:repository_unreachable)

        {%{repositorio: repo.name, coletadas: 0, alcancado: false, vinculos_ausentes: 0}, ctx}
    end
  end

  # ------------------------------------------------------- quem escreveu e quem recebeu

  @doc false
  # Registra como pessoa quem a origem nomeia como autor ou designado, e devolve o `ctx` com o
  # mapa acrescido.
  #
  # ## Por que a coleta de issues cria pessoa
  #
  # A ingestão de EO traz **membros** da organização. Quem saiu antes de a plataforma começar a
  # olhar nunca entra por lá — e o trabalho dela fica. Medido em 2026-08-13: **288** aparições sem
  # pessoa, em **15** logins; `sofialctv` escreveu 64 issues e nunca esteve em `eo_people`.
  #
  # ## É o mesmo mapeamento, e o mesmo caminho de escrita
  #
  # `github.user.to.eo.person` já existe e já diz que "uma conta de usuário do GitHub identifica um
  # agente que atuou no repositório". O que muda é de onde o nó vem: da issue, e não da lista de
  # membros. Um segundo caminho de escrita discordaria do primeiro no dia em que um mudasse.
  #
  # ## Bot não é pessoa
  #
  # A classificação é `Mapper.account_type/1` — **chamada**, nunca reimplementada. Ela já distingue
  # `Bot`, `App` e o sufixo `[bot]`, e o mapeamento declara a limitação.
  #
  # ## Isto **não** diz que a pessoa é membro
  #
  # Nenhuma evidência de participação em equipe é criada aqui. "Quem é da organização" continua
  # sendo respondido por evidência de equipe; o que esta função sustenta é "quem trabalhou".
  defp observar_quem_trabalhou(ctx, nodes) do
    nodes
    |> Enum.flat_map(&contas_do_no/1)
    |> Enum.uniq_by(& &1["id"])
    |> Enum.reject(&Map.has_key?(ctx.pessoas, &1["login"]))
    |> Enum.reduce(ctx, fn conta, ctx ->
      case gravar_pessoa(ctx, conta) do
        {:ok, pessoa} -> %{ctx | pessoas: Map.put(ctx.pessoas, pessoa.login, pessoa.id)}
        :ignora -> ctx
      end
    end)
  end

  # Só contas com identidade: o nó de um autor apagado na origem vem sem `id`, e criar pessoa a
  # partir do login seria chavear identidade por string que o GitHub deixa renomear — a L25.
  defp contas_do_no(node) do
    designados = get_in(node, ["assignees", "nodes"]) || []

    [node["author"] | designados]
    |> Enum.filter(&(is_map(&1) and is_binary(&1["id"]) and is_binary(&1["login"])))
  end

  defp gravar_pessoa(ctx, conta) do
    if Mapper.account_type(conta) == "person" do
      now = DateTime.utc_now(:second)

      RawData.store(%{
        tenant_id: ctx.tenant.id,
        sync_id: ctx.sync.id,
        raw_entity_type: "github.user",
        external_id: conta["id"],
        payload: conta,
        mapping_id: "github.user.to.eo.person",
        mapping_version: Mapper.version("github.user.to.eo.person"),
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        collected_at: now
      })

      with {:ok, mapped} <- Mapper.apply_mapping("github.user.to.eo.person", conta) do
        mapped
        |> Map.merge(%{
          source_system: "github",
          source_instance: ctx.tool.instance_url,
          external_id: conta["id"],
          collected_at: now,
          last_observed_at: now,
          no_longer_observed_at: nil
        })
        |> Mapper.complete("github.user", conta)
        |> then(&EO.upsert_person_from_source(ctx.tenant, &1))
      end
    else
      :ignora
    end
  end

  # O número vai para o log **e** para o resultado da fase, e não para um campo novo em
  # `syncs`: o consumidor visível é a coluna `part of` na lista de issues, e um segundo
  # número no cartão da sincronização entraria ao lado de "records collected" e "issues",
  # que respondem outras perguntas.
  #
  # **Silêncio quando é zero**, pela mesma razão que a tela esconde "0 unreachable": a
  # linha que aparece em toda execução treina quem lê a ignorá-la, e é justamente a linha
  # que importa quando não é zero.
  defp marcar_vinculos_ausentes(ctx, observado_id, nome) do
    {:ok, count} =
      WorkItems.mark_decomposition_links_no_longer_observed(
        ctx.tenant,
        observado_id,
        ctx.started_at
      )

    if count > 0 do
      Logger.info(
        "#{nome}: #{count} vínculo(s) de decomposição que a origem não declara mais — " <>
          "marcados como ausentes, nunca apagados"
      )
    end

    count
  end

  defp marcar_issues_coletadas(ctx, observado_id, nome) do
    ctx.tenant
    |> CMPO.mark_issues_collected(observado_id, DateTime.utc_now(:second))
    |> registrar_ou_seguir(nome)
  end

  # `:not_found` significa que o repositório saiu da observação **no meio** da execução —
  # alguém o excluiu enquanto a fase rodava. Casar só `{:ok, _}` derrubava a fase inteira
  # com `MatchError` por causa de um repositório, e a data ausente é exatamente o que se
  # quer para quem saiu da observação: a plataforma não tem mais o que dizer sobre ele.
  #
  # Isto **não** é fallback silencioso: o log nomeia o repositório, e nenhuma decisão
  # posterior lê a data como se ela existisse.
  defp registrar_ou_seguir({:ok, _}, _nome), do: :ok

  defp registrar_ou_seguir({:error, :not_found}, nome) do
    Logger.warning("#{nome} saiu da observação durante a coleta — nada a registrar sobre ele")
    :ok
  end

  defp registrar_ou_seguir({:error, %Ecto.Changeset{} = changeset}, nome) do
    Logger.warning("não foi possível atualizar #{nome}: #{inspect(changeset.errors)}")
    :ok
  end

  defp gravar_issue(ctx, observado_id, node) do
    now = DateTime.utc_now(:second)

    RawData.store(%{
      tenant_id: ctx.tenant.id,
      sync_id: ctx.sync.id,
      raw_entity_type: "github.issue",
      external_id: node["id"],
      payload: node,
      mapping_id: "github.issue.user_story.to.sro.atomic_user_story",
      mapping_version: 2,
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      collected_at: now
    })

    ctx.sync |> Ingestion.reload() |> Ingestion.tally(:unchanged)

    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: observado_id,
        number: node["number"],
        title: node["title"],
        state: node["state"],
        issue_type: get_in(node, ["issueType", "name"]),
        issue_type_external_id: get_in(node, ["issueType", "id"]),
        external_parent_id: get_in(node, ["parent", "id"]),
        sub_issue_count: get_in(node, ["subIssues", "totalCount"]) || 0,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        external_id: node["id"],
        external_created_at: parse_datetime(node["createdAt"]),
        external_updated_at: parse_datetime(node["updatedAt"]),
        external_closed_at: parse_datetime(node["closedAt"]),
        # `bodyText`, não `body`: o segundo traz markdown cru, e a tela renderizaria
        # conteúdo da origem como HTML.
        body: node["bodyText"],
        state_reason: node["stateReason"],
        author_login: get_in(node, ["author", "login"]),
        author_person_id: ctx.pessoas[get_in(node, ["author", "login"])],
        milestone_title: get_in(node, ["milestone", "title"]),
        project_titles: titulos_de_quadro(node),
        comment_count: get_in(node, ["comments", "totalCount"]) || 0,
        reaction_count: get_in(node, ["reactions", "totalCount"]) || 0
      })

    designados =
      for %{"login" => login} <- get_in(node, ["assignees", "nodes"]) || [],
          do: %{login: login, person_id: ctx.pessoas[login]}

    rotulos =
      for rotulo <- get_in(node, ["labels", "nodes"]) || [],
          do: %{name: rotulo["name"], color: rotulo["color"]}

    {:ok, _} = WorkItems.replace_assignees(ctx.tenant, issue.id, designados)
    {:ok, _} = WorkItems.replace_labels(ctx.tenant, issue.id, rotulos)

    issue
  end

  # O quadro entra como **referência**: só o título. A coleta de quadros como entidade
  # ficou fora da feature 004 (F4), e inventá-la aqui criaria quadro sem proveniência.
  defp titulos_de_quadro(node) do
    for item <- get_in(node, ["projectItems", "nodes"]) || [],
        titulo = get_in(item, ["project", "title"]),
        titulo != nil,
        do: titulo
  end

  # ---------------------------------------------------------------------- vínculos

  # Depois de todas as issues existirem: uma parte pode ser coletada depois do pai, e
  # ligar durante a paginação perderia os vínculos das partes ainda não gravadas.
  defp vincular(ctx, nodes) do
    # Por `external_id`, e **não** por `number`. O número é único dentro do repositório,
    # e esta organização tem 14 — dois repositórios têm issue #1. Chavear por número
    # ligou partes de um repositório ao pai de outro, e o efeito foi silencioso: a
    # classificação saiu errada em vez de dar erro.
    #
    # É a mesma lição que `collected_issues` já carrega no índice único, e eu a violei
    # no código de ligação.
    por_externo = Map.new(WorkItems.list_by_external_id(ctx.tenant), &{&1.external_id, &1.id})

    for node <- nodes,
        parte <- get_in(node, ["subIssues", "nodes"]) || [] do
      pai_id = por_externo[node["id"]]
      parte_id = por_externo[parte["id"]]

      cond do
        is_nil(pai_id) ->
          :ignora

        is_nil(parte_id) ->
          # Parte fora do escopo observado: a relação existe e é registrada; a parte não
          # é promovida (FR-018).
          WorkItems.recusar(ctx.tenant, %{
            parent_issue_id: pai_id,
            child_external_id: parte["id"],
            reason: "out_of_scope"
          })

        true ->
          WorkItems.record_decomposition_link(ctx.tenant, %{
            parent_issue_id: pai_id,
            child_issue_id: parte_id
          })
      end
    end
  end

  # ---------------------------------------------------------------------- promoção

  # Por último, porque a classificação épico/atômica depende dos vínculos já gravados.
  #
  # ## Um caminho só, e ele é o do recálculo
  #
  # Esta função tinha o **seu próprio** laço de promoção: montava a decisão com
  # `WorkItems.decide/2` e gravava. O recálculo da feature 005 tinha outro, com a etapa
  # estrutural. Dois caminhos para a mesma decisão, e quem rodava por último ganhava.
  #
  # O efeito medido no dado real: a coleta das 10h14 regravou **3451 issues como não
  # promovidas** sobre as promoções que a etapa estrutural havia decidido às 02h08. A
  # interface passou a mostrar 77% sem conceito, e nada no log dizia por quê — a coleta
  # concluiu com sucesso.
  #
  # Pior: aquele laço **não era idempotente**. Gravava uma linha por issue por
  # sincronização, com proveniência nula para as não promovidas — 40 238 promoções para
  # 4474 issues, nove por issue.
  #
  # `Mapping.recompute/2` é o caminho. Ele aplica as três etapas — tipo declarado, título,
  # estrutura —, grava **só o que mudou**, e é o mesmo que a tela de regras usa.
  defp promover(ctx, organization) do
    {:ok, efeito} = Mapping.recompute(ctx.tenant, organization.id)

    Ingestion.checkpoint_page(ctx.sync, "promocao", nil, efeito.written)
    Ingestion.broadcast(ctx.tenant.id, {:sync_progress, ctx.sync.id, "promocao"})

    Logger.info(
      "promoção: #{efeito.written} linhas gravadas, " <>
        "#{efeito.concept_changed} mudaram de conceito"
    )

    efeito
  end

  # ----------------------------------------------------------------------- comuns

  # Devolve `{:ok, nodes, total}` — o total é o denominador do progresso, e vem da origem.
  # `nil` quando a origem não o informa, e nesse caso a tela mostra contagem em vez de
  # percentual.
  defp paginar(ctx, query_name, variables, cursor \\ nil, acumulado \\ [], total \\ nil) do
    vars = Map.merge(variables, %{page_size: @page_size, after: cursor})

    case Client.graphql(ctx.tool.instance_url, ctx.token, read_query(query_name), vars) do
      # O cliente devolve o ENVELOPE — `%{data: ..., rate_limit: ...}` —, e não o `data`
      # direto. Casar com `{:ok, data}` compilava, rodava, e devolvia lista vazia sem
      # erro: o job completava com zero coletados. Foi o que aconteceu na primeira
      # execução contra o dado real.
      {:ok, %{data: data}} ->
        {nodes, page_info, total_da_pagina} = extrair(data, query_name)
        acumulado = acumulado ++ nodes
        total = total || total_da_pagina

        if page_info["hasNextPage"],
          do: paginar(ctx, query_name, variables, page_info["endCursor"], acumulado, total),
          else: {:ok, acumulado, total}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extrair(data, "repositories") do
    repos = get_in(data, ["organization", "repositories"]) || %{}
    {repos["nodes"] || [], repos["pageInfo"] || %{}, repos["totalCount"]}
  end

  defp extrair(data, "issues") do
    issues = get_in(data, ["repository", "issues"]) || %{}
    {issues["nodes"] || [], issues["pageInfo"] || %{}, issues["totalCount"]}
  end

  defp read_query(name) do
    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{name}.graphql")
    |> File.read!()
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
