defmodule TheBand.Jobs.SyncGitHubEO do
  @moduledoc """
  Coleta organização, pessoas e equipes do GitHub para a Enterprise Ontology.

  Percorre quatro entidades em ordem, com checkpoint por entidade: a organização,
  os membros da organização, os times, e os integrantes de cada time. Os dois
  conjuntos de pessoas não coincidem, e coletar só um daria visão parcial sem que
  a pessoa usuária soubesse.

  ## Como as garantias são obtidas

    * **idempotência** (FR-014) — vem do upsert por Application Reference no
      módulo EO, não daqui;
    * **retomada** (FR-015) — o cursor é gravado depois de cada página, e o job
      retoma do checkpoint;
    * **rate limit** (FR-016) — `{:snooze, segundos}` devolve o job à fila até a
      janela reabrir. Nunca `Process.sleep`: segurar o processo bloquearia a fila
      inteira e faria a pausa parecer travamento;
    * **uma por ferramenta** (FR-018) — `unique` aqui, mais o índice parcial no
      banco.
  """

  use Oban.Worker, queue: :ingestion, max_attempts: 5, unique: [period: 300, fields: [:args]]

  # O atributo precisa ser registrado, ou o compilador o trata como esquecido e reprova em
  # `--warnings-as-errors`. `accumulate: true` porque ele é declarado por função.
  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  require Logger

  alias TheBand.Ingestion
  alias TheBand.Ingestion.GithubBranches
  alias TheBand.Ingestion.GithubChangeRequests
  alias TheBand.Ingestion.GithubCommitFiles
  alias TheBand.Ingestion.GithubIssueComments
  alias TheBand.Ingestion.GithubProjects
  alias TheBand.Ingestion.GithubVerifications
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.SemanticIntegration.Mapper
  alias TheBand.Sources
  alias TheBand.Sources.ToolCredential
  alias TheBand.Tenants

  @page_size 50

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "sync_id" => sync_id}}) do
    # O tenant vem nos args e é validado antes de qualquer coisa acontecer.
    with {:ok, tenant} <- Tenants.fetch(tenant_id),
         {:ok, sync} <- Ingestion.fetch_sync(tenant, sync_id),
         {:ok, tool} <- Sources.fetch_connected_tool(tenant, sync.connected_tool_id),
         %ToolCredential{} = credential <- Sources.active_credential(tool) do
      # Fora do `with` de propósito: o ramo de erro precisa da `tool` para marcá-la, e o
      # `else` de um `with` não enxerga as variáveis ligadas nas cláusulas anteriores.
      case Sources.fetch_secret(credential) do
        {:ok, token} -> run(tenant, sync, tool, token)
        {:error, :unreadable} -> credencial_ilegivel(tenant, sync, tool)
      end
    else
      nil ->
        {:error, :no_active_credential}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # A credencial está gravada e íntegra, e a chave que a cifrou não existe mais. É estado
  # permanente: repetir não conserta, e por isso não vira retentativa nem exceção. Vira
  # *precisa de atenção*, que nomeia a única coisa que resolve — cadastrar outra credencial.
  #
  # Antes desta função o caso se apresentava como `ArgumentError` ao carregar o campo, e
  # derrubava as telas `/tools` e `/syncs` — inclusive a que oferece o conserto.
  defp credencial_ilegivel(tenant, sync, tool) do
    Sources.mark_needs_attention(
      tool,
      "credencial ilegível — a chave mestra mudou desde que ela foi gravada. " <>
        "Cadastre uma credencial nova; a anterior não é recuperável."
    )

    sync
    |> Ingestion.reload()
    |> Ingestion.finish(:interrupted, error_reason: "credencial ilegível — chave mestra trocada")

    Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
    {:error, :unreadable_credential}
  end

  defp run(tenant, sync, tool, token) do
    started_at = sync.started_at

    ctx = %{
      tenant: tenant,
      sync: sync,
      tool: tool,
      token: token,
      org: tool.organization_login
    }

    # A coleta devolve **qual organização observou**, e não só que terminou. É o que a
    # marca de ausência precisa saber: "não apareceu" só significa algo em relação ao
    # que foi olhado, e a coleta olha uma organização por vez (L19).
    case collect(ctx) do
      {:ok, organization_id} ->
        {:ok, _} = EO.mark_evidence_no_longer_observed(tenant, organization_id, started_at)
        pending = EO.count_evidence_pending_role(tenant)

        # Segunda fase da MESMA sincronização: repositórios, issues e promoção.
        # Sincronizar traz tudo — dois registros de `sync` para uma ação de quem opera
        # tornariam "o que esta coleta trouxe" uma pergunta com duas respostas parciais.
        #
        # A ordem importa: a organização precisa existir para o repositório apontar para
        # ela, e é a primeira fase que a grava.
        trabalho = coletar_trabalho(ctx)

        sync
        |> Ingestion.reload()
        |> Ingestion.finish(:completed, memberships_pending_role: pending)

        Sources.touch_last_sync(tool)
        Sources.clear_needs_attention(tool)
        Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
        Logger.info("trabalho coletado: #{inspect(trabalho)}")
        :ok

      {:snooze, seconds} ->
        Ingestion.broadcast(tenant.id, {:sync_paused, sync.id, seconds})
        {:snooze, seconds}

      {:error, :unauthorized} ->
        # Credencial revogada no meio da coleta: interrupção controlada, progresso
        # parcial preservado, ferramenta marcada. As demais seguem normais.
        Sources.mark_needs_attention(tool, "credencial recusada pela ferramenta durante a coleta")

        sync
        |> Ingestion.reload()
        |> Ingestion.finish(:interrupted, error_reason: "credencial recusada durante a coleta")

        Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
        {:error, :unauthorized}

      {:error, reason} ->
        finish_with_error(tenant, sync, reason)
    end
  end

  # A coleta de trabalho não derruba a sincronização de EO: pessoas e equipes já foram
  # gravadas, e perdê-las por causa de uma falha na segunda fase seria pior que
  # registrar a falha. O motivo fica no log e a fase seguinte tenta na próxima coleta.
  defp coletar_trabalho(ctx) do
    case GithubWorkItems.collect(ctx) do
      {:ok, resumo} ->
        Map.merge(resumo, coletar_caixas_de_tempo(ctx))

      {:error, reason} ->
        Logger.warning("coleta de repositórios e issues falhou: #{inspect(reason)}")
        %{repositories: 0, issues: 0, error: reason}
    end
  end

  # **Depois das issues**, e a ordem é dependência de dado: o vínculo entre issue e
  # caixa de tempo precisa da issue gravada, e ela vem da fase anterior.
  #
  # Falhar aqui não derruba o que já foi coletado, pelo mesmo motivo da fase de
  # trabalho: repositórios e issues já estão no banco, e perdê-los por causa de uma
  # falha nos quadros seria pior que registrar a falha.
  defp coletar_caixas_de_tempo(ctx) do
    resumo_quadros =
      case GithubProjects.collect(ctx) do
        {:ok, resumo} ->
          resumo

        {:error, reason} ->
          Logger.warning("coleta de quadros falhou: #{inspect(reason)}")
          %{projects: 0, sprints: 0, links: 0, sprints_error: reason}
      end

    Map.merge(resumo_quadros, coletar_comentarios(ctx))
  end

  # **Depois das issues**, pela mesma dependência de dado: o comentário aponta para a
  # issue gravada. E lê as issues da BASE, não da memória da fase anterior (L47) —
  # issue nova com comentário entra na mesma passada.
  #
  # Falhar aqui não derruba nada do que veio antes; sem checkpoint gravado, a próxima
  # coleta percorre de novo (L29).
  defp coletar_comentarios(ctx) do
    # A fase absorve falha por repositório (vira `unreachable` no resumo dela, com
    # log) — por isso não há ramo de erro aqui.
    {:ok, resumo} = GithubIssueComments.collect(ctx)

    Map.merge(
      %{comments: resumo.comments, comment_issues: resumo.issues_visited},
      coletar_mudancas(ctx)
    )
  end

  # **Depois das issues**, e pela mesma dependência de dado: o vínculo entre solicitação
  # e issue precisa da issue gravada. Lê da BASE, não da memória da fase anterior (L47).
  #
  # A fase absorve falha por repositório (vira `unreachable` no resumo dela, com log) —
  # por isso não há ramo de erro aqui.
  defp coletar_mudancas(ctx) do
    {:ok, resumo} = GithubChangeRequests.collect(ctx)

    Map.merge(
      %{
        change_requests: resumo.change_requests,
        commits: resumo.commits,
        attended_issues: resumo.attended_issues
      },
      coletar_arquivos(ctx)
    )
  end

  # **Depois dos commits**, e por dependência de dado: o arquivo pende de um commit
  # gravado, e o pendente é lido da BASE (L47).
  #
  # `limit` e `wait_for_rate_limit: false` são a diferença desta fase para a coleta
  # avulsa: são 5.000 requisições por hora e uma por commit, e uma sincronização que
  # dorme esperando a janela reabrir pareceria travada — o Oban a mataria por tempo
  # antes de ela terminar. A fatia por passada avança o checkpoint e a próxima
  # sincronização continua de onde esta parou; a coleta avulsa, sem limite, percorre
  # tudo esperando a janela.
  @fatia_de_arquivos 500

  defp coletar_arquivos(ctx) do
    {:ok, resumo} =
      GithubCommitFiles.collect(ctx, limit: @fatia_de_arquivos, wait_for_rate_limit: false)

    Map.merge(
      %{commit_files: resumo.files, file_commits: resumo.commits_visited},
      coletar_verificacoes(ctx)
    )
  end

  # A verificação contínua não depende das fases anteriores — pende só do repositório
  # observado. Fica por último porque é a mais cara por repositório (uma requisição por
  # execução para trazer os jobs), e falhar aqui não pode custar o que já foi coletado.
  #
  # A fase absorve falha por repositório (vira `unreachable` no resumo dela, com log) —
  # por isso não há ramo de erro aqui.
  defp coletar_verificacoes(ctx) do
    {:ok, resumo} = GithubVerifications.collect(ctx)

    Map.merge(
      %{
        verifications: resumo.verifications,
        verification_components: resumo.components,
        monolithic_jobs: resumo.monolithic_jobs,
        repositories_without_ci: resumo.without_ci,
        # Nunca zero disfarçando "acabou": é o que diz à próxima sincronização que sobrou
        # trabalho, e a diferença entre "volte depois" e "algo quebrou".
        verifications_rate_limited: resumo.rate_limited
      },
      coletar_branches(ctx)
    )
  end

  # **Não é incremental, e por isso fica no fim.** A pergunta é "que branches existem
  # agora", e responder exige o conjunto inteiro para saber o que deixou de existir — filtro
  # por data traria só as novas, e branch apagada nunca seria marcada.
  #
  # O custo é uma consulta por repositório, medido: 6, 63 e 47 branches nos repositórios do
  # piloto, todas numa página de 100.
  #
  # A fase absorve falha por repositório (vira `unreachable` no resumo dela, com log) — por
  # isso não há ramo de erro aqui.
  defp coletar_branches(ctx) do
    {:ok, resumo} = GithubBranches.collect(ctx)

    %{
      branches: resumo.branches,
      protected_branches: resumo.protected,
      # "Não soubemos dizer" nunca vira "não protegida": sem escopo de administração o campo
      # não vem da origem, e este contador é o que impede a leitura errada.
      branch_protection_unknown: resumo.protection_unknown,
      branches_gone: resumo.marked_unobserved
    }
  end

  # Falha transitória **não** encerra a sincronização. Marcá-la como falha levaria
  # alguém a investigar uma coleta que o Oban ainda vai retentar sozinho — e,
  # pior, liberaria o índice que impede duas coletas simultâneas da mesma
  # ferramenta, porque ele só bloqueia enquanto o estado é `running`.
  defp finish_with_error(tenant, sync, reason) do
    if Client.transient?(reason) do
      Logger.warning("falha transitória na coleta, será retentada: #{inspect(reason)}")
      Ingestion.broadcast(tenant.id, {:sync_retrying, sync.id, Client.describe_error(reason)})
    else
      sync
      |> Ingestion.reload()
      |> Ingestion.finish(:failed, error_reason: Client.describe_error(reason))

      Logger.error("coleta falhou: #{inspect(reason)}")
      Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
    end

    {:error, reason}
  end

  # ------------------------------------------------------------------ coleta

  defp collect(ctx) do
    with {:ok, org_node, organization} <- collect_organization(ctx),
         # A organização coletada viaja no contexto porque toda equipe precisa dela.
         # Guardamos o **nó**, e não a linha do banco, para que o mesmo dado seja
         # embutido no payload preservado — ver `handle_team/2`.
         ctx = Map.merge(ctx, %{organization_node: org_node, organization_id: organization.id}),
         :ok <- paginate(ctx, "github.user", "organization_members", &handle_member/2),
         :ok <- paginate(ctx, "github.team", "teams", &handle_team/2),
         :ok <- collect_team_members(ctx) do
      # Avaliada **ao fim**, e não antes: é o único momento em que se sabe quem ficou
      # fora de todas as equipes. Antes disso o conjunto de equipes está incompleto, e
      # a derivada acolheria gente que estava em time ainda não coletado.
      with :ok <- derive_default_team(ctx), do: {:ok, ctx.organization_id}
    end
  end

  # Regra `github.default_team`, contrato `derived-team.md`.
  defp derive_default_team(ctx) do
    organization = EO.fetch_organization!(ctx.tenant, ctx.organization_id)
    fora = EO.list_people_without_team(ctx.tenant, organization.id)

    case fora do
      [] ->
        # Nenhuma equipe derivada é criada quando todos estão em equipes observadas:
        # seria registro sem referente (FR-007). E a que já existia, se existir,
        # esvazia e é marcada — nunca apagada.
        retire_empty_derived_team(ctx.tenant, organization)

      pessoas ->
        with {:ok, team} <- EO.upsert_derived_team(ctx.tenant, organization) do
          Enum.each(pessoas, &link_to_derived_team(ctx.tenant, team, organization, &1))

          Logger.info(
            "equipe derivada de #{organization.login}: #{length(pessoas)} pessoas fora de time"
          )

          :ok
        end
    end
  end

  defp link_to_derived_team(tenant, team, organization, person) do
    EO.record_derived_team_membership(tenant, %{
      person_id: person.id,
      team_id: team.id,
      person_external_id: person.external_id,
      team_external_id: team.external_id,
      source_instance: organization.source_instance,
      observed_at: DateTime.utc_now(:second)
    })
  end

  defp retire_empty_derived_team(tenant, organization) do
    case EO.fetch_derived_team(tenant, organization.id) do
      nil -> :ok
      team -> with {:ok, _} <- EO.retire_derived_team(tenant, team), do: :ok
    end
  end

  defp collect_organization(ctx) do
    case query(ctx, "organization", %{organization: ctx.org}) do
      {:ok, %{data: %{"organization" => nil}}} ->
        {:error, {:organization_not_found, ctx.org}}

      {:ok, %{data: %{"organization" => node}}} ->
        {:ok, organization} =
          store_and_upsert(
            ctx,
            node,
            "github.organization",
            "github.organization.to.eo.organization"
          )

        Ingestion.checkpoint_page(ctx.sync, "github.organization", nil, 1)
        {:ok, node, organization}

      other ->
        normalize_error(other)
    end
  end

  # Escopado à organização desta coleta, e só às equipes **observadas**.
  #
  # Sem o escopo, coletar a organização A paginaria os integrantes das equipes da
  # organização B — consultando o GitHub por slugs que não existem naquela
  # organização. E a equipe derivada não tem integrantes na origem: pedi-los seria
  # perguntar à ferramenta sobre uma equipe que ela não conhece.
  defp collect_team_members(ctx) do
    ctx.tenant
    |> EO.list_teams(organization_id: ctx.organization_id, origin: :observed)
    |> Enum.reduce_while(:ok, fn team, _acc ->
      case paginate(
             ctx,
             "github.team_member:#{team.slug}",
             "team_members",
             &handle_team_member(&1, &2, team),
             extra: %{team_slug: team.slug}
           ) do
        :ok -> {:cont, :ok}
        other -> {:halt, other}
      end
    end)
  end

  # Paginação genérica: uma página por vez, checkpoint depois de processar.
  defp paginate(ctx, entity_type, query_name, handler, opts \\ []) do
    cursor = Ingestion.resume_cursor(ctx.sync, entity_type)
    do_paginate(ctx, entity_type, query_name, handler, cursor, opts)
  end

  defp do_paginate(ctx, entity_type, query_name, handler, cursor, opts) do
    variables =
      %{organization: ctx.org, page_size: @page_size}
      |> Map.merge(Keyword.get(opts, :extra, %{}))
      |> then(fn vars -> if cursor, do: Map.put(vars, :after, cursor), else: vars end)

    case query(ctx, query_name, variables) do
      {:ok, %{data: data, rate_limit: rate_limit}} ->
        {nodes, page_info} = extract(data, query_name)
        Enum.each(nodes, &handler.(ctx, &1))

        next_cursor = if page_info["hasNextPage"], do: page_info["endCursor"], else: nil
        # Depois de processar, nunca antes. Reprocessar a última página é seguro
        # porque a ingestão é idempotente; perdê-la não seria.
        Ingestion.checkpoint_page(ctx.sync, entity_type, next_cursor, length(nodes))

        Ingestion.broadcast(
          ctx.tenant.id,
          {:sync_progress, ctx.sync.id, entity_type, length(nodes)}
        )

        cond do
          is_nil(next_cursor) ->
            :ok

          match?({:pause_until, _}, Client.pause_needed?(rate_limit)) ->
            {:pause_until, reset_at} = Client.pause_needed?(rate_limit)
            {:snooze, max(DateTime.diff(reset_at, DateTime.utc_now()), 1)}

          true ->
            do_paginate(ctx, entity_type, query_name, handler, next_cursor, opts)
        end

      other ->
        normalize_error(other)
    end
  end

  # ------------------------------------------------------------- transformação

  defp handle_member(ctx, node) do
    store_and_upsert(ctx, node, "github.user", "github.user.to.eo.person")
  end

  # A organização é o **pai da consulta**, não campo do nó do time — declarar
  # `organization.id` como caminho de origem produzia nulo, e foi isso que deixou
  # `eo_teams.organization_id` vazia em 100% dos registros (achado F6).
  #
  # A correção embute o pai no nó **antes de preservar o payload**, e não depois de
  # mapear. Assim o payload guardado responde sozinho de qual organização a equipe
  # veio, e o reprocessamento (FR-017) reproduz o vínculo sem consultar a origem.
  # Injetar depois do armazenamento faria a coleta acertar e o reprocessamento errar.
  defp handle_team(ctx, node) do
    node = Map.put(node, "organization", Map.take(ctx.organization_node, ["id", "login"]))
    store_and_upsert(ctx, node, "github.team", "github.team.to.eo.organizational_team")
  end

  defp handle_team_member(ctx, edge, team) do
    node = edge["node"]
    level = edge["role"]

    with {:ok, person} <-
           store_and_upsert(ctx, node, "github.team_member", "github.team_member.to.eo.person"),
         :ok <- EO.check_evidence(%{platform_access_level: level}) do
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: person.id,
        team_id: team.id,
        person_external_id: node["id"],
        team_external_id: team.external_id,
        # Nível de acesso na plataforma. Não vira papel organizacional, e a
        # invariante acima é o que impede que vire por descuido futuro.
        platform_access_level: level,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        observed_at: DateTime.utc_now(:second)
      })
    else
      {:error, reason} ->
        ctx.sync |> Ingestion.reload() |> Ingestion.tally({:skipped, to_string(inspect(reason))})
        {:error, reason}
    end
  end

  defp store_and_upsert(ctx, node, raw_entity_type, mapping_id) do
    now = DateTime.utc_now(:second)

    RawData.store(%{
      tenant_id: ctx.tenant.id,
      sync_id: ctx.sync.id,
      raw_entity_type: raw_entity_type,
      external_id: node["id"],
      payload: node,
      mapping_id: mapping_id,
      mapping_version: Mapper.version(mapping_id),
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      collected_at: now
    })

    with {:ok, mapped} <- Mapper.apply_mapping(mapping_id, node) do
      attrs =
        mapped
        |> Map.merge(%{
          source_system: "github",
          source_instance: ctx.tool.instance_url,
          external_id: node["id"],
          collected_at: now,
          last_observed_at: now,
          no_longer_observed_at: nil
        })
        |> Mapper.complete(raw_entity_type, node)

      result = write(ctx, raw_entity_type, attrs)

      case result do
        {:ok, record} ->
          ctx.sync |> Ingestion.reload() |> Ingestion.tally(record.outcome || :unchanged)
          {:ok, record}

        {:error, changeset} ->
          reason = changeset_reason(changeset)
          ctx.sync |> Ingestion.reload() |> Ingestion.tally({:skipped, reason})
          Logger.warning("registro ignorado em #{raw_entity_type}: #{reason}")
          {:error, reason}
      end
    end
  end

  defp write(ctx, "github.organization", attrs),
    do: EO.upsert_organization_from_source(ctx.tenant, attrs)

  defp write(ctx, "github.team", attrs), do: EO.upsert_team_from_source(ctx.tenant, attrs)
  defp write(ctx, _person_like, attrs), do: EO.upsert_person_from_source(ctx.tenant, attrs)

  # ------------------------------------------------------------------ auxiliares

  defp query(ctx, name, variables) do
    Client.graphql(ctx.tool.instance_url, ctx.token, read_query(name), variables)
  end

  # O caminho é montado a partir de literal do próprio código — `"issues"`, `"repositories"` —,
  # e nunca de entrada externa. A anotação nomeia o achado em vez de desligar a verificação, e
  # deixa de valer no dia em que alguém passar valor vindo de fora.
  @sobelow_skip ["Traversal.FileModule"]
  defp read_query(name) do
    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{name}.graphql")
    |> File.read!()
  end

  defp extract(data, "organization_members") do
    page = get_in(data, ["organization", "membersWithRole"]) || %{}
    {page["nodes"] || [], page["pageInfo"] || %{}}
  end

  defp extract(data, "teams") do
    page = get_in(data, ["organization", "teams"]) || %{}
    {page["nodes"] || [], page["pageInfo"] || %{}}
  end

  defp extract(data, "team_members") do
    page = get_in(data, ["organization", "team", "members"]) || %{}
    {page["edges"] || [], page["pageInfo"] || %{}}
  end

  defp normalize_error({:error, :unauthorized}), do: {:error, :unauthorized}
  defp normalize_error({:error, reason}), do: {:error, reason}
  defp normalize_error(other), do: {:error, other}

  defp changeset_reason(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end
end
