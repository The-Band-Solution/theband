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
  alias TheBand.Ingestion.Cota
  alias TheBand.Ingestion.GithubBranches
  alias TheBand.Ingestion.GithubChangeRequests
  alias TheBand.Ingestion.GithubCommitFiles
  alias TheBand.Ingestion.GithubIssueComments
  alias TheBand.Ingestion.GithubProjects
  alias TheBand.Ingestion.GithubVerifications
  alias TheBand.Ingestion.GithubWorkItems
  alias TheBand.Ingestion.Janela
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
        {:ok, token} -> run(tenant, sync, tool, token, com_dono(credential))
        {:error, :unreadable} -> credencial_ilegivel(tenant, sync, tool)
      end
    else
      nil ->
        {:error, :no_active_credential}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # A identidade da cota é o dono do token (ADR 0007, parte 1). Credenciais anteriores à
  # ADR não o têm gravado: uma chamada a `/user` — a mesma da validação — o descobre e
  # persiste, uma vez. Se falhar, a coleta segue com a identidade por credencial, que é
  # menos correta e está declarada em `Cota.chave/2`; a próxima sincronização tenta de novo.
  defp com_dono(credential) do
    case Sources.descobrir_dono(credential) do
      {:ok, credential} ->
        credential

      {:error, motivo} ->
        Logger.warning("dono do token não descoberto: #{inspect(motivo)}")
        credential
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

  defp run(tenant, sync, tool, token, credential) do
    started_at = sync.started_at

    ctx = %{
      tenant: tenant,
      sync: sync,
      tool: tool,
      token: token,
      # A identidade da cota — ADR 0007. Toda requisição do conector passa pelo gestor com
      # esta chave: é o usuário do GitHub dono do token, e não o token nem a ferramenta.
      cota: Cota.chave(tool, credential),
      org: tool.organization_login,
      # **O instante de referência das marcas de ausência**, e ele TEM de estar no `ctx`.
      # `GithubWorkItems` marca a issue e o vínculo de decomposição que sumiram, e
      # `GithubProjects` marca a iteração ausente — nove pontos leem `ctx.started_at`. Sem a
      # chave, toda sincronização agendada morria com `KeyError`, nos três tenants, nas
      # cinco tentativas do Oban, desde 2026-08-17.
      #
      # Passou por 1.038 testes porque o caminho que lê a chave **só roda quando há dado
      # para marcar**: com fixture vazia, nenhuma issue precisa de marca e a linha nunca é
      # alcançada (L62). E os scripts de coleta avulsa montavam o `ctx` à mão, sempre com a
      # chave — satisfaziam o contrato que o job violava (L66).
      started_at: started_at
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

        # A janela fechou numa etapa do trabalho (ADR 0006, item 5). O sync NÃO fecha —
        # ele não terminou, está esperando. Marcá-lo `completed` diria que a coleta
        # trouxe tudo, e a tela mostraria 23 repositórios com verificação como se fossem todos os
        # que têm CI. Foi exatamente o que aconteceu em 2026-09-05.
        case trabalho do
          %{snooze: segundos} ->
            Logger.info("coleta em espera pela janela: continua em #{segundos}s")
            Ingestion.broadcast(tenant.id, {:sync_paused, sync.id, segundos})
            {:snooze, segundos}

          _ ->
            sync
            |> Ingestion.reload()
            |> Ingestion.finish(:completed, memberships_pending_role: pending)

            Sources.touch_last_sync(tool)
            Sources.clear_needs_attention(tool)
            Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
            Logger.info("trabalho coletado: #{inspect(trabalho)}")
            :ok
        end

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
        finish_with_error(tenant, sync, tool, token, reason)
    end
  end

  # A coleta de trabalho não derruba a sincronização de EO: pessoas e equipes já foram
  # gravadas, e perdê-las por causa de uma falha na segunda fase seria pior que
  # registrar a falha. O motivo fica no log e a fase seguinte tenta na próxima coleta.
  #
  # **As etapas são um GRAFO, e a próxima é a que tem dependência pronta e balde aberto** —
  # ADR 0007, parte 6. Os dois baldes de cota são independentes: com a GraphQL esgotada, as
  # etapas REST (arquivos, verificações) têm janela e não precisam da GraphQL para andar. A
  # lista fixa de antes hibernava o job inteiro e desperdiçava uma hora do outro balde.
  #
  # A cada volta:
  # - `pendentes`: etapas não concluídas neste sync (checkpoint `etapa:<nome>`) e que não
  #   falharam nesta passada;
  # - `prontas`: pendentes com TODAS as dependências concluídas — declaradas em `etapas/0` e
  #   conferidas por teste, porque uma etapa antes da sua dependência não falharia: coletaria
  #   zero e marcaria `done`;
  # - `com_janela`: prontas cujo balde o gestor diz aberto, e que não devolveram espera nesta
  #   passada.
  # Executa a primeira com janela, na ordem da lista. Sem nenhuma: hiberna até o MENOR reset
  # entre os baldes fechados — e não até o do balde que acabou de fechar.
  defp coletar_trabalho(ctx), do: proxima_etapa(ctx, %{fechados: %{}, falhas: %{}})

  defp proxima_etapa(ctx, acumulado) do
    pendentes =
      Enum.reject(etapas(), &(concluida?(ctx, &1) or Map.has_key?(acumulado.falhas, &1.nome)))

    case pendentes do
      [] ->
        resumo_final(acumulado)

      _ ->
        prontas = Enum.filter(pendentes, &dependencias_concluidas?(ctx, &1))
        com_janela = Enum.filter(prontas, &janela_aberta?(ctx, &1, acumulado))
        escolher(ctx, acumulado, pendentes, prontas, com_janela)
    end
  end

  # Nenhuma pronta: o que falta depende de uma etapa que falhou nesta passada. Fica para a
  # próxima sincronização, registrado — e não em loop.
  defp escolher(_ctx, acumulado, pendentes, [], _com_janela) do
    resumo_final(Map.put(acumulado, :bloqueadas, Enum.map(pendentes, & &1.nome)))
  end

  # Prontas, todas sem janela: hiberna até o menor reset que desbloqueia alguma.
  defp escolher(_ctx, acumulado, _pendentes, prontas, []) do
    segundos =
      prontas
      |> Enum.map(&Map.get(acumulado.fechados, &1.balde))
      |> Enum.reject(&is_nil/1)
      |> Enum.min(fn -> Janela.segundos_ate(nil) end)

    acumulado |> resumo_final() |> Map.put(:snooze, segundos)
  end

  defp escolher(ctx, acumulado, _pendentes, _prontas, [etapa | _]) do
    proxima_etapa(ctx, executar_etapa(ctx, etapa, acumulado))
  end

  defp executar_etapa(ctx, %{nome: nome, balde: balde, fun: fun}, acumulado) do
    case fun.(ctx) do
      {:ok, resumo} ->
        {:ok, _} = Ingestion.concluir_etapa(ctx.sync, Atom.to_string(nome))
        Map.merge(acumulado, resumo)

      # A etapa parou na janela: o balde dela está fechado nesta passada, e as etapas de
      # OUTRO balde ainda podem rodar. O gestor já sabe (foi ele que recusou, ou observou o
      # 403); o registro aqui é para não tentar o mesmo balde de novo nesta passada.
      {:snooze, segundos} ->
        put_in(acumulado, [:fechados, balde], segundos)

      {:error, motivo} ->
        if Client.rate_limit?(motivo) do
          put_in(acumulado, [:fechados, balde], segundos_de_espera(motivo, ctx.tool, ctx.token))
        else
          Logger.warning("etapa #{nome} falhou: #{inspect(motivo)}")
          put_in(acumulado, [:falhas, nome], motivo)
        end
    end
  end

  defp concluida?(ctx, %{nome: nome}),
    do: Ingestion.etapa_concluida?(ctx.sync, "etapa:" <> Atom.to_string(nome))

  defp dependencias_concluidas?(ctx, %{depende_de: deps}),
    do: Enum.all?(deps, &concluida?(ctx, %{nome: &1}))

  # Sem identidade de cota (scripts avulsos, testes que montam o `ctx` à mão) não há gestor a
  # consultar — e aí a lista se comporta como a de antes: em ordem, até alguém devolver espera.
  defp janela_aberta?(ctx, %{balde: balde}, acumulado) do
    not Map.has_key?(acumulado.fechados, balde) and
      (is_nil(ctx[:cota]) or Cota.janela_aberta?(ctx[:cota], balde) == :aberta)
  end

  # O resumo que o `run/5` lê: os contadores das etapas, mais `erros: %{etapa => motivo}`
  # quando houve, e `snooze`/`bloqueadas` quando a passada não terminou tudo.
  defp resumo_final(%{falhas: falhas} = acumulado) do
    resumo = Map.drop(acumulado, [:fechados, :falhas])
    if falhas == %{}, do: resumo, else: Map.put(resumo, :erros, falhas)
  end

  # O grafo: nome, balde de cota, dependências de dado. A ordem da lista decide entre
  # etapas igualmente prontas e com janela.
  defp etapas do
    [
      # Repositórios e issues — tudo o que vem depois aponta para um repositório observado.
      %{nome: :trabalho, balde: :graphql, depende_de: [], fun: &GithubWorkItems.collect/1},
      # **Depois das issues**: o vínculo entre issue e caixa de tempo precisa da issue gravada.
      %{
        nome: :caixas_de_tempo,
        balde: :graphql,
        depende_de: [:trabalho],
        fun: &coletar_caixas_de_tempo/1
      },
      # **Depois das issues**: o comentário aponta para a issue gravada. Lê da BASE, não da
      # memória da etapa anterior (L47) — issue nova com comentário entra na mesma passada.
      %{
        nome: :comentarios,
        balde: :graphql,
        depende_de: [:trabalho],
        fun: &coletar_comentarios/1
      },
      # **Depois das issues**: o vínculo entre solicitação e issue precisa da issue gravada.
      %{nome: :mudancas, balde: :graphql, depende_de: [:trabalho], fun: &coletar_mudancas/1},
      # **Depois dos commits**, que a etapa de mudanças grava: o arquivo pende de um commit.
      %{nome: :arquivos, balde: :core, depende_de: [:mudancas], fun: &coletar_arquivos/1},
      # Pende só do repositório observado. É REST: anda com a GraphQL fechada.
      %{nome: :verificacoes, balde: :core, depende_de: [:trabalho], fun: &coletar_verificacoes/1},
      # **Não é incremental, e por isso fica no fim.** A pergunta é "que branches existem
      # agora", e responder exige o conjunto inteiro para saber o que deixou de existir.
      %{nome: :branches, balde: :graphql, depende_de: [:trabalho], fun: &coletar_branches/1}
    ]
  end

  defp coletar_caixas_de_tempo(ctx) do
    with {:ok, resumo} <- GithubProjects.collect(ctx) do
      {:ok, Map.take(resumo, [:projects, :sprints, :links, :without_projects])}
    end
  end

  defp coletar_comentarios(ctx) do
    with {:ok, resumo} <- GithubIssueComments.collect(ctx) do
      {:ok, %{comments: resumo.comments, comment_issues: resumo.issues_visited}}
    end
  end

  defp coletar_mudancas(ctx) do
    with {:ok, resumo} <- GithubChangeRequests.collect(ctx) do
      {:ok,
       %{
         change_requests: resumo.change_requests,
         commits: resumo.commits,
         attended_issues: resumo.attended_issues
       }}
    end
  end

  # `limit`: são 5 000 requisições por hora e uma por commit. A fatia por passada avança o
  # checkpoint e a próxima sincronização continua de onde esta parou. A espera pela janela
  # é do gestor de cotas, e não desta etapa — ela devolve `{:snooze}` como as outras.
  @fatia_de_arquivos 500

  defp coletar_arquivos(ctx) do
    with {:ok, resumo} <- GithubCommitFiles.collect(ctx, limit: @fatia_de_arquivos) do
      {:ok, %{commit_files: resumo.files, file_commits: resumo.commits_visited}}
    end
  end

  defp coletar_verificacoes(ctx) do
    with {:ok, resumo} <- GithubVerifications.collect(ctx) do
      {:ok,
       %{
         verifications: resumo.verifications,
         verification_components: resumo.components,
         monolithic_jobs: resumo.monolithic_jobs,
         repositories_without_ci: resumo.without_ci,
         # Nunca zero disfarçando "acabou": é o que diz à próxima sincronização que sobrou
         # trabalho, e a diferença entre "volte depois" e "algo quebrou".
         verifications_rate_limited: resumo.rate_limited
       }}
    end
  end

  # O custo é uma consulta por repositório, medido: 6, 63 e 47 branches nos repositórios do
  # piloto, todas numa página de 100.
  defp coletar_branches(ctx) do
    with {:ok, resumo} <- GithubBranches.collect(ctx) do
      {:ok,
       %{
         branches: resumo.branches,
         protected_branches: resumo.protected,
         # "Não soubemos dizer" nunca vira "não protegida": sem escopo de administração o
         # campo não vem da origem, e este contador é o que impede a leitura errada.
         branch_protection_unknown: resumo.protection_unknown,
         branches_gone: resumo.marked_unobserved
       }}
    end
  end

  # Falha transitória **não** encerra a sincronização. Marcá-la como falha levaria
  # alguém a investigar uma coleta que o Oban ainda vai retentar sozinho — e,
  # pior, liberaria o índice que impede duas coletas simultâneas da mesma
  # ferramenta, porque ele só bloqueia enquanto o estado é `running`.
  defp finish_with_error(tenant, sync, tool, token, reason) do
    cond do
      # RATE LIMIT: espera, e não retenta — medido em 2026-09-04.
      #
      # Retentar é o que `transient?` produz, e para o limite de taxa isso é a decisão
      # errada: a janela leva até uma hora, e as cinco tentativas do Oban se esgotam em
      # minutos, todas dentro da mesma janela fechada. O job era descartado, e a coleta
      # parava de vez — foi assim que ela morreu em 2 de 88 repositórios.
      #
      # `{:snooze, segundos}` devolve o job à fila SEM consumir tentativa, que é o que o
      # moduledoc deste módulo promete desde o começo (FR-016).
      Client.rate_limit?(reason) ->
        adiar_ate_reabrir(tenant, sync, tool, token, reason)

      Client.transient?(reason) ->
        Logger.warning("falha transitória na coleta, será retentada: #{inspect(reason)}")
        Ingestion.broadcast(tenant.id, {:sync_retrying, sync.id, Client.describe_error(reason)})
        {:error, reason}

      true ->
        sync
        |> Ingestion.reload()
        |> Ingestion.finish(:failed, error_reason: Client.describe_error(reason))

        Logger.error("coleta falhou: #{inspect(reason)}")
        Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
        {:error, reason}
    end
  end

  # O sync fica `running` de propósito: ele não falhou, está esperando a janela. Marcar
  # `failed` aqui levaria alguém a investigar uma coleta que vai continuar sozinha — e
  # liberaria o índice que impede duas coletas simultâneas da mesma ferramenta.
  # O RESET vem do próprio erro quando ele o traz — achado da avaliação técnica de
  # 2026-09-05. A REST e a GraphQL têm baldes SEPARADOS (`core` e `graphql`), com reset
  # independente. `segundos_ate_reabrir/3` lê o do GraphQL; um `{:rate_limited, reset}` da
  # REST já carrega o reset do balde `core` no cabeçalho, e consultar o outro faria o job
  # dormir a hora do balde errado.
  defp adiar_ate_reabrir(tenant, sync, tool, token, reason) do
    segundos = segundos_de_espera(reason, tool, token)

    Logger.warning("limite de taxa atingido; a coleta continua em #{segundos}s")
    Ingestion.broadcast(tenant.id, {:sync_paused, sync.id, segundos})

    {:snooze, segundos}
  end

  # REST: o cabeçalho já disse quando o balde `core` reabre — um minuto de folga, porque
  # reabrir no instante exato às vezes ainda recusa.
  defp segundos_de_espera({:rate_limited, %DateTime{} = reset}, _tool, _token),
    do: max(DateTime.diff(reset, DateTime.utc_now(), :second) + 60, 60)

  # O gestor recusou a GraphQL sem saber o reset (a origem recusa sem dizer quando volta).
  defp segundos_de_espera({:rate_limited, nil}, tool, token),
    do: Client.segundos_ate_reabrir(tool.instance_url, token)

  # GraphQL: o erro não traz o reset; `/rate_limit` traz, e não consome cota.
  defp segundos_de_espera(_graphql, tool, token),
    do: Client.segundos_ate_reabrir(tool.instance_url, token)

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
    # Concluída nesta sincronização, não pagina de novo (ADR 0007, parte 4). O cursor
    # sozinho não distinguia "terminou" de "nunca começou" — os dois eram `nil`.
    if Ingestion.etapa_concluida?(ctx.sync, entity_type) do
      :ok
    else
      cursor = Ingestion.resume_cursor(ctx.sync, entity_type)
      do_paginate(ctx, entity_type, query_name, handler, cursor, opts)
    end
  end

  defp do_paginate(ctx, entity_type, query_name, handler, cursor, opts) do
    variables =
      %{organization: ctx.org, page_size: @page_size}
      |> Map.merge(Keyword.get(opts, :extra, %{}))
      |> then(fn vars -> if cursor, do: Map.put(vars, :after, cursor), else: vars end)

    case query(ctx, query_name, variables) do
      {:ok, %{data: data}} ->
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

        # A pausa preventiva saiu daqui: é o gestor de cotas que decide, ANTES de cada
        # requisição, na porta única do cliente (ADR 0007). Quando ele recusa, `query/3`
        # devolve `{:error, {:rate_limited, reset}}` e o job hiberna pelo caminho comum.
        if is_nil(next_cursor),
          do: :ok,
          else: do_paginate(ctx, entity_type, query_name, handler, next_cursor, opts)

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
    Client.graphql(ctx.tool.instance_url, ctx.token, read_query(name), variables,
      cota: ctx[:cota]
    )
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
