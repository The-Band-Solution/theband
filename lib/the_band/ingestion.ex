defmodule TheBand.Ingestion do
  @moduledoc """
  Orquestra a coleta: abre a sincronização, acompanha o progresso e fecha com o
  relatório de FR-028.

  Uma sincronização por ferramenta de cada vez (FR-018), garantida em dois
  níveis: índice único parcial no banco e `unique` no worker Oban. A corrida
  existe nos dois — a segunda requisição HTTP e o segundo job enfileirado.
  """

  import Ecto.Query

  require Logger

  alias TheBand.Ingestion.Checkpoint
  alias TheBand.Ingestion.Sync
  alias TheBand.Jobs.SyncGitHubEO
  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @topic "syncs"

  @doc "Assina as atualizações de progresso de um tenant, para a tela acompanhar ao vivo."
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, @topic <> ":" <> tenant_id)

  @spec broadcast(Ecto.UUID.t(), term()) :: :ok
  def broadcast(tenant_id, message),
    do: Phoenix.PubSub.broadcast(TheBand.PubSub, @topic <> ":" <> tenant_id, message)

  @doc """
  Abre uma sincronização e enfileira o trabalho.

  Devolve `{:error, :already_running}` quando já existe uma em curso — a segunda
  **não** inicia em paralelo, e quem chamou é informado em vez de ver duas
  coletas disputando a mesma janela de API.
  """
  @spec start_sync(Tenant.t(), ConnectedTool.t(), keyword()) ::
          {:ok, Sync.t()}
          | {:error, :already_running | :no_active_credential | :enqueue_failed | term()}
  def start_sync(%Tenant{id: tenant_id} = tenant, %ConnectedTool{} = tool, opts \\ []) do
    # Origem encerrada não é coletada (FR-008). O filtro passa por
    # `observation_ended?/1`, que é o mesmo caminho que a tela usa — dois caminhos
    # discordariam, e a plataforma coletaria do que a tela mostra como encerrado.
    if Sources.observation_ended?(tool) do
      {:error, :observation_ended}
    else
      do_start_sync(tenant_id, tenant, tool, Keyword.get(opts, :worker, SyncGitHubEO))
    end
  end

  defp do_start_sync(tenant_id, tenant, tool, worker) do
    case Sources.active_credential(tool) do
      nil ->
        {:error, :no_active_credential}

      credential ->
        attrs = %{
          tenant_id: tenant_id,
          connected_tool_id: tool.id,
          credential_id: credential.id,
          status: "running",
          started_at: DateTime.utc_now(:second)
        }

        %Sync{}
        |> Sync.changeset(attrs)
        |> Repo.insert()
        |> handle_open(tenant, worker)
    end
  end

  # O resultado da criação do trabalho é **conferido**, e antes não era: ele ia para o
  # vazio. Se a criação falha, o registro fica `running` sem nada para executá-lo — e o
  # índice único passa a bloquear a ferramenta, que é o defeito da issue #175 por outra
  # porta. Ninguém saberia se já aconteceu, porque o retorno era descartado.
  #
  # Encerra **na hora**, e não espera a reconciliação: o motivo dela seria errado. "O
  # processo que a executava não existe mais" afirma que houve processo, e aqui ele nunca
  # existiu.
  defp handle_open({:ok, sync}, tenant, worker) do
    case enqueue(tenant, sync, worker) do
      {:ok, _job} ->
        {:ok, sync}

      {:error, reason} ->
        Logger.error("não foi possível enfileirar a coleta #{sync.id}: #{inspect(reason)}")

        finish(sync, :interrupted,
          error_reason: "o trabalho que a executaria não pôde ser criado"
        )

        {:error, :enqueue_failed}
    end
  end

  # O índice único parcial é a defesa que impede duas coletas simultâneas; aqui
  # ele é traduzido no motivo que a tela precisa exibir.
  defp handle_open({:error, %Ecto.Changeset{errors: errors}}, _tenant, _worker) do
    if Keyword.has_key?(errors, :connected_tool_id),
      do: {:error, :already_running},
      else: {:error, :invalid}
  end

  # O worker é escolha de quem chama, e não vive no registro do `sync`: o que o payload
  # preservado carrega é `raw_entity_type`, e é ele que diz o que foi coletado. Uma
  # coluna de worker guardaria o **como** em vez do **quê**, e envelheceria a cada
  # renomeação de módulo.
  defp enqueue(%Tenant{id: tenant_id}, %Sync{id: sync_id}, worker) do
    %{"tenant_id" => tenant_id, "sync_id" => sync_id}
    |> worker.new()
    |> Oban.insert()
  rescue
    # `Oban.insert/1` levanta quando o worker não é worker — dois dos cinco descartes no
    # dado real vêm de `module is not a worker`. Levantar aqui deixaria o registro `running`,
    # que é exatamente o que esta feature existe para impedir.
    error -> {:error, error}
  end

  # ------------------------------------------------------------------- leitura

  @doc """
  O que **aquela** sincronização trouxe de repositórios e issues.

  Conta por `sync_id` em `raw_payloads`, e não o total do tenant. A primeira versão desta
  função somava o tenant inteiro e exibia o número dentro do cartão de cada sync — o que
  fazia uma coleta de 14 repositórios aparecer com 135 ao lado, porque outra organização
  havia sido coletada depois.

  Contar o estado atual e mostrá-lo como resultado de uma execução é o mesmo erro que a
  coluna `impact` do evento de observação evita: o que interessa é o que foi observado
  **naquele** momento.
  """
  @spec work_summary(Sync.t()) :: %{repositorios: non_neg_integer(), issues: non_neg_integer()}
  def work_summary(%Sync{id: sync_id}) do
    contagens =
      Repo.all(
        from p in "raw_payloads",
          where: p.sync_id == type(^sync_id, :binary_id),
          where: p.raw_entity_type in ["github.repository", "github.issue"],
          group_by: p.raw_entity_type,
          select: {p.raw_entity_type, count(p.id)}
      )
      |> Map.new()

    %{
      repositorios: Map.get(contagens, "github.repository", 0),
      issues: Map.get(contagens, "github.issue", 0)
    }
  end

  @spec list_syncs(Tenant.t(), keyword()) :: [Sync.t()]
  def list_syncs(%Tenant{id: tenant_id}, opts \\ []) do
    query =
      from s in Sync,
        where: s.tenant_id == ^tenant_id,
        order_by: [desc: s.started_at]

    query = if opts[:limit], do: limit(query, ^opts[:limit]), else: query
    Repo.all(query)
  end

  @spec fetch_sync(Tenant.t(), Ecto.UUID.t()) :: {:ok, Sync.t()} | {:error, :not_found}
  def fetch_sync(%Tenant{id: tenant_id}, id) do
    case Repo.one(from s in Sync, where: s.tenant_id == ^tenant_id and s.id == ^id) do
      nil -> {:error, :not_found}
      sync -> {:ok, sync}
    end
  end

  @spec running_sync(ConnectedTool.t()) :: Sync.t() | nil
  def running_sync(%ConnectedTool{id: tool_id}) do
    Repo.one(from s in Sync, where: s.connected_tool_id == ^tool_id and s.status == "running")
  end

  @spec list_checkpoints(Sync.t()) :: [Checkpoint.t()]
  def list_checkpoints(%Sync{id: sync_id}) do
    Repo.all(from c in Checkpoint, where: c.sync_id == ^sync_id, order_by: c.entity_type)
  end

  # ------------------------------------------------------------------ progresso

  @doc """
  Grava o checkpoint de uma página **já processada** (R5, SC-006).

  Chamado depois do processamento, nunca antes.
  """
  @spec checkpoint_page(
          Sync.t(),
          String.t(),
          String.t() | nil,
          non_neg_integer(),
          non_neg_integer() | nil
        ) :: {:ok, Checkpoint.t()} | {:error, Ecto.Changeset.t()}
  def checkpoint_page(%Sync{} = sync, entity_type, cursor, record_count, expected \\ nil) do
    existing =
      Repo.one(
        from c in Checkpoint, where: c.sync_id == ^sync.id and c.entity_type == ^entity_type
      )

    attrs = %{
      tenant_id: sync.tenant_id,
      sync_id: sync.id,
      entity_type: entity_type,
      cursor: cursor,
      page_count: acumular(existing, :page_count, 1),
      record_count: acumular(existing, :record_count, record_count),
      last_page_at: DateTime.utc_now(:second),
      # O esperado ACUMULA, e não guarda o primeiro. Cada chamada corresponde a UMA
      # origem já paginada por inteiro: repositórios vêm numa chamada com o total da
      # organização; issues vêm numa chamada por repositório, cada uma com o total dele.
      #
      # Guardar o primeiro dava `194 de 0`, porque o primeiro repositório coletado é o
      # `.github`, que tem zero issues — e `0 || novo` devolve 0 em Elixir.
      expected_count: acumular_esperado(existing, expected),
      status: if(cursor, do: "running", else: "completed")
    }

    (existing || %Checkpoint{})
    |> Checkpoint.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Cursor de onde retomar, quando a coleta foi interrompida (FR-015)."
  @spec resume_cursor(Sync.t(), String.t()) :: String.t() | nil
  def resume_cursor(%Sync{id: sync_id}, entity_type) do
    Repo.one(
      from c in Checkpoint,
        where: c.sync_id == ^sync_id and c.entity_type == ^entity_type,
        select: c.cursor
    )
  end

  @doc "Acumula o resultado de uma escrita no relatório da sincronização (FR-028)."
  @spec tally(
          Sync.t(),
          :created
          | :updated
          | :unchanged
          | :repository_unreachable
          | :repository_skipped
          | {:skipped, String.t()}
        ) ::
          {:ok, Sync.t()} | {:error, Ecto.Changeset.t()}
  def tally(%Sync{} = sync, outcome) do
    attrs =
      case outcome do
        :created ->
          %{
            records_collected: sync.records_collected + 1,
            records_created: sync.records_created + 1
          }

        :updated ->
          %{
            records_collected: sync.records_collected + 1,
            records_updated: sync.records_updated + 1
          }

        :unchanged ->
          %{records_collected: sync.records_collected + 1}

        # Conta **repositório**, e por isso não passa por `records_*`: aqueles contam registros,
        # e somar 39 repositórios ali faria a soma que a tela exibe mentir.
        #
        # Incrementado **a cada falha**, nunca no fim da fase: coleta interrompida antes do fim
        # ficaria com zero, e zero afirma que tudo foi alcançado. É a mesma regra do checkpoint —
        # registrar depois de processar, por item.
        :repository_unreachable ->
          %{repositories_unreachable: sync.repositories_unreachable + 1}

        # Conta **repositório**, e pelo mesmo motivo do de cima não passa por `records_*`:
        # aqueles contam registros, e somar repositórios ali faria a soma que a tela exibe
        # mentir.
        #
        # Incrementado a cada pulo, e não no fim da fase: coleta interrompida no meio ficaria
        # com zero, e zero afirma que tudo foi percorrido.
        :repository_skipped ->
          %{repositories_skipped: sync.repositories_skipped + 1}

        {:skipped, reason} ->
          %{
            records_collected: sync.records_collected + 1,
            records_skipped: sync.records_skipped + 1,
            skip_reasons: Map.update(sync.skip_reasons, reason, 1, &(&1 + 1))
          }
      end

    sync |> Sync.changeset(attrs) |> Repo.update()
  end

  @spec finish(Sync.t(), :completed | :failed | :interrupted, keyword()) ::
          {:ok, Sync.t()} | {:error, Ecto.Changeset.t()}
  def finish(%Sync{} = sync, status, opts \\ []) do
    attrs =
      %{
        status: to_string(status),
        finished_at: DateTime.utc_now(:second),
        error_reason: opts[:error_reason]
      }
      |> then(fn attrs ->
        case opts[:memberships_pending_role] do
          nil -> attrs
          n -> Map.put(attrs, :memberships_pending_role, n)
        end
      end)
      |> then(fn attrs ->
        # Ausente quando quem encerrou foi a plataforma, e a ausência é a afirmação.
        case opts[:interrupted_by_user_id] do
          nil -> attrs
          id -> Map.put(attrs, :interrupted_by_user_id, id)
        end
      end)

    sync |> Sync.changeset(attrs) |> Repo.update()
  end

  defp acumular(nil, _campo, incremento), do: incremento
  defp acumular(existing, campo, incremento), do: Map.fetch!(existing, campo) + incremento

  defp acumular_esperado(_existing, nil), do: nil
  defp acumular_esperado(nil, novo), do: novo
  defp acumular_esperado(%{expected_count: nil}, novo), do: novo
  defp acumular_esperado(%{expected_count: atual}, novo), do: atual + novo

  @spec reload(Sync.t()) :: Sync.t()
  def reload(%Sync{id: id}), do: Repo.get!(Sync, id)

  # ------------------------------------------------- execução presa (feature 008)

  # Duas noções de "vivo", e confundi-las é o defeito que a execução no dado real revelou.
  #
  # `@ativos` — o que **impede o encerramento automático**. Inclui `executing`, porque a
  # plataforma não pode encerrar por conta própria uma execução que talvez esteja rodando:
  # encerrar libera o índice, e uma coleta nova rodaria **em paralelo** com a que continua.
  #
  # `@vai_executar` — o que a plataforma consegue **provar**. A fila vai pegar o trabalho em
  # `available`, `scheduled`, `retryable` e `suspended`, e isso é verificável. `executing`
  # **não** é prova de vida: é um claim que sobrevive ao processo que o fez. O job 5 do banco
  # de desenvolvimento está `executing` desde 2026-08-09, num nó que não existe mais.
  #
  # É por isso que a ação humana existe (US3): só uma pessoa sabe que reiniciou a aplicação,
  # e a plataforma não tem como saber.
  #
  # As duas listas são **derivadas** de `Oban.Job.states/0`, nunca copiadas: uma versão nova
  # do Oban que acrescente estado entraria em silêncio numa lista literal — e a primeira
  # versão desta feature já errou assim, esquecendo `suspended`.
  @terminais ~w(completed discarded cancelled)
  @ativos Enum.map(Oban.Job.states(), &to_string/1) -- @terminais
  @vai_executar @ativos -- ["executing"]

  # A execução recém-aberta não é candidata. Abrir o registro e criar o trabalho são duas
  # operações, e no intervalo a execução tem a assinatura exata de "presa" — `running` e sem
  # trabalho. O intervalo real é de milissegundos; um minuto é margem de três ordens de
  # grandeza. Falha na criação **não** espera a carência: `start_sync/3` encerra na hora.
  # Falha isolada não é sinal; repetida é. Três é o número que a tela declara.
  @falhas_para_avisar 3

  @carencia_segundos 60

  @doc """
  Encerra toda execução `running` cujo trabalho não existe mais.

  **Atravessa tenants de propósito**: é manutenção da plataforma, não consulta de tenant, e
  nenhum dado de um tenant chega a outro. A ação **por pessoa** continua escopada, em
  `interrupt_sync/3`.

  Devolve as execuções que encerrou. Lista vazia é o caso normal, e **não** produz log:
  ruído periódico treina quem lê a ignorar o log, e aí o log que importa passa batido.

  A decisão é **ausência de trabalho ativo**, nunca idade. Uma coleta de 16 minutos é
  indistinguível de uma coleta morta pela idade, e encerrar coleta viva derruba trabalho em
  andamento — pior que o bloqueio que esta função existe para resolver.
  """
  @spec reconcile_stuck_syncs() :: {:ok, [Sync.t()]}
  def reconcile_stuck_syncs do
    limite = DateTime.add(DateTime.utc_now(:second), -@carencia_segundos, :second)

    encerradas =
      from(s in Sync, where: s.status == "running" and s.started_at <= ^limite)
      |> Repo.all()
      |> Enum.reject(&trabalho_ativo?/1)
      |> Enum.flat_map(fn sync ->
        case finish(sync, :interrupted, error_reason: motivo(sync)) do
          {:ok, encerrada} ->
            Logger.warning(
              "sincronização #{sync.id} encerrada pela plataforma: #{encerrada.error_reason}"
            )

            [encerrada]

          {:error, _} ->
            []
        end
      end)

    {:ok, encerradas}
  end

  @doc """
  Enfileira a coleta das ferramentas **vencidas** — issue #443.

  ## Por que estado, e não uma entrada por ferramenta no cron

  A sincronização nunca foi agendada: o `crontab` tinha o reconciliador e a rodada mensal, e
  o único disparo era o botão na tela. Medido em 2026-08-19, os dois maiores tenants estavam
  há **cinco dias** sem coleta completa — e, sem periodicidade, ninguém esperava que
  houvesse.

  Uma entrada por ferramenta no `crontab` cresceria com o número de tenants e exigiria
  implantar para mudar o ritmo, que é decisão de quem administra. Este trabalho olha
  **estado**: quem tem intervalo, e quando rodou por último. É o mesmo motivo que
  `ReconcileStuckSyncs` documenta — estado sobrevive a reinício e a nó que morre sem avisar.

  ## O que impede coleta em cima de coleta

  Três guardas, e cada uma cobre um caso que as outras não:

    * `sync_interval_minutes` nulo → **manual**, não entra;
    * já existe coleta `running` para a ferramenta → não enfileira. Sem isto, uma coleta que
      leva mais que o intervalo seria disparada de novo, e a plataforma coletaria duas vezes
      o mesmo — é a L02, onde 32 registros apareceram no lugar de 16 e o número pareceu
      plausível;
    * `start_sync/3` recusa observação encerrada e credencial ausente, e é a mesma função
      que a tela chama. Dois caminhos discordariam.

  ## A ferramenta que falha repetidamente CONTINUA sendo tentada

  Marcar como precisando de atenção é aviso, não bloqueio. Parar de tentar transformaria uma
  falha transitória em permanente, e a plataforma deixaria de coletar sem que ninguém
  tivesse decidido isso.
  """
  @spec enqueue_due_syncs() :: {:ok, %{enqueued: integer(), skipped_running: integer()}}
  def enqueue_due_syncs do
    vencidas()
    |> Enum.reduce({:ok, %{enqueued: 0, skipped_running: 0}}, fn tool, {:ok, acc} ->
      if coleta_em_andamento?(tool) do
        {:ok, %{acc | skipped_running: acc.skipped_running + 1}}
      else
        {:ok, %{acc | enqueued: acc.enqueued + enfileirar(tool)}}
      end
    end)
  end

  # Vencida é: tem intervalo, e nunca rodou ou rodou antes do corte. `is_nil(last_sync_at)`
  # entra porque ferramenta recém-configurada precisa da primeira coleta — esperar um
  # intervalo inteiro faria "a cada 6 horas" significar "em 6 horas".
  defp vencidas do
    Repo.all(
      from t in ConnectedTool,
        where:
          not is_nil(t.sync_interval_minutes) and
            (is_nil(t.last_sync_at) or
               t.last_sync_at <=
                 ago(t.sync_interval_minutes, "minute")),
        order_by: [asc_nulls_first: t.last_sync_at]
    )
  end

  # **Por TENANT, e não por ferramenta** — issue #446.
  #
  # A guarda por ferramenta impedia a mesma organização de coletar duas vezes, e era o
  # suficiente enquanto cada coleta percorria só os repositórios dela. Mas as três coletas de
  # um tenant compartilham duas coisas que a ferramenta não sabe:
  #
  #   * **a janela de rate limit**, que é da conta do GitHub e não da organização;
  #   * **o pool de conexões do banco**, que já esgotou em `too many clients already` com
  #     duas cargas concorrentes.
  #
  # Serializar custa tempo de parede — um tenant com três organizações leva três ciclos em
  # vez de um. Num intervalo de seis horas isso não é custo; num pico de rate limit, o
  # contrário é.
  #
  # Vale **só para o agendador**. O botão na tela continua por ferramenta: uma pessoa
  # clicando três vezes está decidindo, e recusar a decisão dela seria surpresa.
  defp coleta_em_andamento?(%ConnectedTool{tenant_id: tenant_id}) do
    Repo.exists?(from s in Sync, where: s.tenant_id == ^tenant_id and s.status == "running")
  end

  defp enfileirar(%ConnectedTool{tenant_id: tenant_id} = tool) do
    with {:ok, tenant} <- TheBand.Tenants.fetch(tenant_id),
         {:ok, _sync} <- start_sync(tenant, tool) do
      Logger.info(
        "coleta automática enfileirada para #{tool.organization_login} " <>
          "(intervalo de #{tool.sync_interval_minutes} min, última em #{inspect(tool.last_sync_at)})"
      )

      1
    else
      # Recusa esperada — observação encerrada, credencial ausente, coleta já em andamento.
      # Não é falha do agendador, e virar erro faria o trabalho periódico parecer quebrado a
      # cada cinco minutos. `debug` e não `warning` pelo mesmo motivo: ferramenta em manual
      # com observação encerrada é estado normal, e avisar sobre ele todo ciclo afogaria o
      # aviso que importa.
      {:error, motivo} ->
        Logger.debug(
          "coleta automática de #{tool.organization_login} não enfileirada: #{inspect(motivo)}"
        )

        0
    end
  end

  @doc """
  Descreve quando a próxima coleta automática acontece — a frase que a tela mostra.

  Devolve `:manual` quando não há intervalo, `:vencida` quando já passou da hora, ou
  `{:em, segundos}`. Três respostas e não uma string porque a tela decide o rótulo; devolver
  texto daqui espalharia vocabulário de interface pelo contexto.
  """
  @spec proxima_coleta(ConnectedTool.t()) :: :manual | :vencida | {:em, integer()}
  def proxima_coleta(%ConnectedTool{sync_interval_minutes: nil}), do: :manual
  def proxima_coleta(%ConnectedTool{last_sync_at: nil}), do: :vencida

  def proxima_coleta(%ConnectedTool{} = tool) do
    proxima = DateTime.add(tool.last_sync_at, tool.sync_interval_minutes * 60, :second)
    restam = DateTime.diff(proxima, DateTime.utc_now(:second))

    if restam <= 0, do: :vencida, else: {:em, restam}
  end

  @doc """
  Marca as ferramentas cuja coleta falha repetidamente — issue #443.

  ## Por que isto existe

  A sincronização agendada morreu em **três tenants por duas semanas** com o mesmo
  `KeyError`, e nada avisou. O registro ficava `interrupted`, o Oban desistia depois de
  cinco tentativas, e a única maneira de descobrir era abrir a tabela `syncs`.

  Falha isolada não é sinal — rede cai, a origem devolve 502, o nó reinicia. **Falha
  repetida é.** O que distingue as duas é a contagem, e é ela que este trabalho olha.

  ## O limiar é declarado, não escondido

  #{@falhas_para_avisar} coletas consecutivas sem completar. O número aparece na tela junto
  com o aviso: limiar escondido faz quem lê achar que é propriedade do dado, e não escolha
  de quem mediu.

  ## O que conta como falha, e o que não

  `failed` e `interrupted` contam. `running` **não** interrompe a sequência nem conta: a
  coleta em andamento ainda não decidiu nada, e tratá-la como sucesso limparia o aviso de
  quem está falhando agora.

  ## Coleta que completa limpa o aviso

  Uma sincronização completa é evidência de que a ferramenta responde e a credencial vale —
  qualquer motivo de atenção anterior descreve um estado que deixou de valer.
  """
  @spec flag_tools_failing_repeatedly() :: {:ok, %{flagged: integer(), cleared: integer()}}
  def flag_tools_failing_repeatedly do
    Repo.all(from t in ConnectedTool, order_by: t.id)
    |> Enum.reduce({:ok, %{flagged: 0, cleared: 0}}, fn tool, {:ok, acc} ->
      case avaliar_sequencia(tool) do
        {:falhando, quantas, motivo} ->
          {:ok, _} = Sources.mark_needs_attention(tool, frase_de_falha(quantas, motivo))
          {:ok, %{acc | flagged: acc.flagged + 1}}

        :saudavel ->
          {:ok, %{acc | cleared: acc.cleared + limpar_se_marcada(tool)}}

        :sem_dado ->
          {:ok, acc}
      end
    end)
  end

  # As últimas coletas DECIDIDAS da ferramenta, da mais recente para a mais antiga. A em
  # andamento é ignorada: ela ainda não decidiu, e contá-la de um lado ou de outro seria
  # afirmar resultado que não existe.
  defp avaliar_sequencia(%ConnectedTool{id: tool_id}) do
    decididas =
      Repo.all(
        from s in Sync,
          where: s.connected_tool_id == ^tool_id and s.status != "running",
          order_by: [desc: s.started_at],
          limit: @falhas_para_avisar,
          select: %{status: s.status, error_reason: s.error_reason}
      )

    consecutivas = Enum.take_while(decididas, &(&1.status in ["failed", "interrupted"]))

    cond do
      decididas == [] -> :sem_dado
      length(consecutivas) >= @falhas_para_avisar -> falhando(consecutivas)
      true -> :saudavel
    end
  end

  defp falhando(consecutivas) do
    motivo = Enum.find_value(consecutivas, &(&1.error_reason not in [nil, ""] && &1.error_reason))
    {:falhando, length(consecutivas), motivo}
  end

  # A frase que a pessoa lê. Diz **quantas**, **o limiar** e **o motivo da origem** — sem os
  # três, o aviso obriga a ir ao banco para saber o que fazer, que é o problema que ele
  # existe para resolver.
  defp frase_de_falha(quantas, nil) do
    "#{quantas} coletas seguidas não completaram (o aviso aparece a partir de " <>
      "#{@falhas_para_avisar}). Nenhuma delas registrou motivo — verifique o log da coleta."
  end

  defp frase_de_falha(quantas, motivo) do
    "#{quantas} coletas seguidas não completaram (o aviso aparece a partir de " <>
      "#{@falhas_para_avisar}). A última falha disse: #{motivo}"
  end

  defp limpar_se_marcada(%ConnectedTool{needs_attention_since: nil}), do: 0

  defp limpar_se_marcada(tool) do
    {:ok, _} = Sources.clear_needs_attention(tool)
    1
  end

  @doc """
  Encerra por **decisão humana**, e grava o autor.

  `:job_alive` é a defesa que o `:not_found` não dá: sem ela, a ação da tela seria o caminho
  para derrubar uma coleta viva por engano. A tela reconfere aqui, e não confia no próprio
  botão — entre desenhar e clicar, a coleta pode ter voltado a executar.
  """
  @spec interrupt_sync(Tenant.t(), Ecto.UUID.t(), User.t()) ::
          {:ok, Sync.t()} | {:error, :not_found | :not_running | :job_alive}
  def interrupt_sync(%Tenant{} = tenant, sync_id, %User{} = user) do
    with {:ok, sync} <- fetch_sync(tenant, sync_id),
         :ok <- confirmar_running(sync),
         :ok <- confirmar_sem_trabalho(sync) do
      finish(sync, :interrupted,
        error_reason: motivo_humano(sync, user),
        interrupted_by_user_id: user.id
      )
    end
  end

  @doc """
  Se o que sustenta esta execução é um trabalho **em execução** que a plataforma não pode
  verificar.

  Existe para a tela avisar o risco certo: encerrar aqui é decisão de quem sabe que o
  processo morreu, e se a coleta estiver de fato rodando uma segunda começa em paralelo.
  """
  @spec claimed_by_dead_process?(Sync.t()) :: boolean()
  def claimed_by_dead_process?(%Sync{id: sync_id}) do
    Repo.exists?(from j in trabalhos(sync_id), where: j.state == "executing")
  end

  @doc """
  Se a tela deve **oferecer** a ação de encerrar.

  Consulta de exibição, e não a decisão: quem decide é `interrupt_sync/3`, que reconfere.
  """
  @spec interruptible?(Sync.t()) :: boolean()
  def interruptible?(%Sync{status: "running"} = sync), do: not vai_executar?(sync)
  def interruptible?(%Sync{}), do: false

  # O motivo diz **o que a pessoa afirmou**, e não o que a plataforma observou. Quando há
  # trabalho `executing`, ela está afirmando que o processo morreu — informação que só ela
  # tem, e que o registro precisa carregar para quem lê depois.
  defp motivo_humano(sync, user) do
    quem = user.name || user.email

    if Repo.exists?(from j in trabalhos(sync.id), where: j.state == "executing") do
      "encerrada por #{quem}: o trabalho constava em execução, e o processo não existe mais"
    else
      "encerrada por #{quem}"
    end
  end

  defp confirmar_running(%Sync{status: "running"}), do: :ok
  defp confirmar_running(%Sync{}), do: {:error, :not_running}

  # A pessoa pode encerrar o que a plataforma não consegue provar vivo — inclusive o caso do
  # trabalho `executing` num nó que morreu, que é o que aconteceu duas vezes e motivou a issue
  # #175. O que ela **não** pode encerrar é trabalho que a fila vai pegar: aí a coleta começa
  # sozinha, e encerrar o registro faria duas rodarem juntas.
  defp confirmar_sem_trabalho(sync) do
    if vai_executar?(sync), do: {:error, :job_alive}, else: :ok
  end

  defp trabalho_ativo?(%Sync{id: sync_id}) do
    Repo.exists?(from j in trabalhos(sync_id), where: j.state in @ativos)
  end

  defp vai_executar?(%Sync{id: sync_id}) do
    Repo.exists?(from j in trabalhos(sync_id), where: j.state in @vai_executar)
  end

  # A ligação é pelos args porque o sync **não guarda** id de job: pôr um lá seria
  # identificador de fila dentro do registro de domínio. Os args são escritos por
  # `enqueue/3`, no mesmo módulo que os lê.
  defp trabalhos(sync_id) do
    from j in Oban.Job, where: fragment("? ->> 'sync_id' = ?", j.args, ^sync_id)
  end

  # O motivo depende da causa, e **nunca inventa falha que ninguém observou**. Ausência de
  # trabalho é dita como ausência: dizer "erro" ali afirmaria uma falha que a plataforma não
  # viu, e apagaria a diferença entre falha transitória e permanente — a L29.
  defp motivo(%Sync{id: sync_id}) do
    consulta =
      from j in trabalhos(sync_id),
        where: j.state == "discarded",
        order_by: [desc: j.attempted_at, desc: j.id],
        limit: 1

    case Repo.one(consulta) do
      nil ->
        "o processo que a executava não existe mais"

      job ->
        "as tentativas se esgotaram (#{job.attempt} de #{job.max_attempts}): #{ultimo_erro(job)}"
    end
  end

  defp ultimo_erro(%Oban.Job{errors: errors}) when is_list(errors) and errors != [] do
    errors
    |> List.last()
    |> Map.get("error", "sem detalhe registrado")
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 300)
  end

  defp ultimo_erro(%Oban.Job{}), do: "sem detalhe registrado"
end
